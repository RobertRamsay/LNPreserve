"""Bounded original-capture checks; not a GameMaker run or input replay."""
import hashlib
from itertools import product
from build_project import ROOT, PROJECT, read_json, write_json
from ln2_level_source import level_memory, layout, MPU
from export_ln1_world import call

def main():
    levels=[]
    for level in range(1,8):
        ram=level_memory(level);source=layout(ram)
        folder=PROJECT/f'datafiles/play/ln2/level{level}'
        world=read_json(folder/'world.json');vectors=read_json(folder/'navigation_vectors.json')['vectors']
        assert hashlib.sha256(ram).hexdigest()==world['source_sha256']
        for case in vectors:
            mem=list(ram);mem[0xa2]=case['room'];mem[0x54],mem[0x55]=case['point']
            mem[0x234]=mem[0x2af]=0
            call(mem,source['exit']);expected=case['expected']
            assert (mem[0x2af]==255)==expected['level_end']
            if not expected['level_end']:
                for name,address in [('room',0xa2),('entry',0x278),('x',0x54),('y',0x55),('facing',0x69)]:
                    assert mem[address]==expected[name],(level,case,name)
        modes=sorted({b[5]&63 for r in world['rooms'] for b in r['boundaries'] if b[4]&1 and b[5]&63})
        levels.append(dict(level=level,title=world['title'],source_sha256=world['source_sha256'],
            room_records=len(world['rooms']),interaction_records=len(world['items']),original_exit_cases=len(vectors),
            sensor_modes_in_export=modes,complete_playthrough_verified=False))
    # Stub only the blocking sink loop. Record its requested repeat count;
    # execute the actual dispatcher and entrance code on either side of it.
    checks=0;ram=level_memory(1)
    assert ram[0xa1cf:0xa1d2]==bytes.fromhex('aa a9 ff')
    for flag,crossings,busy,interrupt in product((0,255),(0,1,128,129),(0,0xc3),(0,64)):
        mem=list(ram);mem[0xa1cf]=0x60
        mem[0x3ea]=flag;mem[0x81]=crossings;mem[0x80]=5|interrupt;mem[0x61]=busy
        mem[0xa2]=1;mem[0x234]=0;mem[0x278]=0
        cpu=MPU(memory=mem,pc=0x9fd8);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1];requests=[]
        for _ in range(10000):
            if cpu.pc==0x1ff:break
            if cpu.pc==0xa1cf:requests.append(cpu.a)
            cpu.step()
        else:raise AssertionError('dispatcher did not return')
        accepted=bool(flag and crossings&128 and crossings&1 and (not busy or interrupt))
        assert requests==([5] if accepted else [])
        assert mem[0x3ea]==(0 if accepted else flag)
        assert mem[0xa2]==(3 if accepted else 1)
        if accepted:assert mem[0x278]==2
        checks+=1
    write_json(ROOT/'evidence/ln2_progression_audit.json',dict(levels=levels,
        hole_dispatcher_cases=checks,sink_loop_stubbed=True,original_exit_cases=sum(l['original_exit_cases'] for l in levels),
        native_tests_run_here=False,gpu_tests_run_here=False,complete_gameplay_verified=False))
    print('Original checks:',checks,'hole dispatcher cases;',sum(l['original_exit_cases'] for l in levels),'exit cases across seven levels')

if __name__=='__main__':main()
