"""Offline LN2 enemy oracle: original decisions, movement, and action playback.

Shared random returns isolate AI from the unverified CIA sampling phase.
Combat/world dispatch is tested separately, not simulated by this oracle.
"""
import json,random,sys
from build_project import ROOT,PROJECT,read_json,write_json
from ln2_level_source import level_memory,layout,word
from export_ln1_world import call as source_call
from export_ln1_levels import register_project
from make_ln2_player_vectors import state as player_state
sys.path.insert(0,str(ROOT/'tools/vendor/pydeps'))
from py65.devices.mpu6502 import MPU

FIELDS=dict(x=0x56,y=0x57,fraction_x=0x52,fraction_y=0x53,facing=0x6b,heading=0x6a,
 frame=0x67,action_state=0x66,countdown=0x5a,duration=0x5b,flags=0x5e,action_mirror=0x5f,
 weapon=0x72,active=0xcb,mode=0xcf,combat_state=0x6f,previous_combat=0x73,traits=0xd0,
 speed=0xd3,patrol_x=0xd1,origin_x=0x28e,origin_y=0x28f,target_x=0x28a,target_y=0x28b,
 decision_tick=0x274,action_tick=0x26e,wait_tick=0x275,wait_duration=0xcc,turn_tick=0x2be,
 react_tick=0x276,react_random=0xd5,attack_count=0x2bd,health=0x22a,depth_y=0x76,
 separation_y=0x236,projectile_active=0x281,boundary_hit=0x2b0,edge_blocked=0x2b1,
 actor_blocked=0x2b2,last_boundary=0x2b3,hit_side=0x2b4,last_side=0x2b5,
 boundary_history1=0x2a4,boundary_history2=0x2a5)

def state(mem,data):
    result={key:mem[address] for key,address in FIELDS.items()}
    result.update(action=word(mem,0x62),knockouts=mem[data['knockout_table']+mem[0xa2]],
        recovery_time=mem[data['recovery_low_table']+mem[0xa2]]+256*mem[data['recovery_high_table']+mem[0xa2]])
    return result

def call(mem,source,entry,randoms):
    cpu=MPU(memory=mem,pc=entry);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1]
    used=[];display=None
    for _ in range(50000):
        if cpu.pc==0x1ff:return used,display
        if cpu.pc==source['random']:
            value=next(randoms);used.append(value);cpu.a=value;cpu.p&=~1
            cpu.pc=(cpu.stPopWord()+1)&65535
        elif cpu.pc in (source['actor_enemy'],source['mask']):
            if cpu.pc==source['actor_enemy']:display=dict(frame=cpu.y,mirror=cpu.a!=0)
            cpu.pc=(cpu.stPopWord()+1)&65535
        else:cpu.step()
    raise AssertionError(f'Original enemy failed to return at ${cpu.pc:04x}')

def main():
    rng=random.Random(65022);vectors=[];included=[]
    for level in range(1,8):
        ram=level_memory(level);s=layout(ram);folder=ROOT/f'source/local/recovered/ln2/level{level}'
        d=read_json(folder/'gameplay.json');w=read_json(folder/'world.json')
        target=PROJECT/f'datafiles/play/ln2/level{level}/gameplay.json';write_json(target,d);included.append(target)
        fixtures=[]
        for mode in list(range(13))+[15]:
            for facing in (1,3,5,7):
                for weapon in (0,1,3):
                    fixtures.append((f'mode{mode}_face{facing}_weapon{weapon}',None,mode,facing,weapon))
        for room in w['rooms']:
            if room['enemy']['active']>=128:
                fixtures.append((f'room{room["id"]}_spawn',room,None,None,None))
        for name,room,mode,facing,weapon in fixtures:
            mem=list(ram);mem[s['actor_draw']]=0x60;mem[s['mask']]=0x60
            if room is None:
                mem[s['boundary_table']+1]=0;bounds=[]
                values=dict(x=rng.randrange(12,240),y=rng.randrange(20,160),fraction_x=rng.randrange(256),
                    fraction_y=rng.randrange(256),facing=facing,heading=facing,weapon=weapon,active=128+weapon,
                    mode=mode,combat_state=facing>>1,traits=rng.choice((0,64,128,192)),speed=rng.randrange(4),
                    patrol_x=120,origin_x=8,origin_y=80,target_x=96,target_y=106,decision_tick=0,action_tick=0,
                    wait_tick=0,wait_duration=rng.randrange(32),turn_tick=0,react_tick=0,react_random=rng.randrange(256),
                    attack_count=rng.randrange(4),health=44,separation_y=6,depth_y=100,projectile_active=0,
                    boundary_hit=255,edge_blocked=0,actor_blocked=0,last_boundary=255,hit_side=0,last_side=0,
                    boundary_history1=255,boundary_history2=255)
                for key,value in values.items():mem[FIELDS[key]]=value
                mem[0x62]=mem[0x63]=0
                mem[d['knockout_table']+mem[0xa2]]=128 if mode==11 else 0
                mem[d['recovery_low_table']+mem[0xa2]]=0;mem[d['recovery_high_table']+mem[0xa2]]=0
            else:
                entry=next(i for i,dest in enumerate(w['tables']['exit_destinations']) if dest==room['id'])
                source_call(mem,s['entrance'],x=entry);source_call(mem,s['boundary_enter']);source_call(mem,s['enemy_enter'])
                bounds=room['boundaries']
            mem[0xe2]=32;mem[0xf0]=6;mem[0xef]=0
            initial=state(mem,d);p=player_state(mem);frames=[];display=dict(frame=mem[0x67],mirror=False)
            randoms=iter(rng.randrange(256) for _ in range(4000))
            for tick in range(33,97 if room else 73):
                mem[0xe2]=tick
                used,_=call(mem,s,s['enemy_decide'],randoms)
                used2,drawn=call(mem,s,s['enemy_action'],randoms)
                if drawn is not None:display=drawn
                frames.append(dict(tick=tick,randoms=used+used2,expected=state(mem,d),display=display))
            vectors.append(dict(level=level,name=name,initial=initial,player=p,tick_epoch=6,boundaries=bounds,frames=frames))
        print('LN2 enemy level',level,len(fixtures),'sequences',flush=True)
    target=PROJECT/'datafiles/verification/ln2_enemy_vectors.json'
    target.write_text(json.dumps(dict(vectors=vectors,scope=__doc__),separators=(',',':'))+'\n');included.append(target)
    resources={}
    for name in ['ln2_enemy','ln2_enemy_checks']:
        meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
        write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);resources[name]={'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}
    register_project(resources,included)
    print(sum(len(v['frames']) for v in vectors),'original LN2 enemy updates')

if __name__=='__main__':main()
