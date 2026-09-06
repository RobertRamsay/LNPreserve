"""Recover Fire's opened gate/lit cauldron and Void's original impact colours.

Run the original bitmap handlers offline; retain editable PNG overlays and
original dynamic masks. GPU fixtures sample the resulting original bitmaps.
"""
import copy, hashlib, random
from PIL import Image, ImageChops
import build_project as builder
from export_ln3_scenery_animation import scene_memory
from export_ln3_runtime import *
from export_ln3_content import bitmap
from export_ln3_assets import mask_shapes


def main():
    frames=[]; hashes={}; gpu=[]
    data=dict(sprite='spr_ln3_mechanisms',gate=-1,cauldron={},bolt={})
    def overlay(base,im,level,rid,kind,mask=None):
        if mask is None:
            r,g,b,_=ImageChops.difference(base,im).split()
            mask=ImageChops.lighter(r,ImageChops.lighter(g,b)).point(lambda v:255 if v else 0)
        layer=im.copy();layer.putalpha(mask);key=hashlib.sha256(layer.tobytes()).hexdigest()
        if key not in hashes:hashes[key]=len(frames);frames.append(layer)
        frame=hashes[key];points=[(x,y) for y in range(144) for x in range(240) if mask.getpixel((x,y))]
        points=random.Random(level*1000+len(gpu)).sample(points,min(96,len(points)))
        gpu.append(dict(level=level,room_id=rid,frame=frame,kind=kind,
            samples=[[x,y,*im.getpixel((x,y))[:3]] for x,y in points]))
        return frame

    ram=level_memory(4);s=layout(ram);world=read_json(PROJECT/'datafiles/play/ln3/level4/world.json')
    mem=scene_memory(ram,s,7);base=bitmap(mem)
    mem[0x313]=0;mem[0x44]=212;mem[0x45]=112;mem[0xe6]=24;mem[0xde]=6;mem[0xf4]=18
    call(mem,0x6e7c);assert mem[0x313]==1
    data['gate']=overlay(base,bitmap(mem),4,7,'gate')
    # Re-entering an opened gate must use precisely the same original fragment.
    again=scene_memory(ram,s,7);again[0x313]=1;call(again,0x6ebc)
    assert bitmap(again).tobytes()==bitmap(mem).tobytes()

    mem=scene_memory(ram,s,10);base=bitmap(mem)
    mem[0x2e8]=0;mem[0xf4]=23;mem[0x44]=96;mem[0x45]=104;mem[0xde]=0;mem[0xe6]=27;mem[0x59]=3
    call(mem,0x50f4);assert mem[0x2e8]==1
    scenery=read_json(PROJECT/'datafiles/play/ln3/level4/scenery_animation.json')
    record=next(r for r in scenery['rooms'] if r['id']==10)
    room=next(r for r in world['rooms'] if r['id']==10);handler=calls(ram,s['scene_animation'])[0]
    phases=[]
    for cycle in range(3):
        for command in record['sequence']:
            call(mem,handler,x=command);changed=copy.deepcopy(room)
            for part in changed['masks']:part['part']=mem[part['source_address']+2]
            phases.append((bitmap(mem),mask_shapes(mem,changed)))
    n=len(record['sequence']);assert all(phases[n+i]==phases[2*n+i] for i in range(n))
    union=Image.new('L',base.size)
    # Include every pixel touched in the lit AND unlit cycles so switching
    # versions cannot leave an old flame on the static background.
    unlit=scene_memory(ram,s,10)
    all_images=[im for im,_ in phases]
    for command in record['sequence']*2:
        call(unlit,handler,x=command);all_images.append(bitmap(unlit))
    for im in all_images:
        r,g,b,_=ImageChops.difference(base,im).split();union=ImageChops.lighter(union,ImageChops.lighter(r,ImageChops.lighter(g,b)))
    union=union.point(lambda v:255 if v else 0)
    data['cauldron']=dict(first=[],repeat=[])
    for i,(im,shapes) in enumerate(phases[:2*n]):
        frame=overlay(base,im,4,10,'cauldron',union)
        data['cauldron']['first' if i<n else 'repeat'].append(dict(frame=frame,shapes=shapes))

    ram=level_memory(5);s=layout(ram);mem=scene_memory(ram,s,11);base=bitmap(mem)
    scenery=read_json(PROJECT/'datafiles/play/ln3/level5/scenery_animation.json')
    record=next(r for r in scenery['rooms'] if r['id']==11);handler=calls(ram,s['scene_animation'])[0]
    states=[(-1,list(mem))]
    for i,command in enumerate(record['sequence']*2):
        call(mem,handler,x=command)
        frame=record['first' if i<len(record['sequence']) else 'repeat'][i%len(record['sequence'])]['frame']
        states.append((frame,list(mem)))
    for frame,mem in states:
        if str(frame) in data['bolt']:continue
        normal=bitmap(mem);mem[0x30d]=8;mem[0x30e]=8;flashes=[]
        for tick in range(9):
            call(mem,0x7db9);flashes.append(bitmap(mem))
        assert mem[0x30d]==0
        assert flashes[-1].tobytes()==normal.tobytes(),('impact restore differs',frame)
        # Sample over the static scene plus the matching ordinary scenery frame.
        ids=[]
        for im in flashes[:8]:
            index=overlay(normal,im,5,11,'bolt');gpu[-1].update(scenery_frame=frame,bolt_wait=7-len(ids));ids.append(index)
        data['bolt'][str(frame)]=list(reversed(ids))
    source=ROOT/'build/ln3-mechanism-import.png';frames[0].save(source)
    name=data['sprite'];resources={name:builder.sprite_resource(name,source,'Graphics/ln3_game_actors',frames)}
    included=[]
    for relative,value in [('play/ln3/mechanisms.json',data),('verification/ln3_mechanism_gpu.json',dict(vectors=gpu,scope=__doc__))]:
        path=PROJECT/'datafiles'/relative;write_json(path,value);included.append(path)
    register_project(resources,included)
    write_json(ROOT/'evidence/ln3_mechanisms.json',dict(scope=__doc__,unique_frames=len(frames),gpu_states=len(gpu),whole_game_parity=False))
    print(len(frames),'unique original mechanism overlays;',len(gpu),'GPU fixture states')


if __name__=='__main__':main()
