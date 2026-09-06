"""Original LN3 room reset, enemy entry, hazard and climbing comparisons."""
import json,random
from export_ln3_runtime import *

def main():
    rng=random.Random(0x4e4f);vectors=[]
    for level in range(1,6):
        ram=level_memory(level);s=layout(ram);a=action_layout(ram,s)
        data=read_json(PROJECT/f'datafiles/play/ln3/level{level}/runtime.json')
        c=calls(ram,s['exit']);reset=c[c.index(s['scene_enter'])-1]
        updates=calls(ram,s['game_update']);ci=updates.index(s['collision'])
        entries=[reset,s['enemy_enter'],updates[ci+1],updates[ci+2],s['interaction']]
        if level>1:entries.append(updates[updates.index(s['movement_setup'])-1])
        for operation,entry in enumerate(entries):
            for scene in data['rooms']:
                for case in range(8):
                    mem=list(ram);mem[0xe3]=scene['id'];mem[0xe6]=mem[0xec]=255
                    call(mem,s['player_action'],a=rng.choice([0,1,2,3,6,20,21,28,29,30,35,36]))
                    call(mem,s['enemy_action'],a=rng.randrange(39,61))
                    mem[0xfc]=rng.choice([0,0,255]);mem[0xfb]=rng.choice([0,0,255]);mem[0xe1]=rng.randrange(256)
                    mem[0x2f6]=rng.choice([0,1,2]);mem[0x312]=rng.choice([0,1]);mem[0x2f8]=rng.randrange(3)
                    mem[0x2d0]=rng.choice([0,1]);mem[0x2d1]=rng.choice([0,1]);mem[0x317]=0
                    mem[0x2fc]=rng.choice([0,1]);mem[0x303]=rng.choice([0,0,1]);mem[0x301]=rng.choice([0,1,127,128,255]);mem[0x302]=rng.choice([0,128])
                    mem[0x31f]=rng.randrange(5);mem[0xf3]=rng.randrange(9);mem[0xf2]=rng.randrange(256)
                    mem[0x2f9]=rng.choice([0,0,1,2]);mem[0x309]=rng.randrange(2);mem[0xf4]=rng.choice([17,20,15,0]);mem[0x304]=rng.choice([0,1,3,255])
                    raw_joy=rng.choice([0,1,2,4,5,6,8,9,10]);mem[0xdc00]=raw_joy^255
                    if operation==4 and scene['climbs']:
                        climb=scene['climbs'][case%len(scene['climbs'])]
                        mem[0x44]=rng.choice([climb[0]-1,climb[0],climb[1]-1,climb[1]])&255
                        mem[0x45]=rng.choice([climb[2]-1,climb[2],climb[3]-1,climb[3]])&255
                        mem[0x2f9]=mem[0x2fc]=0;mem[0xe6]=rng.randrange(6);mem[0xdc00]=(climb[4]&15)^255;raw_joy=climb[4]&15
                    before=state(mem,a);call(mem,entry)
                    vectors.append(dict(level=level,room_id=scene['id'],operation=operation,joy=raw_joy,before=before,expected=state(mem,a)))
        print('LN3 scene vectors',level,flush=True)
    path=PROJECT/'datafiles/verification/ln3_scene_vectors.json';path.write_text(json.dumps(dict(vectors=vectors,scope=__doc__),separators=(',',':'))+'\n')
    register_project({},[path]);print(len(vectors),'original scene/interaction states')

if __name__=='__main__':main()
