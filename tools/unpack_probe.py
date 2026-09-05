"""Offline unpacking probe only. This is not a C64 accuracy oracle."""
from pathlib import Path
import sys,collections,json,re
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/vendor/pydeps'))
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
if __name__=='__main__':
    source=ROOT/'source/local/last_ninja_the_side_a_ccs/001_LAST_NINJA_CCS.bin'
    b=source.read_bytes();mem=[0]*65536;load=int.from_bytes(b[:2],'little');mem[load:load+len(b)-2]=b[2:]
    mem[0]=0x2f;mem[1]=0x37
    m=MPU(memory=mem,pc=2066);d=Disassembler(m);hist=collections.Counter();tail=collections.deque(maxlen=20)
    stages=[]
    for i in range(12000000):
        hist[m.pc]+=1;tail.append((hex(m.pc),d.instruction_at(m.pc)[1]))
        if m.pc==0xa659:
            basic=bytes(m.memory[0x801:0x880])
            match=re.search(rb'\x9e([0-9]+)',basic)
            if match and int(match[1]) not in stages:
                m.pc=int(match[1]);stages.append(m.pc)
                print('Next BASIC SYS unpacking stage:',hex(m.pc));continue
            print('ROM CLR reached without a new unpacking entry');break
        if m.disassemble[mem[m.pc]][0]=='???':
            print('unsupported opcode',hex(mem[m.pc]),hex(m.pc));break
        if m.pc>=0xe000:
            print('ROM call',hex(m.pc),'after',i);break
        m.step()
    out=ROOT/'source/local/captures';out.mkdir(exist_ok=True)
    (out/'ln1-unpack-probe.bin').write_bytes(bytes(m.memory))
    print('steps',i,'common PCs',[(hex(p),n) for p,n in hist.most_common(8)],'tail',list(tail))
