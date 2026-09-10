"""Recover LN2 message glyphs by executing its original inline printer."""
import sys
from pathlib import Path
import argparse
p=argparse.ArgumentParser();p.add_argument('capture',type=Path);args=p.parse_args()
import build_project as b
from export_ln1_world import call
from export_ln2_hud import screen
from export_ln1_levels import register_project
ram=args.capture.read_bytes()
images=[]
for code in range(64):
    mem=list(ram);mem[0xd011]=128
    # Execute the game's inline text printer, using the lives message colours.
    mem[0x500:0x50b]=[0x20,0x83,0x15,0,0,ram[0x8e5a],ram[0x8e5b],code or 64,0,0x60,0]
    call(mem,0x500)
    im=screen(mem).crop((0,0,8,8))
    im.putdata([(r,g,bl,0 if (r,g,bl)==(0,0,0) else a) for r,g,bl,a in im.getdata()])
    images.append(im)
temp=b.ROOT/'build/ln2-original-font.png';images[1].save(temp);b.REFRESH_GRAPHICS=True
register_project({'spr_ln2_message_font':b.sprite_resource('spr_ln2_message_font',temp,'Graphics/ln2_game_level1',images)},[])
