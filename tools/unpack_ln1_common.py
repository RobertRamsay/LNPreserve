"""Offline recovery of the supplied CCS LN1 common code using py65 1.2.0.

Requires privately extracted source/local/last_ninja_the_side_a_ccs input.
Skips the title UI, not game decompression. Not a C64 boot or cycle test.
Output stays ignored; never commit original RAM or disk data.
"""
from pathlib import Path
import sys,re
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/vendor/pydeps'))
from py65.devices.mpu6502 import MPU
raw=(ROOT/'source/local/last_ninja_the_side_a_ccs/001_LAST_NINJA_CCS.bin').read_bytes()
mem=[0]*65536;load=int.from_bytes(raw[:2],'little');mem[load:load+len(raw)-2]=raw[2:]
mem[0]=47;mem[1]=55
cpu=MPU(memory=mem,pc=2066);stages=[];title_skipped=False
for i in range(12000000):
    if cpu.pc==0xa659:
        match=re.search(rb'\x9e([0-9]+)',bytes(mem[0x801:0x880]))
        if match and int(match[1]) not in stages:
            cpu.pc=int(match[1]);stages.append(cpu.pc);continue
        break
    if cpu.pc==0xffd2 and not title_skipped:
        # Skip title/KERNAL UI only, execute its original bank-copy and unpack.
        title_skipped=True;cpu.pc=0xc8b8;continue
    if cpu.pc>=0xe000: break
    if mem[cpu.pc]==0xc3:
        # NMOS DCP (zp,X): decrement memory then compare accumulator.
        zp=(mem[cpu.pc+1]+cpu.x)&255
        address=mem[zp]|(mem[(zp+1)&255]<<8)
        value=(mem[address]-1)&255;mem[address]=value
        result=(cpu.a-value)&255
        cpu.p=(cpu.p&~(cpu.CARRY|cpu.ZERO|cpu.NEGATIVE)) | (cpu.CARRY if cpu.a>=value else 0) | (cpu.ZERO if result==0 else 0) | (result&128)
        cpu.pc+=2;cpu.processorCycles+=8;continue
    if cpu.disassemble[mem[cpu.pc]][0]=='???':
        raise RuntimeError(f'unsupported {mem[cpu.pc]:02x} at {cpu.pc:04x}')
    cpu.step()
assert cpu.pc == 0xa659 and title_skipped, 'incomplete unpack'
(ROOT/'source/local/captures').mkdir(parents=True,exist_ok=True)
print('stopped',hex(cpu.pc),'steps',i,'stages',stages)
(ROOT/'source/local/captures/ln1-common-unpacked.bin').write_bytes(bytes(mem))
