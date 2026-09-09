"""Original LN2 body parts while the fourth hardware sprite is a projectile.

Keep the three body sprites separate so the source mask's per-sprite paired
alignment remains exact. Identical 24x21 PNGs are shared across poses/banks.
"""
import hashlib,json
from PIL import Image
import build_project as builder
from build_project import ROOT,PROJECT,read_json,write_json
from ln2_level_source import *
from export_ln1_world import call
from export_ln1_levels import register_project
from extract_ln1_actors import sprite_image
from export_ln2_content import composition
from decode_graphics import PALETTE

def parts(ram,s,frame,mirror,costume,shared):
    mem=list(ram);mem[0x200:0x250]=[0]*80;mem[0x9e]=255;mem[0x54:0x58]=[120]*4
    mem[0x70]=0;mem[0x72]=0;mem[0x7d]=costume;mem[0x7f]=costume;mem[0x280:0x282]=[0,0]
    call(mem,s['actor_enemy'],a=255 if mirror else 0,x=4,y=frame);result=[]
    for slot in (6,5,4):
        if not mem[0x210+slot]:continue
        p=mem[0x169d+slot]+256*mem[0x16a5+slot]+(512 if mem[0x218+slot]&1 else 0)
        im=sprite_image(mem[p:p+63],bool(mem[0x238+slot]),mem[0x220+slot]&15,shared)
        if not im.getchannel('A').getbbox():continue
        result.append((im,mem[0x200+slot]+256*mem[0x208+slot]-144,mem[0x210+slot]-170))
    return result

def main():
    images=[];ids={};resources={};included=[];vectors=[];palette={tuple(rgb):format(i,'x') for i,rgb in enumerate(PALETTE)}
    for level in range(1,8):
        ram=level_memory(level);s=layout(ram);world=read_json(PROJECT/f'datafiles/play/ln2/level{level}/world.json');shared=tuple(world['shared_sprite_colours'])
        costumes=sorted({0}|{r['enemy']['costume'] for r in world['rooms']});frames=set(range(64))|set(world['actor_frames'])
        for values in world.get('enemy_extra_frames',{}).values():frames.update(values)
        poses={}
        for costume in costumes:
            poses[str(costume)]={}
            for frame in sorted(frames):
                for mirror in (False,True):
                    pose=[]
                    for im,x,y in parts(ram,s,frame,mirror,costume,shared):
                        key=im.tobytes()
                        if key not in ids:ids[key]=len(images);images.append(im)
                        pose.append(dict(frame=ids[key],x=x,y=y))
                    poses[str(costume)][f'{frame}:{int(mirror)}']=pose
                    if frame in {0,16,32,48,99,max(frames)}:
                        im=composition(ram,s,frame,mirror,0,costume,True,shared,omit_weapon=True)
                        rows=[''.join('.' if im.getpixel((x,y))[3]==0 else palette[im.getpixel((x,y))[:3]] for x in range(96)) for y in range(96)]
                        vectors.append(dict(level=level,frame=frame,mirror=mirror,costume=costume,rows=rows))
        path=PROJECT/f'datafiles/play/ln2/level{level}/projectile_bodies.json';path.write_text(json.dumps(dict(poses=poses),separators=(',',':'))+'\n');included.append(path)
        print('LN2 projectile body bank',level,'costumes',len(costumes),flush=True)
    name='spr_ln2_projectile_bodies';source=ROOT/'build/ln2-projectile-body-import.png';images[0].save(source)
    resources[name]=builder.sprite_resource(name,source,'Graphics/ln2_game_level1',images)
    for relative,value in [('play/ln2/projectile_bodies.json',dict(sprite=name,unique_frames=len(images),scope=__doc__)),
        ('verification/ln2_projectile_bodies_gpu.json',dict(vectors=vectors,palette=PALETTE,scope=__doc__))]:
        path=PROJECT/'datafiles'/relative;path.write_text(json.dumps(value,separators=(',',':'))+'\n');included.append(path)
    register_project(resources,included);print(len(images),'shared original body-part PNGs;',len(vectors),'original compositor fixtures')

if __name__=='__main__':main()
