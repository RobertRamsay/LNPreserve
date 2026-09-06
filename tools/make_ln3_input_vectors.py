"""Compare the complete original LN3 input-selection routine in all five banks.

Includes weapon selection and leaving climbing poses. It does not advance
animation, world interactions, collisions, timers, or the original system bus.
"""
import json,random
from build_project import ROOT,PROJECT,read_json,write_json
from ln3_level_source import level_memory,layout,word
from make_ln3_action_vectors import action_layout,state as action_state
from export_ln1_world import call
from export_ln1_levels import register_project

FIELDS=dict(previous_joy=0xe5,fire_mode=0x20,fire_latch=0x2fe,input_block=0x303,
            stun=0x2fc,climb_flags=0x2f9,climb_goal=0x2fa,climb_start=0x2fb,
            climb_counter=0x309,climb_end_x=0x305,climb_end_y=0x306,
            climb_return_x=0x307,climb_return_y=0x308,weapon_notice_timer=0x14c,
            pending_weapon=0x2e9,notice_icon=0x319)

def state(mem,a):
    result=action_state(mem,a);result.update({k:mem[p] for k,p in FIELDS.items()})
    result['inventory']=list(mem[2:0x20]);return result

def main():
    rng=random.Random(0x4fc7);vectors=[];included=[]
    for level in range(1,6):
        ram=level_memory(level);s=layout(ram);a=action_layout(ram,s);select=s['player_action']-55
        assert ram[select:select+7]==bytes.fromhex('c9 27 90 02 e9 27 0a')
        rows=word(ram,select+22);choices=ram[select+45]+256*ram[select+49]
        inp=s['player_input'];mirror_table=word(ram,inp+0x75);kneel=word(ram,inp+0x128)
        # The input prefix and weapon selector are byte-for-byte equivalent
        # apart from relocated operands. Resolve the key-state operand there.
        key_state=word(ram,inp+0xcb)
        data=dict(level=level,control_rows=list(ram[rows:rows+78]),
                  control_choices=[list(ram[choices+i*9:choices+i*9+9]) for i in range(19)],
                  diagonal_actions=list(ram[mirror_table:mirror_table+4]),
                  weapon_kneel_actions=list(ram[kneel:kneel+16]))
        assert max(data['control_rows'])<19 and max(sum(data['control_choices'],[]))<39,(level,hex(choices))
        assert max(data['diagonal_actions'])<61 and max(data['weapon_kneel_actions'])<39
        path=PROJECT/f'datafiles/play/ln3/level{level}/input.json';write_json(path,data);included.append(path)
        for action in range(39):
            for joy in (0,1,2,4,5,6,8,9,10,16,17,18,20,21,22,24,25,26):
                mem=list(ram);mem[0xe6]=action;mem[0xe7]=rng.choice([0,1,128]);mem[0xde]=rng.choice([0,6,96,102])
                mem[0xe5]=rng.choice([0,joy]);mem[0x20]=rng.randrange(2);mem[0x2fe]=rng.choice([0,255])
                mem[0x321]=rng.randrange(5);mem[0xdc00]=joy^255
                for p in (0xfb,0x2fc,0x303):mem[p]=rng.choice([0,0,0,128])
                mem[0x2f9]=rng.choice([0,0,0,1,2]);mem[0x45]=rng.randrange(40,180)
                for p in (0x2fa,0x2fb,0x306,0x308):mem[p]=rng.randrange(40,180)
                for p in (0x305,0x307):mem[p]=rng.randrange(24,240)
                for p in range(2,6):mem[p]=rng.choice([0,255])
                switch=rng.choice([False,False,True]);mem[key_state]=0 if switch else 255
                before=state(mem,a);call(mem,s['player_input'])
                vectors.append(dict(level=level,joy=joy,weapon_switch=switch,before=before,expected=state(mem,a)))
        print('LN3 level',level,'original input selection recovered',flush=True)
    path=PROJECT/'datafiles/verification/ln3_input_vectors.json'
    path.write_text(json.dumps(dict(vectors=vectors,scope=__doc__),separators=(',',':'))+'\n');included.append(path)
    resources={}
    for name in ('ln3_input','ln3_input_checks'):
        meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
        write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);resources[name]={'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}
    register_project(resources,included);print(len(vectors),'original LN3 input states')

if __name__=='__main__':main()
