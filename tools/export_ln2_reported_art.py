import sys,json,hashlib,argparse
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent/'vendor/pydeps'))
import ln2_level_source as ls
parser=argparse.ArgumentParser(description='Recover LN2 level HUD icons and Central Park encounters from original RAM captures.')
parser.add_argument('--source-root',type=Path,required=True,help='Directory containing source/local/captures')
ls.ROOT=parser.parse_args().source_root
import build_project as b
from export_ln1_world import call
from export_ln1_levels import register_project
from export_ln2_hud import screen
from export_ln2_content import composition
from extract_ln1_actors import sprite_image
b.REFRESH_GRAPHICS=True;resources={};evidence={};tmp=b.ROOT/'build/ln2-reported-art.png'
def sprite(name,images,origin=(0,0)):
 images[0].save(tmp);resources[name]=b.sprite_resource(name,tmp,'Graphics/ln2_game_level1',images)
 if origin!=(0,0):
  p=b.PROJECT/'sprites'/name/(name+'.yy');m=b.read_json(p);m['origin']=9;m['sequence']['xorigin'],m['sequence']['yorigin']=origin;b.write_json(p,m)
for level in range(1,8):
 ram=ls.level_memory(level);address=ls.locate(ram,0xb307,24);icons=[]
 for item in range(17):
  mem=list(ram);mem[0xd011]=128;call(mem,address,a=item,x=0)
  im=screen(mem).crop((264,24,304,56)).convert('RGBA')
  im.putdata([(red,green,blue,0 if (red,green,blue)==(0,0,0) else alpha) for red,green,blue,alpha in im.getdata()]);icons.append(im)
 sprite(f'spr_ln2_level{level}_status_icons',icons)
 evidence[str(level)]={'source_sha256':hashlib.sha256(ram).hexdigest(),'icon_routine':address,'icon_hashes':[hashlib.sha256(im.tobytes()).hexdigest() for im in icons]}
 print('Original icons',level,hex(address),flush=True)
ram=ls.level_memory(1);s=ls.layout(ram);images=[]
for room,frame in [(14,103),(16,104),(17,104)]:
 mem=list(ram);mem[0xa2]=room;mem[0x278]=0;mem[0x3eb]=255 if room==17 else 0
 call(mem,0x942a);shared=(mem[0xd025]&15,mem[0xd026]&15)
 assert shared=={14:(10,9),16:(10,8),17:(8,10)}[room]
 images.extend(composition(ram,s,frame,mirror,0,0,True,shared) for mirror in (False,True))
 evidence[f'boat{room}']={'frame':frame,'shared_colours':shared}
sprite('spr_ln2_park_boats',images,(48,64))
mem=list(ram);mem[0x200:0x250]=[0]*80;mem[0x56:0x58]=[120,120];mem[0x7d]=mem[0x7f]=0;mem[0x70]=mem[0x72]=0;mem[0x9e]=255
call(mem,s['actor_enemy'],a=0,x=4,y=105)
parts=[]
for i in range(4,7):
 address=mem[0x169d+i]+256*mem[0x16a5+i]+(512 if mem[0x218+i]&1 else 0)
 parts.append(sprite_image(mem[address:address+63],bool(mem[0x238+i]),mem[0x220+i]&15,(11,2)))
sprite('spr_ln2_bee_parts',parts)
evidence['bees']={'event':16,'routine':0xa9ba,'room':15,'offset_x':[ram[0xcd9d+i] for i in (0,4,8)],'offset_y':[ram[0xcd9e+i] for i in (0,4,8)]}
register_project(resources,[]);b.write_json(b.ROOT/'evidence/ln2_reported_art.json',evidence)
print('Recovered per-level icons, original boat palettes and three bee parts.')
