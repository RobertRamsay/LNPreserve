"""Compare LN3's complete animation update and body/weapon placement handlers.

The bitmap/sprite compositor is intercepted; part PNG pixels, scene masking,
input, collisions and original IRQ timing are outside this animation check.
"""
import json
from build_project import ROOT,PROJECT,read_json,write_json
from ln3_level_source import level_memory,layout,calls,MPU
from ln3_animation_data import decode
from make_ln3_action_vectors import action_layout
from make_ln3_input_vectors import state as input_state
from export_ln1_world import call
from export_ln1_levels import register_project

def state(mem,a):
    result=input_state(mem,a);result.update(drawn_mask=mem[0x32b],draw_buffer=mem[0xdd],ammo=mem[0x1e],
        selected_item=mem[0xf4],near_enemy=mem[0x320],room_id=mem[0xe3])
    for i,p in enumerate(result['parts']):p['frame']=mem[0x2ae+i]
    return result

def animation_call(mem,s):
    cpu=MPU(memory=mem,pc=s['sprite_update']);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1]
    compositor=calls(mem,s['sprite_update'])[-1];draw={k:[-1]*8 for k in ('draw_frames','draw_x','draw_y','draw_colours','draw_mirror')}
    for _ in range(50000):
        if cpu.pc==0x1ff:return draw
        if cpu.pc==compositor:
            i=mem[0xdc]
            for name,value in [('draw_frames',mem[0x2ae+i]),('draw_x',mem[0x40+2*i]),('draw_y',mem[0x41+2*i]),
                               ('draw_colours',mem[0x29e+i]),('draw_mirror',int(bool(mem[0xde]&mem[0xff78+i])))]:draw[name][i]=value
            cpu.pc=(cpu.stPopWord()+1)&65535
        else:cpu.step()
    raise AssertionError(f'LN3 animation failed to return at {cpu.pc:04x}')

def main():
    vectors=[];included=[];total=0
    for level in range(1,6):
        ram=level_memory(level);s=layout(ram);a=action_layout(ram,s);data=decode(ram,s)
        path=PROJECT/f'datafiles/play/ln3/level{level}/animation.json';write_json(path,data);included.append(path)
        for action in range(61):
            for weapon in range(5):
                mem=list(ram);mem[0xe1]=255;mem[0xde]=102 if (action+weapon)%2 else 0
                mem[0xe6]=255;mem[0xec]=255;mem[0xe4]=0;mem[0x321]=mem[0x322]=weapon;mem[0x2e9]=(weapon+1)%5
                mem[0x320]=0;mem[0x1e]=2;mem[2:6]=[255]*4;mem[0x53]=mem[0x57]=0
                for i in range(8):mem[0x58+i]=0
                call(mem,s['player_action'],a=action if action<39 else 0)
                call(mem,s['enemy_action'],a=action if action>=39 else 39)
                initial=state(mem,a);frames=[]
                length=max(len(data['sequences'][mem[0x50+i]]['frames']) for i in (0,1,2,4,5,6))+3
                assert length<=64,(level,action,length)
                for frame in range(length):
                    draw=animation_call(mem,s);expected=state(mem,a);expected.update(draw);frames.append(expected)
                vectors.append(dict(level=level,action=action,weapon=weapon,initial=initial,frames=frames));total+=length
        print('LN3 level',level,'animation playback recovered',flush=True)
    path=PROJECT/'datafiles/verification/ln3_animation_vectors.json'
    path.write_text(json.dumps(dict(vectors=vectors,scope=__doc__),separators=(',',':'))+'\n');included.append(path)
    resources={}
    for name in ('ln3_animation','ln3_animation_checks'):
        meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
        write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);resources[name]={'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}
    register_project(resources,included);print(total,'original LN3 animation updates')

if __name__=='__main__':main()
