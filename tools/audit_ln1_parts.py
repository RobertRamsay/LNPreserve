"""Audit LN1 actor poses against their original hardware-sprite parts.

Read-only. Rebuilds every player/enemy pose from the original part records
(the same rules as export_ln1_play.composition) and compares the result with
the frames the game draws today (graphics/characters.json). Also counts how
many distinct parts the poses really use. Writes evidence/ln1_part_audit.json.
"""
from pathlib import Path
import argparse,collections,json,re
from PIL import Image
from decode_graphics import PALETTE

ROOT=Path(__file__).resolve().parents[1]
SPRITES=ROOT/'LNPreserve/sprites'

def unpack(data,pointer):
    result=[];cursor=pointer
    while len(result)<63:
        value=data[cursor];cursor+=1
        if value==0xa0:result.append(data[cursor]);cursor+=1
        elif 0xa0<value<0xb0:result.extend([0]*(value&15))
        else:result.append(value)
    return bytes(result[:63])

def part_raw(ram,part,xb):
    if xb&128:return bytes(ram[0x9e00+part*64:0x9e00+part*64+63])
    return unpack(ram,ram[0x8000+part]+256*ram[0x80c0+part])

def sprite_image(raw,multicolour,colour,shared=(7,8)):
    image=Image.new('RGBA',(24,21))
    for y in range(21):
        for x in range(24):
            value=raw[y*3+x//8]
            code=(value>>(6-2*((x%8)//2)))&3 if multicolour else (value>>(7-x%8))&1
            index=[0,shared[0],colour,shared[1]][code] if multicolour else colour
            image.putpixel((x,y),(*PALETTE[index],255 if code else 0))
    return image

def slots(frame,weapon,enemy):
    return [16 if enemy else 4,8,12]+([16+weapon*4] if weapon else [])

def compose(ram,frame,mirror,weapon,enemy):
    """Returns the 96x96 pose and the parts used, back to front."""
    canvas=Image.new('RGBA',(96,96));used=[]
    base=0xd000+frame*32;width=ram[base+3]*2
    for offset in reversed(slots(frame,weapon,enemy)):
        part,xb,yb,flags=ram[base+offset:base+offset+4]
        if part==255:continue
        img=sprite_image(part_raw(ram,part,xb),bool(flags&128),flags&15)
        if flags&96:img=img.resize((24*(2 if flags&64 else 1),21*(2 if flags&32 else 1)),Image.Resampling.NEAREST)
        dx=(xb&127)-48
        if mirror:
            dx=width-dx-(24 if flags&64 else 0)
            img=img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        dy=yb if yb<128 else yb-256
        canvas.alpha_composite(img,(48+dx-24,64+dy-50))
        used.append(dict(slot=offset,part=part,stored=bool(xb&128),dx=(xb&127)-48,dy=dy,
                         multicolour=bool(flags&128),colour=flags&15,expand_x=bool(flags&64),expand_y=bool(flags&32)))
    return canvas,used

_frames={}
def frame_image(sprite,index):
    if sprite not in _frames:
        text=(SPRITES/sprite/f'{sprite}.yy').read_text(encoding='utf-8-sig')
        _frames[sprite]=re.findall(r'\{"\$GMSpriteFrame":"[^"]*","%Name":"([0-9a-f-]{36})"',text)
    return Image.open(SPRITES/sprite/f'{_frames[sprite][index]}.png').convert('RGBA')

def same(a,b):
    if a.size!=b.size:return False,-1
    pa,pb=a.load(),b.load();bad=0
    for y in range(a.size[1]):
        for x in range(a.size[0]):
            va,vb=pa[x,y],pb[x,y]
            if (va[3]>0)!=(vb[3]>0) or (va[3]>0 and va[:3]!=vb[:3]):bad+=1
    return bad==0,bad

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ram',type=Path,required=True,help='LN1 in-game RAM capture (64 KB)')
    args=parser.parse_args()
    ram=args.ram.read_bytes();assert len(ram)==65536
    chars=json.loads((ROOT/'LNPreserve/datafiles/graphics/characters.json').read_text(encoding='utf-8'))
    report=dict(schema=1,ram=str(args.ram),poses={},parts={},mismatches=[])
    body=collections.defaultdict(set);weapon_parts=collections.defaultdict(set);frames_now=collections.defaultdict(set)
    for enemy in (False,True):
        who='enemy' if enemy else 'player'
        for weapon in range(4):
            bank=f'spr_ln1_{who}_weapon_{weapon}';poses=chars['banks'][bank]['poses']
            match=total=0
            for mirror in (0,1):
                for frame in range(56):
                    pose=chars['poses'][poses[frame+64*mirror]]
                    built,used=compose(ram,frame,mirror,weapon,enemy)
                    ok,bad=same(built,frame_image(pose['sprite'],pose['frame']))
                    total+=1;match+=ok
                    if not ok:report['mismatches'].append(dict(bank=bank,frame=frame,mirror=mirror,pixels=bad))
                    frames_now[who].add((pose['sprite'],pose['frame']))
                    for u in used:
                        key=(u['part'],u['stored'])
                        (weapon_parts[who] if u['slot']>=20 or (not enemy and u['slot']==16) else body[who]).add(key)
            report['poses'][bank]=dict(compared=total,identical=match)
    for who in ('player','enemy'):
        report['parts'][who]=dict(body_parts=len(body[who]),weapon_parts=len(weapon_parts[who]),
                                  frames_drawn_today=len(frames_now[who]))
    out=ROOT/'evidence/ln1_part_audit.json';out.write_text(json.dumps(report,indent=1)+'\n',encoding='utf-8')
    for bank,r in report['poses'].items():print(f"{bank}: {r['identical']}/{r['compared']} identical")
    for who,r in report['parts'].items():print(who,r)
    print('mismatches',len(report['mismatches']),report['mismatches'][:5])

if __name__=='__main__':main()
