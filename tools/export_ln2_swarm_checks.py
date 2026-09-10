import sys,json,random,argparse
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent/'vendor/pydeps'))
from py65.devices.mpu6502 import MPU
root=Path(__file__).resolve().parents[1];project=root/'LNPreserve'
parser=argparse.ArgumentParser();parser.add_argument('--source-root',type=Path,required=True);args=parser.parse_args()
ram=(args.source_root/'source/local/captures/ln2-game-ram.bin').read_bytes()
rng=random.Random(2215);cases=[]
for i in range(256):
    xy=[rng.randrange(256) for _ in range(4)]
    if i<128:xy=[120,120,120+(i%17)-8,120+(i//17)-4]
    xs=[rng.randrange(50,58) for _ in range(3)];ys=[rng.randrange(-5,3) for _ in range(3)]
    mem=list(ram);mem[0x54:0x58]=xy
    for j in range(3):mem[0xcd9d+4*j]=xs[j];mem[0xcd9e+4*j]=ys[j]&255
    cpu=MPU(memory=mem,pc=0xa9ba);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1]
    queue=[];damage=0
    mem[0xb416]=0x60;mem[0xb441]=0x60
    for step in range(20000):
        if cpu.pc==0x1ff:break
        if cpu.pc==0xb416:cpu.a=rng.randrange(256);queue.append(cpu.a)
        if cpu.pc==0xb441:damage+=cpu.a
        cpu.step()
    else:raise AssertionError('oracle did not return')
    cases.append(dict(xy=xy,x=xs,y=ys,random=queue,result_xy=mem[0x56:0x58],result_x=[mem[0xcd9d+j*4] for j in range(3)],result_y=[(mem[0xcd9e+j*4]+128)%256-128 for j in range(3)],damage=damage))
(project/'datafiles/play/ln2/swarm_checks.json').write_text(json.dumps(cases),encoding='utf-8')
