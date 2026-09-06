"""Original final enemy release after the LN2 keypad has been solved.

Bitmap compositor/mask calls are suppressed. The complete release handler,
enemy selector and reset routines otherwise execute as supplied instructions.
"""
import json,random
from ln2_level_source import *
from build_project import PROJECT,read_json,write_json
from export_ln1_levels import register_project
from make_ln2_enemy_vectors import state as enemy_state,FIELDS
from export_ln1_world import call


def main():
    ram=level_memory(7);s=layout(ram);d=read_json(PROJECT/'datafiles/play/ln2/level7/gameplay.json');rng=random.Random(0xb3fd);vectors=[]
    for i in range(384):
        mem=list(ram);mem[0xa2]=1
        for p in (s['actor_draw'],s['actor_player'],s['actor_enemy'],s['mask']):mem[p]=0x60
        call(mem,s['enemy_enter'])
        for key in ('x','y','fraction_x','fraction_y','countdown','duration','frame','combat_state','traits','speed','mode','health','facing','heading','action_mirror'):
            mem[FIELDS[key]]=rng.randrange(256)
        mem[0x3ea]=rng.choice([0,255,255]);mem[0x29f:0x2a4]=[rng.choice([0,128,129]) for _ in range(5)]
        before=dict(enemy=enemy_state(mem,d),costume=mem[0x7f],retreat_trait=mem[0xd6],candles=mem[0x29f:0x2a4],gate=mem[0x3ea])
        call(mem,0xb3fd,x=28,y=16)
        after=dict(enemy=enemy_state(mem,d),costume=mem[0x7f],retreat_trait=mem[0xd6],candles=mem[0x29f:0x2a4],gate=mem[0x3ea])
        vectors.append(dict(before=before,expected=after,accepted=mem[0x3ea]!=0))
    path=PROJECT/'datafiles/verification/ln2_boss_release_vectors.json';path.write_text(json.dumps(dict(vectors=vectors,scope=__doc__),separators=(',',':'))+'\n')
    data=dict(retreat_trait=ram[0xa7d4]>>4,frame=ram[0xa78d],mirror=ram[0xa795],traits=ram[0xa7e6],costume=before['costume'])
    target=PROJECT/'datafiles/play/ln2/boss_release.json';write_json(target,data);register_project({},[path,target])
    print(len(vectors),'original LN2 final enemy release states',data)


if __name__=='__main__':main()
