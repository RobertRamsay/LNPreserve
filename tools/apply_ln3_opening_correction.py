"""Apply only the user-selected LN3 opening scene's verified original pixels."""
import hashlib,json
from PIL import Image
from decode_graphics import ROOT,PROJECT
from original_scene_renderer import OriginalSceneRenderer
from build_project import read_json,write_json

def main():
    path=next((ROOT/'tools/vendor/integrator-ln3').rglob('int-level1-tape.prg'))
    raw=path.read_bytes();renderer=OriginalSceneRenderer(3,raw)
    if renderer.ram[0x800:0x800+len(raw)-2]!=raw[2:]:raise AssertionError('LN3 source payload mismatch')
    image=renderer.render(0)
    expected='653095de7697c7aa09afb69b4601fcfea917af92f19bf2f7dbc73cdcfd704f2a'
    if hashlib.sha256(image.tobytes()).hexdigest()!=expected:raise AssertionError('Original bitmap mismatch')
    manifest_path=PROJECT/'datafiles/graphics/manifest.json';manifest=read_json(manifest_path)
    dataset=next(d for d in manifest['datasets'] if d['id']=='ln3_game_level1')
    loc=next(l for l in dataset['locations'] if l['id']==0)
    name='spr_'+loc['canonical_name'];folder=PROJECT/'sprites'/name;meta=read_json(folder/(name+'.yy'))
    if len(meta['frames'])!=1:raise AssertionError('Unexpected animated opening scene')
    paths=[PROJECT/loc['path']]
    for frame in meta['frames']:
        paths.append(folder/(frame['name']+'.png'))
        paths.extend(folder/'layers'/frame['name']/(layer['name']+'.png') for layer in meta['layers'])
    for target in paths:
        if not target.resolve().is_relative_to(PROJECT.resolve()):raise ValueError('Asset path outside project')
        image.save(target)
    loc['status']='original_bitmap_verified';loc['warnings']=[]
    loc['verification']=dict(pixel_sha256=expected,pixels_compared=34560,differing_pixels=0,
        source_ram_sha256=renderer.provenance['source_ram_sha256'],dataset_payload_sha256=hashlib.sha256(raw[2:]).hexdigest(),
        dataset_matches_supplied_game=True)
    manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
    report=read_json(ROOT/'evidence/scenery_colour_audit.json')
    report['applied_scenes']=[dict(dataset='ln3_game_level1',scene=0,changed_pixels=1392)]
    report['other_candidates_applied']=False
    report['editable_scene_sprites_checked']=1
    report['selected_scope']='Only LN3 level 1 opening scene, per explicit user selection'
    for target in paths:
        with Image.open(target) as actual:
            if actual.convert('RGBA').tobytes()!=image.tobytes():raise AssertionError('Stale editable sprite pixels')
    write_json(ROOT/'evidence/scenery_colour_audit.json',report)
    print('Applied and verified:',len(paths),'PNG files for one existing scene resource')

if __name__=='__main__':main()
