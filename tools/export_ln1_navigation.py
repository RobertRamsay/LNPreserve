"""Recover directional debug exits and check them against original $7478.

Direction comes from the facing at the reciprocal entrance in the current room.
Unused padded exit entries are not treated as doors. Each chosen boundary point
then executes the original exit routine to check destination, spawn and facing.
"""
import hashlib,json
from export_ln1_world import ROOT,call

def main():
    ram=(ROOT/'source/local/captures/ln1-game-ram.bin').read_bytes()
    world=json.loads((ROOT/'LNPreserve/datafiles/play/ln1/world.json').read_text())
    def active(room):
        count=next((i+1 for i,v in enumerate(room['exit_thresholds']) if v==255),4)
        return room['exits'][:count]
    def original(room,x,y):
        mem=list(ram);mem[0xa2]=room;mem[0x54]=x;mem[0x55]=y;call(mem,0x7478)
        return dict(entry=mem[0x278],room=mem[0xa2],x=mem[0x54],y=mem[0x55],
            facing=mem[0x69],heading=mem[0x68],frame=mem[0x65],turn_lock=mem[0x2b8])
    rooms=[];vectors=[]
    for room in world['rooms']:
        entries=[-1]*4;spawn_entry=None
        for entry in active(room):
            dest=entry>>2
            if dest==0:continue
            for back in active(world['rooms'][dest-1]):
                if back>>2!=room['id']:continue
                index=world['entry_index'][back]
                x=world['entry_x'][index];y=world['entry_y'][index]
                direction=((world['entry_heading'][index]+4)&7)//2
                edge=min([(x-1,0,y),(247-x,247,y),(y-8,x,8),(189-y,x,189)])
                expected=original(room['id'],edge[1],edge[2])
                if expected['entry']!=entry:raise AssertionError('Reciprocal entrance does not select the same original exit')
                if entries[direction] not in (-1,entry):raise AssertionError('Ambiguous directional exit')
                if entries[direction]==entry:continue
                entries[direction]=entry
                if spawn_entry is None:spawn_entry=back
                vectors.append(dict(room=room['id'],direction=direction,source_entrance=back,
                    boundary_point=list(edge[1:]),expected=expected))
        for direction,(x,y) in enumerate([(247,60),(247,152),(0,133),(0,56)]):
            expected=original(room['id'],x,y)
            if entries[direction]<0 and expected['room']==0:
                entries[direction]=0
                vectors.append(dict(room=room['id'],direction=direction,boundary_point=[x,y],expected=expected))
        if spawn_entry is None:raise AssertionError('No recovered scene entrance')
        rooms.append(dict(id=room['id'],entries=entries,spawn_entry=spawn_entry))
    meta=dict(schema=1,directions=['NE','SE','SW','NW'],rooms=rooms,
        source_ram_sha256=hashlib.sha256(ram).hexdigest(),
        scope='Directional test navigation only; entry tables checked with original exit routine, not gameplay timing')
    (ROOT/'LNPreserve/datafiles/play/ln1/navigation.json').write_text(json.dumps(meta,indent=2)+'\n')
    (ROOT/'LNPreserve/datafiles/verification/ln1_navigation_vectors.json').write_text(json.dumps(dict(
        source_ram_sha256=meta['source_ram_sha256'],routine=0x7478,vectors=vectors),indent=2)+'\n')
    print(len(rooms),'rooms;',len(vectors),'original-code exit checks')

if __name__=='__main__':main()
