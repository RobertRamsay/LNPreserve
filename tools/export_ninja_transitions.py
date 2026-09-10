"""Rebuild native transition assets from original supplied C64 bytes; offline only."""
import sys,json,hashlib
from pathlib import Path
import argparse
p=argparse.ArgumentParser();p.add_argument('ln1_unpacked',type=Path);p.add_argument('ln2_capture',type=Path);args=p.parse_args()
from py65.devices.mpu6502 import MPU
from PIL import Image
import build_project as b
from export_ln1_levels import register_project
from decode_graphics import PALETTE
r1=args.ln1_unpacked.read_bytes()
r2=args.ln2_capture.read_bytes()
b.REFRESH_GRAPHICS=True;resources={}
def sprite(name,images):
 p=b.ROOT/'build/transition-import.png';images[0].save(p)
 resources[name]=b.sprite_resource(name,p,'Graphics/ln2_game_level1',images)
mem=list(r1);mem[0xe000:0xff40]=[255]*8000
cpu=MPU(memory=mem,pc=0x7db3);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1]
images=[Image.new('RGBA',(240,144))];writes=0
for step in range(2000000):
 if cpu.pc==0x1ff:break
 # Fixed CIA timer sample for repeatable offline recovery of this random wipe.
 mem[0xdc04]=cpu.processorCycles&255;mem[0xdc05]=(cpu.processorCycles>>8)&255
 if cpu.pc==0x7dee:
  writes+=1
  if writes%128==0 or writes==4865:
   im=Image.new('RGBA',(240,144));pix=im.load()
   for y in range(144):
    for x in range(0,240,2):
     byte=mem[0xe000+(y//8*40+x//8)*8+y%8]
     if (byte>>(6-(x%8//2)*2))&3==0:pix[x,y]=pix[x+1,y]=(0,0,0,255)
   images.append(im)
 cpu.step()
else:raise AssertionError('LN1 wipe did not finish')
print('LN1 source block clears',writes,'frames',len(images))
assert writes==4865 and len(images)==40
sprite('spr_ln1_death_dissolve',images)
# Execute LN2 setup to recover both sprite patterns exactly.
mem=list(r2);mem[0xd011]=128;cpu=MPU(memory=mem,pc=0x93af)
while cpu.pc!=0x9412:cpu.step()
body=mem[0xc00:0xc3f];edge=mem[0xc40:0xc7f];images=[]
for tick in range(81):
 boundary=29+tick*2;im=Image.new('RGBA',(240,144));pix=im.load()
 for y in range(144):
  raster=y+50
  if raster<boundary:pattern=body;row=raster%21;own=8
  elif raster<boundary+21:pattern=edge;row=raster-boundary;own=7
  else:continue
  for x in range(0,240,4):
   sx=(x%48)//2;code=(pattern[row*3+sx//8]>>(6-(sx%8//2)*2))&3
   if code:
    colour=(*PALETTE[[0,11,own,2][code]],255)
    for dx in range(4):pix[x+dx,y]=colour
 images.append(im)
sprite('spr_ln2_death_wipe',images)
# A palette substitution shader follows LN1's exact $6fe1 darkening table.
name='sh_ln1_palette_fade';folder=b.PROJECT/'shaders'/name;folder.mkdir(exist_ok=True)
template=(b.PROJECT/'shaders/sh_ln_crt/sh_ln_crt.yy').read_text().replace('sh_ln_crt',name)
(folder/(name+'.yy')).write_text(template)
(folder/(name+'.vsh')).write_text((b.PROJECT/'shaders/sh_ln_crt/sh_ln_crt.vsh').read_text())
vec=lambda c:'vec3('+','.join(str(v/255) for v in c)+')'
code='varying vec2 v_vTexcoord; varying vec4 v_vColour; uniform float u_steps;\nvoid main(){vec4 src=texture2D(gm_BaseTexture,v_vTexcoord);vec3 result=src.rgb;float best=10.0;float d;\n'
for i,col in enumerate(PALETTE):
 code+='d=distance(src.rgb,'+vec(col)+');if(d<best){best=d;result='+vec(col)+';'
 j=i
 for step in range(1,16):
  j=r1[0x6fe1+j];code+=f'if(u_steps>={step}.0)result='+vec(PALETTE[j])+';'
 code+='}\n'
code+='gl_FragColor=vec4(result,src.a)*v_vColour;}\n'
(folder/(name+'.fsh')).write_text(code)
resources[name]={'id':{'name':name,'path':f'shaders/{name}/{name}.yy'}}
register_project(resources,[])
(b.ROOT/'evidence/ninja_transition_source.json').write_text(json.dumps(dict(ln1_sha256=hashlib.sha256(r1).hexdigest(),ln2_sha256=hashlib.sha256(r2).hexdigest(),ln1_clear_blocks=writes,ln1_mask_frames=40,ln1_palette=list(r1[0x6fe1:0x6ff1]),ln2_boundary=[29,189,2],scope='Original routines executed offline; CIA sample deterministic, VIC sprite presentation reconstructed at source pixel resolution.'),indent=2))
