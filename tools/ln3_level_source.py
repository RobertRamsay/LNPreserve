"""Locate LN3's original per-level routines for offline data/oracle recovery."""
import sys
from pathlib import Path
from build_project import ROOT
sys.path.insert(0,str(ROOT/'tools/vendor/pydeps'))
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler

def word(ram,address):return ram[address]+256*ram[address+1]

def level_memory(level):return (ROOT/f'source/local/captures/ln3-level{level}-ram.bin').read_bytes()

def locate(ram,address,length=32):
    original=level_memory(1);pattern=list(original[address:address+length]);d=Disassembler(MPU(memory=list(original)))
    p=address;immediates=[];branches=[]
    while p<address+length:
        size,ins=d.instruction_at(p)
        if '#$' in ins and p+1<address+length:immediates.append(p+1-address)
        if original[p] in (0x10,0x30,0x50,0x70,0x90,0xb0,0xd0,0xf0) and p+1<address+length:branches.append(p+1-address)
        if size==3 and word(original,p+1)>=0x100:
            for i in (1,2):
                if p+i<address+length:pattern[p+i-address]=None
        p+=size
    for relax in ([],immediates,branches):
        for i in relax:pattern[i]=None
        candidates=[p for p in range(0x4c00,0x9000-length) if ram[p]==pattern[0]
                    and all(v is None or ram[p+i]==v for i,v in enumerate(pattern))]
        if len(candidates)==1:return candidates[0]
    raise ValueError(f'LN3 ${address:04x} relocated ambiguously: {candidates}')

def layout(ram):
    routines=dict(enemy_recover=0x4f61,game_update=0x4f89,
        player_input=0x4fc7,player_action=0x51f6,
        movement_setup=0x5535,move=0x555a,
        enemy_action=0x5e8a,scene_animation=0x5f19,sprite_update=0x600e,
        mask=0x61a3,combat=0x67c6,
        scene_enter=0x6e47,scene_draw=0x71f9)
    result={name:locate(ram,address) for name,address in routines.items()}
    entry=ram.index(bytes.fromhex('78 d8 a2 ff 9a a9 2f 85 00 a9 35 85 01'),0x4c00,0x5000)
    result.update(entry=entry,main_loop=entry+33)
    result['exit']=word(ram,entry+39);result['enemy_enter']=word(ram,entry+20)
    update=calls(ram,result['game_update'])
    motion_index=update.index(result['move']);scene_index=update.index(result['scene_animation']);sprite_index=update.index(result['sprite_update'])
    assert update[0]==result['player_input'] and update[motion_index-1]==result['movement_setup'],update
    for name,index in [('enemy_input',2),('enemy_attack',3),('interaction',motion_index+1),('collision',motion_index+2),('enemy_path',scene_index-1),('projectiles',sprite_index+1)]:
        result[name]=update[index]
    compositor=calls(ram,result['sprite_update'])[-1]
    result['sprite_unpack']=calls(ram,compositor)[0]
    return result

def calls(ram,address):
    d=Disassembler(MPU(memory=list(ram)));p=address;result=[]
    while p<address+512:
        if ram[p]==0x60:return result
        size,_=d.instruction_at(p)
        if ram[p]==0x20:result.append(word(ram,p+1))
        p+=size
    raise ValueError(f'LN3 routine ${address:04x} has no bounded return')

if __name__=='__main__':
    for level in range(1,6):print(level,{k:hex(v) for k,v in layout(level_memory(level)).items()})
