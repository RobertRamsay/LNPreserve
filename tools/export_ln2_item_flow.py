"""Original LN2 post-interaction animation continuations across seven levels."""
import json
from ln2_level_source import *
from build_project import PROJECT,read_json,write_json
from export_ln1_levels import register_project
from export_ln1_world import call
from export_ln2_content import actions


def main():
    included=[];vectors=[]
    for level in range(1,8):
        ram=level_memory(level);entry=locate(ram,0xbf56,33);old=word(ram,entry+5);new=word(ram,entry+17)
        pairs=[dict(before=word(ram,old+i),after=word(ram,new+i)) for i in range(10,-1,-2)]
        for pointer in [p['before'] for p in pairs]+[0]:
            for countdown in range(256):
                mem=list(ram);mem[0x60]=pointer&255;mem[0x61]=pointer>>8;mem[0x58]=countdown;call(mem,entry)
                vectors.append(dict(level=level,action=pointer,countdown=countdown,expected_action=word(mem,0x60),expected_countdown=mem[0x58]))
        path=PROJECT/f'datafiles/play/ln2/level{level}/item_flow.json';write_json(path,dict(pairs=pairs));included.append(path)
        path=PROJECT/f'datafiles/play/ln2/level{level}/gameplay.json';d=read_json(path);added=actions(ram,[p['after'] for p in pairs]);before=len(d['actions']);d['actions'].update(added)
        new_frames={a['frame'] for a in added.values() if a['frame']!=255}-set(d['frames'])
        assert not new_frames,('New item continuation artwork required',level,new_frames)
        write_json(path,d);write_json(ROOT/f'source/local/recovered/ln2/level{level}/gameplay.json',d)
        print('LN2 item continuation',level,'new graph records',len(d['actions'])-before,flush=True)
    path=PROJECT/'datafiles/verification/ln2_item_flow_vectors.json';path.write_text(json.dumps(dict(vectors=vectors,scope=__doc__),separators=(',',':'))+'\n');included.append(path)
    register_project({},included);print(len(vectors),'original post-interaction animation states')


if __name__=='__main__':main()
