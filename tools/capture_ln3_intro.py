import sys,struct,json,hashlib
from pathlib import Path
from PIL import Image
base=Path(__file__).resolve().parents[1];sys.path.insert(0,str(base/'tools'))
import vice_reference as v
from decode_graphics import PALETTE
# Usage: python tools/capture_ln3_intro.py <MSR.d81> <output-dir>
out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=True)
# Reference uses tools/vendor/vice and source/local/captures, as other source checks do.
with v.Reference(Path(sys.argv[1])) as ref:
 ref.socket.settimeout(120)
 disk=str(Path(sys.argv[1]).resolve()).encode()
 ref.command(0xdd,struct.pack("<BHB",1,0,len(disk))+disk)
 while True:
  ref.until(0x400)
  if ref.memory(0x400,0x405)==bytes.fromhex('78 a9 7f a2 2f a0'):break
 name=str(out/'start.vsf').encode();ref.command(0x41,bytes([0,0,len(name)])+name)
 print('Original intro start recovered',flush=True)
 frames=[];ids={};timeline=[]
 for tick in range(16000):
  hit=ref.until_any([0xef3,0x10c5])
  if hit==0x10c5:break
  b=ref.command(0x84,b'\x01\x00');fl,w,h,x,y,iw,ih,bpp=struct.unpack_from('<I6HB',b)
  raw=b[fl:fl+w*h]
  im=Image.frombytes('P',(w,h),raw).crop((x,y,x+iw,y+ih))
  assert im.size==(320,200),(fl,w,h,x,y,iw,ih,len(b))
  data=im.tobytes();key=hashlib.sha256(data).hexdigest()
  if key not in ids:
   ids[key]=len(frames);frames.append(data)
   im.putpalette([n for col in PALETTE for n in col]+[0]*(768-48))
   if tick%100==0:im.save(out/f'preview-{tick}.png')
  timeline.append(ids[key])
  if tick%500==0:print(tick,len(frames),flush=True)
 else:raise RuntimeError('Intro did not complete')
 (out/'frames.bin').write_bytes(b''.join(frames))
 (out/'timeline.json').write_text(json.dumps(timeline))
 print('Complete',len(timeline),'ticks',len(frames),'unique frames',flush=True)
