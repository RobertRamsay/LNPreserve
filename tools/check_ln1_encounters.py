"""Bounded offline LN1 checks from privately supplied CCS disk banks.

Requires source/local/captures/ln1-common-unpacked.bin from the offline
unpacker. This is not a running C64, GameMaker build or full-game replay.
"""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/vendor/pydeps'))
from py65.devices.mpu6502 import MPU

def bank(level):
    ram = bytearray((ROOT/'source/local/captures/ln1-common-unpacked.bin').read_bytes())
    folder=ROOT/f'source/local/last_ninja_the_side_{"a" if level<5 else "b"}_ccs'
    for block, address in [(2,0xdf00),(3,0xd800),(4,0xcc00),(5,0x9e00),(6,0x600),(7,0xb000)]:
        path,=folder.glob(f'*_{block}{chr(64+level)}.bin')
        payload=path.read_bytes()[2:]
        if block==2:
            ram[0xdf00:0xe000]=payload[:256];ram[0xff40:0xfff8]=payload[256:]
        else:ram[address:address+len(payload)]=payload
    return ram

def call(ram, pc, a=0, x=0, y=0, stop=0x1ff):
    cpu=MPU(memory=ram,pc=pc);cpu.a=a;cpu.x=x;cpu.y=y
    cpu.sp=0xfd;ram[0x1fe]=0xfe;ram[0x1ff]=1
    for _ in range(100000):
        if cpu.pc==stop:return cpu
        if cpu.disassemble[ram[cpu.pc]][0]=='???':raise AssertionError(hex(cpu.pc))
        cpu.step()
    raise AssertionError(f'routine did not return: {cpu.pc:04x}')

def records(ram, entries):
    pending=list(entries);result={}
    while pending:
        address=pending.pop()
        if address<256 or str(address) in result:continue
        cursor=address;flags=ram[cursor];cursor+=1
        duration=ram[cursor] if flags&2 else -1;cursor+=bool(flags&2)
        frame=ram[cursor];cursor+=1;dx=dy=0;state=combat=-1
        if flags&128:dx,dy=ram[cursor:cursor+2];cursor+=2
        if flags&1:
            state=ram[cursor];cursor+=1
            if 16<=state<32:combat=ram[cursor];cursor+=1
        following=ram[cursor]|ram[cursor+1]<<8 if flags&32 else cursor
        result[str(address)]=dict(flags=flags,duration=duration,frame=frame,dx=dx,dy=dy,state=state,combat_data=combat,next=following)
        pending.append(following)
        assert len(result)<512
    return result

def main():
    ram=bank(6)
    gameplay=json.loads((ROOT/'LNPreserve/datafiles/play/ln1/level6/gameplay.json').read_text())
    for address,record in records(ram,[0x4e08,0x4e20]).items():
        assert gameplay['actions'][address]==record,(address,record)
    print('dog missing records:',json.dumps(records(ram,[0x4e08,0x4e20]),sort_keys=True))
    for crossings in [0,1,127,128,129]:
        mem=list(ram);mem[0x2b6]=crossings;mem[0xcb]=134
        mem[0x62]=8;mem[0x63]=0x4e;mem[0x2b5]=13;mem[0x61]=0
        call(mem,0xbdc4)
        assert (mem[0x62]|mem[0x63]<<8)==(0x4e0c if crossings in (1,127) else 0x4e08)
        assert mem[0xd2]==(3 if crossings in (1,127) else 0)
        print('dog boundary',crossings,'action',hex(mem[0x62]|mem[0x63]<<8),'speed',mem[0xd2])
    for elapsed in [0,1,249,250,255]:
        mem=list(ram);mem[0xb0]=mem[0xb1]=0;mem[0x7d]=2
        mem[0x26d]=250;mem[0x1b]=(250+elapsed)&255
        mem[0x251:0x254]=[0,0,0]
        call(mem,0x561f,stop=0x5671)
        expected=2 if elapsed<250 else 0
        assert mem[0x7d]==expected and mem[0x251:0x254]==[expected]*3
        print('dye elapsed',elapsed,'state',mem[0x7d],'colours',mem[0x251:0x254])
    dungeon=bank(4)
    assert (dungeon[0x552a],dungeon[0x5530])==(11,1)
    print('dungeon shared colours',list(dungeon[0x552a:0x552b])+list(dungeon[0x5530:0x5531]))
    world=json.loads((ROOT/'LNPreserve/datafiles/play/ln1/level6/world.json').read_text())
    navigation=json.loads((ROOT/'LNPreserve/datafiles/play/ln1/level6/navigation.json').read_text())
    for room in world['rooms']:
        assert room['exits']==list(ram[0xaf04+room['id']*8:0xaf08+room['id']*8])
    for room in navigation['rooms']:
        if room['id']<12:continue
        for route in room['routes']:
            x,y=route['x'],route['y']
            _,x,y=min([(x-1,0,y),(247-x,247,y),(y-8,x,8),(189-y,x,189)])
            mem=list(ram);mem[0xa2]=room['id'];mem[0x54]=x;mem[0x55]=y
            call(mem,0x7478)
            print('exit',room['id'],route['direction'],'native entry',route['entry'],'source entry',mem[0x278])
            assert mem[0x278]==route['entry']

if __name__=='__main__':main()
