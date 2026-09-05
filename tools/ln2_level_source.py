"""Locate the supplied LN2's relocated level routines for offline recovery."""
import hashlib
import sys
from pathlib import Path
from build_project import ROOT
sys.path.insert(0,str(ROOT/'tools/vendor/pydeps'))
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler

def word(ram,address):return ram[address]+256*ram[address+1]

def level_memory(level):
    name='ln2-game-ram.bin' if level==1 else f'ln2-level{level}-ram.bin'
    return (ROOT/'source/local/captures'/name).read_bytes()

def locate(ram,address,length=24):
    original=level_memory(1);pattern=list(original[address:address+length])
    dis=Disassembler(MPU(memory=list(original)));pc=address;immediates=[];branches=[]
    while pc<address+length:
        size,instruction=dis.instruction_at(pc)
        if '#$' in instruction and pc+1<address+length:immediates.append(pc+1-address)
        if original[pc] in (0x10,0x30,0x50,0x70,0x90,0xb0,0xd0,0xf0) and pc+1<address+length:branches.append(pc+1-address)
        if size==3 and word(original,pc+1)>=0x100:
            for i in (1,2):
                if pc+i<address+length:pattern[pc+i-address]=None
        pc+=size
    candidates=[i for i in range(0x600,0xd000-length) if ram[i]==pattern[0]
                and all(v is None or ram[i+j]==v for j,v in enumerate(pattern))]
    if not candidates:
        # Some pointers are passed as immediate low/high bytes, and level
        # constants also vary. Still require an unambiguous instruction shape.
        for i in immediates:pattern[i]=None
        candidates=[i for i in range(0x600,0xd000-length) if ram[i]==pattern[0]
                    and all(v is None or ram[i+j]==v for j,v in enumerate(pattern))]
    if not candidates:
        for i in branches:pattern[i]=None
        candidates=[i for i in range(0x600,0xd000-length) if ram[i]==pattern[0]
                    and all(v is None or ram[i+j]==v for j,v in enumerate(pattern))]
    if len(candidates)!=1:raise ValueError(f'LN2 ${address:04x} relocated ambiguously: {candidates}')
    return candidates[0]

def layout(ram):
    routines={
        'scene_draw':(0x88e2,24),'scene_choose':(0x95a7,4),'exit':(0x908e,31),
        'entrance':(0x9102,32),'player_update':(0xa2fc,32),'player_input':(0xa3ca,24),
        'player_move':(0xa5df,32),'enemy_move':(0xa628,32),'player_action':(0xa6db,37),
        'enemy_action':(0xa6c6,23),'move':(0xa7de,32),'boundary':(0xb9a7,32),
        'boundary_enter':(0xb847,29),'enemy_enter':(0xb4be,44),'enemy_select':(0xb23c,32),
        'enemy_decide':(0xacb7,41),'action_events':(0xa91b,38),
        'item_enter':(0xc12d,28),'item_interact':(0xbebb,30),
        'actor_draw':(0xbacc,43),'sprite_unpack':(0xbe15,53),
        'actor_player':(0xbab7,21),'actor_enemy':(0xbaac,11),
        'mask':(0x95ec,34),'player_begin':(0xa4d9,32),
        'random':(0xb416,32),'enemy_recover':(0xafc0,46),'enemy_regen':(0xb2cc,28),
    }
    # Level-specific scene-choice code is reached by the same main-loop slot;
    # avoid treating short or modified room-condition prefixes as signatures.
    routines.pop('scene_choose')
    result={name:locate(ram,address,length) for name,(address,length) in routines.items()}
    loop=ram.index(bytes.fromhex('a5 e2 cd 68 02 f0 f9 a5 e2 8d 68 02'),0x600,0xd000)
    result['main_loop']=loop
    entrance=result['entrance'];result['exit_destinations']=word(ram,entrance+1)
    result['exit_thresholds']=word(ram,result['exit']+14)
    result['exit_count']=word(ram,entrance+23)-result['exit_destinations']
    result['entry_x']=word(ram,entrance+23);result['entry_y']=word(ram,entrance+31)
    result['entry_heading']=word(ram,entrance+41)
    render=result['scene_draw'];result['scene_data']=word(ram,render+3)-4
    result['item_table']=word(ram,result['item_enter']+3)
    result['frame_table']=word(ram,result['actor_draw']+9)
    assert ram[result['boundary_enter']+40]==0x9d
    result['boundary_table']=word(ram,result['boundary_enter']+41)
    selections=[i for i in range(0x600,0xd000-9)
                if ram[i:i+4]==bytes.fromhex('20 0e 14 20') and ram[i+6:i+9]==bytes.fromhex('68 85 b0')]
    assert len(selections)==1,selections
    result['scene_choose']=word(ram,selections[0]+4)
    return result

if __name__=='__main__':
    for level in range(1,8):
        ram=level_memory(level);print(level,layout(ram),hashlib.sha256(ram).hexdigest(),flush=True)
