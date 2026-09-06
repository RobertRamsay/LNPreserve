"""Validate native LN3 masks for all 66 recovered scenes against original code.

The check covers individual 24x21 visibility masks and retained edge data.
GPU application to editable PNG sprites and full gameplay timing are separate.
"""
import json,random
from build_project import ROOT,PROJECT,read_json,write_json
from ln3_level_source import level_memory,layout
from export_ln3_assets import mask_shapes
from export_ln1_world import call
from export_ln1_levels import register_project

def main():
    rng=random.Random(0x6287);vectors=[];included=[]
    for level in range(1,6):
        ram=level_memory(level);s=layout(ram);world=read_json(ROOT/f'source/local/recovered/ln3/level{level}/world.json')
        rooms=[dict(id=r['id'],shapes=mask_shapes(ram,r)) for r in world['rooms']]
        path=PROJECT/f'datafiles/play/ln3/level{level}/masks.json';write_json(path,dict(rooms=rooms));included.append(path)
        for room in rooms:
            for case in range(64):
                x=rng.randrange(24,250);y=rng.randrange(40,206);foot=rng.choice([0,255,min(255,y+21)]+[max(0,m['baseline']) for m in room['shapes']])
                spill=rng.randrange(256);part=1 if case%2==0 else 5
                mem=list(ram);mem[0xe3]=room['id'];mem[0xdc]=part
                mem[0x40+2*part]=x;mem[0x41+2*part]=y;mem[0x45 if part<4 else 0x4d]=foot
                mem[0x63]=spill;mem[0x200:0x23f]=[255]*63;call(mem,s['mask'])
                vectors.append(dict(level=level,room_id=room['id'],x=x,y=y,foot=foot,spill=spill,
                                    expected=list(mem[0x200:0x23f]),expected_spill=mem[0x63]))
        print('LN3 level',level,'source mask fixtures recovered',flush=True)
    path=PROJECT/'datafiles/verification/ln3_mask_vectors.json'
    path.write_text(json.dumps(dict(vectors=vectors,scope=__doc__),separators=(',',':'))+'\n');included.append(path)
    resources={}
    for name in ('ln3_masks','ln3_mask_checks'):
        meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
        write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);resources[name]={'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}
    register_project(resources,included);print(len(vectors),'original LN3 masks')

if __name__=='__main__':main()
