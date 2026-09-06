"""Original LN3 pickup/mechanism rules and proximity notifications.

HUD bitmap writes execute offline; the native check compares gameplay state,
inventory, score and notice selection. Complete HUD pixels and timing remain
outside this component check.
"""
import json,random
from export_ln3_runtime import *
from make_ln3_combat_vectors import combat_layout
from ln3_level_source import MPU

ENTRIES=[0x698e,0x6b2b,0x6983,0x6a24,0x6b1c]
NOTICES=[0x6ef9,0x6fee,0x6e57,0x6f42,0x6fdf]

def item_state(mem,a):
    result=state(mem,a);result['portrait_visible']=mem[0x31b];return result

def original(mem,entry,notice):
    cpu=MPU(memory=mem,pc=entry);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1];found=-1
    for _ in range(100000):
        if cpu.pc==0x1ff:return found
        if cpu.pc==notice:found=cpu.x
        cpu.step()
    raise AssertionError(f'LN3 item routine did not return: {cpu.pc:04x}')

def main():
    vectors=[];included=[];rng=random.Random(0x698e)
    for level in range(1,6):
        ram=level_memory(level);s=layout(ram);a=action_layout(ram,s);c=combat_layout(ram,s)
        entry=ENTRIES[level-1];lo=word(ram,entry+3);hi=word(ram,entry+8)
        slo=word(ram,c['score']+1);shi=word(ram,c['score']+7);score=ram[slo+5]+256*ram[shi+5]
        data=dict(level=level,rooms=[],score_awards=[list(ram[score:score+6])])
        for rid in range(hi-lo):
            p=ram[lo+rid]+256*ram[hi+rid];records=[]
            while ram[p]!=255:
                records.append(list(ram[p:p+5]));p+=5;assert len(records)<20
            data['rooms'].append(dict(id=rid,items=records))
            for record in records:
                for case in range(120):
                    mem=list(ram);mem[0xe3]=rid
                    mem[2:0x1b]=[rng.choice([0]*6+[1,128]) for _ in range(25)]
                    mem[2+record[0]]=rng.choice([0]*8+[1,128]) if record[0]<25 else mem[2+record[0]]
                    mem[0xe6]=rng.choice([0,24,26,26,27,27,28]);mem[0x59]=rng.choice([0,2,3,3,3,4])
                    mem[0x44]=rng.choice([record[1]-1,record[1],(record[1]+record[2])//2,record[2],record[2]+1])&255
                    mem[0x45]=rng.choice([record[3]-1,record[3],(record[3]+record[4])//2,record[4],record[4]+1])&255
                    mem[0xf3]=rng.randrange(9);mem[0xf2]=rng.choice([0,0,1]);mem[0x31a]=rng.choice([record[0],0,24]);mem[0x31b]=rng.randrange(2)
                    mem[0x2f6]=rng.randrange(3);mem[0x2ff]=rng.choice([0,1,255]);mem[0xf4]=rng.choice([0,6,13,17]);mem[0x1d]=rng.choice([1,4,5,255]);mem[0x1c]=rng.choice([0,10,44])
                    mem[0x100:0x106]=[48,48,57,57,57,48]
                    before=item_state(mem,a);found=original(mem,entry,NOTICES[level-1])
                    vectors.append(dict(level=level,room_id=rid,before=before,expected=item_state(mem,a),found=found))
        path=PROJECT/f'datafiles/play/ln3/level{level}/items.json';write_json(path,data);included.append(path)
        print('LN3 items',level,sum(len(r['items']) for r in data['rooms']),flush=True)
    path=PROJECT/'datafiles/verification/ln3_item_vectors.json';path.write_text(json.dumps(dict(vectors=vectors,scope=__doc__),separators=(',',':'))+'\n');included.append(path)
    resources={}
    for name in ('ln3_items','ln3_item_checks'):
        meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
        write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);resources[name]={'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}
    register_project(resources,included);print(len(vectors),'original pickup/mechanism states')

if __name__=='__main__':main()
