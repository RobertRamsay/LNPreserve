"""Original LN3 level-specific mechanisms and special encounter requests.

Blocking fades, portal presentation and ending presentation stop at their
first sequence boundary. Native gameplay state and requested sequences are
compared; these are not full special-encounter or timing replays.
"""
import json,random
from export_ln3_runtime import *
from make_ln3_item_vectors import item_state
from ln3_level_source import MPU

FIELDS=dict(fire_cauldron=0x2e8,fire_damage_wait=0x152,wind_damage_wait=0x154,
    bolt_vy=0x323,bolt_vx=0x30c,bolt_flash=0x30d,bolt_flash_wait=0x30e)
ENTRIES={1:[0x515a],2:[0x50dd,0x5218],3:[0x50a0],4:[0x50f4,0x5125,0x518b,0x6e7c],5:[0x6902,0x695f,0x6a7b]}
STOPS={1:{0x5186:1},2:{},3:{0x50d4:2},4:{},5:{0x69d4:3,0x6a86:4}}

def special_state(mem,a):
    result=item_state(mem,a);result.update({k:mem[p] for k,p in FIELDS.items()})
    result['bolt_energy']=word(mem,0x2ce);return result

def original(mem,entry,level):
    cpu=MPU(memory=mem,pc=entry);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1];event=0
    for _ in range(100000):
        if cpu.pc==0x1ff:return event
        if cpu.pc in STOPS[level]:return STOPS[level][cpu.pc]
        if level==4 and cpu.pc==0x726d:event=5
        cpu.step()
    raise AssertionError(f'LN3 special routine did not return: {cpu.pc:04x}')

def main():
    rng=random.Random(0x6902);vectors=[];included=[]
    for level in range(1,6):
        ram=level_memory(level);s=layout(ram);a=action_layout(ram,s)
        data=dict(level=level)
        if level==1:data['fade_colours']=list(ram[0x7e92:0x7e9b])
        if level==2:data.update(carrier_x=list(ram[0x5200:0x5202]),carrier_y=list(ram[0x5202:0x5204]),carrier_modes=list(ram[0x51fe:0x5200]))
        if level==3:data['fade_colours']=list(ram[0x7da4:0x7dad])
        data['initial']={k:ram[p] for k,p in FIELDS.items()};data['initial']['bolt_energy']=word(ram,0x2ce)
        for operation,entry in enumerate(ENTRIES[level]):
            for case in range(320):
                mem=list(ram);mem[0xe3]=rng.choice({1:[0,8],2:([4,6,0] if operation==0 else [3,0]),3:[3,0],4:([10,0] if operation<2 else ([2,0] if operation==2 else [7,0])),5:[11,12,0]}[level])
                mem[0x44]=rng.choice([80,88,96,104,112,120,128,136,144,160,191,192,200,204,208,219,220])
                mem[0x45]=rng.choice([72,80,87,88,95,96,100,104,111,112,119,120,128,136])
                mem[0x43]=rng.choice([60,70,89,90,100,120,160]);mem[0x48]=rng.choice([76,85,86,100,248]);mem[0x49]=rng.choice([80,119,120,135,136,160,172])
                mem[0xde]=rng.choice([0,6]);mem[0xe6]=rng.choice([0,24,26,26,27]);mem[0x59]=rng.choice([0,3,3,4]);mem[0xf4]=rng.choice([0,5,6,18,19,22,23])
                mem[2:0x1b]=[rng.choice([0,1,1,128]) for _ in range(25)];mem[0x1c]=rng.choice([0,1,2,44]);mem[0x1b]=rng.choice([0,13,26,40]);mem[0xfb]=rng.choice([0]*8+[1]);mem[0xfc]=rng.choice([0,255])
                mem[0x2e8]=rng.randrange(2);mem[0x312]=rng.randrange(2);mem[0x313]=rng.randrange(2);mem[0x2d0]=rng.randrange(2);mem[0x2d1]=rng.randrange(2)
                mem[0x2f6]=rng.randrange(3);mem[0x151]=rng.choice([0,0,1]);mem[0x152]=rng.choice([0,0,1]);mem[0x154]=rng.choice([0,0,1]);mem[0x2aa]=rng.choice([0,141])
                mem[0x2f9]=rng.choice([0,1,2]);mem[0x2fc]=rng.choice([0,0,1]);mem[0x303]=rng.randrange(2);mem[0x302]=128
                mem[0xe1]=rng.choice([6,118,246]);mem[0x57]=rng.choice([0,114,114]);mem[0x4e]=rng.choice([72,85,86,100,160,230,244]);mem[0x4f]=rng.choice([64,86,170,175,176,200])
                mem[0x323]=rng.choice([0,1,15,241,255]);mem[0x30c]=rng.choice([12,244]);mem[0x30b]=rng.choice([0,1]);mem[0xf1]=rng.choice([0,1,2,3,4])
                energy=rng.choice([0,1,13,26,880]);mem[0x2ce]=energy&255;mem[0x2cf]=energy>>8
                # Guarantee representative successful mechanism cases in every bank.
                if case%8==0:
                    if level==1:mem[0xe3]=8;mem[0x2f6]=1;mem[0x151]=0
                    if level==2 and operation==0:
                        side=case//8%2;mem[0xe3]=4+2*side;mem[0x2d0+side]=0;mem[0xde]=6;mem[0xe6]=26;mem[0x59]=3;mem[2]=1;mem[0x44]=data['carrier_x'][side]+8;mem[0x45]=data['carrier_y'][side]+8
                    if level==3:mem[0xe3]=3;mem[0x312]=0;mem[0x44]=136;mem[0x45]=88;mem[0xe6]=26;mem[0x59]=4;mem[0xf4]=5
                    if level==4 and operation<2:
                        mem[0xe3]=10;mem[0xde]=0;mem[0x44]=96;mem[0x45]=104;mem[0xe6]=27;mem[0x59]=3;mem[0x2e8]=operation;mem[0xf4]=23 if operation==0 else 19;mem[0x14]=0;mem[0xd]=mem[0x12]=1
                    if level==4 and operation==3:mem[0xe3]=7;mem[0x313]=0;mem[0x44]=212;mem[0x45]=112;mem[0xe6]=24;mem[0xde]=6;mem[0xf4]=18
                before=special_state(mem,a);event=original(mem,entry,level)
                vectors.append(dict(level=level,operation=operation,before=before,expected=special_state(mem,a),event=event))
        path=PROJECT/f'datafiles/play/ln3/level{level}/special.json';write_json(path,data);included.append(path)
        print('Original LN3 special rules',level,flush=True)
    path=PROJECT/'datafiles/verification/ln3_special_vectors.json';path.write_text(json.dumps(dict(vectors=vectors,scope=__doc__),separators=(',',':'))+'\n');included.append(path)
    resources={}
    for name in ('ln3_special','ln3_special_checks'):
        meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
        write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);resources[name]={'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}
    register_project(resources,included);print(len(vectors),'original special states and sequence requests')

if __name__=='__main__':main()
