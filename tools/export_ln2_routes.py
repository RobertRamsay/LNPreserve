"""Original interior-exit oracle. Display-only fades/descents are intercepted.
Checks destination selection and gates, not whole-machine raster timing.
"""
from pathlib import Path
import argparse,itertools,hashlib
from build_project import PROJECT,ROOT,read_json,write_json
from ln2_level_source import MPU,word
from export_ln1_levels import register_project

def main():
    parser=argparse.ArgumentParser();parser.add_argument('captures',type=Path);args=parser.parse_args()
    vectors=[];sensors=[];audit=[]
    extra={1:{6},2:{38},3:{41},4:{48},5:set(),6:{54},7:set()}
    stubs={1:{0xb341},2:{0x9eb1},3:{0x8a92},4:set(),5:set(),6:{0x9fb5},7:set()}
    for level in range(1,8):
        ram=(args.captures/('ln2-game-ram.bin' if level==1 else f'ln2-level{level}-ram.bin')).read_bytes()
        w=read_json(PROJECT/f'datafiles/play/ln2/level{level}/world.json');seen=set();modes=set()
        for room in w['rooms']:
            for i,b in enumerate(room['boundaries']):
                if not b[4]&1:continue
                mode=b[5]&63;modes.add(mode)
                if mode not in {1,2,3,4}|extra[level]:continue
                sensors.append(dict(level=level,room=room['id'],line=i,mode=mode))
                if (room['id'],mode) in seen:continue
                seen.add((room['id'],mode))
                start=ram.index(bytes.fromhex('a68130016024807004'))
                for flags,busy,interrupt,locked,gate in itertools.product((0,1,128,129),(0,1),(0,64),(0,1),(0,255)):
                    mem=list(ram);mem[0xa2]=room['id'];mem[0x81]=flags;mem[0x80]=mode|interrupt;mem[0x61]=0xc3 if busy else 0;mem[0x234]=locked
                    for index in (17,19,20):mem[0x3d8+index]=gate
                    cpu=MPU(memory=mem,pc=start);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1];entry=-1
                    for _ in range(10000):
                        if cpu.pc==0x1ff:break
                        if cpu.pc==w['source_layout']['entrance']:entry=cpu.x;break
                        if cpu.pc in stubs[level]:cpu.pc=(cpu.stPopWord()+1)&65535
                        else:cpu.step()
                    else:raise AssertionError((level,mode,hex(cpu.pc)))
                    vectors.append(dict(level=level,room=room['id'],mode=mode|interrupt,flags=flags,busy=busy,locked=locked,gate=gate,entry=entry))
        audit.append(dict(level=level,rooms=len(w['rooms']),sensor_modes=sorted(modes),interior_routes=len(seen),sha256=hashlib.sha256(ram).hexdigest()))
    path=PROJECT/'datafiles/verification/ln2_interior_routes.json';write_json(path,dict(vectors=vectors,sensors=sensors,levels=audit,scope=__doc__));register_project({},[path])
    write_json(ROOT/'evidence/ln2_transition_audit.json',dict(levels=audit,sensor_lines=len(sensors),original_cases=len(vectors),scope=__doc__))
    print(len(sensors),'exit sensor lines;',len(vectors),'original gate/destination cases',flush=True)

if __name__=='__main__':main()
