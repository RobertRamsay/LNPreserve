"""Compare LN3's boundary walk and responses across all five original banks.

Boundary response includes sliding, enemy steering and hazard flags. Subsequent
hazard presentation, room travel, combat and IRQ timing are outside this check.
"""
import json,random,math
from build_project import ROOT,PROJECT,read_json,write_json
from ln3_level_source import level_memory,layout,word,calls
from make_ln3_action_vectors import action_layout
from make_ln3_animation_vectors import state as animation_state
from export_ln1_world import call
from export_ln1_levels import register_project

FIELDS=dict(collision_retried=0x2ee,collision_pass=0x2ef,collision_flags=0xe8,collision_type=0xe9,
            collision_extended=0x300,trap_count=0x301,trap_flags=0x302,boundary_index=0x310,
            last_boundary=0x311,trap_contacts=0x31f,waterline=0x2f5,special_scene_phase=0x2f6,fire_gate=0x313)

def state(mem,a):
    result=animation_state(mem,a);result.update({k:mem[p] for k,p in FIELDS.items()});return result

def main():
    rng=random.Random(0x584f);vectors=[];included=[]
    for level in range(1,6):
        ram=level_memory(level);s=layout(ram);a=action_layout(ram,s);setup=calls(ram,s['collision'])[0]
        actor_table=word(ram,setup+16)
        world=read_json(ROOT/f'source/local/recovered/ln3/level{level}/world.json')
        data=dict(level=level,actor_order=[ram[actor_table+1]//2,ram[actor_table]//2],
                  hazard_actor_exempt=level!=5,rooms=[dict(id=q['id'],boundaries=[b['raw'] for b in q['boundaries']]) for q in world['rooms']])
        assert sorted(data['actor_order'])==[0,4],data['actor_order']
        path=PROJECT/f'datafiles/play/ln3/level{level}/collision.json';write_json(path,data);included.append(path)
        for room in data['rooms']:
            for boundary_index,raw in enumerate(room['boundaries']):
                slope=raw[4]>>6
                for position in (0,1,2):
                    x=[raw[0],(raw[0]+raw[2])//2,raw[2]][position]
                    line=raw[1]+math.ceil((x-(raw[0]-2))/4)*(1 if slope==1 else -1)
                    if slope==0:line=(raw[1]+raw[3])//2
                    for offset in (-4,0,4):
                        mem=list(ram);mem[0xe3]=room['id'];mem[0xe4]=rng.choice([1,2,4,5,6,8,9,10])
                        mem[0xe6]=255;call(mem,s['player_action'],a=rng.choice([0,1,2,3,4,5,28,29,34]))
                        mem[0x2fc]=mem[0x303]=mem[0x2f9]=0;mem[0xe1]=118;mem[0x54]=116
                        mem[0x309]=rng.choice([0,1]);mem[0x2f6]=rng.choice([0,2]);mem[0x313]=rng.choice([0,255])
                        mem[0x311]=rng.choice([0,255]);mem[0x2f4]=rng.choice([0,0,3])
                        for base in (0,4):
                            actor_x=(x+(2 if base else 0))&255;actor_y=(line+offset)&255
                            for i in (base+1,base+2):
                                mem[0x40+2*i]=actor_x;mem[0x41+2*i]=(actor_y-(21 if i%4==1 else 0))&255
                                mem[0x240+2*i]=(actor_x-rng.choice([-4,0,4]))&255
                                mem[0x241+2*i]=(mem[0x41+2*i]-rng.choice([-1,0,1]))&255
                                mem[0x2b6+i]=mem[0xe4]&15
                            mem[0xf7+(2 if base else 0)]=actor_x;mem[0xf8+(2 if base else 0)]=actor_y
                        before=state(mem,a);call(mem,s['collision'])
                        vectors.append(dict(level=level,room_id=room['id'],boundary=boundary_index,before=before,expected=state(mem,a)))
        print('LN3 level',level,'source boundary responses recovered',flush=True)
    path=PROJECT/'datafiles/verification/ln3_collision_vectors.json'
    path.write_text(json.dumps(dict(vectors=vectors,scope=__doc__),separators=(',',':'))+'\n');included.append(path)
    resources={}
    for name in ('ln3_collision','ln3_collision_checks'):
        meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
        write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);resources[name]={'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}
    register_project(resources,included);print(len(vectors),'original LN3 boundary responses')

if __name__=='__main__':main()
