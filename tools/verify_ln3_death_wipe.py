"""Trace original $70d7 writes, treating each raster wait as satisfied."""
from pathlib import Path
import sys,json
root=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(Path('audit_python_deps').resolve()),str(root/'tools')]
from py65.devices.mpu6502 import MPU
class Memory(list):
 def __getitem__(self,k):return 255 if k==0x2e1 else super().__getitem__(k)
 def __setitem__(self,k,v):
  if 0xe000<=k<0xe000+18*320:trace.append((k-0xe000)//320*8+(k&7))
  super().__setitem__(k,v)
trace=[];m=Memory((root/'source/local/captures/ln3-hud-ram.bin').read_bytes())
c=MPU(memory=m,pc=0x70d7);c.sp=0xfd;m[0x1fe]=0xfe;m[0x1ff]=1
for _ in range(200000):
 if c.pc==0x1ff:break
 c.step()
else:raise AssertionError('wipe did not return')
assert trace==[y for y in range(144) for x in range(30)],trace[:100]
print('4320 source bitmap writes: 144 rows in ascending order, 30 bytes per row.')
(root/'evidence/ln3_death_wipe.json').write_text(json.dumps({'routine':'$70d7','writes':len(trace),'rows':144,'order':'top to bottom','status':'passed'},indent=2)+'\n')
