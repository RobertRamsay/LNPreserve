"""Recover original Sewer flame panels; never regenerate whole room backgrounds."""
import sys,argparse,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--source-root',type=Path,required=True);args=p.parse_args()
sys.path[:0]=[str(args.source_root/'audit_python_deps'),str(Path(__file__).resolve().parent)]
import ln2_level_source as ls
ls.ROOT=args.source_root
import build_project as b
from export_ln1_world import call
from export_ln2_content import bitmap
from export_ln1_levels import register_project
from PIL import Image
r=ls.level_memory(3);s=ls.layout(r);rooms=[];ptr=0x86c6
while r[ptr]!=255:rooms.append(r[ptr]);ptr+=3
images=[];bounds=[]
for room in rooms:
 m=list(r);m[0xa2]=room;m[0x3d8:0x3f2]=[0]*26
 for a in [0x140e,s['scene_choose'],s['item_enter']]:call(m,a)
 base=bitmap(m);states=[]
 for phase in range(3):
  mem=m.copy();mem[0xe2]=6;mem[0x3e9]=0;mem[0x3ea]=(phase+2)%3;call(mem,0x8683)
  assert mem[0x3ea]==phase
  states.append(bitmap(mem))
 mask=[any(im.getpixel((x,y))!=base.getpixel((x,y)) for im in states) for y in range(144) for x in range(240)]
 assert any(mask)
 for im in states:
  out=Image.new('RGBA',im.size);out.putdata([px if yes else (0,0,0,0) for px,yes in zip(im.getdata(),mask)]);images.append(out)
 bounds.append(images[-1].getbbox())
name='spr_ln2_sewer_flames';tmp=b.ROOT/'build/sewer-flames.png';images[0].save(tmp);b.REFRESH_GRAPHICS=True
res=b.sprite_resource(name,tmp,'Graphics/ln2_game_level3',images);register_project({name:res},[])
b.write_json(b.ROOT/'evidence/ln2_sewer_flames.json',dict(source_sha256=hashlib.sha256(r).hexdigest(),routine=0x8683,rooms=rooms,bounds=bounds,frames=3,period_ticks=6))
print('Flame rooms',rooms,'bounds',bounds)
