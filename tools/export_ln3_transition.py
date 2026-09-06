"""Recover Void's original transition sprites, messages and timing tables.

The eight hardware sprites form the moving curtain and figure. Their original
pixel data, positions, expansion and multicolour settings remain separate from
the editable native sequence logic. Disk-loaded ENDING remains separate work.
"""
from PIL import Image
import build_project as builder
from export_ln3_runtime import *
from export_ln3_scenery_animation import scene_memory
from export_ln3_content import bitmap


def main():
    ram=level_memory(5);s=layout(ram);resources={};included=[]
    data=dict(parts=[],fade_colours=list(ram[0x800f:0x8018]),part_sprite='spr_ln3_transition_parts',
        text_sprite='spr_ln3_transition_text',scope=__doc__)
    frames=[];keys={}
    for i in range(8):
        pointer=ram[0x7fff+i];raw=ram[0x400+(pointer-64)*64:0x400+(pointer-64)*64+63]
        colour=ram[0x8007+i];mc=bool(248&(1<<i));pixels=[]
        for y in range(21):
            for x in range(24):
                byte=raw[y*3+x//8]
                code=(byte>>(6-(x%8//2)*2))&3 if mc else (byte>>(7-x%8))&1
                c=[0,15,colour,12][code] if mc else colour
                pixels.append((*PALETTE[c],255 if code else 0))
        im=Image.new('RGBA',(24,21));im.putdata(pixels);key=im.tobytes()
        if key not in keys:keys[key]=len(frames);frames.append(im)
        data['parts'].append(dict(frame=keys[key],x=ram[0x7fef+i],y=ram[0x7ff7+i],
            scale_x=2 if 250&(1<<i) else 1,scale_y=2 if 9&(1<<i) else 1))
    source=ROOT/'build/ln3-transition-import.png';frames[0].save(source);name=data['part_sprite']
    resources[name]=builder.sprite_resource(name,source,'Graphics/ln3_game_actors',frames)
    mem=scene_memory(ram,s,11)
    for p in range(0xe000,0xe000+18*320):mem[p]=0
    call(mem,0x6e88,x=5);call(mem,0x6e88,x=6);frames=[bitmap(mem)]
    call(mem,0x6a6d);call(mem,0x6e88,x=7);frames.append(bitmap(mem))
    mem=scene_memory(ram,s,12)
    for p in range(0xe000,0xe000+18*320):mem[p]=0
    call(mem,0x6e88,x=8);frames.append(bitmap(mem))
    frames[0].save(source);name=data['text_sprite'];resources[name]=builder.sprite_resource(name,source,'Graphics/ln3_game_actors',frames)
    # Original movement helper runs once at raster 251. Compare whole traces,
    # including the leading sprite's stop condition and byte wrapping upward.
    vectors=[]
    for mode in (1,2):
        for start in (0,10,32,114,174,176,254):
            mem=list(ram);mem[0x2df]=2;mem[0x2e0]=mode
            for i in range(8):mem[0xd001+2*i]=(start+i*2)&255
            trace=[]
            for _ in range(90):
                before=[mem[0xd001+2*i] for i in range(8)];signal=mem[0x2e1]
                call(mem,0x7d59)
                trace.append(dict(before=before,signal=signal,after=[mem[0xd001+2*i] for i in range(8)],expected_signal=mem[0x2e1]))
            vectors.append(dict(mode=mode,trace=trace))
    for relative,value in [('play/ln3/transition.json',data),('verification/ln3_transition_vectors.json',dict(vectors=vectors,scope=__doc__))]:
        path=PROJECT/'datafiles'/relative;write_json(path,value);included.append(path)
    register_project(resources,included);print(len(data['parts']),'original transition parts, 3 message bitmaps, 1260 original sprite-motion states')


if __name__=='__main__':main()
