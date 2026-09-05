"""Capture the supplied LN1 level packages after their original disk loader.

This is an offline extraction fixture: setting the level-complete flag bypasses
the preceding objectives. It does not verify a completed playthrough.
"""
import argparse
import hashlib
import json
from vice_reference import ROOT, Reference
from ln1_level_source import level_memory


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--through', type=int, default=6, choices=range(2, 7))
    parser.add_argument('--reconstruct', action='store_true', help='Load source banks offline, then run original level initialization')
    args = parser.parse_args()
    out = ROOT / 'source/local/captures'
    report = []
    for level in range(2, args.through + 1):
        target = out / f'ln1-level{level}-ram.bin'
        if target.is_file() and (out / f'ln1-level{level}.vsf').is_file():
            print('Already captured level', level, flush=True)
            continue
        previous = out / ('ln1-game.vsf' if level == 2 else f'ln1-level{level-1}.vsf')
        side = 'a' if level < 5 else 'b'
        disk = ROOT / f'source/local/last_ninja_the_side_{side}_ccs/disk.d64'
        with Reference(disk) as ref:
            ref.socket.settimeout(50)
            if args.reconstruct:
                ref.load_snapshot(out / 'ln1-level2.vsf')
                source, banks = level_memory(level)
                for lo, hi in [(0x600,0x5400),(0x9e00,0xc000),(0xcc00,0xce80),(0xd800,0xe000),(0xff40,0xfff8)]:
                    ref.write(lo, source[lo:hi])
                ref.set_registers(PC=0xbc60)
                print('Initializing recovered original banks for level', level, flush=True)
            else:
                ref.load_snapshot(previous)
                ref.write(0x2af, [255])
                ref.until(0xce80)
                print('Loading original level', level, 'source IDs', ref.memory(0x804, 0x805).hex(), flush=True)
                # $bc60 can also execute inside a loader tune before the final bank
                # replaces it. $cf11 is the loader's final jump after all eight files.
                ref.until(0xcf11)
            ram = ref.memory(0, 65535)
            if ram[0x805] != 0x40 + level:
                (out / 'ln1-unexpected-loader-ram.bin').write_bytes(ram)
                raise AssertionError(f'Unexpected source level {ram[0x804:0x806].hex()}')
            (out / f'ln1-level{level}-loaded-ram.bin').write_bytes(ram)
            marker = bytes.fromhex('20 09 56 20 79 6e 20 12 5a')
            loop = ram.index(marker, 0xbc60, 0xc000) + 6
            ref.until(loop)
            ram = ref.memory(0, 65535)
            target.write_bytes(ram)
            name = str(out / f'ln1-level{level}.vsf').encode()
            ref.command(0x41, bytes([0, 1, len(name)]) + name)
            record = dict(level=level, ram_sha256=hashlib.sha256(ram).hexdigest(),
                          input_boundary=loop, initial_room=ram[0xa2], initial_entry=ram[0x278])
            report.append(record)
            print(record, flush=True)
    (out / 'ln1-level-capture.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
