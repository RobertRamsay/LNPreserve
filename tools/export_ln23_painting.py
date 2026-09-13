from pathlib import Path
import sys,json,struct,hashlib
import numpy as np
import argparse
r=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description="Record LN2/LN3 original bitmap painting, offline only")
parser.add_argument('--ln2-captures',type=Path,required=True)
parser.add_argument('--ln3-common',type=Path,required=True)
parser.add_argument('--ln3-levels',type=Path,required=True)
args=parser.parse_args()
sys.path[:0]=[str(r/'tools'),str(r/'tools/vendor/pydeps')]
from py65.devices.mpu6502 import MPU
from export_ln1_world import call
from export_ln1_levels import register_project
ys,xs=np.indices((144,120));cells=ys//8*40+(xs*2)//8
report=[];included=[]
def pixels(mem,game):
 m=np.asarray(mem,dtype=np.uint8)
 if game==2:b,s,c,bg=0x2000,0x400,0x800,0x32
 else:b,s,c,bg=0xe000,0xcc00,0xd800,0xc0
 code=(m[b+cells*8+ys%8]>>(6-(xs%4)*2))&3
 colours=np.stack([np.full_like(code,m[bg]&15),m[s+cells]>>4,m[s+cells]&15,m[c+cells]&15])
 return np.take_along_axis(colours,code[None],axis=0)[0].ravel()
def normalize_initial_background(frames, background):
 # The RAM capture belongs to a previous room. Replace only its initial blank
 # colour; re-diff every later native frame so no foreground pixel is lost.
 original=np.zeros(17280,dtype=np.uint8);previous=original.copy();result=[]
 dtype=np.dtype([('index','<u2'),('colour','u1')])
 for number,frame in enumerate(frames):
  cycle,count=struct.unpack_from('<IH',frame)
  records=np.frombuffer(frame,dtype=dtype,offset=6,count=count)
  original[records['index']]=records['colour'];desired=original.copy()
  if number==0 and cycle<100 and np.all(desired==desired[0]):desired[:]=background
  changed=np.flatnonzero(desired!=previous)
  if len(changed):
   records=np.empty(len(changed),dtype=dtype);records['index']=changed;records['colour']=desired[changed]
   result.append(struct.pack('<IH',cycle,len(changed))+records.tobytes())
  previous=desired
 assert np.array_equal(previous,original)
 return result

for game,levels in [(2,7),(3,5)]:
 out=r/f'LNPreserve/datafiles/play/ln{game}/painting';out.mkdir(exist_ok=True);backgrounds=[]
 for level in range(1,levels+1):
  world=json.loads((r/f'LNPreserve/datafiles/play/ln{game}/level{level}/world.json').read_text())
  if game==2:
   ram=(args.ln2_captures/('ln2-game-ram.bin' if level==1 else f'ln2-level{level}-ram.bin')).read_bytes();source=world['source_layout']
  else:
   ram=bytearray(args.ln3_common.read_bytes())
   raw=(args.ln3_levels/f'int-level{level}-tape.prg').read_bytes();base=int.from_bytes(raw[:2],'little');ram[base:base+len(raw)-2]=raw[2:]
  backgrounds.append([0]*(max(x['id'] for x in world['rooms'])+1))
  for room in world['rooms']:
   rid=room['id'];mem=list(ram)
   if game==2:
    mem[0xa2]=rid;mem[0x3d8:0x3f2]=world['initial_inventory'];call(mem,0x140e)
    entries=[(source['scene_choose'],0),(source['item_enter'],0)]
   else:
    for address,length in [(0xcc00,1000),(0xd000,1000),(0xd800,1000),(0xe000,8000)]:mem[address:address+length]=[0]*length
    entries=[(0x71f9,rid)]
   initial=mem.copy();old=np.zeros(17280,dtype=np.uint8);frames=[];next_cycle=0;elapsed=0
   for entry,a in entries:
    cpu=MPU(memory=mem,pc=entry);cpu.a=a;cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1]
    def capture():
     global old
     cur=pixels(mem,game);idx=np.flatnonzero(cur!=old)
     if len(idx):
      payload=bytearray(struct.pack('<IH',elapsed+cpu.processorCycles,len(idx)))
      for i in idx:payload+=struct.pack('<HB',int(i),int(cur[i]))
      frames.append(payload);old=cur.copy()
    for step in range(2500000):
     if cpu.pc==0x1ff:break
     cpu.step()
     if elapsed+cpu.processorCycles>=next_cycle:capture();next_cycle+=19656
    else:raise RuntimeError((game,level,rid,hex(cpu.pc)))
    capture();elapsed+=cpu.processorCycles
   reference=initial.copy()
   for entry,a in entries:call(reference,entry,a=a)
   assert np.array_equal(pixels(reference,game),old),(game,level,rid,'final pixels')
   background=mem[0x32 if game==2 else 0xc0]&15;backgrounds[-1][rid]=background
   frames=normalize_initial_background(frames,background)
   path=out/f'{level}-{rid}.bin';path.write_bytes(struct.pack('<II',elapsed,len(frames))+b''.join(frames));included.append(path)
   report.append(dict(game=game,level=level,room=rid,background=background,cycles=elapsed,frames=len(frames),bytes=path.stat().st_size,final_pixels_equal=True,source_sha256=hashlib.sha256(bytes(ram)).hexdigest()))
  print('Exported',game,level,'rooms',len(world['rooms']),flush=True)
 bg=out/'backgrounds.json';bg.write_text(json.dumps(backgrounds));included.append(bg)
register_project({},included)
(r/'evidence/ln23_painting.json').write_text(json.dumps(dict(timing='Original instruction cycles at 985248 Hz; display contention/interrupts not calibrated',rooms=report),indent=2))
print('TOTAL',len(report),flush=True)
