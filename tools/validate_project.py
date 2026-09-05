"""Check disk integrity, C64 pixel decoding and every registered GM resource."""
from pathlib import Path
import hashlib,json,sys,unittest,wave
from PIL import Image
from extract_disks import sector_offset,chain,directory
from decode_graphics import decode_object,PALETTE
from build_project import read_json
ROOT=Path(__file__).resolve().parents[1];PROJECT=ROOT/'LNPreserve'

class ConversionChecks(unittest.TestCase):
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
