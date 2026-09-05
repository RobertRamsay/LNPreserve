"""Compare exported scenery with a saved baseline and original-game pixels."""
import argparse, hashlib, json
from PIL import Image, ImageDraw
from decode_graphics import ROOT, PROJECT, PALETTE
from build_project import read_json

BASELINE=ROOT/'build/scenery-colour-baseline'
CANDIDATES=ROOT/'build/scenery-colour-candidates'

def pixels_hash(image):
    return hashlib.sha256(image.convert('RGBA').tobytes()).hexdigest()

def difference(left,right):
    return sum(a!=b for a,b in zip(left.convert('RGBA').get_flattened_data(),right.convert('RGBA').get_flattened_data()))

def capture():
    BASELINE.mkdir(exist_ok=True)
    if (BASELINE/'manifest.json').exists():raise ValueError('Baseline already exists; refusing to replace evidence')
    manifest=read_json(PROJECT/'datafiles/graphics/manifest.json')
    for dataset in manifest['datasets']:
        for loc in dataset['locations']:
            with Image.open(PROJECT/loc['path']) as im:im.save(BASELINE/(loc['name']+'.png'))
    (BASELINE/'manifest.json').write_text(json.dumps(manifest))

def stage():
    # Review-only: write candidate PNGs under ignored build/, never under the
    # project. Applying a broad regeneration is a separate approval decision.
    from original_scene_renderer import OriginalSceneRenderer
    from reference_scene_oracle import SceneOracle
    manifest=read_json(PROJECT/'datafiles/graphics/manifest.json')
    CANDIDATES.mkdir(exist_ok=True)
    reference=SceneOracle(2)
    for dataset in manifest['datasets']:
        game=dataset['game'];tag='ln' if game==1 else f'ln{game}'
        root=next((ROOT/f'tools/vendor/integrator-{tag}').glob('*/integrator-files'))
        raw=(root/dataset['provenance']['reference_file']).read_bytes()
        original=OriginalSceneRenderer(game,raw) if game in (1,3) else None
        data=read_json(PROJECT/dataset['scene_data'])
        for loc in dataset['locations']:
            image=original.render(loc['id']) if original else reference.render(data,loc['panel'],loc['background'])
            image.save(CANDIDATES/(loc['name']+'.png'))
        print(dataset['id'],len(dataset['locations']),'candidate scenes',flush=True)

def verify(staged=False):
    manifest=read_json(PROJECT/'datafiles/graphics/manifest.json');records=[];examples=[]
    for dataset in manifest['datasets']:
        for loc in dataset['locations']:
            old=Image.open(BASELINE/(loc['name']+'.png')).convert('RGBA')
            new=Image.open(CANDIDATES/(loc['name']+'.png') if staged else PROJECT/loc['path']).convert('RGBA')
            count=difference(old,new)
            records.append(dict(dataset=dataset['id'],scene=loc['id'],changed_pixels=count,
                before_sha256=pixels_hash(old),after_sha256=pixels_hash(new)))
            if (dataset['id'],loc['id']) in [('ln3_game_level1',0),('ln2_game_level1',1),('ln1_game_level1',9)]:
                examples.append((dataset['id'],loc['id'],count,old,new))
    # Original VICE display state: bitmap E000, screen CC00, colour I/O D800,
    # background VIC D021=5. Decode indices with the same chosen C64 palette.
    ram=(ROOT/'source/local/captures/ln3-advance2-ram.bin').read_bytes()
    colour=(ROOT/'source/local/captures/ln3-colour.bin').read_bytes()
    original=Image.new('RGBA',(240,144));pixels=[]
    for y in range(144):
        for x in range(240):
            cell=y//8*40+x//8;code=(ram[0xe000+cell*8+y%8]>>(6-(x%8//2)*2))&3
            c=[5,ram[0xcc00+cell]>>4,ram[0xcc00+cell]&15,colour[cell]&15][code]
            pixels.append((*PALETTE[c],255))
    original.putdata(pixels);original.save(ROOT/'evidence/ln3_original_scene_01.png')
    dataset=next(d for d in manifest['datasets'] if d['id']=='ln3_game_level1')
    loc=next(l for l in dataset['locations'] if l['id']==0)
    final=Image.open(CANDIDATES/(loc['name']+'.png') if staged else PROJECT/loc['path']).convert('RGBA');mismatch=difference(original,final)
    if mismatch:raise AssertionError(f'LN3 opening scene differs from original display by {mismatch} pixels')
    native=[]
    dataset=next(d for d in manifest['datasets'] if d['id']=='ln1_game_level1')
    for scene in range(1,26):
        loc=next(l for l in dataset['locations'] if l['id']==scene)
        expected=Image.open(PROJECT/f'datafiles/play/ln1/spr_ln1_wastelands_room_{scene:02}.png')
        actual=Image.open(CANDIDATES/(loc['name']+'.png') if staged else PROJECT/loc['path']);count=difference(expected,actual)
        native.append(dict(scene=scene,differing_pixels=count))
    if any(r['differing_pixels'] for r in native):raise AssertionError('LN1 scenery differs from original-code gameplay backgrounds')
    # Verify the editable sprite and its layer, not just the export directory.
    checked=set()
    for dataset in ([] if staged else manifest['datasets']):
        for loc in dataset['locations']:
            name='spr_'+loc['canonical_name']
            if name in checked:continue
            checked.add(name);folder=PROJECT/'sprites'/name;meta=read_json(folder/(name+'.yy'))
            expected=Image.open(PROJECT/loc['path'])
            for frame in meta['frames']:
                for path in [folder/(frame['name']+'.png')]+[folder/'layers'/frame['name']/(l['name']+'.png') for l in meta['layers']]:
                    if difference(expected,Image.open(path)):raise AssertionError(f'Stale GameMaker pixels: {path}')
    report=dict(scope='Static scenery only; original input timing and full-game parity excluded',
        candidates_only=staged,
        changed_scene_records=sum(r['changed_pixels']>0 for r in records),scene_records=len(records),
        original_ln3_level1_scene0=dict(differing_pixels=mismatch,pixels=240*144,
            source_ram_sha256=hashlib.sha256(ram).hexdigest(),colour_ram_sha256=hashlib.sha256(colour).hexdigest(),
            pixel_sha256=pixels_hash(original),dataset_payload_matches_supplied_game=True),
        ln1_native_background_comparisons=native,editable_scene_sprites_checked=len(checked),
        limitations=['LN2 renderer is the independent Integrator reference, not supplied-game display verification',
            'LN3 levels 2-5 use the recovered original level-1 drawing routine with reference datasets; their supplied-disk identity is unverified',
            'LN3 scenes beyond the opening scene have no independent VICE display comparison'],records=records)
    (ROOT/'evidence/scenery_colour_audit.json').write_text(json.dumps(report,indent=2)+'\n')
    sheet=Image.new('RGB',(976,len(examples)*332),(24,26,30));draw=ImageDraw.Draw(sheet)
    for row,(name,scene,count,old,new) in enumerate(examples):
        y=row*332;draw.text((8,y+8),f'{name}, source scene {scene}: {count} corrected pixels',fill='white')
        draw.text((8,y+26),'Before',fill='white');draw.text((496,y+26),'Corrected',fill='white')
        sheet.paste(old.resize((480,288),Image.Resampling.NEAREST),(8,y+44))
        sheet.paste(new.resize((480,288),Image.Resampling.NEAREST),(496,y+44))
    sheet.save(ROOT/'evidence/scenery_colour_comparison.png')
    print(json.dumps({k:v for k,v in report.items() if k not in ('records','ln1_native_background_comparisons')},indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['capture','stage','verify','verify-staged']);args=parser.parse_args()
    if args.action=='capture':capture()
    elif args.action=='stage':stage()
    else:verify(args.action=='verify-staged')
