from pathlib import Path
import argparse,itertools,hashlib
import ln2_level_source as ls
parser=argparse.ArgumentParser(description='Recover original LN2 alligator compositions and 6502 continuation vectors.')
parser.add_argument('--source-root',type=Path,required=True,help='Directory containing source/local/captures')
args=parser.parse_args()
ls.ROOT=args.source_root.resolve()
import build_project as b
from export_ln2_content import composition,actions
from export_ln1_levels import register_project
r=ls.level_memory(3);s=ls.layout(r);records=actions(r,[0xb3ef,0xb408,0xb41c,0xb430,0xb444]);frames=sorted({v['frame'] for v in records.values() if v['frame']!=255})
gp=b.PROJECT/'datafiles/play/ln2/level3/gameplay.json';g=b.read_json(gp);g['actions'].update(records);b.write_json(gp,g)
images=[composition(r,s,f,m,enemy=True,canvas=(256,256),origin=(128,160)) for f in frames for m in [False,True]]
name='spr_ln2_sewer_alligator';tmp=b.ROOT/'build/alligator-import.png';images[0].save(tmp);b.REFRESH_GRAPHICS=True;res=b.sprite_resource(name,tmp,'Graphics/ln2_game_level3',images)
p=b.PROJECT/'sprites'/name/(name+'.yy');meta=b.read_json(p);meta['origin']=9;meta['sequence']['xorigin']=128;meta['sequence']['yorigin']=160;b.write_json(p,meta)
cases=[]
for ex,px,flag,rnd in itertools.product([0,59,60,75,76,100,125,126,141,142,255],[0,7,8,47,48,59,76,100,142,255],[0,255],[0,64]):
 mem=list(r);mem[0x56]=ex;mem[0x54]=px;mem[0x3ed]=flag;cpu=ls.MPU(memory=mem,pc=0x9083);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1];used=0
 for _ in range(1000):
  if cpu.pc==0x1ff:break
  if cpu.pc==0x9aed:cpu.a=rnd;used+=1;cpu.pc=(cpu.stPopWord()+1)&65535
  else:cpu.step()
 else:raise AssertionError(hex(cpu.pc))
 cases.append(dict(ex=ex,px=px,flag=flag,random=rnd,used=used,expected_flag=mem[0x3ed],action=ls.word(mem,0x62)))
out=b.PROJECT/'datafiles/verification/ln2_alligator_checks.json';b.write_json(out,dict(cases=cases,frames=frames,source_sha256=hashlib.sha256(r).hexdigest()))
register_project({name:res},[out]);b.write_json(b.ROOT/'evidence/ln2_alligator.json',dict(cases=len(cases),routine=0x9083,frames=frames,source_sha256=hashlib.sha256(r).hexdigest(),bounds=[im.getbbox() for im in images]))
print('Recovered',frames,'and',len(cases),'source continuation cases')
