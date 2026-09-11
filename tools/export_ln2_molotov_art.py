from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_project as b
from export_ln1_levels import register_project
from PIL import Image
def frame(name,index):
 p=b.PROJECT/'sprites'/name;m=b.read_json(p/(name+'.yy'));return Image.open(p/(m['frames'][index]['name']+'.png')).convert('RGBA')
wick=frame('spr_ln2_level2_status_icons',10);plain=wick.copy()
white=[]
for y in range(wick.height):
 for x in range(wick.width):
  px=wick.getpixel((x,y))
  if px[3] and min(px[:3])>180:
   white.append((x,y));plain.putpixel((x,y),(0,0,0,0))
print('Wick pixels',white,'size',wick.size)
images=[plain,wick]
for phase in range(3):
 im=wick.copy()
 for xy in white:im.putpixel(xy,(136,57,50,255))
 flame=frame('spr_ln2_sewer_flames',18+phase).crop((144,24,152,32))
 for y in range(8):
  for x in range(8):
   px=flame.getpixel((x,y))
   if max(px[:3])-min(px[:3])<35:flame.putpixel((x,y),(0,0,0,0))
 im.alpha_composite(flame,(22,0));images.append(im)
name='spr_ln2_molotov_states';tmp=b.ROOT/'build/molotov-import.png';images[0].save(tmp);b.REFRESH_GRAPHICS=True
res=b.sprite_resource(name,tmp,'Graphics/ln2_game_level2',images);register_project({name:res},[])
b.write_json(b.ROOT/'evidence/ln2_molotov_art.json',dict(base='spr_ln2_level2_status_icons frame 10',wick_pixels=white,flames='spr_ln2_sewer_flames frames 18-20',states=['bottle','wick','lit0','lit1','lit2']))
