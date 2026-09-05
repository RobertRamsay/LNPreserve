"""Check disk integrity, C64 pixel decoding and every registered GM resource."""
from pathlib import Path
import hashlib,json,sys,unittest,wave
from PIL import Image
from extract_disks import sector_offset,chain,directory
from decode_graphics import decode_object,decode_dataset,render_panel,PALETTE
from build_project import read_json
ROOT=Path(__file__).resolve().parents[1];PROJECT=ROOT/'LNPreserve'

class ConversionChecks(unittest.TestCase):
    def test_ln3_opening_scene_matches_captured_original_bitmap(self):
        manifest=read_json(PROJECT/'datafiles/graphics/manifest.json')
        dataset=next(d for d in manifest['datasets'] if d['id']=='ln3_game_level1')
        scene=next(s for s in dataset['locations'] if s['id']==0)
        with Image.open(PROJECT/scene['path']) as im:
            self.assertEqual(hashlib.sha256(im.convert('RGBA').tobytes()).hexdigest(),
                '653095de7697c7aa09afb69b4601fcfea917af92f19bf2f7dbc73cdcfd704f2a')

    def test_panel_final_record_and_horizontal_reversal(self):
        # Two-record PRG: asymmetric bitmap, then a mirrored panel placement.
        # The final placement + terminator occupy just four bytes at EOF.
        payload=bytearray(0x47);payload[:3]=bytes([2,0,8])
        payload[3:0x43]=bytes([255])*64;payload[3:5]=bytes([1,0])
        payload[0x43:0x47]=bytes([0x47,0x88,0x52,0x08])
        payload.extend(bytes([0x11]+[0x1b]*8+[0x12,3]))
        payload.extend(bytes([0,0x8e,14,255]))
        for game in (2,3):
            data,_=decode_dataset(b'\0\x08'+payload,game)
            self.assertEqual(data['issues'],[])
            self.assertEqual(len(data['panels']['1']['entries']),1)
            image,mask,warnings=render_panel(data,1,0)
            self.assertEqual([image.getpixel((x,0))[:3] for x in range(8)],
                             [PALETTE[c] for c in (3,3,2,2,1,1,0,0)])
            self.assertIsNone(mask.getchannel('A').getbbox())
            self.assertEqual(warnings,[])
            # Terminator alone at EOF is also a complete empty panel.
            empty=payload[:-4]+b'\xff'
            data,_=decode_dataset(b'\0\x08'+empty,game)
            self.assertEqual(data['issues'],[])
            self.assertEqual(data['panels']['1']['entries'],[])

    def test_cleaned_assets_keep_all_source_references(self):
        manifest=read_json(PROJECT/'datafiles/graphics/manifest.json')
        catalog={d['id']:d for d in read_json(PROJECT/'datafiles/catalog.json')['datasets']}
        unique={};source_count=0
        for dataset in manifest['datasets']:
            if dataset['game']>1:self.assertEqual(dataset['issues'],[])
            for role in ('objects','locations'):
                shown=catalog[dataset['id']][role]
                self.assertEqual(len(shown),len({r['sprite_name'] for r in shown}))
                key='source_id' if role=='objects' else 'id'
                self.assertEqual(sorted(r[key] for r in dataset[role]),sorted(i for r in shown for i in r['source_ids']))
                for r in dataset[role]:
                    source_count+=1;path=PROJECT/r['path']
                    with Image.open(path) as im:
                        rgba=im.convert('RGBA');fingerprint=(role,im.size,hashlib.sha256(rgba.tobytes()).hexdigest())
                        self.assertEqual(unique.setdefault(fingerprint,r['path']),r['path'])
                        if role=='locations':self.assertEqual(im.size,(240,144))
                    if role=='locations':
                        self.assertFalse(any(w.startswith('unresolved_record_') for w in r['warnings']))
        self.assertEqual(source_count,2033)
        self.assertEqual(len(unique),manifest['image_deduplication']['unique_images'])
        names={r['id']['name'] for r in read_json(PROJECT/'LNPreserve.yyp')['resources']}
        self.assertNotIn('spr_ln1_water_ripple',names)
        self.assertTrue(all(r['sprite_name'] in names for d in catalog.values() for role in ('objects','locations') for r in d[role]))

    def test_ln2_loader_tail_objects_are_present(self):
        for level,panel,obj in ((1,4,0),(2,2,1),(3,2,1),(4,3,2),(5,4,3),(6,4,3),(7,4,3)):
            scene=read_json(PROJECT/f'datafiles/graphics/ln2_loader_level{level}/scene_data.json')
            self.assertEqual(scene['panels'][str(panel)]['entries'][-1]['object'],obj)

    def test_disk_sector_boundaries_and_last_byte(self):
        self.assertEqual(sector_offset(18,0),17*21*256)
        self.assertEqual(sector_offset(35,16)+256,174848)
        with self.assertRaises(ValueError):sector_offset(18,19)
        disk=bytearray(174848);offset=sector_offset(1,0)
        disk[offset:offset+4]=bytes([0,3,0x41,0x42])
        self.assertEqual(chain(disk,1,0)[0],b'AB')
        disk[offset:offset+2]=bytes([1,0])
        with self.assertRaisesRegex(ValueError,'Cyclic'):chain(disk,1,0)

    def test_supplied_disk_hashes_and_extracted_file_bytes(self):
        report=json.loads((ROOT/'evidence/disk_inventory.json').read_text())
        checked=0
        for archive in report['archives']:
            for disk in archive['disks']:
                path=ROOT/'source/local'/disk['id']/'disk.d64'
                if not path.exists():continue
                data=path.read_bytes();self.assertEqual(hashlib.sha256(data).hexdigest(),disk['sha256'])
                entries=directory(data);self.assertEqual(len(entries),len(disk['entries']))
                for actual,record in zip(entries,disk['entries']):
                    self.assertNotIn('error',actual)
                    self.assertEqual(actual['sha256'],record['sha256'])
                    self.assertEqual(actual['_data'],(ROOT/record['path']).read_bytes())
                checked+=1
        if not checked:self.skipTest('Original disks are local inputs; extract ZIPs to enable this check')
        self.assertEqual(checked,8)

    def test_c64_multicolour_pairs_and_transparent_zero(self):
        # One C64 cell: codes 00,01,10,11; two pixels per code.
        data=bytes([0x11]+[0x1b]*8+[0x12,0x83])
        metadata,image=decode_object(data,0)
        self.assertEqual(image.size,(8,8));self.assertEqual(metadata['colour'],[0x83])
        self.assertEqual(image.getpixel((0,0))[3],0)
        for x,index in ((2,1),(4,2),(6,3)):
            self.assertEqual(image.getpixel((x,0)),(*PALETTE[index],255))
            self.assertEqual(image.getpixel((x,0)),image.getpixel((x+1,0)))
        with self.assertRaises(ValueError):decode_object(bytes([0xff]),0)

    def test_registered_resources_and_png_layers_exist(self):
        project=read_json(PROJECT/'LNPreserve.yyp');names=set()
        for ref in project['resources']:
            name=ref['id']['name'];self.assertNotIn(name,names);names.add(name)
            path=PROJECT/ref['id']['path'];self.assertTrue(path.is_file(),str(path))
            obj=read_json(path);self.assertEqual(obj['name'],name)
            if obj['resourceType']=='GMSprite':
                for frame in obj['frames']:
                    image=path.parent/(frame['name']+'.png')
                    with Image.open(image) as png:self.assertEqual(png.size,(obj['width'],obj['height']))
                    for layer in obj['layers']:
                        self.assertTrue((path.parent/'layers'/frame['name']/(layer['name']+'.png')).is_file())
            elif obj['resourceType']=='GMSound':
                with wave.open(str(path.parent/obj['soundFile'])) as audio:self.assertGreater(audio.getnframes(),0)
        for included in project['IncludedFiles']:
            self.assertTrue((PROJECT/included['filePath']/included['name']).is_file())
        self.assertFalse(project['TextureGroups'][0]['autocrop'],'Mask texture coordinates require full transparent bounds')

if __name__=='__main__':
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(ConversionChecks)
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    report=dict(tests_run=result.testsRun,failures=len(result.failures),errors=len(result.errors),
                skipped=len(result.skipped),passed=result.wasSuccessful(),original_gameplay_parity='not_tested')
    (ROOT/'evidence/structural_checks.json').write_text(json.dumps(report,indent=2)+'\n')
    sys.exit(not result.wasSuccessful())
