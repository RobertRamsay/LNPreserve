"""Compare LN2 player rules with all seven original level implementations.

Original rendering is intercepted. World dispatch, vehicles and system bus
timing are outside this routine-level comparison and remain separate work.
"""
import json
import sys
from pathlib import Path
from build_project import ROOT,PROJECT,read_json,write_json
from ln2_level_source import level_memory,layout,word
from export_ln2_content import FIELDS
from export_ln1_world import call as source_call
from export_ln1_levels import register_project
sys.path.insert(0,str(ROOT/'tools/vendor/pydeps'))
from py65.devices.mpu6502 import MPU

def state(mem):
    value={name:mem[address] for name,address in FIELDS.items()}
    value.update(action=word(mem,0x60),enemy_x=mem[0x56],enemy_y=mem[0x57])
    return value

def call(mem,source,tick,joy):
    mem[0xe2]=tick;mem[0x7c]=joy
    cpu=MPU(memory=mem,pc=source['player_update']);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1]
    display=None
    for _ in range(50000):
        if cpu.pc==0x1ff:return display
        if cpu.pc in (source['actor_player'],source['mask']):
            if cpu.pc==source['actor_player']:
                mem[0x9f]=0;display=dict(frame=cpu.y,mirror=cpu.a!=0)
            cpu.pc=(cpu.stPopWord()+1)&65535
        else:cpu.step()
    raise AssertionError(f'LN2 original player failed to return at ${cpu.pc:04x}')

def main():
    vectors=[];included=[]
    for level in range(1,8):
        ram=level_memory(level);source=layout(ram);folder=ROOT/f'source/local/recovered/ln2/level{level}'
        world=read_json(folder/'world.json');data=read_json(folder/'gameplay.json')
        data.update(level=level,timer_period_cycles=word(ram,0x28c)+1)
        data['initial']=state(ram)
        target=PROJECT/f'datafiles/play/ln2/level{level}/gameplay.json';write_json(target,data);included.append(target)
        sequences=[];initial_room=world['tables']['exit_destinations'][0]
        for direction in [0,1,2,4,8,5,6,9,10]:
            sequences.append((f'walk_{direction}',initial_room,0,1,[direction]*64+[0]*8))
            if direction:
                for weapon in [0,1,3,4]:
                    sequences.append((f'fire_{direction}_weapon{weapon}',initial_room,weapon,1,[0]*4+[16]*4+[direction|16]*40+[0]*12))
                sequences.append((f'walk_fire_{direction}',initial_room,0,1,[direction]*12+[direction|16]*40+[0]*12))
        for room in world['rooms']:
            if not room['boundaries']:continue
            for rotation in range(3):
                sequences.append((f'room{room["id"]}_mode{rotation}',room['id'],0,rotation,[9]*12+[10]*12+[6]*12+[5]*12))
        for name,room,weapon,rotation,inputs in sequences:
            mem=list(ram);entry=next(i for i,dest in enumerate(world['tables']['exit_destinations']) if dest==room)
            source_call(mem,source['entrance'],x=entry);source_call(mem,source['boundary_enter'])
            mem[0x70]=mem[0x89]=weapon;mem[0x3f3]=rotation;mem[0x293]=0
            initial=state(mem);frames=[];display=dict(frame=mem[0x65],mirror=False)
            bounds=next(r['boundaries'] for r in world['rooms'] if r['id']==room)
            for index,joy in enumerate(inputs):
                tick=(initial['tick']+index+1)&255;drawn=call(mem,source,tick,joy)
                if drawn is not None:display=drawn
                frames.append(dict(joy=joy,tick=tick,expected=state(mem),display=display))
            vectors.append(dict(level=level,name=name,initial=initial,boundaries=bounds,frames=frames))
        print('LN2 level',level,len(sequences),'source player sequences',flush=True)
    target=PROJECT/'datafiles/verification/ln2_player_vectors.json';target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps(dict(fields=FIELDS,vectors=vectors,scope=__doc__),separators=(',',':'))+'\n');included.append(target)
    resources={}
    for name in ['ln2_player','ln2_player_checks']:
        meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
        write_json(PROJECT/f'scripts/{name}/{name}.yy',meta)
        resources[name]={'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}
    register_project(resources,included)
    print(sum(len(v['frames']) for v in vectors),'original LN2 player updates')

if __name__=='__main__':main()
