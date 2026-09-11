import sys
from pathlib import Path
import argparse
pa=argparse.ArgumentParser();pa.add_argument('--source-root',type=Path,required=True);args=pa.parse_args()
sys.path[:0]=[str(args.source_root/'audit_python_deps'),str(Path(__file__).resolve().parent)]
import ln2_level_source as ls
ls.ROOT=args.source_root
import build_project as b
from export_ln1_world import call
from export_ln2_content import bitmap,actions
from export_ln1_levels import register_project
b.REFRESH_GRAPHICS=True
resources={};evidence=[]
for level,room,flag in [(4,14,17),(5,5,17),(5,9,20),(6,9,19),(6,9,20)]:
 r=ls.level_memory(level);s=ls.layout(r);w=b.read_json(b.PROJECT/f'datafiles/play/ln2/level{level}/world.json')
 item=next(i for i in w['items'] if i['room']==room and i['id']==flag)
 m=list(r);m[0xa2]=room;m[0x3d8:0x3f2]=[0]*26
 for addr in [0x140e,s['scene_choose'],s['item_enter']]:call(m,addr)
 images=[bitmap(m)];ptr=item['removed_panel'];m[2:4]=[ptr&255,ptr>>8];call(m,ls.locate(r,0x8914,24));images.append(bitmap(m))
 changed=sum(x!=y for x,y in zip(images[0].getdata(),images[1].getdata()));print(level,room,flag,changed,flush=True);assert changed>0 or (level,flag)==(6,20)
 name=f'spr_ln2_panel_{level}_{room}_{flag}';tmp=b.ROOT/'build'/f'{name}.png';images[0].save(tmp)
 resources[name]=b.sprite_resource(name,tmp,f'Graphics/ln2_game_level{level}',images)
 evidence.append(dict(level=level,room=room,flag=flag,panel=ptr,changed_pixels=changed))
for level,roots in [(4,[0xbd33,0xbd38,0xbd4d,0xbd71,0xbd7e,0xbd93]),(5,[0xbba9,0xbbae,0xbbc3,0xbbe2,0xbbf4,0xbc09]),(6,[0xc0ab])]:
 p=b.PROJECT/f'datafiles/play/ln2/level{level}/gameplay.json';g=b.read_json(p);g['actions'].update(actions(ls.level_memory(level),roots));b.write_json(p,g)
register_project(resources,[])
b.write_json(b.ROOT/'evidence/ln2_later_panels.json',evidence)
print(evidence)
