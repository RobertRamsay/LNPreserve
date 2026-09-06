"""Original LN3 sprite-part movement/actor separation, isolated from collision
geometry, input, animation side effects, IRQ timing and full-game behavior."""
import json,random
from build_project import ROOT,PROJECT,read_json,write_json
from ln3_level_source import level_memory,layout,word
from export_ln3_content import actor_state
from export_ln1_world import call
from export_ln1_levels import register_project

def state(mem):
    s=actor_state(mem);s.update(enemy_turn_direction=mem[0x2f3],enemy_turn_wait=mem[0x2f4],room_id=mem[0xe3])
    for i,part in enumerate(s['parts']):part.update(old_x=mem[0x240+i*2],old_y=mem[0x241+i*2])
    return s

def main():
    vectors=[];included=[];rng=random.Random(0x5535)
    for level in range(1,6):
        ram=level_memory(level);s=layout(ram);base=word(ram,s['movement_setup']+10)
        data=dict(level=level,motion=[dict(direction=ram[base+i*2],dx=ram[base+i*2+1]>>4,dy=ram[base+i*2+1]&15) for i in range(16)],
                  clear_masks=list(ram[0xff80:0xff88]),
                  hazard_actor_exempt=bytes.fromhex('a5 54 c9 8a') in ram[s['move']:s['interaction']])
        path=PROJECT/f'datafiles/play/ln3/level{level}/movement.json';write_json(path,data);included.append(path)
        for case in range(1200):
            mem=list(ram);mem[0xe1]=rng.choice([0,6,96,102,255]);mem[0xde]=rng.randrange(256)
            if level==2:mem[0xe3]=rng.choice([0,4,5,6])
            mem[0xe6]=rng.choice([0,2,5,6,28,29,35]);mem[0xfc]=rng.choice([0,0,255])
            for i in range(8):
                mem[0x40+i*2]=rng.choice([0,1,12,23,24,40,80,120,239,240,243,244,255])
                mem[0x41+i*2]=rng.choice([0,20,40,100,103,104,143,189,255])
                mem[0x50+i]=rng.choice([0,114,138]) if i in (3,4,7) else rng.randrange(100)
                mem[0x2a6+i]=rng.choice([0,128,129,130,131,132,133,134,135,136,137,138])
                mem[0x2b6+i]=rng.randrange(16);mem[0x2be+i]=rng.randrange(5);mem[0x2c6+i]=rng.randrange(5)
            mem[0xf7]=mem[0x44];mem[0xf8]=mem[0x45];mem[0xf9]=mem[0x4c];mem[0xfa]=mem[0x4d]
            before=state(mem);setup=case%2==0
            if setup:call(mem,s['movement_setup'])
            call(mem,s['move']);vectors.append(dict(level=level,setup=setup,before=before,expected=state(mem)))
        print('LN3 movement bank',level,'original comparisons recovered',flush=True)
    path=PROJECT/'datafiles/verification/ln3_movement_vectors.json';path.write_text(json.dumps(dict(vectors=vectors,scope=__doc__),separators=(',',':'))+'\n');included.append(path)
    resources={}
    for name in ('ln3_movement','ln3_movement_checks'):
        meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
        write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);resources[name]={'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}
    register_project(resources,included);print(len(vectors),'original LN3 part-movement states')

if __name__=='__main__':main()
