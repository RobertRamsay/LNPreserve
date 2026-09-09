"""Original LN2 projectile spawn/update rules across seven supplied banks.

Melee/interaction, damage, reaction and HUD callees are recorded requests.
The original visibility-buffer probe is supplied as input; raster/composition
and hardware phase are separate from this routine-level state comparison.
"""
import json,random
from ln2_level_source import *
from build_project import PROJECT,read_json,write_json
from export_ln1_levels import register_project

def source(ram):
    return {name:locate(ram,p,n) for name,p,n in [('update',0xb6b0,44),('spawn',0xb5d0,36),
        ('player_spawn',0xb67f,35),('hit',0xb65e,33),('hurt',0xaac0,36),('damage_player',0xb441,29),('damage_enemy',0xb45f,37)]}

def state(mem):
    return dict(tick=mem[0xe2],previous=mem[0x273],weapon=mem[0x70],selected_weapon=mem[0x89],
        selected_item=mem[0x279],ammo=mem[0x3dc],object_flag=mem[0x3eb],
        actor_x=[mem[0x54],mem[0x56]],actor_y=[mem[0x55],mem[0x57]],facing=[mem[0x69],mem[0x6b]],
        combat=[mem[0x6d],mem[0x6f]],enemy_active=mem[0xcb],
        projectiles=[dict(kind=mem[0x280+i],facing=mem[0x282+i],x=mem[0x284+i],y=mem[0x286+i],
            life=mem[0x288+i],buffer=mem[0x295+i],enabled=mem[0x24b+i*4],sprite_y=mem[0x213+i*4],
            probes=[mem[0xcc1+i*256]|mem[0xcc4+i*256]|mem[0xcc7+i*256],mem[0xec1+i*256]|mem[0xec4+i*256]|mem[0xec7+i*256]]) for i in range(2)])

def original(mem,s,operation,actor):
    cpu=MPU(memory=mem,pc=s['spawn' if operation else 'update']);cpu.x=actor*2;cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1];requests=[]
    hooks={s['damage_player']:('damage',0),s['damage_enemy']:('damage',1),s['hurt']:('hurt',-1),
        word(mem,s['spawn']+5):('attack',-1),word(mem,s['spawn']+0x47):('icon',-1)}
    for _ in range(10000):
        if cpu.pc==0x1ff:return requests
        if cpu.pc in hooks:
            kind,target=hooks[cpu.pc]
            requests.append(dict(kind=kind,actor=target if target>=0 else cpu.x//2,value=cpu.a if kind in ('damage','icon') else 0))
            cpu.pc=(cpu.stPopWord()+1)&65535
        else:cpu.step()
    raise AssertionError((operation,hex(cpu.pc)))

def main():
    rng=random.Random(0xb6b0);vectors=[];included=[]
    for level in range(1,8):
        ram=level_memory(level);s=source(ram);u=s['update'];spawn=s['player_spawn']
        spawn_xy=word(ram,spawn+13);motion=word(ram,u+0x8c);offsets=word(ram,u+0x24)
        data=dict(spawn_xy=list(ram[spawn_xy:spawn_xy+9]),motion=list(ram[motion:motion+32]),offsets=list(ram[offsets:offsets+8]))
        assert data['offsets']==[0,0,20,14,16,18,8,8],(level,data)
        for operation in (0,1):
            for i in range(1024):
                mem=list(ram);mem[0xe2]=rng.randrange(256);mem[0x273]=(mem[0xe2]-rng.choice([0,1,1,2,7,16]))&255
                mem[0x54:0x58]=[rng.randrange(256) for _ in range(4)];mem[0x69]=rng.choice([1,3,5,7]);mem[0x6b]=rng.choice([1,3,5,7])
                mem[0x6d]=rng.choice([0,8,12,20,24,36]);mem[0x6f]=rng.choice([1,9,13,21,25,37]);mem[0xcb]=rng.choice([0,128,130])
                mem[0x70]=rng.choice([0,1,2,3,4,4]);mem[0x89]=mem[0x70];mem[0x279]=rng.choice([0,10,10]);mem[0x3dc]=rng.choice([0,128,129,130,137]);mem[0x3eb]=rng.choice([0,255])
                for j in range(2):
                    mem[0x280+j]=rng.choice([0,0,1,6,7,9,14,15]);mem[0x282+j]=rng.choice([1,3,5,7]);mem[0x284+j]=rng.randrange(256);mem[0x286+j]=rng.randrange(256)
                    mem[0x288+j]=rng.choice([0,1,2,7,8,9,30,255]);mem[0x295+j]=rng.choice([0,1,255]);mem[0x24b+j*4]=rng.randrange(256);mem[0x213+j*4]=rng.randrange(256)
                    for p in [0xcc1+j*256,0xcc4+j*256,0xcc7+j*256,0xec1+j*256,0xec4+j*256,0xec7+j*256]:mem[p]=rng.choice([0,0,0,255])
                    if i%4==0:
                        mem[0x284+j]=mem[0x54+(1-j)*2];mem[0x286+j]=mem[0x55+(1-j)*2];mem[0x288+j]=7
                actor=i&1;before=state(mem);requests=original(mem,s,operation,actor)
                vectors.append(dict(level=level,operation=operation,actor=actor,before=before,expected=state(mem),requests=requests))
        path=PROJECT/f'datafiles/play/ln2/level{level}/projectiles.json';write_json(path,data);included.append(path)
        print('LN2 projectile bank',level,flush=True)
    path=PROJECT/'datafiles/verification/ln2_projectile_vectors.json';path.write_text(json.dumps(dict(vectors=vectors,scope=__doc__),separators=(',',':'))+'\n');included.append(path)
    name='ln2_projectiles';meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
    write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);register_project({name:{'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}},included)
    print(len(vectors),'original spawn/update states; external requests and visibility inputs are explicit')

if __name__=='__main__':main()
