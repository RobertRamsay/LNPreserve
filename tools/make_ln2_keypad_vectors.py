"""Original LN2 final-room keypad edge handling, digits and code acceptance.

Starts at the original input poll. Bitmap output and the blocking delay before
that poll are excluded; submitted digits still run the original comparison.
"""
import json,random
from ln2_level_source import *
from build_project import PROJECT,read_json,write_json
from export_ln1_levels import register_project


def state(mem):
    return dict(cursor=mem[0x1e],previous=mem[0x1f]^255,digits=mem[0xb35f:0xb363],code=mem[0x297:0x29b])


def original(mem,joy):
    mem[0xdc00]=joy^255;cpu=MPU(memory=mem,pc=0xb375);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1]
    cpu.stPush(0);cpu.stPush(18)
    for step in range(1000):
        if cpu.pc==0x1ff:return 1 if cpu.y==18 else 2
        if cpu.pc==0xb358 or (cpu.pc==0xb375 and step):return 0
        if cpu.pc==0xa523:cpu.pc=(cpu.stPopWord()+1)&65535
        else:cpu.step()
    raise AssertionError('Original LN2 keypad poll did not return')


def main():
    ram=level_memory(7);rng=random.Random(0xb337);vectors=[]
    for i in range(4096):
        mem=list(ram);mem[0x1e]=i%4;mem[0x1f]=(i//4%32)^255
        mem[0xb35f:0xb363]=[rng.randrange(27,37) for _ in range(4)]
        mem[0x297:0x29b]=list(mem[0xb35f:0xb363]) if i%3==0 else [rng.randrange(27,37) for _ in range(4)]
        joy=i//128%32;before=state(mem);event=original(mem,joy)
        vectors.append(dict(before=before,joy=joy,expected=state(mem),event=event))
    path=PROJECT/'datafiles/verification/ln2_keypad_vectors.json';path.write_text(json.dumps(dict(vectors=vectors,scope=__doc__),separators=(',',':'))+'\n')
    name='ln2_object_rules';meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
    write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);register_project({name:{'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}},[path])
    print(len(vectors),'original LN2 keypad input/acceptance states')


if __name__=='__main__':main()
