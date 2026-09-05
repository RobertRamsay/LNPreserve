"""Original-code projectile motion/lifetime vectors; no render or combat claim."""
from export_ln1_world import call
from ln1_level_source import level_memory, relocated
from export_ln1_levels import register_project
from build_project import PROJECT, write_json


def main():
    vectors=[]
    for level in range(1,7):
        ram,_=level_memory(level);routine=relocated(ram,0x5130,40)
        for slot in range(2):
            for facing in [1,3,5,7]:
                for kind in [1,2,3]:
                    for x,y in [(50,70),(120,120),(239,174),(8,34)]:
                        for life in [1,2,63,64,65,86,255]:
                            mem=list(ram);mem[0xcb]=0;mem[0x280:0x282]=[0,0]
                            mem[0x280+slot]=kind;mem[0x282+slot]=facing;mem[0x284+slot]=x
                            mem[0x286+slot]=y;mem[0x288+slot]=life;mem[0x1b]=100;mem[0x273]=99
                            call(mem,routine)
                            vectors.append(dict(level=level,slot=slot,facing=facing,kind=kind,x=x,y=y,life=life,
                                                expected=[mem[0x280+slot],mem[0x284+slot],mem[0x286+slot],mem[0x288+slot]]))
    path=PROJECT/'datafiles/verification/ln1_projectile_vectors.json'
    write_json(path,dict(vectors=vectors,scope='Single timer-tick motion/lifetime; collision targets and rendering disabled'))
    register_project({},[path]);print(len(vectors),'original projectile updates')


if __name__=='__main__':main()
