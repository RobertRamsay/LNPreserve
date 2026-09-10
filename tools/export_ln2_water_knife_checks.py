"""Recover Central Park source data; use --source-root containing source/local/captures."""
import argparse,sys,json,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent/'vendor/pydeps'))
parser=argparse.ArgumentParser();parser.add_argument('--source-root',type=Path,required=True);args=parser.parse_args()
from py65.devices.mpu6502 import MPU
from export_ln1_world import call
from export_ln1_levels import register_project
root=Path(__file__).resolve().parents[1]/'LNPreserve';ram=(args.source_root/'source/local/captures/ln2-game-ram.bin').read_bytes();rng=random.Random(0xa25f)
boat=[];knives=[]
for i in range(512):
 mem=list(ram);room=[14,17][i%2];xy=[rng.randrange(256) for _ in range(4)]
 if i<384:xy=[100,100,100+((i%64)-32),100-(i//64)*5]
 flags=rng.choice([128,129,130,131]);mem[0xa2]=room;mem[0x54:0x58]=xy;mem[0x81]=flags;mem[0x2b6]=0
 cpu=MPU(memory=mem,pc=0xa25f);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1]
 for t in range(300):
  if cpu.pc==0x1ff:break
  cpu.step()
 else:raise AssertionError('boat timeout')
 boat.append(dict(room=room,xy=xy,flags=flags,supported=cpu.a!=0,y=mem[0x55],result_flags=mem[0x81],splash_flag=mem[0x2b6]))
for kind in range(2,6):
 for x in [0,3,112,252,255]:
  for facing in [1,3,5,7]:
   for occupied in [0,1]:
    mem=list(ram);mem[0x56:0x58]=[x,56];mem[0x6b]=facing;mem[0x281]=occupied
    before=[mem[a] for a in [0x281,0x283,0x285,0x287,0x289,0x296]]
    call(mem,0xb626,a=kind)
    knives.append(dict(kind=kind,x=x,facing=facing,before=before,after=[mem[a] for a in [0x281,0x283,0x285,0x287,0x289,0x296]]))
p=root/'datafiles/play/ln2/water_knife_checks.json';p.write_text(json.dumps(dict(boat=boat,knives=knives)));register_project({},[p])
