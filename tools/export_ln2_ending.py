"""Original LN2 victory picture, palette loop, digit font and state fixtures.

Original bitmap/text instructions execute offline. Native display uses PNGs;
the VIC raster, health-bar drawing and score-event completeness are separate.
"""
import hashlib,random,sys
from PIL import Image,ImageChops
import build_project as builder
from build_project import ROOT,PROJECT,read_json,write_json
from ln2_level_source import *
from export_ln1_world import call
from export_ln1_levels import register_project
from export_ln2_content import actions
from decode_graphics import PALETTE

def until(mem,start,end):
    cpu=MPU(memory=mem,pc=start)
    for _ in range(100000):
        if cpu.pc==end:return
        cpu.step()
    raise AssertionError(hex(cpu.pc))

def picture(mem):
    im=Image.new('RGBA',(320,200));pixels=[]
    for y in range(200):
        for x in range(320):
            cell=y//8*40+x//8;code=mem[0x2000+cell*8+y%8]>>(6-(x//2%4)*2)&3
            colour=[mem[0xd021]&15,mem[0x400+cell]>>4,mem[0x400+cell]&15,mem[0xd800+cell]&15][code]
            pixels.append((*PALETTE[colour],255))
    im.putdata(pixels);return im

def overlay_set(base,images):
    union=Image.new('L',base.size)
    for im in images:
        r,g,b,_=ImageChops.difference(base,im).split();union=ImageChops.lighter(union,ImageChops.lighter(r,ImageChops.lighter(g,b)))
    union=union.point(lambda v:255 if v else 0)
    result=[]
    for im in images:im=im.copy();im.putalpha(union);result.append(im)
    return result

def phase_memories(mem):
    states=[];seen={};mem[0x22d]=0
    # Substitution merges pre-existing colours during the first traversal.
    # Preserve that first traversal separately from the eventual steady loop.
    for _ in range(64):
        key=(mem[0x22d],bytes(mem[0x400:0x7e8]),bytes(mem[0xd800:0xdbe8]))
        if key in seen:return states,list(range(1,len(states)))+[seen[key]]
        seen[key]=len(states);states.append(mem.copy())
        mem[0xe2]=(mem[0x26d]+6)&255;call(mem,0x8f90)
    raise AssertionError('Original ending palette did not repeat')

def state(mem):
    return dict(target=mem[0x229:0x22b],display=mem[0x22b:0x22d],knockouts=mem[0x12e],
        enemy_action=word(mem,0x62),reward=mem[0x3ef],eye_timer=mem[0x29d],eye_phase=mem[0x29c])

def predicate(mem):
    cpu=MPU(memory=mem,pc=0x8cd2);requests=[]
    for _ in range(100):
        if cpu.pc==0x8cba:return 0,requests
        if cpu.pc==0x8cff:return 1,requests
        if cpu.pc==0x9e22:
            requests.append(cpu.x+cpu.a*256);cpu.pc=(cpu.stPopWord()+1)&65535
        else:cpu.step()
    raise AssertionError(hex(cpu.pc))

def main():
    builder.REFRESH_GRAPHICS='--refresh' in sys.argv
    ram=level_memory(7);s=layout(ram);mem=list(ram);mem[0xa2]=1
    call(mem,0x140e);call(mem,s['scene_choose']);call(mem,s['item_enter'])
    mem[0xd800:0xdbe8]=mem[0x800:0xbe8];mem[0xd021]=mem[0x32]&15
    base=picture(mem);states,following=phase_memories(mem.copy());game_images=[picture(m) for m in states];resources={};included=[]
    data=dict(source_sha256=hashlib.sha256(ram).hexdigest(),palette_period=ram[0x95d1],palette_next=following,
        palette_phases=[m[0x22d] for m in states],scope=__doc__)
    def sprite(name,images):
        target=PROJECT/'sprites'/name;meta=target/(name+'.yy')
        old=read_json(meta) if meta.exists() and builder.REFRESH_GRAPHICS else None
        source=ROOT/'build/ln2-ending-import.png';images[0].save(source)
        resources[name]=builder.sprite_resource(name,source,'Graphics/ln2_game_level7',images)
        if old:
            keep={f['name'] for f in read_json(meta)['frames']}
            for frame in old['frames']:
                if frame['name'] in keep:continue
                paths=[target/(frame['name']+'.png')]+[target/'layers'/frame['name']/(layer['name']+'.png') for layer in old['layers']]
                for path in paths:
                    assert path.resolve().is_relative_to(target.resolve())
                    if path.exists():path.unlink()
                folder=target/'layers'/frame['name']
                if folder.exists() and not any(folder.iterdir()):folder.rmdir()
        return name
    def unique_sprite(name,images):
        unique=[];ids={};mapping=[]
        for im in images:
            key=im.tobytes()
            if key not in ids:ids[key]=len(unique);unique.append(im)
            mapping.append(ids[key])
        return sprite(name,unique),mapping
    data['palette_sprite'],data['palette_frames']=unique_sprite('spr_ln2_final_palette',overlay_set(base,game_images))
    # The original stores six score digits and three pairs of time digits in
    # these inline strings. Leave their cells blank for the native live result.
    ending_images=[];ending_memories=[]
    for copy in states:
        copy=copy.copy();copy[0x8f05:0x8f0b]=[64]*6
        for p in (0x8f25,0x8f28,0x8f2b):copy[p:p+2]=[64]*2
        until(copy,0x8cff,0x8f2e);ending_images.append(picture(copy));ending_memories.append(copy)
    mem=ending_memories[0];endbase=ending_images[0]
    data['picture_sprite'],data['picture_frames']=unique_sprite('spr_ln2_ending',ending_images)
    candle=read_json(PROJECT/'datafiles/play/ln2/final_mechanisms.json');candleimages=[]
    for i in range(5):
        variants=[]
        for command in (32,33,34):
            copy=mem.copy();copy[0xb485:0xb488]=[command,candle['x'][i],candle['y'][i]];copy[2:4]=[0x85,0xb4];call(copy,0x7e8a);variants.append(picture(copy))
        candleimages.extend(overlay_set(endbase,variants))
    data['candle_sprite']=sprite('spr_ln2_ending_candles',candleimages)
    fonts=[]
    for ch in range(27,37):
        copy=mem.copy();copy[0x700:0x70a]=[0x20,0x83,0x15,0,0,7,0xc0,ch,0,0x60];call(copy,0x700);fonts.append(picture(copy).crop((0,0,8,8)))
    data['font_sprite']=sprite('spr_ln2_ending_digits',fonts)
    data['score_xy']=[ram[0x8f01]*8,ram[0x8f02]*8];data['time_xy']=[ram[0x8f21]*8,ram[0x8f22]*8]
    vectors=[];rng=random.Random(0x8c7b)
    for operation in range(4):
        for i in range(768):
            copy=list(ram);copy[0x229:0x22d]=[rng.randrange(45) for _ in range(4)];copy[0x12e]=rng.randrange(256)
            copy[0x62:0x64]=[rng.randrange(256),rng.choice([0,0xc1])];copy[0x3ef]=rng.choice([0,255]);copy[0x29c]=rng.randrange(256);copy[0x29d]=rng.choice([0,1,255]);copy[0xe2]=(copy[0x268]+1)&255
            if i%3==0:copy[0x22b:0x22d]=copy[0x229:0x22b]
            before=state(copy);requests=[];event=0
            if operation==0:until(copy,0x8cad,0x8cba)
            elif operation==1:call(copy,0x8f58)
            elif operation==2:event,requests=predicate(copy)
            else:until(copy,0x8f3a,0x8f49)
            vectors.append(dict(operation=operation,before=before,expected=state(copy),event=event,requests=requests))
    palette=[];motion=[]
    for i in range(2048):
        copy=list(ram);copy[0x22d]=i%8;copy[0xe2]=rng.randrange(256);copy[0x26d]=rng.randrange(256)
        before=dict(phase=copy[0x22d],tick=copy[0xe2],previous=copy[0x26d]);call(copy,0x8f90)
        palette.append(dict(before=before,phase=copy[0x22d],previous=copy[0x26d]))
        copy=list(ram);copy[0x56]=rng.choice([0,117,118,119,133,134,135,255]);copy[0x57]=rng.choice([0,113,114,115,255]);copy[0x76]=rng.randrange(256);copy[0x6b]=rng.choice([1,3,5,7])
        before=dict(x=copy[0x56],y=copy[0x57],depth_y=copy[0x76],facing=copy[0x6b]);call(copy,0x9b84)
        motion.append(dict(before=before,expected=dict(x=copy[0x56],y=copy[0x57],depth_y=copy[0x76],facing=copy[0x6b])))
    gpu=[];gamegpu=[]
    for i,im in enumerate(ending_images):
        points=random.Random(i).sample([(x,y) for y in range(200) for x in range(320)],512)
        gpu.append(dict(phase=i,samples=[[x,y,*im.getpixel((x,y))[:3]] for x,y in points]))
    for i,im in enumerate(game_images):
        points=random.Random(i).sample([(x,y) for y in range(144) for x in range(240)],2048)
        gamegpu.append(dict(phase=i,samples=[[x,y,*im.getpixel((x,y))[:3]] for x,y in points]))
    for relative,value in [('play/ln2/ending.json',data),('verification/ln2_ending_vectors.json',dict(vectors=vectors,palette=palette,motion=motion,scope=__doc__)),
        ('verification/ln2_ending_gpu.json',dict(vectors=gpu,game=gamegpu,scope='Original first/repeated palette traversals and static ending bitmap, before live digits/candles/actors'))]:
        path=PROJECT/'datafiles'/relative;write_json(path,value);included.append(path)
    name='ln2_ending';meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
    write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);resources[name]={'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}
    register_project(resources,included);print('LN2 ending:',len(vectors),'victory states,',len(palette),'palette states,',len(motion),'spirit motion states;',len(states),'original palette pictures with steady-loop return',following[-1])

if __name__=='__main__':main()
