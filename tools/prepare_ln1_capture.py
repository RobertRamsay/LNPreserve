"""Write local VICE monitor scripts for repeatable LN1 extraction, not parity."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    out=ROOT/'source/local/captures';out.mkdir(parents=True,exist_ok=True)
    prg=ROOT/'source/local/last_ninja_the_side_a_ccs/001_LAST_NINJA_CCS.bin'
    if not prg.is_file():raise FileNotFoundError('Extract the supplied LN1 ZIP first')
    path=lambda name:(out/name).as_posix()
    (out/'ln1-bootstrap.mon').write_text(f'''load "{prg.as_posix()}" 0
r pc=0812
radix d
z 5000000
keybuf "\\x85"
z 5000000
radix h
bank ram
bsave "{path('ln1-ram.bin')}" 0 0000 ffff
dump "{path('ln1-boot.vsf')}"
quit
''')
    (out/'ln1-start.mon').write_text(f'''undump "{path('ln1-boot.vsf')}"
bank cpu
r pc=c89b
radix d
z 6000000
radix h
bank ram
bsave "{path('ln1-game-ram.bin')}" 0 0000 ffff
dump "{path('ln1-game.vsf')}"
quit
''')
    print('Extraction scripts written. PC $c89b bypasses the crack-title input wait only.')
if __name__=='__main__':main()
