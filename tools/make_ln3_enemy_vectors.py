"""Compare original LN3 enemy decisions, attacks, patrols and getting up.

Random raster input is supplied equally. Combat damage, animation playback,
scene collisions, health regeneration timing and system bus timing are separate.
"""
import json,random
from build_project import ROOT,PROJECT,read_json,write_json
from ln3_level_source import level_memory,layout,word,calls
from make_ln3_action_vectors import action_layout
from make_ln3_collision_vectors import state as collision_state
from export_ln1_world import call
from export_ln1_levels import register_project

FIELDS=dict(enemy_probe_wait=0x158,enemy_probe_x=0x159,enemy_dodge_wait=0x2ec,enemy_dodge_direction=0x2ed,
            enemy_pending_weapon=0x31a,weapon_fx_request=0xf2,weapon_fx_state=0xf3,
            enemy_attack_wait=0x147,patrol_remaining=0xee,patrol_index=0xef,patrol_joy=0xf0)

def state(mem,a):
    result=collision_state(mem,a);result.update({k:mem[p] for k,p in FIELDS.items()})
    result['enemy_throw_wait']=word(mem,0x156);return result

def main():
    rng=random.Random(0x52ea);vectors=[];included=[]
    for level in range(1,6):
        ram=level_memory(level);s=layout(ram);a=action_layout(ram,s);helpers=calls(ram,s['enemy_input'])
        draw=helpers[4];kneel=word(ram,draw+17);weapons=word(ram,draw+33);face=calls(ram,s['enemy_attack'])[0]
        attack_wait=word(ram,face-6);patrol=s['enemy_path'];table=None
        for p in range(patrol,patrol+70):
            if ram[p]==0xbd and ram[p+3:p+6]==bytes.fromhex('85 70 bd') and ram[p+8:p+10]==bytes.fromhex('85 71'):
                table=word(ram,p+1);break
        assert table is not None
        patrols=[]
        for kind in range(4):
            p=word(ram,table+2*kind);steps=[]
            while ram[p]!=255:
                steps.append(list(ram[p:p+2]));p+=2;assert len(steps)<64
            patrols.append(steps)
        data=dict(level=level,kneel_actions=list(ram[kneel:kneel+9]),room_weapons=list(ram[weapons:weapons+14]),
                  attack_wait=list(ram[attack_wait:attack_wait+4]),patrols=patrols,hazard_actor_exempt=level!=5)
        assert max(data['kneel_actions'])<61 and max(data['room_weapons'][:13])<=3,data
        path=PROJECT/f'datafiles/play/ln3/level{level}/enemy.json';write_json(path,data);included.append(path)
        world=read_json(ROOT/f'source/local/recovered/ln3/level{level}/world.json')
        entrypoints=[s['enemy_input'],s['enemy_attack'],s['enemy_path'],calls(ram,s['game_update'])[1]]
        for operation,entry in enumerate(entrypoints):
            for case in range(300):
                mem=list(ram);mem[0xe3]=rng.choice(world['rooms'])['id'];mem[0xec]=255;mem[0xe4]=rng.choice([0,1,2,4,5,6,8,9,10,17,18])
                call(mem,s['enemy_action'],a=rng.randrange(39,61));mem[0xed]=rng.choice([0,5,0,128]);mem[0xde]=rng.choice([0,6,96,102])
                mem[0x321]=rng.randrange(5);mem[0x322]=rng.randrange(5);mem[0x318]=rng.randrange(3)
                mem[0x317]=rng.choice([0,0,0,128,129,130,131]);mem[0xe1]=rng.choice([6,102,118,255])
                mem[0x54]=rng.choice([116,116,116,138]) if level!=5 else 116
                mem[0xfc]=rng.choice([0,0,0,255]);mem[0xfb]=rng.choice([0]*8+[255]);mem[0x309]=rng.choice([0]*8+[1])
                mem[0x2d9]=rng.choice([0,1,43,44]);mem[0x158]=rng.choice([0,1,16]);mem[0x159]=rng.choice([99,100,101,104])
                mem[0xf9]=mem[0x4c]=100;mem[0xfa]=mem[0x4d]=100;mem[0x4a]=100;mem[0x4b]=79
                mem[0xf7]=mem[0x44]=100+rng.choice([-64,-24,-16,-9,-8,-2,0,2,8,9,16,24,64])
                mem[0xf8]=mem[0x45]=100+rng.choice([-64,-16,-8,-4,-3,0,3,4,8,16,64])
                mem[0x42]=mem[0x44];mem[0x43]=mem[0x45]-21
                mem[0x2f3]=rng.choice([0,1,2,4,5,6,8,9,10]);mem[0x2f4]=rng.choice([0,0,1,4])
                mem[0x2ec]=rng.choice([0,0,1,8]);mem[0x2ed]=rng.choice([4,8]);mem[0x2bc]=rng.choice([0,1,2,4,5,6,8,9,10])
                mem[0x320]=rng.randrange(2);mem[0x156:0x158]=rng.choice([[0,0],[0,0],[1,0],[232,3]])
                mem[0x147]=rng.choice([0,0,0,1,4]);mem[0x31a]=rng.randrange(4);mem[0xf3]=rng.choice([0,5])
                mem[0xee]=rng.choice([0,0,1,3]);mem[0xef]=0;mem[0xf0]=rng.choice([0,1,2,4,5,6,8,9,10])
                random_byte=rng.randrange(256);mem[0xd012]=random_byte
                before=state(mem,a);call(mem,entry)
                vectors.append(dict(level=level,operation=operation,random=random_byte,before=before,expected=state(mem,a)))
        print('LN3 level',level,'enemy decisions recovered',flush=True)
    path=PROJECT/'datafiles/verification/ln3_enemy_vectors.json'
    path.write_text(json.dumps(dict(vectors=vectors,scope=__doc__),separators=(',',':'))+'\n');included.append(path)
    resources={}
    for name in ('ln3_enemy','ln3_enemy_checks'):
        meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
        write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);resources[name]={'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}
    register_project(resources,included);print(len(vectors),'original LN3 enemy decisions')

if __name__=='__main__':main()
