"""Original LN2 five-candle mechanism, animation and final victory predicate.

The original bitmap fragment and enemy animation calls are recorded requests;
their presentation is verified separately. The room's geometry and defeat
predicate execute as original instructions, without an injected hit result.
"""
import json,random
from ln2_level_source import *
from build_project import PROJECT,read_json,write_json
from export_ln1_levels import register_project

FIELDS=dict(x=0x54,y=0x55,facing=0x69,countdown=0x58,enemy_x=0x56,enemy_y=0x57,
    enemy_facing=0x6b,enemy_mirror=0x5f,enemy_active=0xcb,enemy_knockouts=0x12e,
    final_palette_phase=0x22d,boss_defeated=0x2b9,exit_locked=0x234,
    tick=0xe2,candle_tick=0x3ec,room_id=0xa2,selected_item=0x279,
    enemy_costume=0x7f,enemy_mode=0xcf,separation_y=0x236)


def state(mem):
    s={k:mem[p] for k,p in FIELDS.items()};s['candles']=mem[0x29f:0x2a4];return s


def original(mem,entry):
    cpu=MPU(memory=mem,pc=entry);cpu.sp=0xfd;cpu.x=42;cpu.y=22;mem[0x1fe:0x200]=[0xfe,1];requests=[]
    for _ in range(3000):
        if cpu.pc==0x1ff:return dict(accepted=bool(cpu.p&2),carry=bool(cpu.p&1),item=cpu.y,requests=requests)
        if cpu.pc==0x9e22:
            requests.append(dict(kind='enemy',address=cpu.x+cpu.a*256));cpu.pc=(cpu.stPopWord()+1)&65535
        elif cpu.pc==0x7e8a:
            p=word(mem,2);requests.append(dict(kind='fragment',bytes=mem[p:p+3]));cpu.pc=(cpu.stPopWord()+1)&65535
        else:cpu.step()
    raise AssertionError('Original LN2 candle rule did not return')


def main():
    ram=level_memory(7);rng=random.Random(0xb244);vectors=[]
    data=dict(rectangles=[list(ram[0xb2e7+i:0xb2eb+i]) for i in range(0,80,4)],
        x=list(ram[0x9279:0x927e]),y=list(ram[0x927e:0x9283]),initial=list(ram[0x29f:0x2a4]),
        initial_keycode=list(level_memory(1)[0x297:0x29b]))
    for operation,entry in enumerate((0xb244,0x9230,0x9cff,0xb440,0x9cb3)):
        for case in range(768):
            mem=list(ram)
            for k,p in FIELDS.items():mem[p]=rng.randrange(256)
            mem[0x2b9]=rng.choice([0]*8+[255]);mem[0x12e]=rng.choice([0,1,128,255]);mem[0x279]=rng.choice([0,16,16]);mem[0xa2]=rng.choice([0,1,1])
            mem[0x29f:0x2a4]=[rng.choice([0,128,129]) for _ in range(5)]
            mem[0x69]=rng.choice([1,3,5,7]);mem[0x6b]=rng.choice([1,3,5,7]);mem[0x56]=rng.choice([30,89,90,118,162,163]);mem[0x57]=rng.choice([97,98,114,130,131,187])
            mem[0x7f]=rng.choice([2,2,14])
            if case%3==0:
                rectangle=data['rectangles'][(case//3%5)*4+((mem[0x69]&6)//2)]
                mem[0x54]=(rectangle[0]+rectangle[2])//2;mem[0x55]=(rectangle[1]+rectangle[3])//2
            if case%12==0:
                mem[0x29f:0x2a4]=[128]*5;mem[0x29f+case//3%5]=0;mem[0x56]=118;mem[0x57]=114;mem[0x12e]=128;mem[0x2b9]=0
            before=state(mem);result=original(mem,entry)
            vectors.append(dict(operation=operation,before=before,expected=state(mem),result=result))
    included=[]
    for relative,value in [('play/ln2/final_mechanisms.json',data),('verification/ln2_candle_vectors.json',dict(vectors=vectors,scope=__doc__))]:
        path=PROJECT/'datafiles'/relative;path.write_text(json.dumps(value,separators=(',',':'))+'\n');included.append(path)
    register_project({},included);print(len(vectors),'original LN2 candle and final-victory states')


if __name__=='__main__':main()
