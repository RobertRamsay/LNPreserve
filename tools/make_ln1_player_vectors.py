"""Exercise original player machine code as an offline oracle for native GML.

Executes $5a12 and its original callees from supplied-game RAM. Only drawing
entrypoints $7660/$6ff9 are intercepted, leaving movement/collision/action code
intact. IRQ and VIC bus stalls are outside this routine-level comparison.
"""
import hashlib,json,sys
from export_ln1_play import ROOT,FIELDS
sys.path.insert(0,str(ROOT/'tools/vendor/pydeps'))
from py65.devices.mpu6502 import MPU

def state(mem):
    value={name:mem[address] for name,address in FIELDS.items()}
    value.update(action=mem[0x60]+mem[0x61]*256,enemy_x=mem[0x56],enemy_y=mem[0x57],tick=mem[0x1b])
    return value

def call(mem,tick,joy):
    mem[0x1b]=tick;mem[0xb5]=joy
    cpu=MPU(memory=mem,pc=0x5a12);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1]
    display=None
    for _ in range(50000):
        if cpu.pc==0x1ff:return display
        if cpu.pc in (0x7660,0x6ff9):
            if cpu.pc==0x7660:
                mem[0x9f]=0;display=dict(frame=cpu.y,mirror=cpu.a!=0)
            cpu.pc=(cpu.stPopWord()+1)&65535
        else:cpu.step()
    raise AssertionError(f'Original player did not return: ${cpu.pc:04x}')

def main():
    ram=(ROOT/'source/local/captures/ln1-game-ram.bin').read_bytes();vectors=[]
    sequences=[]
    for direction in [0,1,2,4,8,5,6,9,10]:
        sequences.append((f'walk_{direction}',[direction]*96+[0]*8))
        if direction:
            sequences.append((f'fire_{direction}',[0]*4+[16]*4+[direction|16]*80+[0]*24))
            sequences.append((f'walk_fire_{direction}',[direction]*12+[direction|16]*64+[direction]*12+[0]*8))
    sequences.append(('turns_and_reversal',([9]*8+[10]*8+[6]*8+[5]*8+[9]*8+[6]*8+[8]*8+[4]*8)*2))
    sequences.extend([('prayer_kneel',[0]*64),('prayer_stand',[0]*64)])
    for name,inputs in sequences:
        mem=list(ram)
        if name.startswith('prayer_'):
            entry=0xada5 if name=='prayer_kneel' else 0xadbd
            mem[0x60]=entry&255;mem[0x61]=entry>>8;mem[0x5c]=mem[entry];mem[0x58]=0
            mem[0x68]=mem[0x69]=mem[0x96]=7;mem[0x5d]=2;mem[0xb6]=mem[0x6c]=255
        initial=state(mem);frames=[];display=dict(frame=mem[0x65],mirror=False)
        for index,joy in enumerate(inputs):
            tick=(initial['tick']+index+1)&255
            drawn=call(mem,tick,joy)
            if drawn is not None:display=drawn
            frames.append(dict(joy=joy,tick=tick,expected=state(mem),display=display))
        vectors.append(dict(name=name,initial=initial,frames=frames))
    out=ROOT/'LNPreserve/datafiles/verification/ln1_player_vectors.json'
    out.write_text(json.dumps(dict(schema=1,source_ram_sha256=hashlib.sha256(ram).hexdigest(),
        fields=FIELDS,vectors=vectors,scope='Original player movement, boundary and action routines; drawing intercepted; world updates and system timing excluded.'),separators=(',',':'))+'\n')
    print(len(vectors),'sequences;',sum(len(v['frames']) for v in vectors),'original player updates')

if __name__=='__main__':main()
