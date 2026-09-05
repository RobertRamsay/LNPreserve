"""Original $bee3 water timer vectors; drawing and interrupt timing excluded."""
import hashlib,json
from export_ln1_world import ROOT,call

def main():
    ram=(ROOT/'source/local/captures/ln1-game-ram.bin').read_bytes()
    vectors=[]
    for tick in range(256):
        for elapsed in (0,1,2,3,127,255):
            clock=(tick-elapsed)&255
            mem=list(ram);mem[0x1b]=tick;mem[0x26f]=clock;mem[0x55]=100
            mem[0x5a8d]=0x60 # Intercept renderer, leaving timer logic untouched.
            call(mem,0xbee3)
            vectors.append(dict(tick=tick,clock=clock,y=100,expected_y=mem[0x55],expected_clock=mem[0x26f]))
    result=dict(source_sha256=hashlib.sha256(ram).hexdigest(),entry='$bee3',
        excluded=['rendering at $5a8d','interrupt and whole-game timing'],vectors=vectors)
    path=ROOT/'LNPreserve/datafiles/verification/ln1_water_vectors.json'
    path.write_text(json.dumps(result,separators=(',',':'))+'\n')
    print('Exported',len(vectors),'original water timer vectors')

if __name__=='__main__':main()
