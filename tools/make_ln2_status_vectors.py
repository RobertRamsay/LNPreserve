"""Original LN2 score, clock and health-bar state; raster drawing excluded."""
import json,random
from ln2_level_source import *
from build_project import PROJECT,write_json,read_json
from export_ln1_levels import register_project
from export_ln1_world import call

def clock_state(mem):
    return dict(digits=[mem[0x1c9a+i] for i in (0,1,10,11,20,21)],fraction=mem[0x228],
        running=mem[0x230],blocked=mem[0x2b7],dirty=mem[0x22f])

def run_until(mem,start,end):
    cpu=MPU(memory=mem,pc=start)
    for _ in range(5000):
        if cpu.pc==end:return
        cpu.step()
    raise AssertionError(hex(cpu.pc))

def main():
    ram=level_memory(7);rng=random.Random(0x1ccb);score=[];clock=[];health=[]
    for i in range(2048):
        mem=list(ram);digits=[rng.randrange(27,37) for _ in range(6)];mem[0x1cc3:0x1cc9]=digits
        amount=rng.choice([0x05,0x15,0x25,0x50,0x99]);low=i&1
        call(mem,0x1ccf if low else 0x1ccb,a=amount)
        score.append(dict(digits=digits,amount=amount,low=low,expected=mem[0x1cc3:0x1cc9]))
        mem=list(ram);mem[0x228]=rng.randrange(50);mem[0x230]=rng.choice([0,127,255]);mem[0x2b7]=rng.choice([0,0,255]);mem[0x22f]=rng.randrange(256)
        for j,p in enumerate((0,1,10,11,20,21)):mem[0x1c9a+p]=rng.randrange(27,ram[0x1db0+j])
        if i%2==0:mem[0x228]=49
        before=clock_state(mem);run_until(mem,0x1f79,0x1fba);clock.append(dict(before=before,expected=clock_state(mem)))
        mem=list(ram);mem[0xe2]=i&255;mem[0x2b7]=rng.choice([0,0,255]);mem[0x229:0x22d]=[rng.randrange(45) for _ in range(4)]
        before=dict(tick=mem[0xe2],blocked=mem[0x2b7],target=mem[0x229:0x22b],display=mem[0x22b:0x22d])
        run_until(mem,0x1ec7,0x1f2d);health.append(dict(before=before,expected=mem[0x22b:0x22d]))
    included=[]
    for relative,value in [('play/ln2/status.json',dict(clock_limits=list(ram[0x1db0:0x1db6]))),
        ('verification/ln2_status_vectors.json',dict(score=score,clock=clock,health=health,scope=__doc__))]:
        path=PROJECT/'datafiles'/relative;write_json(path,value);included.append(path)
    name='ln2_status';meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
    write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);register_project({name:{'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}},included)
    print(len(score)+len(clock)+len(health),'original score/clock/health-display states')

if __name__=='__main__':main()
