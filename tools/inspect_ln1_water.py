"""Observe the supplied game's drowning renderer in VICE; offline only.

Room/position are injected into a supplied-disk snapshot. This is a renderer
fixture, not an input replay or a whole-game accuracy claim.
"""
from pathlib import Path
import hashlib,json,struct
from PIL import Image,ImageDraw
from vice_reference import Reference,ROOT

def screen(ref):
    data=ref.command(0x91,b'\1');palette=[];pos=2
    for _ in range(int.from_bytes(data[:2],'little')):
        length=data[pos];palette.extend(data[pos+1:pos+4]);pos+=length+1
    data=ref.command(0x84,b'\1\0')
    fields,w,h,x,y,iw,ih,bits,length=struct.unpack_from('<I6HBI',data)
    picture=Image.frombytes('P',(w,h),data[fields:fields+length]);picture.putpalette(palette+[0]*(768-len(palette)))
    return picture.convert('RGB')

def main():
    folder=ROOT/'source/local/captures/water';folder.mkdir(exist_ok=True)
    with Reference() as ref:
        ref.load_snapshot(ROOT/'source/local/captures/ln1-game.vsf')
        ref.until(0xbd26)
        ref.write(0xa2,[11]);ref.write(0x278,[44]);ref.set_registers(PC=0xbcf6)
        ref.until(0xbd26)
        ref.write(0x54,[112,120]);ref.write(0x60,[0,0]);ref.write(0x65,[0]);ref.write(0x68,[1,1])
        ref.write(0x70,[0]);ref.write(0xd6,[0]);ref.write(0x2b5,[16,1]);ref.write(0xb5,[0])
        ref.until(0xbef2)
        initial=dict(registers=ref.registers(),y=ref.memory(0x55,0x55)[0],tick=ref.memory(0x1b,0x1b)[0],clock=ref.memory(0x26f,0x26f)[0])
        assert initial['registers']['PC']==0xbef2, 'Reference did not stay paused at hazard entry'
        frames=[];states=[]
        for index in range(80):
            ref.until(0xbeef) # Only reached when the timer has advanced Y.
            ref.until(0xbf06)
            assert ref.registers()['PC']==0xbf06, 'Reference did not stay paused after drawing'
            state=dict(index=index,y=ref.memory(0x55,0x55)[0],tick=ref.memory(0x1b,0x1b)[0],
                cutoff=ref.memory(0x9e,0x9e)[0],frame=ref.memory(0x65,0x65)[0],clock=ref.memory(0x26f,0x26f)[0],
                sprite_registers=list(ref.memory(0xd000,0xd02e,'io')))
            states.append(state)
            pic=screen(ref);pic.save(folder/f'water-{index:02}.png');frames.append(pic)
            print(index,state['y'],state['tick'],flush=True)
            if state['y']-21>=state['cutoff']:break
        (folder/'trace.json').write_text(json.dumps(states,indent=2)+'\n',encoding='utf-8')
        frames[0].save(folder/'original-water.gif',save_all=True,append_images=frames[1:],duration=100,loop=0)
        report=dict(fixture='Injected room 11 river position; original rendering and sinking routine',
            snapshot_sha256=hashlib.sha256((ROOT/'source/local/captures/ln1-game.vsf').read_bytes()).hexdigest(),
            initial=initial,checkpoints=states,paused_checkpoints_verified=True,whole_game_replay=False,
            observation='Player frame remains fixed while original sprite rows are cleared at the waterline; no independent ripple observed')
        (ROOT/'evidence/ln1_river_reference.json').write_text(json.dumps(report,indent=2)+'\n')
        selected=[round(i*(len(states)-1)/4) for i in range(5)]
        sheet=Image.new('RGB',(1200,174),(24,26,30));draw=ImageDraw.Draw(sheet)
        for i,index in enumerate(selected):
            pic=Image.open(folder/f'water-{index:02}.png').crop((144,50,384,194))
            sheet.paste(pic,(i*240,30))
            draw.text((i*240+4,8),f"Original river: Y {states[index]['y']}",fill='white')
        sheet.save(ROOT/'evidence/ln1_original_river.png')

if __name__=='__main__':main()
