"""Prepare the supplied Censor LN3 edition for static extraction in VICE.

The crack-title space read is substituted at its original input boundary. Six
trainers receive N. This changes extraction input, not original gameplay code,
and must never be advertised as an unmodified-input acceptance replay.
"""
import subprocess,sys
from vice_reference import Reference,ROOT
from inspect_ln1_water import screen

def main():
    out=ROOT/'source/local/captures';out.mkdir(exist_ok=True)
    disk=ROOT/'source/local/last_ninja_3_the_side_a/disk.d64'
    prg=disk.parent/'001_LAST_N_3_6HI_CEN.bin'
    if not prg.exists():raise FileNotFoundError('Extract the supplied LN3 ZIP first')
    commands=out/'ln3-bootstrap.mon'
    commands.write_text(f'''load "{prg.as_posix()}" 0
r pc=080b
radix d
z 4000000
radix h
bank ram
bsave "{(out/'ln3-boot-ram.bin').as_posix()}" 0 0000 ffff
dump "{(out/'ln3-boot.vsf').as_posix()}"
quit
''')
    subprocess.run([sys.executable,str(ROOT/'tools/capture_reference.py'),str(disk),
        '--cycles','120000000','--name','ln3_bootstrap','--commands',str(commands)],check=True)
    with Reference(disk) as ref:
        ref.load_snapshot(out/'ln3-boot.vsf');ref.until(0x26c6);ref.set_registers(A=0xef)
        for _ in range(110):ref.step(65535)
        ref.command(0x72,b'\x06NNNNNN')
        for index in range(2210):
            ref.step(65535)
            if index%500==0:print('Loading supplied LN3:',index,flush=True)
        raw=next((ROOT/'tools/vendor/integrator-ln3').rglob('int-level1-tape.prg')).read_bytes()
        memory=ref.memory(0,65535);base=int.from_bytes(raw[:2],'little')
        if memory[base:base+len(raw)-2]!=raw[2:]:raise AssertionError('Supplied LN3 level 1 did not load')
        (out/'ln3-advance2-ram.bin').write_bytes(memory)
        (out/'ln3-colour.bin').write_bytes(ref.memory(0xd800,0xdbff,'io'))
        screen(ref).save(out/'ln3-original.png')
        name=str(out/'ln3-advance2.vsf').encode();ref.command(0x41,bytes([0,1,len(name)])+name)
    print('Supplied LN3 level 1 data matches the reference payload exactly.')

if __name__=='__main__':main()
