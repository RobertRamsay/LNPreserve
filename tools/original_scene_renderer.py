"""Offline scenery extraction using the supplied games' own 6502 drawing code.

Only PNGs and decoded records enter GameMaker. CPU timing here is irrelevant to
static image extraction and does not establish native gameplay cycle accuracy.
"""
import hashlib
from PIL import Image
from decode_graphics import ROOT, PALETTE, word
from export_ln1_world import call, bitmap


class OriginalSceneRenderer:
    def __init__(self, game, raw):
        if game not in (1, 3):
            raise ValueError('No supplied-game renderer recovered for this game')
        self.game = game
        name = 'ln1-game-ram.bin' if game == 1 else 'ln3-advance2-ram.bin'
        path = ROOT / 'source/local/captures' / name
        self.ram = path.read_bytes()
        if len(self.ram) != 65536:
            raise ValueError('Expected a complete original RAM capture')
        self.provenance = dict(engine_game=game, entry=0x5dfe if game == 1 else 0x71f9,
            source_ram_sha256=hashlib.sha256(self.ram).hexdigest(),
            offline_only=True, system_timing_verified=False)
        self.initial = list(self.ram)
        base = word(raw, 0)
        self.initial[base:base+len(raw)-2] = raw[2:]
        if game == 1:
            table = word(self.initial, 0x800)
            self.initial[0x0a:0x0e] = [table & 255, table >> 8, table & 255, (table >> 8) + 1]

    def render(self, scene):
        mem = self.initial.copy()
        if self.game == 1:
            mem[0xa2] = scene
            call(mem, 0x5452)
            call(mem, 0x5dfe)
            return bitmap(mem)
        for address, length in ((0xcc00, 1000), (0xd000, 1000), (0xd800, 1000), (0xe000, 8000)):
            mem[address:address+length] = [0] * length
        call(mem, 0x71f9, a=scene)
        pixels = []
        for y in range(144):
            for x in range(240):
                cell = y // 8 * 40 + x // 8
                code = (mem[0xe000+cell*8+y%8] >> (6-(x%8//2)*2)) & 3
                colour = [mem[0xc0], mem[0xcc00+cell] >> 4,
                    mem[0xcc00+cell] & 15, mem[0xd800+cell] & 15][code]
                pixels.append((*PALETTE[colour], 255))
        image = Image.new('RGBA', (240, 144))
        image.putdata(pixels)
        return image
