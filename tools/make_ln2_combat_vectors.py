"""Independent original melee range tests across the seven LN2 banks."""
import json,random,sys
from build_project import ROOT,PROJECT,read_json,write_json
from ln2_level_source import level_memory,layout,locate
from export_ln1_levels import register_project
sys.path.insert(0,str(ROOT/'tools/vendor/pydeps'))
from py65.devices.mpu6502 import MPU

def main():
    rng=random.Random(650220);vectors=[]
    for level in range(1,8):
        ram=level_memory(level);entry=locate(ram,0xab70,32)
        for i in range(3000):
            mem=list(ram);attacker=i&1;offset=attacker*2
            mem[0x54]=128;mem[0x55]=96;mem[0x56]=rng.randrange(81,176);mem[0x57]=rng.randrange(76,117)
            mem[0x6d]=rng.randrange(12,40);mem[0x6f]=rng.randrange(12,40);mem[0x6d+offset]=rng.randrange(20,36)
            mem[0x70]=rng.randrange(5);mem[0x72]=rng.randrange(5);mem[0xcb]=rng.choice((0,128,129,130,131));mem[0x2bd]=rng.randrange(6)
            cpu=MPU(memory=mem,pc=entry);cpu.x=offset;cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1]
            for _ in range(1000):
                if cpu.pc==0x1ff:break
                cpu.step()
            else:raise AssertionError('LN2 hit routine did not return')
            def actor(o):return dict(x=mem[0x54+o],y=mem[0x55+o],combat_state=mem[0x6d+o],weapon=mem[0x70+o])
            vectors.append(dict(level=level,player=actor(0),enemy=actor(2),active=mem[0xcb],attack_count=mem[0x2bd],
                                enemy_attacks=bool(attacker),expected=mem[0x1f] if cpu.a else -1))
    path=PROJECT/'datafiles/verification/ln2_combat_vectors.json';path.write_text(json.dumps(dict(vectors=vectors),separators=(',',':'))+'\n')
    register_project({},[path]);print(len(vectors),'original LN2 melee comparisons')

if __name__=='__main__':main()
