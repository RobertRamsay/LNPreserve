from pathlib import Path
from PIL import Image,ImageDraw
root=Path.cwd();p=next((root/'source/local/last_ninja_the_side_a_ccs').glob('*5B.bin'));r=p.read_bytes()[2:]
ram=(root/'source/local/captures/ln1-game-ram.bin').read_bytes()
print('source',p.name,'bytes',len(r),'RAM matches',hex(ram.find(r)),hex(ram.find(r[:256])))
im=Image.new('RGB',(480,((len(r)//64+11)//12)*52),(40,40,40));d=ImageDraw.Draw(im)
for f in range(len(r)//64):
 for y in range(21):
  for x in range(24):
   v=(r[f*64+y*3+x//8]>>(6-2*((x%8)//2)))&3
   if v:im.putpixel((f%12*40+x,f//12*52+y),(85*v,85*v,85*v))
 d.text((f%12*40,f//12*52+26),str(f),fill='white')
im.save(root/'evidence/ln1_5b_probe.png')
b=(root/'source/local/captures/ln1-game.vsf').read_bytes()
pos=58
while pos+22<len(b):
 name=b[pos:pos+16].split(bytes([0]))[0].decode(errors='replace');size=int.from_bytes(b[pos+18:pos+22],'little')
 print(name,pos,size,b[pos+16:pos+18].hex())
 if size<22:break
 pos+=size
