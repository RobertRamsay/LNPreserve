"""Recover the latent final-room LN2 enemy bank and original pixel fixtures.

Ordinary room entry leaves this enemy inactive. Releasing it after the keypad
uses the original room's weapon/costume, so that bank must exist independently
of whether its initial active flag is set. Identical banks reuse existing art.
"""
from PIL import Image
import build_project as builder
from build_project import ROOT,PROJECT,read_json,write_json
from export_ln2_assets import digest
from export_ln2_content import composition,actions
from ln2_level_source import level_memory,layout
from export_ln1_levels import register_project
from decode_graphics import PALETTE


def main():
    candidates=set()
    for level in range(1,8):
        world=read_json(PROJECT/f'datafiles/play/ln2/level{level}/world.json')
        for field in ('player_banks','player_extra_banks','enemy_banks','enemy_extra_banks'):
            value=world[field];candidates.update(value.values() if isinstance(value,dict) else value)
    known={}
    for name in sorted(candidates):
        path=PROJECT/f'sprites/{name}/{name}.yy';meta=read_json(path)
        images=[Image.open(path.parent/(f['name']+'.png')).convert('RGBA') for f in meta['frames']]
        known.setdefault(digest(images,(48,64)),name)
    level=7;ram=level_memory(level);s=layout(ram);target=PROJECT/'datafiles/play/ln2/level7/world.json';world=read_json(target)
    enemy=next(r['enemy'] for r in world['rooms'] if r['id']==1);weapon=enemy['weapon'];costume=enemy['costume'];key=f'{weapon}_{costume}'
    gameplay=PROJECT/'datafiles/play/ln2/level7/gameplay.json';g=read_json(gameplay);g['actions'].update(actions(ram,[0xc1b9,0xc1c0]));write_json(gameplay,g)
    # Frame 99 is the final enemy's alternative defeat entrance. Keep ordinary
    # actor banks' indexing intact and give this bank its own extra-frame map.
    extra=world['actor_frames']+([99] if 99 not in world['actor_frames'] else [])
    world.setdefault('enemy_extra_frames',{})[key]=extra
    resources={};vectors=[];palette={tuple(rgb):format(i,'x') for i,rgb in enumerate(PALETTE)}
    for suffix,poses,field in [('body',list(range(64)),'enemy_banks'),('effects_final',extra,'enemy_extra_banks')]:
        images=[composition(ram,s,f,m,weapon,costume,True,tuple(world['shared_sprite_colours'])) for m in (False,True) for f in poses]
        name=known.get(digest(images,(48,64)))
        if name is None:
            name=f'spr_ln2_level7_enemy_{key}_{suffix}';source=ROOT/'build/ln2-final-enemy-import.png';images[0].save(source)
            resources[name]=builder.sprite_resource(name,source,'Graphics/ln2_game_level7',images)
            path=PROJECT/f'sprites/{name}/{name}.yy';meta=read_json(path);meta['origin']=9;meta['sequence']['xorigin']=48;meta['sequence']['yorigin']=64;write_json(path,meta)
        world[field][key]=name
        for i,im in enumerate(images):
            rows=[''.join('.' if im.getpixel((x,y))[3]==0 else palette[im.getpixel((x,y))[:3]] for x in range(96)) for y in range(96)]
            vectors.append(dict(frame=poses[i%len(poses)],mirror=i>=len(poses),weapon=weapon,costume=costume,rows=rows))
    write_json(target,world);path=PROJECT/'datafiles/verification/ln2_final_enemy_gpu.json';write_json(path,dict(vectors=vectors,palette=PALETTE,scope=__doc__));register_project(resources,[path])
    print(key,len(vectors),'original final enemy pose/mirror images;',len(resources),'new banks')


if __name__=='__main__':main()
