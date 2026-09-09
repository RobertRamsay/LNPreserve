"""Recover original LN2 projectile pixels, clipping and scenery-probe fixtures.

The two sprite buffers and original hardware update execute offline. Runtime
art is deduplicated PNG frames; native visibility must match these original
masked probes before it can replace the source's wall-hit test.
"""
import hashlib,json,random
from PIL import Image
import build_project as builder
from build_project import ROOT,PROJECT,read_json,write_json
from ln2_level_source import *
from export_ln1_world import call
from extract_ln1_actors import sprite_image
from export_ln1_levels import register_project
from decode_graphics import decode_object

def original_mask_records(ram,source,scene):
    records=[]
    for record in scene['masks']:
        pointer=word(ram,source['scene_data']+0x43+record['part']*2)
        obj,_=decode_object(ram,source['scene_data']+(pointer&0x7fff))
        records.append(dict(x=(record['x']+24)&511,y=(record['y']+50)&255,baseline=record['baseline'],
            width=obj['width'],height=obj['height'],bitmap=obj['bitmap']))
    return records

def mask_bits(records,x,y,depth):
    result=[255]*63
    for r in records:
        if r['baseline']<depth:continue
        dx=r['x']-x;dy=r['y']-y;sx=max(0,-dx);sy=max(0,-dy);tx=max(0,dx);ty=max(0,dy)
        if sx>=r['width'] or sy>=r['height'] or tx>=24 or ty>=21:continue
        endx=min(24,r['width']-sx+tx);endy=min(21,r['height']-sy+ty)
        for py in range(ty,endy):
            oy=sy+py-ty
            for px in range(tx,endx,2):
                ox=sx+px-tx;cell=(oy//8)*r['width']+ox//8*8+oy%8
                if (r['bitmap'][cell]>>(6-(ox&6)))&3:result[py*3+px//8]&=255^(192>>(px&6))
    return result

def render(ram,draw,mask,kind,x,y,room=0,masked=False,actor=0,full_mask=False):
    mem=list(ram);mem[0x200:0x250]=[0]*80;mem[0x280+actor]=kind;mem[0x284+actor]=x;mem[0x286+actor]=y
    mem[0xa2]=room;mem[0xc7]=0;mem[0x9e]=255;slot=3+actor*4;call(mem,draw,x=slot,y=actor)
    p=mem[0x169d+slot]+256*mem[0x16a5+slot]+512*mem[0x295+actor]
    if full_mask:mem[p:p+63]=[255]*63
    if masked:call(mem,mask,a=y,x=slot)
    return dict(raw=mem[p:p+63],colour=mem[0x220+slot]&15,x=mem[0x200+slot]-24,y=mem[0x210+slot]-50,
        kind=mem[0x280+actor],buffer=mem[0x295+actor],enabled=mem[0x248+slot],sprite_y=mem[0x210+slot])

def main():
    rng=random.Random(0xbbc3);images=[];ids={};records=[];included=[];fixtures=[];mismatches=[]
    for level in range(1,8):
        ram=level_memory(level);draw=locate(ram,0xbbc3,41);mask=locate(ram,0x95ec,34)
        world=read_json(PROJECT/f'datafiles/play/ln2/level{level}/world.json');maps={};depth=[];source_layout=layout(ram)
        for kind in (1,9,6,14,7,15):
            mapping=[]
            for x in range(256):
                result=render(ram,draw,mask,kind,x,100)
                im=sprite_image(result['raw'],False,result['colour'],(11,2));key=im.tobytes()
                if key not in ids:
                    ids[key]=len(images);images.append(im);records.append(dict(raw=result['raw'],colour=result['colour']))
                mapping.append(ids[key])
            maps[str(kind)]=mapping
        for scene in world['rooms']:
            masks=original_mask_records(ram,source_layout,scene);depth.append(dict(room=scene['id'],masks=masks))
            for case in range(32):
                x=rng.randrange(2,253);y=rng.randrange(34,177);kind=rng.choice([1,9,6,14,7,15]);actor=case&1
                result=render(ram,draw,mask,kind,x,y,scene['id'],True,actor);raw=records[maps[str(kind)][x]]['raw'].copy()
                bits=mask_bits(masks,result['x']+24,result['y']+50,y);raw=[a&b for a,b in zip(raw,bits)]
                if raw!=result['raw']:mismatches.append(dict(level=level,room=scene['id'],x=x,y=y,kind=kind,predicted=raw,actual=result['raw']))
                visibility=render(ram,draw,mask,kind,x,y,scene['id'],True,actor,True)['raw']
                fixtures.append(dict(level=level,room=scene['id'],x=x,y=y,kind=kind,actor=actor,frame=maps[str(kind)][x],expected=result,visibility=visibility))
        path=PROJECT/f'datafiles/play/ln2/level{level}/projectile_art.json';write_json(path,dict(frames=maps,depth=depth));included.append(path)
        print('LN2 projectile artwork bank',level,flush=True)
    name='spr_ln2_projectiles';source=ROOT/'build/ln2-projectile-import.png';images[0].save(source)
    resources={name:builder.sprite_resource(name,source,'Graphics/ln2_game_level1',images)}
    for relative,value in [('play/ln2/projectile_art.json',dict(sprite=name,frames=records,scope=__doc__)),
        ('verification/ln2_projectile_art_vectors.json',dict(vectors=fixtures,scope=__doc__))]:
        path=PROJECT/'datafiles'/relative;path.write_text(json.dumps(value,separators=(',',':'))+'\n');included.append(path)
    register_project(resources,included)
    write_json(ROOT/'build/ln2-projectile-mask-probe.json',dict(mismatches=mismatches,samples=len(fixtures)))
    print(len(images),'unique original projectile images;',len(fixtures),'original masked poses;',len(mismatches),'native mask discrepancies')

if __name__=='__main__':main()
