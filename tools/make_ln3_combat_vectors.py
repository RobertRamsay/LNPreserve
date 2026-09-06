"""Compare LN3 melee damage, reactions, honour/score and projectile hit windows.

Score bitmap rendering is intercepted. Level transitions are recorded as
requests; complete boss encounters, IRQ timing and loading are not verified.
"""
import json,random
from build_project import ROOT,PROJECT,read_json,write_json
from ln3_level_source import level_memory,layout,word,calls,MPU
from make_ln3_action_vectors import action_layout
from make_ln3_enemy_vectors import state as enemy_state
from export_ln1_world import call
from export_ln1_levels import register_project

FIELDS=dict(enemy_flash_mode=0x2dd,enemy_flash=0x2db,death_wait=0x150,boss_honour=0x15a,
            honour_fraction=0x32c,level_sequence=0x315,bolt_reflected=0x30b)

def state(mem,a,requested=False):
    result=enemy_state(mem,a);result.update({k:mem[p] for k,p in FIELDS.items()})
    result.update(score_digits=list(mem[0x100:0x106]),level_requested=requested);return result

def combat_layout(ram,s):
    enemy,player=calls(ram,s['combat']);damage_player=word(ram,enemy+40);damage_enemy=word(ram,player+57)
    reaction=word(ram,enemy+34);score=word(ram,damage_enemy+92)
    assert ram[score+37]==0x4c
    return dict(enemy=enemy,player=player,damage_player=damage_player,damage_enemy=damage_enemy,
                reaction=reaction,score=score,score_display=word(ram,score+38),level_transition=word(ram,damage_enemy+68))

def original(mem,entry,addresses):
    cpu=MPU(memory=mem,pc=entry);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1];requested=False
    for _ in range(50000):
        if cpu.pc==0x1ff:return requested
        if cpu.pc in (addresses['score_display'],addresses['level_transition']):
            if cpu.pc==addresses['level_transition']:requested=True
            cpu.pc=(cpu.stPopWord()+1)&65535
        else:cpu.step()
    raise AssertionError(f'LN3 combat did not return at {cpu.pc:04x}')

def main():
    rng=random.Random(0x67c6);vectors=[];included=[]
    for level in range(1,6):
        ram=level_memory(level);s=layout(ram);a=action_layout(ram,s);c=combat_layout(ram,s)
        def table(address,n):return list(ram[address:address+n])
        score_lo=word(ram,c['score']+1);score_hi=word(ram,c['score']+7)
        data=dict(level=level,attack_actions=table(word(ram,c['enemy']+12),8),attack_cursors=table(word(ram,c['enemy']+19),8),
                  reaction_stances=table(word(ram,c['reaction']+3),7),reactions_low=table(word(ram,c['reaction']+8),8),
                  reactions_high=table(word(ram,c['reaction']+16),8),enemy_damage=table(word(ram,c['damage_player']+13),5),
                  player_damage=table(word(ram,c['damage_enemy']+14),5),enemy_kneel_actions=table(word(ram,c['damage_player']+39),9),
                  score_awards=[table(ram[score_lo+i]+256*ram[score_hi+i],6) for i in range(5)],
                  projectile_hazard_exempt=ram[s['projectiles']:s['projectiles']+4]==bytes.fromhex('a5 54 c9 8a'))
        assert data['attack_actions']==list(range(6,14)),data['attack_actions']
        assert max(sum(data['score_awards'],[]))<10,data['score_awards']
        path=PROJECT/f'datafiles/play/ln3/level{level}/combat.json';write_json(path,data);included.append(path)
        for attack in range(8):
            for player_weapon in range(5):
                for enemy_weapon in range(5):
                    for scenario in range(4):
                        mem=list(ram);mem[0xe6]=mem[0xec]=255;mem[0xe4]=0
                        call(mem,s['player_action'],a=data['attack_actions'][attack] if scenario!=3 else rng.randrange(22))
                        enemy_attack=rng.randrange(8)
                        call(mem,s['enemy_action'],a=39+(data['attack_actions'][enemy_attack] if scenario in (0,3) else rng.randrange(22)))
                        mem[0x59]=data['attack_cursors'][attack];mem[0x5d]=data['attack_cursors'][enemy_attack]
                        mem[0xe7]=rng.choice([0,128]);mem[0xed]=rng.choice([0,128]);mem[0xde]=rng.choice([0,6,96,102])
                        mem[0x321]=player_weapon;mem[0x322]=enemy_weapon;mem[0x317]=rng.choice([0]*7+[128]);mem[0x320]=rng.choice([1]*7+[0])
                        mem[0xfc]=mem[0xfb]=0;mem[0x1c]=rng.choice([0,1,8,44]);mem[0x2d9]=rng.choice([0,1,8,44])
                        mem[0x1b]=rng.choice([0,1,25,26,39,40]);mem[0x32c]=rng.randrange(4);mem[0x15a]=rng.choice([0,25,26,40])
                        mem[0xe3]=13 if scenario==2 else 0;mem[0x100:0x106]=[rng.choice([48,49,56,57]) for _ in range(6)]
                        before=state(mem,a);requested=original(mem,s['combat'],c)
                        vectors.append(dict(level=level,operation=0,before=before,expected=state(mem,a,requested)))
        for case in range(400):
            mem=list(ram);mem[0x53]=mem[0x57]=114;mem[0xe1]=rng.choice([6,102,255])
            mem[0xfb]=rng.choice([0,1,255]);mem[0xfc]=rng.choice([0,0,255]);mem[0xe6]=rng.choice([0,6,24,28,29])
            if level==5:
                mem[0xe3]=rng.choice([0,11]);mem[0x30b]=rng.choice([0,1,255]);mem[0x1c]=rng.choice([0,1,44])
            mem[0x54]=rng.choice([116,138]) if level!=5 else 116
            mem[0x42]=mem[0x4a]=120;mem[0x43]=mem[0x4b]=100
            for x,y in ((0x46,0x47),(0x4e,0x4f)):
                mem[x]=120+rng.choice([-25,-24,-23,-1,0,1,23,24,25]);mem[y]=100+rng.choice([-1,0,1,20,21,22])
            before=state(mem,a);original(mem,s['projectiles'],c)
            vectors.append(dict(level=level,operation=1,before=before,expected=state(mem,a)))
        print('LN3 level',level,'original combat and projectile hits recovered',flush=True)
    path=PROJECT/'datafiles/verification/ln3_combat_vectors.json'
    path.write_text(json.dumps(dict(vectors=vectors,scope=__doc__),separators=(',',':'))+'\n');included.append(path)
    resources={}
    for name in ('ln3_combat','ln3_combat_checks'):
        meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
        write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);resources[name]={'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}
    register_project(resources,included);print(len(vectors),'original LN3 combat/projectile states')

if __name__=='__main__':main()
