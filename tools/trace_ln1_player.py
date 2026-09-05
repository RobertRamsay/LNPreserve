"""Capture original player states for deterministic native translation checks."""
from pathlib import Path
import argparse,json,struct
from vice_reference import Reference,ROOT
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--ticks',type=int,default=8)
    parser.add_argument('--joy',type=int,default=8);parser.add_argument('--port',type=int,default=2);args=parser.parse_args()
    frames=[]
    with Reference() as ref:
        ref.load_snapshot(ROOT/'source/local/captures/ln1-game.vsf')
        ref.until(0xbd23)
        initial=ref.memory(0,65535)
        for tick in range(args.ticks):
            ref.command(0xa2,struct.pack('<HH',args.port,args.joy))
            ref.until(0xbd29)
            ram=ref.memory(0,65535)
            frames.append(dict(tick=tick,stop=ref.last_stop,joy=args.joy,clock=ram[0x1b],
                state=list(ram[0x50:0xe0]),sprites=list(ram[0x200:0x260]),
                boundary_flags=list(ram[0x2b5:0x2b9])))
            print(tick,'joy read',ram[0xb5],'position',list(ram[0x54:0x56]),'frame',ram[0x65],flush=True)
            ref.until(0xbd23)
    out=ROOT/'source/local/captures';name=f'ln1-player-joy{args.joy}'
    (out/f'{name}-initial.bin').write_bytes(initial)
    (out/f'{name}.json').write_text(json.dumps(dict(initial_state=list(initial[0x50:0xe0]),frames=frames),indent=2)+'\n')
if __name__=='__main__':main()
