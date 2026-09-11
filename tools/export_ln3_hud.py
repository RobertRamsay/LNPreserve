"""Recover editable LN3 HUD frames from original C64 routines; offline only."""
from pathlib import Path
import sys,hashlib
sys.path[:0]=[str(Path(__file__).resolve().parent/'vendor/pydeps'),str(Path(__file__).resolve().parent)]
from py65.devices.mpu6502 import MPU
from PIL import Image
import build_project as b
from export_ln1_levels import register_project
from decode_graphics import PALETTE
root=b.ROOT/'source/local/captures';raw=(root/'ln3-hud-ram.bin').read_bytes();io=(root/'ln3-hud-io.bin').read_bytes()
class Mem:
 def __init__(self):self.r=list(raw);self.c=list(io[0x800:0xc00])
 def __getitem__(self,k):
  if isinstance(k,slice):return self.r[k]
  return self.c[k-0xd800] if 0xd800<=k<0xdc00 and self.r[1]&3 and self.r[1]&4 else self.r[k]
 def __setitem__(self,k,v):
  if 0xd800<=k<0xdc00 and self.r[1]&3 and self.r[1]&4:self.c[k-0xd800]=v&15
  else:self.r[k]=v&255

def call(m,p,x=0):
 c=MPU(memory=m,pc=p);c.x=x;c.sp=0xfd;m[0x1fe]=0xfe;m[0x1ff]=1
 for i in range(100000):
  if c.pc==0x1ff:return
  c.step()
 raise ValueError(hex(c.pc))
def pic(m):
 im=Image.new('RGBA',(320,200));pixels=[]
 for y in range(200):
  for x in range(320):
   cell=y//8*40+x//8;code=m.r[0xe000+cell*8+y%8]>>(6-2*((x%8)//2))&3
   colour=[0,m.r[0xcc00+cell]>>4,m.r[0xcc00+cell]&15,m.c[cell]][code]&15
   pixels.append((*PALETTE[colour],255))
 im.putdata(pixels);return im
res={};meta={};b.REFRESH_GRAPHICS=True

def save(name,frames):
 tmp=root/(name+'.png');frames[0].save(tmp);res[name]=b.sprite_resource(name,tmp,'Graphics/ln3_game_level1',frames)
 meta[name]={'frames':len(frames),'width':frames[0].width,'height':frames[0].height}
m=Mem();panel=pic(m)
# Preserve only the status area. Gameplay is rendered independently at native resolution.
for y in range(144):
 for x in range(240):panel.putpixel((x,y),(0,0,0,0))
save('spr_ln3_hud_panel',[panel])
for name,shown,target,routine,rect in [('player',0x2d7,0x1c,0x79f9,(8,152,48,192)),('enemy',0x2d8,0x2d9,0x7a48,(56,152,96,192))]:
 m=Mem();m[target]=0
 for _ in range(44):call(m,routine)
 frames=[pic(m).crop(rect)];m[target]=44
 for _ in range(44):call(m,routine);frames.append(pic(m).crop(rect))
 save('spr_ln3_hud_'+name,frames)
m=Mem();m[0x1b]=0
for _ in range(40):call(m,0x7a98)
frames=[pic(m).crop((112,176,200,200))];m[0x1b]=40
for _ in range(40):call(m,0x7a98);frames.append(pic(m).crop((112,176,200,200)))
save('spr_ln3_hud_bushido',frames)
frames=[]
for digit in range(10):
 m=Mem()
 for i in range(6):m[0x100+i]=48+digit
 call(m,0x6eb6);frames.append(pic(m).crop((128,160,136,168)))
save('spr_ln3_hud_digits',frames)
frames=[]
for item in range(25):
 m=Mem();call(m,0x6faf,x=item);frames.append(pic(m).crop((264,72,296,88)))
save('spr_ln3_hud_items',frames)
frames=[]
for item in range(25):
 m=Mem();m[0x31a]=item
 for step in range(9):
  m[0xf3]=step;m[1]=0x34
  for routine in [0x6b19,0x6bc1,0x6c0f]:call(m,routine,x=step)
  m[1]=0x35;frames.append(pic(m).crop((256,0,304,48)))
# Compare the isolated extraction against the complete original dispatcher.
for item in range(25):
 oracle=Mem();oracle[0xf3]=0;oracle[0x31a]=item
 for step in range(9):
  oracle[0xf2]=1;oracle[0x149]=0;call(oracle,0x6ae3)
  assert pic(oracle).crop((256,0,304,48)).tobytes()==frames[item*9+step].tobytes(),(item,step)
save('spr_ln3_hud_wheel',frames)
m=Mem();frames=[pic(m).crop((256,56,312,64))];call(m,0x7019);frames.append(pic(m).crop((256,56,312,64)))
save('spr_ln3_hud_notice',frames)
frames=[]
for eye,rect in [(0,(248,176,264,184)),(1,(288,176,304,184))]:
 for phase in range(4):
  m=Mem();m[0x14f]=0;m[0x2db]=1 if eye==0 else 2;m[0x2dc]=phase;call(m,0x7b2a);frames.append(pic(m).crop(rect))
save('spr_ln3_hud_eye_flash',frames)
register_project(res,[])
b.write_json(b.ROOT/'evidence/ln3_hud_art.json',{'source':'C64Games DMAgic disk edition, original LN3 routines','url':'https://www.c64games.de/phpseiten/spieledetail.php?filnummer=809','sha256':hashlib.sha256(raw).hexdigest(),'resources':meta,'scope':'Original level 1 UI routines and bitmap; shared panel pending verification against later banks.'})
vectors=[]
for phase in range(9):
 for request in [0,1,4]:
  for wait in [0,1,4]:
   for owned in [0,1,128]:
    m=Mem();m[0xf3]=phase;m[0xf2]=request;m[0x149]=max(0,wait-1);m[0x31a]=4;m[6]=owned
    call(m,0x6ae3)
    vectors.append({'phase':phase,'request':request,'wait':wait,'owned':owned,'expected':[m[0xf3],m[0xf2],m[0x149]]})
path=b.PROJECT/'datafiles/verification/ln3_hud_vectors.json'
b.write_json(path,{'vectors':vectors});register_project({},[path]);print(meta,len(vectors))

