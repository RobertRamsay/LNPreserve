"""Recover original ENDING panels, animation costs, font and scroll traces.

Bitmap updates run offline in the original 6502 routines. Raster reveal and
mid-draw VIC observations are not certified by these whole-image samples.
"""
import hashlib
from PIL import Image
import build_project as builder
from export_ln3_runtime import *
from ln3_level_source import MPU


def picture(mem):
    pixels=[]
    for y in range(200):
        for x in range(320):
            cell=y//8*40+x//8;code=(mem[0xe000+cell*8+y%8]>>(6-(x%8//2)*2))&3
            colour=[0,mem[0xcc00+cell]>>4,mem[0xcc00+cell]&15,mem[0xd800+cell]&15][code]
            pixels.append((*PALETTE[colour&15],255 if code else 0))
    im=Image.new('RGBA',(320,200));im.putdata(pixels);return im


def timed(mem,entry):
    cpu=MPU(memory=mem,pc=entry);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1]
    for _ in range(1000000):
        if cpu.pc==0x1ff:return cpu.processorCycles
        cpu.step()
    raise AssertionError('ENDING routine did not return')


def main():
    ram=(ROOT/'source/local/captures/ln3-ending-ram.bin').read_bytes();frames=[];ids={};resources={};included=[]
    data=dict(sprite='spr_ln3_ending',font_sprite='spr_ln3_ending_font',panels=[],animation=[],
        background_fade=list(ram[0x4f3e:0x4f47]),source_sha256=hashlib.sha256(ram).hexdigest(),scope=__doc__)
    def save(mem):
        im=picture(mem);key=im.tobytes()
        if key not in ids:ids[key]=len(frames);frames.append(im)
        return ids[key]
    def attributes(mem,index):
        mem[0x16]=index;call(mem,0x4f94,x=index);call(mem,0x4fea)
    for index in range(6):
        mem=list(ram);attributes(mem,index);call(mem,0x5042)
        if index==5:call(mem,0x4f2c)
        data['panels'].append(save(mem))
    mem=list(ram);attributes(mem,0);call(mem,0x5042);attributes(mem,1);mem[0x1a]=0
    for _ in range(4):
        cycles=timed(mem,0x509a);data['animation'].append(dict(frame=save(mem),cycles=cycles+12))
    attributes(mem,0);call(mem,0x5042);attributes(mem,4);data['flash_panel']=save(mem)
    call(mem,0x4f47);data['silhouette']=save(mem)
    source=ROOT/'build/ln3-ending-import.png';frames[0].save(source);name=data['sprite']
    resources[name]=builder.sprite_resource(name,source,'Graphics/ln3_game_actors',frames)
    p=word(ram,0x9eca);q=ram.index(36,p);data['text']=ram[p:q].decode('ascii');data['characters']={};fonts=[];fontids={}
    mem=list(ram);attributes(mem,5);call(mem,0x5042);call(mem,0x4f2c)
    data['scroll_colours']=[0,mem[0xcf05]>>4,mem[0xcf05]&15,mem[0xdb05]&15]
    # Source scroll is at row 19, columns 13..28. The original sets all 40
    # colour-RAM cells on that row to 3 before starting it.
    data['scroll_colours']=[0,mem[0xcc00+19*40+13]>>4,mem[0xcc00+19*40+13]&15,3]
    for ch in sorted(set(data['text'])):
        code=64 if ch==' ' else ord(ch);address=0xa07e+(((code-64)&255)*8&255);raw=ram[address:address+8]
        pixels=[]
        for y in range(8):
            for x in range(8):
                value=(raw[y]>>(6-(x//2)*2))&3;pixels.append((*PALETTE[data['scroll_colours'][value]],255 if value else 0))
        im=Image.new('RGBA',(8,8));im.putdata(pixels);key=im.tobytes()
        if key not in fontids:fontids[key]=len(fonts);fonts.append(im)
        data['characters'][ch]=fontids[key]
    fonts[0].save(source);name=data['font_sprite'];resources[name]=builder.sprite_resource(name,source,'Graphics/ln3_game_actors',fonts)
    # An independent original scroll trace verifies each frame's character
    # cursor, tick counter, completion marker and all 128 bitmap bytes.
    mem[0x1c]=0;mem[0x10]=0;mem[0x11]=0;mem[0x1d]=128;vectors=[]
    for tick in range(len(data['text'])*4+4):
        call(mem,0x51c4)
        vectors.append(dict(tick=tick+1,counter=mem[0x1c],cursor=word(mem,0x10),marker=mem[0x1d],bitmap=list(mem[0xf828:0xf8a8])))
    for relative,value in [('play/ln3/ending.json',data),('verification/ln3_ending_vectors.json',dict(vectors=vectors,scope=__doc__))]:
        path=PROJECT/'datafiles'/relative;write_json(path,value);included.append(path)
    name='ln3_ending';meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
    write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);resources[name]={'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}
    register_project(resources,included)
    print(len(frames),'unique original ending panels/frames,',len(fonts),'font images,',len(vectors),'original scroll states')


if __name__=='__main__':main()
