"""Mansion helicopter attachment/drop oracle, excluding world event dispatch."""
import json,sys
from build_project import ROOT,PROJECT,read_json,write_json
from ln2_level_source import level_memory,layout
from make_ln2_player_vectors import state as player_state
from make_ln2_enemy_vectors import state as enemy_state
from export_ln1_levels import register_project
sys.path.insert(0,str(ROOT/'tools/vendor/pydeps'))
from py65.devices.mpu6502 import MPU

def invoke(mem,s,address):
    cpu=MPU(memory=mem,pc=address);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1];draws={}
    for _ in range(50000):
        if cpu.pc==0x1ff:return draws
        if cpu.pc in (s['actor_player'],s['actor_enemy'],s['mask']):
            if cpu.pc!=s['mask']:
                who='player' if cpu.pc==s['actor_player'] else 'enemy';draws[who]=dict(frame=cpu.y,mirror=cpu.a!=0)
                if who=='player':mem[0x9f]=0
            cpu.pc=(cpu.stPopWord()+1)&65535
        else:cpu.step()
    raise AssertionError(f'LN2 intro routine did not return at ${cpu.pc:04x}')

def main():
    r=level_memory(6);s=layout(r);d=read_json(ROOT/'source/local/recovered/ln2/level6/gameplay.json');vectors=[]
    for drop in (False,True):
        mem=list(r);initial=dict(player=player_state(mem),enemy=enemy_state(mem,d),special_mode=mem[0xf8],special_flag=mem[0xb1],exit_locked=bool(mem[0x234]))
        frames=[];display=dict(player=dict(frame=mem[0x65],mirror=False),enemy=dict(frame=mem[0x67],mirror=False))
        released=False
        for i in range(128):
            tick=(initial['player']['tick']+i+1)&255;joy=16 if drop and not released and mem[0x56]>=44 else 0
            if joy:released=True
            mem[0xe2]=tick;mem[0x7c]=joy
            for function in (s['player_update'],s['enemy_action'],0x9b9a):display.update(invoke(mem,s,function))
            p=player_state(mem)
            for key in ('enemy_x','enemy_y','enemy_active'):p.pop(key)
            frames.append(dict(tick=tick,joy=joy,player=p,enemy=enemy_state(mem,d),display=display.copy(),
                               special_mode=mem[0xf8],special_flag=mem[0xb1],exit_locked=bool(mem[0x234])))
        vectors.append(dict(drop=drop,initial=initial,frames=frames))
    path=PROJECT/'datafiles/verification/ln2_intro_vectors.json';path.write_text(json.dumps(dict(vectors=vectors,scope=__doc__),separators=(',',':'))+'\n')
    register_project({},[path]);print('256 original helicopter attachment/drop states')

if __name__=='__main__':main()
