"""Compare source entrance motion and isolated moving-world rules.

Rendering requests and forced entrances are intercepted. This is a routine
oracle, not a full original-game replay or a whole-machine timing claim.
"""
import json,random,sys
from build_project import ROOT,PROJECT,read_json,write_json
from ln2_level_source import level_memory,layout,word
from make_ln2_player_vectors import state as player_state,call as player_call
from make_ln2_enemy_vectors import state as enemy_state
from export_ln1_levels import register_project
from py65.devices.mpu6502 import MPU

WORLD={1:0x9f1c,2:0x9a8e,3:0x85ac,4:0x9851,5:0x9814,6:0x9b9a,7:0x922a}
MODES={1:[1,2,8],2:[3,4],3:[5,6,7],4:[9,11],5:[10],6:[],7:[]}

def snapshot(mem,d):
    p=player_state(mem)
    for key in ('enemy_x','enemy_y','enemy_active','gate_open','gate_mode'):p.pop(key)
    return dict(player=p,enemy=enemy_state(mem,d),inventory=mem[0x3d8:0x3f2],
                player_health=mem[0x229],special_mode=mem[0xf8],special_flag=mem[0xb1],
                special_count=mem[0x29b],exit_locked=bool(mem[0x234]),world_clock=mem[0x277],
                pending_entry=mem[0x278] if mem[0x2a9] else -1,
                projectile=dict(kind=mem[0x280],x=mem[0x284],y=mem[0x286],phase=mem[0x288]))

def invoke(mem,s,address):
    cpu=MPU(memory=mem,pc=address);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1];draws={};entry=-1
    for _ in range(80000):
        if cpu.pc==0x1ff:return draws,entry
        if cpu.pc==s['entrance']:
            entry=cpu.x;cpu.pc=(cpu.stPopWord()+1)&65535
        elif cpu.pc in (s['actor_player'],s['actor_enemy'],s['mask']):
            if cpu.pc!=s['mask']:
                who='enemy' if cpu.pc==s['actor_enemy'] or cpu.x==4 else 'player'
                draws[who]=dict(frame=cpu.y,mirror=cpu.a!=0)
                if who=='player':mem[0x9f]=0
            cpu.pc=(cpu.stPopWord()+1)&65535
        else:cpu.step()
    raise AssertionError(f'LN2 source sequence did not return at ${cpu.pc:04x}')

def main():
    vehicles=[];worlds=[];rng=random.Random(0x0293)
    for level in range(1,8):
        ram=level_memory(level);s=layout(ram);d=read_json(ROOT/f'source/local/recovered/ln2/level{level}/gameplay.json')
        w=read_json(PROJECT/f'datafiles/play/ln2/level{level}/world.json')
        for mode in range(1,6 if level==6 else 5):
            for limit in (1,2,6):
                for facing in (1,3):
                    mem=list(ram);mem[0x60:0x62]=[0,0];mem[0x293]=mode;mem[0x294]=limit
                    mem[0x69]=facing;mem[0x68]=facing;mem[0x54]=120;mem[0x55]=100;mem[0x74]=100;mem[0xb6]=0
                    initial=player_state(mem);frames=[];display=dict(frame=mem[0x65],mirror=False)
                    room=next(r for r in w['rooms'] if r['id']==mem[0xa2])
                    for i in range(64):
                        tick=(initial['tick']+i+1)&255;joy=[0,25,6,18][i%4]
                        drawn=player_call(mem,s,tick,joy)
                        if drawn is not None:display=drawn
                        frames.append(dict(tick=tick,joy=joy,expected=player_state(mem),display=display))
                    vehicles.append(dict(level=level,mode=mode,limit=limit,facing=facing,initial=initial,boundaries=room['boundaries'],frames=frames))
        for mode in MODES[level]:
            room=next(r for r in w['rooms'] if len(r['entries'])>=2)
            for index in range(320):
                mem=list(ram);mem[0xf8]=mode;mem[0xa2]=room['id'];mem[0x2a9]=0;mem[0x234]=0
                mem[0x61]=0;mem[0x63]=0 if index&1 else 0xc7
                mem[0x54]=rng.choice([0,3,21,22,47,48,49,80,127,128,146,147,167,168,172,239,240,255])
                mem[0x55]=rng.choice([0,20,57,58,60,88,100,116,117,130,143,189,255])
                mem[0x56]=rng.choice([0,3,4,7,8,47,48,64,87,88,120,172,239,240,255])
                mem[0x57]=rng.choice([0,21,48,72,87,88,100,114,143,255]);mem[0x76]=mem[0x57]
                mem[0x6d]=rng.choice([0,12,15,20]);mem[0x81]=rng.choice([0,1,128,129,255]);mem[0xb6]=0
                mem[0x229]=44;mem[0xb1]=rng.choice([0,127,255]);mem[0x29b]=0
                mem[0xe2]=rng.randrange(256);mem[0x277]=(mem[0xe2]-rng.choice([0,1,2,3,7]))&255
                mem[0x3ea]=rng.choice([0,255]);mem[0x3ec]=rng.randrange(3)
                mem[0x280]=rng.choice([0,7]);mem[0x284]=rng.randrange(256);mem[0x286]=rng.choice([121,122,123]);mem[0x288]=rng.choice([0,7,8])
                before=snapshot(mem,d);draws,entry=invoke(mem,s,WORLD[level]);expected=snapshot(mem,d)
                if entry>=0:expected['pending_entry']=entry
                worlds.append(dict(level=level,room=room['id'],before=before,expected=expected,draws=draws))
        print('LN2 sequence oracles level',level,'ready',flush=True)
    target=PROJECT/'datafiles/verification/ln2_sequence_vectors.json'
    target.write_text(json.dumps(dict(vehicles=vehicles,worlds=worlds,scope=__doc__),separators=(',',':'))+'\n')
    register_project({},[target])
    print(sum(len(v['frames']) for v in vehicles),'source entrance-motion states;',len(worlds),'moving-world comparisons')

if __name__=='__main__':main()
