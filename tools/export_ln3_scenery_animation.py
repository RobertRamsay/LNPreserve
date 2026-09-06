"""Recover original LN3 animated scenery as editable PNG overlays and masks.

Only pixels touched over the original animation cycle are included in the
overlay. First-entry and repeating cycles are retained separately; identical
frames share one sprite bank. Existing static scene artwork is preserved.
"""
import copy,hashlib,json,random
from PIL import Image,ImageChops
import build_project as builder
from export_ln3_runtime import *
from export_ln3_content import bitmap
from export_ln3_assets import mask_shapes
from ln3_level_source import MPU

def scene_memory(ram,s,rid):
    mem=list(ram)
    for p,n in [(0xcc00,1000),(0xd000,1000),(0xd800,1000),(0xe000,8000)]:mem[p:p+n]=[0]*n
    mem[0xe3]=rid;call(mem,s['scene_draw'],a=rid);return mem

def scene_phase(mem,entry,handler):
    cpu=MPU(memory=mem,pc=entry);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1];command=-1
    for _ in range(1000):
        if cpu.pc==0x1ff:return command
        if cpu.pc==handler:command=cpu.x;cpu.pc=(cpu.stPopWord()+1)&65535
        else:cpu.step()
    raise AssertionError('Scene animation selector failed to return')

def main():
    resources={};included=[];frames=[];frame_ids={};total=0;vectors=[];gpu=[]
    for level in range(1,6):
        ram=level_memory(level);s=layout(ram);lo=word(ram,s['scene_animation']+8);hi=word(ram,s['scene_animation']+14)
        handler=calls(ram,s['scene_animation'])[0];world=read_json(PROJECT/f'datafiles/play/ln3/level{level}/world.json')
        data=dict(level=level,sprite='spr_ln3_scenery_animation',rooms=[])
        for room in world['rooms']:
            rid=room['id'];p=ram[lo+rid]+256*ram[hi+rid];seq=[]
            while ram[p]!=255:seq.append(ram[p]);p+=1;assert len(seq)<64
            record=dict(id=rid,sequence=seq,first=[],repeat=[]);data['rooms'].append(record)
            for cursor in sorted({0,len(seq),max(0,len(seq)-1)}):
                for wait in (0,1,4):
                    for selected in (0,6):
                        for enabled in (0,128):
                            mem=list(ram);mem[0xe3]=rid;mem[0xf1]=cursor;mem[0x14b]=wait;mem[0xf4]=selected;mem[0xe1]=enabled
                            command=scene_phase(mem,s['scene_animation'],handler)
                            vectors.append(dict(level=level,room_id=rid,cursor=cursor,wait=wait,selected=selected,enabled=enabled,
                                command=command,expected_cursor=mem[0xf1],expected_wait=mem[0x14b]))
            if not seq:continue
            total+=len(seq);mem=scene_memory(ram,s,rid);base=bitmap(mem);phases=[]
            for cycle in range(3):
                for command in seq:
                    call(mem,handler,x=command);im=bitmap(mem)
                    changed_room=copy.deepcopy(room)
                    for mask in changed_room['masks']:mask['part']=mem[mask['source_address']+2]
                    shapes=mask_shapes(mem,changed_room)
                    phases.append((im,shapes))
            n=len(seq)
            for i in range(n):
                assert phases[n+i][0].tobytes()==phases[2*n+i][0].tobytes() and phases[n+i][1]==phases[2*n+i][1],(level,rid,'non-stationary animation cycle')
            union=Image.new('L',base.size)
            for im,_ in phases:
                r,g,b,_=ImageChops.difference(base,im).split();union=ImageChops.lighter(union,ImageChops.lighter(r,ImageChops.lighter(g,b)))
            union=union.point(lambda value:255 if value else 0)
            for i,(im,shapes) in enumerate(phases[:2*n]):
                overlay=im.copy();overlay.putalpha(union);key=hashlib.sha256(overlay.tobytes()).hexdigest()
                if key not in frame_ids:frame_ids[key]=len(frames);frames.append(overlay)
                record['first' if i<n else 'repeat'].append(dict(frame=frame_ids[key],shapes=shapes))
                points=[(x,y) for y in range(144) for x in range(240) if union.getpixel((x,y))]
                sample_rng=random.Random(level*10000+rid*100+i)
                points=sample_rng.sample(points,min(64,len(points)))+[(0,0),(239,0),(0,143),(239,143)]
                gpu.append(dict(level=level,room_id=rid,frame=frame_ids[key],samples=[[x,y,*im.getpixel((x,y))[:3]] for x,y in points]))
            print('Original LN3 scenery cycle',level,rid,len(seq),'frames',flush=True)
        path=PROJECT/f'datafiles/play/ln3/level{level}/scenery_animation.json';write_json(path,data);included.append(path)
    source=ROOT/'build/ln3-scenery-import.png';frames[0].save(source);name='spr_ln3_scenery_animation'
    resources[name]=builder.sprite_resource(name,source,'Graphics/ln3_game_actors',frames)
    name='ln3_scenery';meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
    write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);resources[name]={'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}
    path=PROJECT/'datafiles/verification/ln3_scenery_vectors.json';write_json(path,dict(vectors=vectors,scope='Scene animation selection; bitmap handler intercepted for selector vectors. Overlay PNGs and masks come from separate original handler execution.'));included.append(path)
    path=PROJECT/'datafiles/verification/ln3_scenery_gpu.json';write_json(path,dict(vectors=gpu,scope='Original bitmap samples after each first-entry and repeating scene-animation step.'));included.append(path)
    register_project(resources,included)
    write_json(ROOT/'evidence/ln3_scenery_animation.json',dict(scope=__doc__,animation_steps=total,unique_overlay_frames=len(frames),selector_vectors=len(vectors),whole_game_parity=False))
    print(total,'animation steps',len(frames),'unique overlay frames',len(vectors),'original selector states')

if __name__=='__main__':main()
