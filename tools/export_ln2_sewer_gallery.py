"""Author a maintenance gallery with original LN2 panels and compatible geometry."""
import sys,argparse,json,copy,hashlib
from pathlib import Path
pa=argparse.ArgumentParser();pa.add_argument('--source-root',type=Path,required=True);pa.add_argument('--output-root',type=Path,required=True);args=pa.parse_args()
sys.path[:0]=[str(args.source_root/'audit_python_deps'),str(Path(__file__).resolve().parent)]
import ln2_level_source as ls
ls.ROOT=args.source_root
import build_project as b
b.ROOT=args.output_root.resolve();b.PROJECT=b.ROOT/'LNPreserve'
b.ROOT.joinpath('build').mkdir(parents=True,exist_ok=True)
from export_ln1_world import call
from export_ln2_content import bitmap,actions,composition
import export_ln1_levels as levels
levels.ROOT=b.ROOT;levels.PROJECT=b.PROJECT
register_project=levels.register_project
from PIL import Image
r=ls.level_memory(3);s=ls.layout(r);base=s['scene_data'];resources={};included=[];b.REFRESH_GRAPHICS=True
def sprite(name,ims,origin=(0,0)):
 tmp=b.ROOT/'build/gallery-import.png';ims[0].save(tmp);resources[name]=b.sprite_resource(name,tmp,'Graphics/ln2_game_level3',ims)
 if origin!=(0,0):
  p=b.PROJECT/'sprites'/name/(name+'.yy');m=b.read_json(p);m['origin']=9;m['sequence']['xorigin'],m['sequence']['yorigin']=origin;b.write_json(p,m)
panel=r[base+3+11*2];pos=base+ls.word(r,base+0x43+panel*2);commands=[]
while r[pos]!=255:
 n=3+((r[pos+2]>>5)&3);cmd=list(r[pos:pos+n]);pos+=n
 if cmd[0] not in [81,82,83,84]:commands.extend(cmd)
# Match the original block grid: opposing arches, two torches, end railings.
commands += [26,16,16,25,38,17,81,22,21,82,22,20,81,36,19,82,36,18,32,12,25,31,42,27,255]
m=list(r);m[0xa2]=11;m[0x3d8:0x3f2]=[0]*26;call(m,0x140e);call(m,s['scene_choose'])
m[0xe000:0xe000+len(commands)]=commands;m[2:4]=[0,0xe0];call(m,0x73f2);gallery=bitmap(m)
sprite('spr_ln2_sewer_gallery',[gallery])
# Identical wall/depth geometry to the borrowed walkway, with added arch tops.
worldpath=b.PROJECT/'datafiles/play/ln2/level3/world.json';w=b.read_json(worldpath)
prototype=copy.deepcopy(next(rr for rr in w['rooms'] if rr['id']==11))
depthname=prototype['depth_sprite'];meta=b.read_json(b.PROJECT/'sprites'/depthname/(depthname+'.yy'))
depth=Image.open(b.PROJECT/'sprites'/depthname/(meta['frames'][0]['name']+'.png')).convert('RGBA')
sprite('spr_ln2_sewer_gallery_depth',[depth])
flames=[]
for phase in range(3):
 mem=m.copy();cmd=[82+phase,22,20,82+phase,36,18,255];mem[0xe000:0xe007]=cmd;mem[2:4]=[0,0xe0];call(mem,0x73f2)
 im=bitmap(mem);out=Image.new('RGBA',(240,144))
 for x,y in [(64,48),(176,32)]:out.paste(im.crop((x,y,x+8,y+8)),(x,y))
 flames.append(out)
sprite('spr_ln2_gallery_flames',flames)
# Recover this level's own fall/splash bank for gallery water, without changing
# the original rooms' hazard rules.
routine=ls.locate(r,0xa212,30);table=ls.word(r,routine+32);entries=[ls.word(r,table+i*2) for i in range(6)]
splash=r[routine+49]+256*r[routine+51];records=actions(r,entries+[splash]);frames=sorted({v['frame'] for v in records.values()})
gp=b.PROJECT/'datafiles/play/ln2/level3/gameplay.json';g=b.read_json(gp);g['actions'].update(records);b.write_json(gp,g)
sprite('spr_ln2_level3_drowning',[composition(r,s,f,mir) for f in frames for mir in [False,True]],(48,64))
waterpath=b.PROJECT/'datafiles/play/ln2/level3/water.json';b.write_json(waterpath,dict(entries=entries,splash=splash,frames=frames,sprite='spr_ln2_level3_drowning'));included.append(waterpath)
prototype.update(id=15,sprite='spr_ln2_sewer_gallery',depth_sprite='spr_ln2_sewer_gallery_depth',variants=['spr_ln2_sewer_gallery'],variant_flags=[],entries=[],routes=[],spawn_entry=39,authored=True)
prototype['enemy'].update(active=0,x=0,y=0,depth_y=0,action=0,frame=255)
for bb in prototype['boundaries']:
 if bb[4]&1:bb[5]=60
prototype['boundaries'] += [[20,91,34,88,69,189],[214,99,226,102,5,190]]
w['rooms']=[rr for rr in w['rooms'] if rr['id']!=15]+[prototype]
spec=[(6,1,'6-door'),(7,10,'7-right'),(7,2,'7-left'),(9,2,'9-right'),(9,6,'9-middle'),(10,9,'10-left'),(10,13,'10-right'),(12,6,'12-right'),(15,10,'gallery-left'),(15,11,'gallery-right')]
dest=[1,0,3,2,0,4,8,9,6,7];doors=[]
for index,(room,line,name) in enumerate(spec):
 rr=next(v for v in w['rooms'] if v['id']==room);bb=rr['boundaries'][line];x=(bb[0]+bb[2])//2;y=bb[1]+(-1 if bb[4]&64 else 1)*((x-bb[0])*(bb[4]&62)//16)
 door=dict(id=index,name=name,room=room,line=line,x=x,y=y,facing=3 if bb[4]&64 else 5,entry=31+index,target=dest[index])
 doors.append(door)
 for key,value in [('exit_destinations',room),('exit_thresholds',255),('entry_x',x+(10 if door['facing']==3 else -10)),('entry_y',y+8),('entry_heading',door['facing'])]:
  arr=w['tables'][key]
  if len(arr)<=31+index:arr.append(value)
  else:arr[31+index]=value
prototype['entries']=[37,38] # explicit outgoing links, never used as perimeter exits
prototype['routes']=[dict(direction=3,entry=37,x=27,y=98),dict(direction=1,entry=38,x=220,y=109)]
w['sewer_doors']=doors;w['sewer_network_version']=1;b.write_json(worldpath,w)
register_project(resources,included)
b.write_json(b.ROOT/'evidence/ln2_sewer_gallery.json',dict(source_sha256=hashlib.sha256(r).hexdigest(),base_scene=11,added_panels=[26,25,81,82,32,31],doors=doors,authored_room=15,original_routes_preserved=True))
gallery.resize((960,576),Image.Resampling.NEAREST).save(args.source_root/'artifacts/ln2-maintenance-gallery.png')
print('Gallery and',len(doors),'door endpoints recovered/authored; water frames',frames)
