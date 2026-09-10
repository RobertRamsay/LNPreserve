"""Original Central Park fence/gap branch fixtures and missing climb action roots."""
import argparse,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent/'vendor/pydeps'))
parser=argparse.ArgumentParser();parser.add_argument('--source-root',type=Path,required=True);args=parser.parse_args()
from py65.devices.mpu6502 import MPU
from export_ln1_levels import register_project
r=Path(__file__).resolve().parents[1]/'LNPreserve';ram=(args.source_root/'source/local/captures/ln2-game-ram.bin').read_bytes();vectors=[]
for mode,flags,facing,weapon,busy in itertools.product([7,8,9,138,14,15,20],[0,1,128,129,130,131],[1,7],[0,2],[0,1]):
 mem=list(ram);mem[0x80]=mode;mem[0x81]=flags;mem[0x69]=facing;mem[0x70]=weapon;mem[0x61]=busy;mem[0x55]=120;mem[0x74]=100;mem[0xef]=0;mem[0xb6]=0
 cpu=MPU(memory=mem,pc=0x9fd8);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1];calls=[];steps=0
 for i in range(2000):
  if cpu.pc==0x1ff:break
  if cpu.pc in [0xa1a6,0xa1cf,0x9fcc]:
   if cpu.pc==0xa1a6:calls.append(cpu.x+cpu.a*256)
   if cpu.pc==0xa1cf:steps=cpu.a
   cpu.pc=(cpu.stPopWord()+1)&65535
  else:cpu.step()
 else:raise AssertionError('source timeout')
 vectors.append(dict(mode=mode,flags=flags,facing=facing,weapon=weapon,busy=busy,calls=calls,steps=steps,depth=mem[0x74],fixed=mem[0xef]))
p=r/'datafiles/play/ln2/fence_gap_checks.json';p.write_text(json.dumps(vectors));register_project({},[p])

from export_ln2_content import actions
from build_project import write_json
p=r/'datafiles/play/ln2/level1/gameplay.json';data=json.loads(p.read_text());data['actions'].update(actions(ram,[0xc3ab,0xc3e4]));write_json(p,data)
