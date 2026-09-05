"""Execute original LN1 selection code for every previous/current key chord.

Only its two display subroutines are intercepted at their call boundaries.
This verifies selection state and request order, not rendering or system timing.
"""
from pathlib import Path
import hashlib,json,random,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/vendor/pydeps'))
from py65.devices.mpu6502 import MPU

FIELDS={'music':0xaa,'pause':0x2b7,'item':0x279,'weapon':0xd6,'weapon_locked':0x280,'action_reset':0xa0}
def state(mem):
    result={key:mem[address] for key,address in FIELDS.items()}
    result.update(previous=mem[0x2aa:0x2af],inventory=mem[0x3ec:0x3f7],weapons=mem[0x3f6:0x3fc])
    return result

def rows(chord):
    a=255;b=255
    for bit,mask in enumerate((16,32,64,8)):
        if chord>>bit&1:a^=mask
    if chord&16:b^=16
    return a,b

def generate():
    ram=(ROOT/'source/local/captures/ln1-game-ram.bin').read_bytes()
    rng=random.Random(6502);vectors=[]
    for previous in range(32):
        for current in range(32):
            mem=list(ram)
            for addr in range(0x3ec,0x3fc):mem[addr]=rng.choice((0,0,0,1,2,128,255))
            mem[0x3f6]=1 # Unarmed entry ensures both selection loops terminate.
            for key,addr in FIELDS.items():
                mem[addr]=rng.choice((0,255))
            mem[0x279]=rng.randrange(11);mem[0xd6]=rng.randrange(6)
            p0,p7=rows(previous);r0,r7=rows(current)
            mem[0x2aa:0x2af]=[p0&16,p0&32,p0&64,p0&8,p7&16]
            mem[0x260]=r0;mem[0x267]=r7
            initial=state(mem);cpu=MPU(memory=mem,pc=0x6eac)
            effects=[]
            for _ in range(4000):
                if cpu.pc==0x6f6d:break
                if cpu.pc in (0x63cb,0x69e4):
                    if cpu.pc==0x63cb:effects.append(dict(kind='dashboard_icon',a=cpu.a,x=cpu.x))
                    else:effects.append(dict(kind='weapon_panel',a=0,x=0))
                    # Return at the external drawing boundary, without replacing
                    # any instruction inside the selection routine under test.
                    cpu.pc=(cpu.stPopWord()+1)&65535
                    continue
                if cpu.pc==0x6ec4:effects.append(dict(kind='sid_clear',a=0,x=23))
                cpu.step()
            else:raise AssertionError('Selection routine did not terminate')
            vectors.append(dict(previous=previous,current=current,row0=r0,row7=r7,
                                initial=initial,expected=state(mem),effects=effects))
    out=ROOT/'LNPreserve/datafiles/verification';out.mkdir(parents=True,exist_ok=True)
    report=dict(schema=1,source_address_start=0x6eac,source_address_end_exclusive=0x6f6d,
        source_sha256=hashlib.sha256(ram[0x6eac:0x6f6d]).hexdigest(),
        source_bytes=list(ram[0x6eac:0x6f6d]),
        scope='Selection state and ordered external requests. No timing or display parity claim.',vectors=vectors)
    (out/'ln1_control_vectors.json').write_text(json.dumps(report,separators=(',',':'))+'\n')
    (ROOT/'LNPreserve/datafiles/actors/ln1/initial_control_state.json').write_text(json.dumps(state(list(ram)),indent=2)+'\n')
    print(len(vectors),'original-code control vectors generated')

if __name__=='__main__':generate()
