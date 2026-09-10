"""Recover Central Park source data; use --source-root containing source/local/captures."""
import argparse,sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent/'vendor/pydeps'))
parser=argparse.ArgumentParser();parser.add_argument('--source-root',type=Path,required=True);args=parser.parse_args()
import ln2_level_source as ls
ls.ROOT=args.source_root
import build_project as b
from export_ln2_projectile_art import render
from extract_ln1_actors import sprite_image
from export_ln2_content import composition
from export_ln1_levels import register_project
ram=ls.level_memory(1);source=ls.layout(ram);draw=ls.locate(ram,0xbbc3,41);images=[];records=[];maps={};ids={};resources={};b.REFRESH_GRAPHICS=True
for kind in (2,3,4,5,10,11,12,13):
 mapping=[]
 for x in range(256):
  r=render(ram,draw,source['mask'],kind,x,100,actor=1);im=sprite_image(r['raw'],False,r['colour'],(6,11));key=im.tobytes()
  if key not in ids:ids[key]=len(images);images.append(im);records.append(dict(raw=r['raw'],colour=r['colour']))
  mapping.append(ids[key])
 maps[str(kind)]=mapping
name='spr_ln2_juggler_knives';temp=b.ROOT/'build/ln2-knives.png';images[0].save(temp);resources[name]=b.sprite_resource(name,temp,'Graphics/ln2_game_level1',images)
p=b.PROJECT/'datafiles/play/ln2/juggler_knives.json';b.write_json(p,dict(sprite=name,frames=records,maps=maps))
name='spr_ln2_juggler';images=[composition(ram,source,f,m,0,0,True,(6,11),True) for f in range(99,103) for m in (False,True)]
images[0].save(temp);resources[name]=b.sprite_resource(name,temp,'Graphics/ln2_game_level1',images)
q=b.PROJECT/f'sprites/{name}/{name}.yy';meta=b.read_json(q);meta['origin']=9;meta['sequence']['xorigin']=48;meta['sequence']['yorigin']=64;b.write_json(q,meta)
register_project(resources,[p]);print('Recovered eight knife states and original three-part juggler poses.')
