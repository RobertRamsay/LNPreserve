"""Execute the original Streets boundary dispatcher for traffic/bike comparisons."""
import sys,json,argparse
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--source-root',type=Path,required=True);args=parser.parse_args()
sys.path[:0]=[str(args.source_root/'audit_python_deps'),str(Path(__file__).resolve().parent)]
import ln2_level_source as ls
ls.ROOT=args.source_root
from export_ln1_world import call
import build_project as b
r=ls.level_memory(2);out=[]
for mode in [35,36,37,99,100,101]:
 for flag in [0,255]:
  for enemy_y in [0,20]:
   for crossings in [0,1,128,129]:
    for action in [0,0xbc00]:
     m=list(r);m[0x80]=mode;m[0x81]=crossings;m[0x3ea]=flag;m[0x57]=enemy_y
     m[0x60:0x64]=[action&255,action>>8,0,0];m[0x700]=0
     m[0xaee9:0xaeed]=[0x8d,0,7,0x60]
     call(m,0x9ba8)
     out.append(dict(mode=mode,flag=flag,enemy_y=enemy_y,crossings=crossings,action=action,
       expected=[m[0x81],ls.word(m,0x62),m[0x700]]))
p=b.PROJECT/'datafiles/play/ln2/level2/gameplay.json';g=b.read_json(p);g['street_traffic_checks']=out;b.write_json(p,g)
print(len(out),'original traffic/bike dispatch comparisons')
