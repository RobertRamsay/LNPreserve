from pathlib import Path
import sys,struct,json,time
import argparse
r=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(r/'tools'),str(r/'tools/vendor/pydeps')]
parser=argparse.ArgumentParser(description="Record original LN1 room painting. Sources remain offline only.")
parser.add_argument('--common',type=Path,required=True,help='Unpacked original common 64K RAM')
parser.add_argument('--levels',type=Path,required=True,help='Folder containing int-levelN-tape.prg')
args=parser.parse_args()
from export_ln1_levels import register_project
from export_ln1_world import call,bitmap
from py65.devices.mpu6502 import MPU
import numpy as np
from decode_graphics import PALETTE
out=r/'LNPreserve/datafiles/play/ln1/painting';out.mkdir(exist_ok=True)
report=[];files=[]
ys,xs=np.indices((144,120));cells=ys//8*40+(xs*2)//8
def pixels(mem):
 m=np.asarray(mem,dtype=np.uint8);code=(m[0xe000+cells*8+ys%8]>>(6-(xs%4)*2))&3
 cols=np.stack([np.full_like(code,m[0x32]&15),m[0xc000+cells]>>4,m[0xc000+cells]&15,m[0xc400+cells]&15])
 return np.take_along_axis(cols,code[None],axis=0)[0].ravel()
for level in range(1,7):
 ram=bytearray(args.common.read_bytes())
 raw=(args.levels/f'int-level{level}-tape.prg').read_bytes();base=int.from_bytes(raw[:2],'little');ram[base:base+len(raw)-2]=raw[2:]
 ram[0xa:0xe]=bytes([ram[0x800],ram[0x801],ram[0x800],(ram[0x801]+1)&255])
 world=json.loads((r/'LNPreserve/datafiles/play/ln1'/('world.json' if level==1 else f'level{level}/world.json')).read_text())
 for room in range(1,len(world['rooms'])+1):
  mem=list(ram);mem[0xa2]=room;call(mem,0x5452)
  # Clear the visible bitmap/attributes before reproducing the native construction.
  # $5dfe fills the room; don't inherit a captured room's old pixels.
  for cell in set(cells.ravel()):
   mem[0xe000+int(cell)*8:0xe000+int(cell)*8+8]=[0]*8
   mem[0xc000+int(cell)]=0;mem[0xc400+int(cell)]=0
  cpu=MPU(memory=mem,pc=0x5dfe);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1]
  old=np.zeros(17280,dtype=np.uint8);frames=[];next_cycle=0
  def capture():
   global old
   cur=pixels(mem);idx=np.flatnonzero(cur!=old)
   if len(idx):
    data=bytearray(struct.pack('<IH',cpu.processorCycles,len(idx)))
    for i in idx:data+=struct.pack('<HB',int(i),int(cur[i]))
    frames.append(data);old=cur.copy()
  for step in range(2000000):
   if cpu.pc==0x1ff:break
   cpu.step()
   if cpu.processorCycles>=next_cycle:capture();next_cycle+=19656
  else:raise RuntimeError((level,room,cpu.pc))
  capture()
  ref=list(ram);ref[0xa2]=room;call(ref,0x5452);call(ref,0x5dfe)
  assert np.array_equal(pixels(ref),old),(level,room,'final mismatch')
  path=out/f'{level}-{room}.bin';path.write_bytes(struct.pack('<II',cpu.processorCycles,len(frames))+b''.join(frames));files.append(path)
  report.append(dict(level=level,room=room,cycles=cpu.processorCycles,seconds=round(cpu.processorCycles/985248,3),frames=len(frames),final_pixels_equal=True,bytes=path.stat().st_size))
 print('Exported level',level,flush=True)
register_project({},files)
(r/'evidence/ln1_painting.json').write_text(json.dumps(dict(timing='6502 instruction cycles / PAL 985248 Hz; VIC stalls and interrupts not verified',rooms=report),indent=2))
print('ROOMS',len(report),'BYTES',sum(x['bytes'] for x in report),flush=True)
