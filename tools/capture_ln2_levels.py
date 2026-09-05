"""Capture supplied LN2 levels through the original loader, offline only.

The supplied crack's starting-level selector is an extraction aid; all other
trainer options stay off. Input substitutions only dismiss loader/title prompts.
"""
import argparse
import hashlib
import json
from vice_reference import ROOT, Reference


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--first',type=int,default=2)
    parser.add_argument('--through',type=int,default=7);args=parser.parse_args()
    out=ROOT/'source/local/captures';report=[]
    for level in range(args.first,args.through+1):
        target=out/f'ln2-level{level}-ram.bin'
        if target.is_file():continue
        disk=ROOT/f'source/local/last_ninja_2_the_side_{"a" if level==2 else "b"}/disk.d64'
        with Reference(disk) as ref:
            ref.socket.settimeout(45)
            if (out/f'ln2-level{level}-loaded.vsf').is_file():
                ref.load_snapshot(out/f'ln2-level{level}-loaded.vsf')
            elif level==2 and (out/'ln2-level2-load.vsf').is_file():
                ref.load_snapshot(out/'ln2-level2-load.vsf')
            else:
                ref.load_snapshot(out/('ln2-stage.vsf' if level==2 else 'ln2-stage-side-b.vsf'));ref.write(0x055e,[level])
                ref.command(0x72,bytes([1,32]));ref.until(0x170a)
                ref.set_registers(A=0,FL=ref.registers()['FL']|2)
                print('Loading original LN2 level',level,flush=True)
                for _ in range(600):ref.step(65535)
            ram=ref.memory(0,65535)
            (out/f'ln2-level{level}-loaded-ram.bin').write_bytes(ram)
            name=str(out/f'ln2-level{level}-loaded.vsf').encode();ref.command(0x41,bytes([0,0,len(name)])+name)
            title=ram.index(bytes.fromhex('ad 00 dc 2d 01 dc 29 10 d0'),0x600,0xd000)+8
            loop=ram.index(bytes.fromhex('a5 e2 cd 68 02 f0 f9 a5 e2 8d 68 02'),0x600,0xd000)
            ref.until(title);ref.set_registers(A=0,FL=ref.registers()['FL']|2);ref.until(loop)
            ram=ref.memory(0,65535);target.write_bytes(ram)
            name=str(out/f'ln2-level{level}.vsf').encode();ref.command(0x41,bytes([0,1,len(name)])+name)
            from inspect_ln1_water import screen
            screen(ref).save(out/f'ln2-level{level}.png')
            record=dict(level=level,main_loop=loop,title_prompt=title,source_sha256=hashlib.sha256(ram).hexdigest())
            report.append(record);print(record,flush=True)
    (out/'ln2-level-capture.json').write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':main()
