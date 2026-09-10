"""Recover the Sewer scene 5 grate's successful-use bitmap panel."""
import sys,argparse,hashlib
from pathlib import Path
pa=argparse.ArgumentParser();pa.add_argument('--source-root',type=Path,required=True);a=pa.parse_args()
sys.path[:0]=[str(a.source_root/'audit_python_deps'),str(Path(__file__).resolve().parent)]
import ln2_level_source as ls
ls.ROOT=a.source_root
import build_project as b
from export_ln1_world import call
from export_ln2_content import bitmap
from export_ln1_levels import register_project
r=ls.level_memory(3);s=ls.layout(r);w=b.read_json(b.PROJECT/'datafiles/play/ln2/level3/world.json')
item=next(i for i in w['items'] if i['id']==20);m=list(r);m[0xa2]=5;m[0x3d8:0x3f2]=[0]*26
for addr in [0x140e,s['scene_choose'],s['item_enter']]:call(m,addr)
images=[bitmap(m)];ptr=item['removed_panel'];m[2:4]=[ptr&255,ptr>>8];renderer=ls.locate(r,0x8914,24);call(m,renderer);images.append(bitmap(m))
changed=sum(x!=y for x,y in zip(images[0].getdata(),images[1].getdata()));assert changed>0
name='spr_ln2_sewer_grate_states';tmp=b.ROOT/'build/sewer-grate.png';images[0].save(tmp);b.REFRESH_GRAPHICS=True
resource=b.sprite_resource(name,tmp,'Graphics/ln2_game_level3',images);register_project({name:resource},[])
b.write_json(b.ROOT/'evidence/ln2_sewer_grate.json',dict(source_sha256=hashlib.sha256(r).hexdigest(),renderer=renderer,panel=ptr,changed_pixels=changed,required_item=12))
print('Original grate panel',hex(ptr),'renderer',hex(renderer),'changed pixels',changed)
