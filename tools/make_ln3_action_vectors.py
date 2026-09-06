"""Original LN3 player/enemy action setup, including mutable movement tables.

Routine-level comparisons do not cover input, collisions, animation playback,
the original IRQ schedule, or complete gameplay.
"""
import json,random
from build_project import ROOT,PROJECT,read_json,write_json
from ln3_level_source import level_memory,layout,word,calls
from make_ln3_movement_vectors import state as movement_state
from export_ln1_world import call
from export_ln1_levels import register_project

def action_layout(ram,s):
    p=s['player_action'];lookup=calls(ram,p)[0]
    return dict(base=ram[lookup+3]+256*ram[lookup+7],
                directions=word(ram,p+50),player_modes=word(ram,p+61),
                enemy_modes=word(ram,s['enemy_action']+48),
                upward=word(ram,p+103),motion=word(ram,s['movement_setup']+10))

def state(mem,a):
    result=movement_state(mem);result['joy']=mem[0xe4]
    result['action_flags']=[mem[a['base']+i*4+3] for i in range(61)]
    result['motion_directions']=[mem[a['motion']+i*2] for i in range(16)]
    return result

def main():
    vectors=[];included=[];rng=random.Random(0x51f6)
    for level in range(1,6):
        ram=level_memory(level);s=layout(ram);a=action_layout(ram,s)
        data=dict(level=level,actions=[list(ram[a['base']+i*4:a['base']+i*4+4]) for i in range(61)],
            directions=list(ram[a['directions']:a['directions']+9]),
            player_modes=list(ram[a['player_modes']:a['player_modes']+9]),
            enemy_modes=list(ram[a['enemy_modes']:a['enemy_modes']+9]),
            upward_actions=list(ram[a['upward']:a['upward']+6]))
        assert sorted(data['directions'])==[0,1,2,4,5,6,8,9,10],a
        assert max(data['player_modes']+data['enemy_modes'])<16,a
        path=PROJECT/f'datafiles/play/ln3/level{level}/actions.json';write_json(path,data);included.append(path)
        for action in range(61):
            for joy in data['directions']:
                for mirror in (0,102):
                    mem=list(ram);mem[0xde]=mirror;mem[0xe4]=joy|rng.choice([0,16])
                    mem[0xe1]=rng.randrange(256);mem[0xe6]=rng.choice([0,action]);mem[0xec]=rng.choice([39,action])
                    for i in range(8):mem[0x58+i]=rng.randrange(16)
                    before=state(mem,a)
                    call(mem,s['player_action' if action<39 else 'enemy_action'],a=action)
                    vectors.append(dict(level=level,action=action,before=before,expected=state(mem,a)))
        print('LN3 level',level,'action setup recovered',flush=True)
    path=PROJECT/'datafiles/verification/ln3_action_vectors.json'
    path.write_text(json.dumps(dict(vectors=vectors,scope=__doc__),separators=(',',':'))+'\n');included.append(path)
    resources={}
    for name in ('ln3_actions','ln3_action_checks'):
        meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
        write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);resources[name]={'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}
    register_project(resources,included);print(len(vectors),'original LN3 action states')

if __name__=='__main__':main()
