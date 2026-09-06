"""Capture LN3's five supplied-game levels at their original main-loop entry.

Offline extraction fixture: resume the level loader request, select L0..L4,
and restore KERNAL HIBASE ($0288) to 4 before the crack calls CINT. The game
reuses that address for enemy state; CINT otherwise clears zero page/stack.
No gameplay code is patched. These captures are not ordinary-input replays.
"""
import argparse,hashlib,json
from vice_reference import ROOT,Reference
from inspect_ln1_water import screen

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--levels',type=int,nargs='+',default=[1,2,3,4,5]);args=parser.parse_args()
    out=ROOT/'source/local/captures';records=[]
    for level in args.levels:
        assert 1<=level<=5
        target=out/f'ln3-level{level}-ram.bin'
        side='a' if level<=2 else 'b';disk=ROOT/f'source/local/last_ninja_3_the_side_{side}/disk.d64'
        number=f'{level+0x15:02X}'
        packed=next(disk.parent.glob(f'*_{number}_L3_*.bin')).read_bytes()
        assert packed[8]==0x4c
        entry=int.from_bytes(packed[9:11],'little')
        with Reference(disk) as ref:
            ref.socket.settimeout(50)
            ref.load_snapshot(out/('ln3-level2-request.vsf' if side=='a' else 'ln3-request-side-b.vsf'))
            ref.write(0x1f,[level-1]);ref.write(0x6da1,[0x30+level-1]);ref.write(0x288,[4])
            print('Loading original LN3 bank',level,'at',hex(entry),flush=True)
            ref.until(entry)
            ram=ref.memory(0,65535)
            main_loop=entry+33
            assert ram[main_loop:main_loop+5]==bytes.fromhex('ad e7 02 d0 fb')
            ref.until(main_loop)
            ram=ref.memory(0,65535);target.write_bytes(ram)
            raw=next((ROOT/'tools/vendor/integrator-ln3').rglob(f'int-level{level}-tape.prg')).read_bytes();base=int.from_bytes(raw[:2],'little')
            match=ram[base:base+len(raw)-2]==raw[2:]
            (out/f'ln3-level{level}-vic.bin').write_bytes(ref.memory(0xd000,0xd03f,'io'))
            (out/f'ln3-level{level}-colour.bin').write_bytes(ref.memory(0xd800,0xdbff,'io'))
            screen(ref).save(out/f'ln3-level{level}.png')
            name=str(out/f'ln3-level{level}.vsf').encode();ref.command(0x41,bytes([0,1,len(name)])+name)
            record=dict(level=level,entry=entry,main_loop=main_loop,reference_scenery_payload_matches=match,
                        source_sha256=hashlib.sha256(ram).hexdigest())
            records.append(record);print(record,flush=True)
    (out/'ln3-level-capture.json').write_text(json.dumps(dict(levels=records,scope=__doc__),indent=2)+'\n')

if __name__=='__main__':main()
