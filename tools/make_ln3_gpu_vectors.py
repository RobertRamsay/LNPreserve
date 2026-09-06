"""Original decompressed ordinary sprite parts with original scenery masks.

These vectors check editable PNG alpha/tint and GPU application of the native
visibility masks. Multicolour/expanded special actors and complete VIC output
remain separate from this isolated part-rendering check.
"""
import json,random
from export_ln3_runtime import *

def main():
    rng=random.Random(0x6115);vectors=[]
    for level in range(1,6):
        ram=level_memory(level);s=layout(ram);world=read_json(PROJECT/f'datafiles/play/ln3/level{level}/world.json')
        for room in world['rooms']:
            for part in (1,5):
                mem=list(ram);frame=rng.choice([30,55,80,100]);x=rng.randrange(32,232);y=rng.randrange(60,154);foot=min(173,y+21)
                mirror=rng.randrange(2);mem[0xde]=255 if mirror else 0;mem[0xdc]=part;mem[0x318]=0;mem[0x2ae+part]=frame
                mem[0xe3]=room['id'];mem[0x40+part*2]=x;mem[0x41+part*2]=y;mem[0x45 if part<4 else 0x4d]=foot
                mem[0x63]=rng.randrange(256);call(mem,s['sprite_unpack'],x=part);spill=mem[0x63]
                call(mem,s['mask']);raw=list(mem[0x200:0x23f])
                vectors.append(dict(level=level,room_id=room['id'],part=part,frame=frame,x=x,y=y,foot=foot,mirror=mirror,
                    spill=spill,colour=rng.randrange(16),expected=raw))
    path=PROJECT/'datafiles/verification/ln3_gpu_vectors.json';write_json(path,dict(vectors=vectors,scope=__doc__));register_project({},[path])
    print(len(vectors),'original masked sprite parts')

if __name__=='__main__':main()
