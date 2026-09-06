"""Recover native LN3 room-entry data, climbing records and initial globals.

The level captures stop at each original main loop. Their global inventory was
carried through a loader fixture; new-game health/honour/lives instead come from
the earlier supplied-game loading capture. No emulator is shipped in gameplay.
"""
import hashlib,json
from build_project import ROOT,PROJECT,read_json,write_json
from ln3_level_source import level_memory,layout,word,calls
from make_ln3_action_vectors import action_layout
from make_ln3_combat_vectors import state as combat_state
from export_ln1_levels import register_project
from export_ln1_world import call
from decode_graphics import PALETTE

FIELDS=dict(mask_spill=0x63,multicolour=0x2d4,expand_x=0x2d5,expand_y=0x2d6,
    shared_colour1=0xd025,shared_colour2=0xd026,scene_cursor=0xf1,
    logic_wait=0x146,regeneration_wait=0x14e,scene_wait=0x14b,
    item_wait=0x14d,climb_request=0x30a,water_gate=0x312,
    carrier_state=0x2f8,carrier_left=0x2d0,carrier_right=0x2d1,
    ammo_pile=0x2ff,special_wait=0x151,fall_count=0x304,portrait_visible=0x31b)

def state(mem,a):
    result=combat_state(mem,a);result.update({k:mem[p] for k,p in FIELDS.items()})
    result['lives']=mem[0x1d]
    return result

def enemy_table(ram,s):
    start=s['enemy_enter']
    for p in range(start,start+16):
        if ram[p:p+3]==bytes.fromhex('a6 e3 bd'):
            return word(ram,p+3),word(ram,p+8)
    raise AssertionError('Missing enemy table')

def main():
    included=[]
    startup=(ROOT/'source/local/captures/ln3-loaded-ram.bin').read_bytes()
    assert list(startup[0x1b:0x20])==[13,44,5,0,0]
    for level in range(1,6):
        ram=level_memory(level);s=layout(ram);a=action_layout(ram,s)
        world=read_json(PROJECT/f'datafiles/play/ln3/level{level}/world.json')
        mem=list(ram);mem[2:0x20]=startup[2:0x20];mem[0x1f]=level-1
        initial=state(mem,a)
        # These are the original checkpoint/spawn values, before a gameplay tick.
        initial.update(fire_mode=0,fire_latch=255)
        lo,hi=enemy_table(ram,s);climb=s['interaction']
        clo=word(ram,climb+3);chi=word(ram,climb+8)
        assert ram[climb:climb+3]==bytes.fromhex('a6 e3 bd')
        updates=calls(ram,s['game_update']);hazard=updates[updates.index(s['collision'])+1]
        data=dict(level=level,initial=initial,rooms=[],timer_period_cycles=19656,palette=PALETTE,
            hazard_kneel_actions=list(ram[word(ram,hazard+21):word(ram,hazard+21)+16]),
            initial_enemy_health=list(ram[0x250:0x25e]),
            startup_sha256=hashlib.sha256(startup).hexdigest(),startup_scope=__doc__)
        for room in world['rooms']:
            rid=room['id'];p=ram[lo+rid]+256*ram[hi+rid]
            room['playable']=rid==initial['room_id'] or bool(room['exits']) or any(e['destination']==rid for q in world['rooms'] for e in q['exits'])
            if level==5 and rid==12:
                # Void reaches its final encounter through the reflected-bolt
                # sequence at $69ea, rather than the ordinary room-exit table.
                assert ram[0x69ea:0x69ee]==bytes.fromhex('a9 0c 85 e3')
                assert ram[0x69f6:0x69f8]==bytes.fromhex('a9 68') and ram[0x6a01:0x6a03]==bytes.fromhex('a9 7c')
                room['playable']=True
                room['special_entry']=dict(destination=12,spawn_x=ram[0x69f7],spawn_y=ram[0x6a02],facing=0,action=0)
            enemy=[] if ram[p]==255 else list(ram[p:p+6])
            p=ram[clo+rid]+256*ram[chi+rid];climbs=[]
            while ram[p]!=255:
                climbs.append(list(ram[p:p+12]));p+=12;assert len(climbs)<20
            data['rooms'].append(dict(id=rid,enemy=enemy,climbs=climbs,playable=room['playable']))
        # Tables used by the original exceptional room-entry handlers.
        data['special']={}
        if level==1:
            data['special']=dict(animations=list(ram[0x51b3:0x51b6]),colours=list(ram[0x51b6:0x51b9]),
                y_before=list(ram[0x51b9:0x51bc]),y_after=list(ram[0x51bc:0x51bf]))
        if level==2:
            data['special']=dict(animations=list(ram[0x520a:0x520e]),colours=list(ram[0x520e:0x5212]),
                modes=list(ram[0x5212:0x5214]),x=list(ram[0x5214:0x5216]),y=list(ram[0x5216:0x5218]),
                contact_widths=list(ram[0x5f75:0x5f77]))
        if level==3:
            data['special']=dict(animations=list(ram[0x513c:0x5140]),colours=list(ram[0x5140:0x5144]),
                x=list(ram[0x5144:0x5148]),y=list(ram[0x5148:0x514c]))
        if level==4:data['special']=dict(animations=list(ram[0x51b6:0x51b8]),y=list(ram[0x51b8:0x51ba]))
        assert max(data['hazard_kneel_actions'])<39,data['hazard_kneel_actions']
        path=PROJECT/f'datafiles/play/ln3/level{level}/runtime.json';write_json(path,data);included.append(path)
        write_json(PROJECT/f'datafiles/play/ln3/level{level}/world.json',world)
        print('LN3',level,len(data['rooms']),'rooms',sum(bool(r['enemy']) for r in data['rooms']),'ordinary enemy records',sum(len(r['climbs']) for r in data['rooms']),'climbing records')
    resources={}
    for name in ('ln3_scenes','ln3_play','ln3_scene_checks'):
        meta=read_json(PROJECT/'scripts/ln1_player/ln1_player.yy');meta.update(name=name);meta['%Name']=name
        write_json(PROJECT/f'scripts/{name}/{name}.yy',meta);resources[name]={'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}
    register_project(resources,included)

if __name__=='__main__':main()
