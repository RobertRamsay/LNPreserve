"""Independent original-machine-code oracle for enemy decisions and animation.

Random-byte returns are provided explicitly to both implementations. This
isolates behavior from the still-unverified hardware-random sampling phase.
"""
import json,random,sys
from export_ln1_play import ROOT,FIELDS
from make_ln1_player_vectors import state as player_state
sys.path.insert(0,str(ROOT/'tools/vendor/pydeps'))
from py65.devices.mpu6502 import MPU

ENEMY_FIELDS=dict(x=0x56,y=0x57,fraction_x=0x52,fraction_y=0x53,facing=0x6b,heading=0x6a,
    frame=0x67,action_state=0x66,countdown=0x5a,duration=0x5b,flags=0x5e,action_mirror=0x5f,
    weapon=0x72,active=0xcb,mode=0xcf,combat_state=0x6f,previous_combat=0x73,traits=0xd0,
    speed=0xd2,speed_traits=0xd3,colour_traits=0xd4,patrol_x=0xd1,origin_x=0x28e,origin_y=0x28f,
    target_x=0x28a,target_y=0x28b,decision_tick=0x274,action_tick=0x270,wait_tick=0x275,
    wait_duration=0xcc,turn_tick=0xd8,react_tick=0x276,react_random=0xd5,attack_count=0xd7,
    wounds=0x2b9,separation_y=0xd9,projectile_active=0x281)

def enemy_state(mem):
    result={name:mem[addr] for name,addr in ENEMY_FIELDS.items()}
    result['action']=mem[0x62]+256*mem[0x63]
    return result

def call(mem,entry,randoms):
    cpu=MPU(memory=mem,pc=entry);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1]
    used=[];display=None
    for _ in range(50000):
        if cpu.pc==0x1ff:return used,display
        if cpu.pc==0x79d2:
            value=next(randoms);used.append(value);cpu.a=value;cpu.p&=~1
            cpu.pc=(cpu.stPopWord()+1)&65535
        elif cpu.pc in (0x7655,0x6ff9):
            if cpu.pc==0x7655:display=dict(frame=cpu.y,mirror=cpu.a!=0)
            cpu.pc=(cpu.stPopWord()+1)&65535
        else:cpu.step()
    raise AssertionError(f'Original enemy did not return ${cpu.pc:04x}')

def main():
    ram=(ROOT/'source/local/captures/ln1-game-ram.bin').read_bytes();rng=random.Random(6502);vectors=[]
    for mode in range(10):
        for direction in (1,3,5,7):
            for weapon in range(4):
                mem=list(ram)
                initial_fields=dict(x=rng.randrange(12,240),y=rng.randrange(20,160),fraction_x=rng.randrange(256),
                    fraction_y=rng.randrange(256),facing=direction,heading=direction,weapon=weapon,
                    active=128+weapon,mode=mode,combat_state=direction>>1,traits=rng.choice((0,64,128,192)),
                    speed=rng.randrange(4),speed_traits=rng.randrange(4)*4,colour_traits=0,
                    patrol_x=120,origin_x=8,origin_y=80,target_x=96,target_y=106,decision_tick=0,action_tick=0,
                    wait_tick=0,wait_duration=rng.randrange(32),turn_tick=0,react_tick=0,react_random=rng.randrange(256),
                    attack_count=rng.randrange(5),wounds=0,separation_y=10,projectile_active=0)
                for key,value in initial_fields.items():mem[ENEMY_FIELDS[key]]=value
                mem[0x62]=mem[0x63]=0;mem[0x1b]=32
                initial=enemy_state(mem);p=player_state(mem);frames=[];display=dict(frame=mem[0x67],mirror=False)
                randoms=iter(rng.randrange(256) for _ in range(2000))
                for tick in range(33,81):
                    mem[0x1b]=tick
                    used,_=call(mem,0x6a48,randoms)
                    # Action-state dispatch is deliberately separate from this test.
                    _,drawn=call(mem,0x5b54,randoms)
                    if drawn is not None:display=drawn
                    frames.append(dict(tick=tick,randoms=used,expected=enemy_state(mem),display=display))
                vectors.append(dict(name=f'mode{mode}_facing{direction}_weapon{weapon}',initial=initial,player=p,frames=frames))
    out=ROOT/'LNPreserve/datafiles/verification/ln1_enemy_vectors.json'
    out.write_text(json.dumps(dict(schema=1,fields=ENEMY_FIELDS,vectors=vectors,
        scope='Original enemy AI and animation with shared random returns. Drawing, combat dispatch, hardware random phase and full system timing excluded.'),separators=(',',':'))+'\n')
    print(len(vectors),'sequences;',sum(len(v['frames']) for v in vectors),'original enemy updates')

if __name__=='__main__':main()
