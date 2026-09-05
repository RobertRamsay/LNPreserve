"""Execute the original directional melee hit test for native comparison."""
import json,random,sys
from export_ln1_play import ROOT
sys.path.insert(0,str(ROOT/'tools/vendor/pydeps'))
from py65.devices.mpu6502 import MPU

def main():
    ram=(ROOT/'source/local/captures/ln1-game-ram.bin').read_bytes();rng=random.Random(7815);vectors=[]
    for index in range(12000):
        mem=list(ram);attacker=index&1
        mem[0x54]=128;mem[0x55]=96;mem[0x56]=rng.randrange(81,176);mem[0x57]=rng.randrange(76,117)
        mem[0x6d]=rng.randrange(12,40);mem[0x6f]=rng.randrange(12,40)
        mem[0x70]=rng.randrange(7);mem[0x72]=rng.randrange(7)
        mem[0xcb]=rng.choice((0,128,129,130,131,133,137));mem[0xd7]=rng.randrange(6)
        cpu=MPU(memory=mem,pc=0x7ecc);cpu.x=attacker*2;cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1]
        for _ in range(1000):
            if cpu.pc==0x1ff:break
            cpu.step()
        else:raise AssertionError('Hit test did not return')
        # Calls use valid attack classes 20..35; other classes exercise the
        # original's indexed-table spill behavior and are not valid commands.
        cls=mem[0x6d+attacker*2]
        if not 20<=cls<36:continue
        def actor(offset):return dict(x=mem[0x54+offset],y=mem[0x55+offset],combat_state=mem[0x6d+offset],weapon=mem[0x70+offset])
        vectors.append(dict(player=actor(0),enemy=actor(2),active=mem[0xcb],attack_count=mem[0xd7],
            enemy_attacks=bool(attacker),expected=mem[0x1f] if cpu.a else -1))
    (ROOT/'LNPreserve/datafiles/verification/ln1_combat_vectors.json').write_text(json.dumps(dict(vectors=vectors),separators=(',',':'))+'\n')
    print(len(vectors),'original melee hit tests; hits:',sum(v['expected']>=0 for v in vectors))

if __name__=='__main__':main()
