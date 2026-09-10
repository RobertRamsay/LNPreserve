"""Recover Central Park source data; use --source-root containing source/local/captures."""
import argparse,sys,json,hashlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent/'vendor/pydeps'))
parser=argparse.ArgumentParser();parser.add_argument('--source-root',type=Path,required=True);args=parser.parse_args()
import ln2_level_source as ls
ls.ROOT=args.source_root
import build_project as b
from export_ln2_content import actions,composition
from export_ln1_levels import register_project
resources={};included=[];evidence={};b.REFRESH_GRAPHICS=True
for level in [1]:
 ram=ls.level_memory(level);source=ls.layout(ram);routine=ls.locate(ram,0xa212,30)
 table=ls.word(ram,routine+32);entries=[ls.word(ram,table+i*2) for i in range(6)]
 splash=ram[routine+49]+256*ram[routine+51]
 records=actions(ram,entries+[splash]);frames=sorted({v['frame'] for v in records.values()})
 assert set(range(88,99))<=set(frames),(level,frames)
 folder=b.PROJECT/f'datafiles/play/ln2/level{level}'
 p=folder/'gameplay.json';data=json.loads(p.read_text());data['actions'].update(records);b.write_json(p,data)
 name=f'spr_ln2_level{level}_drowning';images=[composition(ram,source,f,mirror,0,0) for f in frames for mirror in (False,True)]
 temp=b.ROOT/'build/ln2-drowning.png';images[0].save(temp)
 resources[name]=b.sprite_resource(name,temp,'Graphics/ln2_game_level'+str(level),images)
 p=b.PROJECT/f'sprites/{name}/{name}.yy';meta=b.read_json(p);meta['origin']=9;meta['sequence']['xorigin']=48;meta['sequence']['yorigin']=64;b.write_json(p,meta)
 p=folder/'water.json';b.write_json(p,dict(entries=entries,splash=splash,frames=frames,sprite=name));included.append(p)
 evidence[str(level)]={'source_sha256':hashlib.sha256(ram).hexdigest(),'routine':routine,'entries':entries,'splash':splash,'frames':frames}
 print('Recovered water animation',level,frames,flush=True)
ram=ls.level_memory(1)
p=b.PROJECT/'datafiles/play/ln2/boat_support.json';b.write_json(p,dict(min_y=list(ram[0xa2be:0xa2be+14]),max_y=list(ram[0xa2cd:0xa2cd+14])));included.append(p)
register_project(resources,included);b.write_json(b.ROOT/'evidence/ln2_water_source.json',evidence)
