"""Trace original walking/failed-jump river entry before the sinking routine.

Room and entrance coordinates are injected, then the unmodified player routine
receives joystick bits immediately after the original input poll. This is a
scoped extraction fixture, not an unchanged-input or cycle-accuracy replay.
"""
import hashlib,json
from PIL import Image,ImageDraw
from vice_reference import Reference,ROOT
from inspect_ln1_water import screen

def main():
    folder=ROOT/'source/local/captures/river-entry';folder.mkdir(exist_ok=True)
    reports=[];strips=[]
    with Reference() as ref:
        for name,joy in [('walk',6),('failed_jump',20)]:
            snapshot=ROOT/'source/local/captures/ln1-game.vsf'
            ref.load_snapshot(snapshot);ref.until(0xbd26)
            ref.write(0xa2,[11]);ref.write(0x278,[44]);ref.set_registers(PC=0xbcf6);ref.until(0xbd26)
            ram=ref.memory(0,65535);entry=ram[0xff3c+44]
            position=[ram[0xffb8+entry],ram[0xffd8+entry]];heading=ram[0xafe0+entry]
            ref.write(0x54,position);ref.write(0x68,[heading,heading])
            updates=[];pictures=[]
            for index in range(180):
                ram=ref.memory(0,0x2ff)
                bits=6 if index<45 else joy
                updates.append(dict(update=index,joy=bits,x=ram[0x54],y=ram[0x55],frame=ram[0x65],
                    action=ram[0x60]+256*ram[0x61],boundary_crossings=ram[0x2b6]))
                pictures.append(screen(ref).crop((144,50,384,194)))
                ref.write(0xb5,[bits])
                if ref.until_any([0xbd26,0xbef2])==0xbef2:break
            else:raise AssertionError('Original river entry did not reach sinking')
            entry_state=list(ref.memory(0x54,0x65));sinking=[];sink_pictures=[]
            for index in range(30):
                ref.until(0xbeef);ref.until(0xbf06)
                state=dict(y=ref.memory(0x55,0x55)[0],frame=ref.memory(0x65,0x65)[0],cutoff=ref.memory(0x9e,0x9e)[0])
                sinking.append(state);sink_pictures.append(screen(ref).crop((144,50,384,194)))
                if state['y']-21>=state['cutoff']:break
            else:raise AssertionError('Original sinking did not reach full submersion')
            if len({s['frame'] for s in sinking})!=1:raise AssertionError('Original drowning pose changed')
            animation=pictures+sink_pictures
            animation[0].save(ROOT/f'evidence/ln1_river_{name}.gif',save_all=True,append_images=animation[1:],duration=38,loop=0)
            selected=[pictures[40],pictures[70],pictures[-1],sink_pictures[5],sink_pictures[12],sink_pictures[-1]]
            strips.append((name,selected))
            reports.append(dict(case=name,room=11,entrance=44,position=position,heading=heading,
                input_poll_boundary=0xbd26,input_address=0xb5,sinking_entry=0xbef2,
                updates=updates,entry_state_54_to_65=entry_state,sinking=sinking))
            print(name,len(updates),'movement updates;',len(sinking),'descents',flush=True)
    sheet=Image.new('RGB',(1440,348),(24,26,30));draw=ImageDraw.Draw(sheet)
    for row,(name,pictures) in enumerate(strips):
        for col,pic in enumerate(pictures):sheet.paste(pic,(col*240,row*174+30))
        draw.text((8,row*174+8),'Supplied C64 original: '+name.replace('_',' '),fill='white')
    sheet.save(ROOT/'evidence/ln1_river_entry_comparison.png')
    report=dict(scope='Original approach, failed jump and complete sinking from injected river entrance; no native pixel or timing certification',
        snapshot_sha256=hashlib.sha256(snapshot.read_bytes()).hexdigest(),
        observation='Both traced entries retain the player pose during sprite-row masking; no independent splash animation was observed',
        white_animation_frames=dict(logical_frames=[150,151,152],raw_parts=[17,18,19],source_bank=0x9e00,
            composition_addresses=[0xd960,0xd970,0xd980],
            source_uses=[dict(room=6,script=0xae82),dict(room=17,script=0xaeaa)],
            observation='Flapping white bird animation travelling horizontally in the Buddha scenes, not referenced by the traced river death'),
        cases=reports)
    (ROOT/'evidence/ln1_river_entry_reference.json').write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__':main()
