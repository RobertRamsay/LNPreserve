import sys,hashlib,argparse
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--source-root',type=Path,required=True);args=parser.parse_args()
sys.path[:0]=[str(args.source_root/'audit_python_deps'),str(Path(__file__).resolve().parent)]
import ln2_level_source as ls
ls.ROOT=args.source_root
import build_project as b
from export_ln2_content import composition
from export_ln1_levels import register_project
r=ls.level_memory(3);s=ls.layout(r);ims=[]
for frame in [102,103,104]:
 for mirror in [False,True]:
  im=composition(r,s,frame,mirror,enemy=True,canvas=(256,256),origin=(128,160));print(frame,mirror,im.getbbox());ims.append(im)
name='spr_ln2_sewer_rats';temp=b.ROOT/'build/sewer-rats.png';ims[0].save(temp);b.REFRESH_GRAPHICS=True
resource=b.sprite_resource(name,temp,'Graphics/ln2_game_level3',ims)
p=b.PROJECT/'sprites'/name/(name+'.yy');m=b.read_json(p);m['origin']=9;m['sequence']['xorigin']=128;m['sequence']['yorigin']=160;b.write_json(p,m)
register_project({name:resource},[])
b.write_json(b.ROOT/'evidence/ln2_sewer_rats.json',dict(source_sha256=hashlib.sha256(r).hexdigest(),frames=[102,103,104],bounds=[im.getbbox() for im in ims],origin=[128,160],action=0xb3c5))

