"""Original LN2 entrance effects: actors, attachment modes and inventory gates."""
import json,sys
from build_project import ROOT,PROJECT,read_json,write_json
from ln2_level_source import level_memory,layout,word
from export_ln1_world import call
from make_ln2_player_vectors import state as player_state
from make_ln2_enemy_vectors import state as enemy_state
from export_ln1_levels import register_project

FLAGS={1:[17,19],2:[17,19],3:[20],4:[18],5:[17,20,21],6:[19,21],7:[16,17,18]}

def main():
    vectors=[]
    for level in range(1,8):
        r=level_memory(level);s=layout(r);folder=ROOT/f'source/local/recovered/ln2/level{level}'
        d=read_json(folder/'gameplay.json');w=read_json(folder/'world.json');rooms={room['id']:room for room in w['rooms']}
        for entry,room in enumerate(w['tables']['exit_destinations']):
            if room==255 or room not in rooms:continue
            for bits in range(1<<len(FLAGS[level])):
                mem=list(r);mem[s['actor_draw']]=0x60;mem[s['mask']]=0x60
                call(mem,s['entrance'],x=entry);call(mem,s['boundary_enter']);call(mem,s['enemy_enter'])
                mem[0xef]=mem[0xf8]=mem[0xb1]=mem[0x234]=0
                for i,flag in enumerate(FLAGS[level]):mem[0x3d8+flag]=255 if bits&(1<<i) else 0
                before=dict(player=player_state(mem),enemy=enemy_state(mem,d))
                inventory=mem[0x3d8:0x3f2]
                call(mem,word(r,s['main_loop']-12))
                bounds=[];p=s['boundary_table']
                while mem[p+1]:bounds.append(mem[p:p+6]);p+=6
                vectors.append(dict(level=level,entry=entry,room=room,inventory=inventory,before=before,
                    boundaries=rooms[room]['boundaries'],expected=dict(player=player_state(mem),enemy=enemy_state(mem,d),
                        boundaries=bounds,special_mode=mem[0xf8],special_flag=mem[0xb1],exit_locked=mem[0x234]!=0,
                        vehicle=mem[0x293],vehicle_limit=mem[0x294])))
        print('LN2 entrance bank',level,'recovered',flush=True)
    path=PROJECT/'datafiles/verification/ln2_entry_vectors.json';path.write_text(json.dumps(dict(vectors=vectors),separators=(',',':'))+'\n')
    name='ln2_entry_checks';meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
    write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);register_project({name:{'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}},[path])
    print(len(vectors),'original entrance-effect comparisons')

if __name__=='__main__':main()
