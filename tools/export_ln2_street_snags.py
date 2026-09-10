"""Recover Streets pot/bike compositions and runtime bitmap panels from original RAM."""
import sys,json,argparse,hashlib
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--source-root',type=Path,required=True);args=parser.parse_args()
sys.path[:0]=[str(args.source_root/'audit_python_deps'),str(Path(__file__).resolve().parent)]
import ln2_level_source as ls
ls.ROOT=args.source_root
import build_project as b
from export_ln2_content import composition,bitmap
from export_ln1_world import call
from export_ln1_levels import register_project
from PIL import Image
r=ls.level_memory(2);s=ls.layout(r);b.REFRESH_GRAPHICS=True;resources={};evidence={}
wpath=b.PROJECT/'datafiles/play/ln2/level2/world.json';w=b.read_json(wpath)
def save(name,ims,origin=(0,0)):
 tmp=b.ROOT/'build/street-import.png';ims[0].save(tmp)
 resources[name]=b.sprite_resource(name,tmp,'Graphics/ln2_game_level2',ims)
 if origin!=(0,0):
  p=b.PROJECT/'sprites'/name/(name+'.yy');m=b.read_json(p);m['origin']=9;m['sequence']['xorigin'],m['sequence']['yorigin']=origin;b.write_json(p,m)
def scene(room):
 mem=list(r);mem[0xa2]=room;mem[0x3d8:0x3f2]=[0]*26
 for a in [0x140e,s['scene_choose'],s['item_enter']]:call(mem,a)
 return mem
ims=[]
for frame in range(99,115):
 for mirror in [False,True]:
  im=composition(r,s,frame,mirror,enemy=True,shared=(2,1) if frame==114 else (11,2),canvas=(256,192),origin=(128,64))
  ims.append(im)
 evidence[str(frame)]=ims[-2].getbbox()
save('spr_ln2_street_scenery',ims,(128,64))
for room,itemid,name in [(8,10,'spr_ln2_street_bottle_states'),(14,19,'spr_ln2_street_manhole_states')]:
 mem=scene(room);item=next(i for i in w['items'] if i['id']==itemid);images=[bitmap(mem)]
 p=item['removed_panel'];mem[2:4]=[p&255,p>>8];call(mem,0x8618);images.append(bitmap(mem))
 save(name,images)
 rr=next(v for v in w['rooms'] if v['id']==room)
 # Two resource names let existing inventory variant selection choose the frame.
 save(name+'_removed',[images[1]])
 rr['variants']=[name,name+'_removed'];rr['variant_flags']=[itemid]
 evidence[name]={'changed_pixels':sum(a!=bb for a,bb in zip(images[0].getdata(),images[1].getdata()))}
traffic=[]
for room in [1,4,5,8,9,11]:
 mem=scene(room);base=bitmap(mem);states=[]
 for flag in [0,255]:
  m=mem.copy();m[0xb0]=50;m[0x3ea]=flag^255;call(m,0x9ac4);states.append(bitmap(m))
 mask=[a!=bb or a!=cc for a,bb,cc in zip(base.getdata(),states[0].getdata(),states[1].getdata())]
 for im in states:
  out=Image.new('RGBA',im.size);out.putdata([p if yes else (0,0,0,0) for p,yes in zip(im.getdata(),mask)]);traffic.append(out)
 evidence['traffic'+str(room)]=sum(mask)
save('spr_ln2_street_lights',traffic)
b.write_json(wpath,w);register_project(resources,[])
b.write_json(b.ROOT/'evidence/ln2_street_art.json',dict(source_sha256=hashlib.sha256(r).hexdigest(),frames=evidence))
print(json.dumps(evidence,indent=2))
