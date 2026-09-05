"""Read native LN1 level data from the supplied CCS disk files, offline only."""
import hashlib
import sys
from pathlib import Path
from build_project import ROOT
sys.path.insert(0, str(ROOT / 'tools/vendor/pydeps'))
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler


def word(ram, address):
    return ram[address] | ram[address + 1] << 8


def level_memory(level):
    """Reconstruct final loader banks using the original $ce80/$cf40 copy map.

    File PRG headers are $1000 and are ignored by the original loader, which
    passes its destination explicitly. Keep a provenance record for each bank.
    """
    ram = bytearray((ROOT / 'source/local/captures/ln1-game-ram.bin').read_bytes())
    banks = []
    if level == 1:
        return bytes(ram), banks
    side = 'a' if level < 5 else 'b'
    folder = ROOT / f'source/local/last_ninja_the_side_{side}_ccs'
    for block, destination in [(2, 0xdf00), (3, 0xd800), (4, 0xcc00), (5, 0x9e00), (6, 0x600), (7, 0xb000)]:
        path, = folder.glob(f'*_{block}{chr(64+level)}.bin')
        raw = path.read_bytes()
        assert raw[:2] == b'\x00\x10'
        payload = raw[2:]
        if block == 2:
            assert len(payload) == 0x1b8
            ram[0xdf00:0xe000] = payload[:0x100]
            ram[0xff40:0xfff8] = payload[0x100:]
        else:
            ram[destination:destination+len(payload)] = payload
        banks.append(dict(block=block, destination=destination, path=path.relative_to(ROOT).as_posix(),
                          sha256=hashlib.sha256(raw).hexdigest(), payload_bytes=len(payload)))
    assert ram[0x805] == 64 + level
    ram[0xa:0xe] = bytes([ram[0x800], ram[0x801], ram[0x800], (ram[0x801]+1)&255])
    return bytes(ram), banks


def relocated(ram, old_address, size):
    """Find the same source routine, masking relocated absolute operands only."""
    original = (ROOT / 'source/local/captures/ln1-game-ram.bin').read_bytes()
    cpu = MPU(memory=list(original)); dis = Disassembler(cpu)
    pattern = list(original[old_address:old_address+size])
    pc = old_address
    while pc < old_address + size:
        length, _ = dis.instruction_at(pc)
        if length == 3 and word(original, pc+1) >= 0x600:
            for offset in (1, 2):
                if pc+offset < old_address+size:
                    pattern[pc+offset-old_address] = None
        pc += length
    candidates = [i for i in range(0x600, 0xc000-size)
                  if ram[i] == pattern[0] and all(v is None or ram[i+j] == v for j, v in enumerate(pattern))]
    if len(candidates) != 1:
        raise AssertionError(f'Routine ${old_address:04x}: ambiguous candidates {candidates}')
    return candidates[0]


def layout(ram):
    spawn = relocated(ram, 0xadc6, 40)
    items = relocated(ram, 0x52be, 42)
    boundary = relocated(ram, 0xbdbb, 44)
    hurt = relocated(ram, 0xad31, 64)
    enemy_begin = word(ram, 0xbc64)
    selector = next(i for i in range(enemy_begin, enemy_begin+100)
                    if ram[i] == 0xbd and ram[i+3:i+6] == bytes.fromhex('85 62 bd')
                    and ram[i+8:i+13] == bytes.fromhex('85 63 a0 00 b1'))
    return dict(enemy_spawn=spawn, item_enter=items, item_offsets=word(ram, items+8),
                item_table=word(ram, items+13), boundary_enter=boundary,
                enemy_entries=word(ram, selector+1), enemy_begin=enemy_begin,
                reactions=word(ram, hurt+45),
                dispatcher=relocated(ram, 0xaac0, 9))
