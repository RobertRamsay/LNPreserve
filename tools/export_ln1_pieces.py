"""Export LN1 character pieces and per-frame recipes for piece-based sprite editing.

The original builds every pose from 24x21 hi-res hardware sprites (three body
pieces plus one weapon piece) and mirrors them in code. This writes those pieces
and, for every current character frame that the recipe rebuilds pixel for pixel,
the recipe itself. Frames that do not rebuild exactly are left out, so they stay
whole-frame editable. Writes LNPreserve/datafiles/actors/ln1/pieces.json.
"""
from pathlib import Path
import argparse,collections,hashlib,json
from PIL import Image
import audit_ln1_parts as a

def recipe(ram,frame,mirror,weapon,enemy,recolour=None):
    """Slots back to front: [piece_key, x, y, flip, expand_x, expand_y, colour] in 96x96 frame pixels."""
    base=0xd000+frame*32;width=ram[base+3]*2;out=[]
    for offset in reversed(a.slots(frame,weapon,enemy)):
        part,xb,yb,flags=ram[base+offset:base+offset+4]
        if part==255:continue
        if flags&128:return None  # LN1 characters are hi-res; multicolour pieces are not exported
        colour=flags&15
        if recolour is not None and colour==8:colour=recolour
        ex,ey=(2 if flags&64 else 1),(2 if flags&32 else 1)
        dx=(xb&127)-48
        if mirror:dx=width-dx-(24 if flags&64 else 0)
        dy=yb if yb<128 else yb-256
        out.append([f'{part}:{int(bool(xb&128))}',48+dx-24,64+dy-50,mirror,ex,ey,colour])
    return out

def render(ram,slots):
    canvas=Image.new('RGBA',(96,96))
    for key,x,y,flip,ex,ey,colour in slots:
        part,stored=map(int,key.split(':'))
        img=a.sprite_image(a.part_raw(ram,part,128 if stored else 0),False,colour)
        if ex>1 or ey>1:img=img.resize((24*ex,21*ey),Image.Resampling.NEAREST)
        if flip:img=img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        canvas.alpha_composite(img,(x,y))
    return canvas

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ram',type=Path,required=True,help='LN1 in-game RAM capture with the $d000 pose tables')
    args=parser.parse_args();ram=args.ram.read_bytes();assert len(ram)==65536
    chars=json.loads((a.ROOT/'LNPreserve/datafiles/graphics/characters.json').read_text(encoding='utf-8'))
    world=json.loads((a.ROOT/'LNPreserve/datafiles/play/ln1/world.json').read_text(encoding='utf-8'))
    candidates=[]
    for enemy in (False,True):
        for weapon in range(4):
            poses=chars['banks'][f"spr_ln1_{'enemy' if enemy else 'player'}_weapon_{weapon}"]['poses']
            for mirror in (0,1):
                for frame in range(56):
                    p=chars['poses'][poses[frame+64*mirror]]
                    candidates.append((p['sprite'],p['frame'],recipe(ram,frame,mirror,weapon,enemy)))
    bank,frames=world['enemy_colour_bank'],world['enemy_colour_frames']
    for trait in range(8):
        colour=ram[0x6ff1+trait]&15 if trait else 8
        for weapon in range(4):
            for mirror in (0,1):
                for frame in range(56):
                    candidates.append((bank,frames[(trait*4+weapon)*128+mirror*64+frame],recipe(ram,frame,mirror,weapon,True,colour)))
    targets={};stats=collections.Counter();pieces=set()
    for sprite,frame,slots in candidates:
        key=f'{sprite}:{frame}'
        if key in targets or slots is None or not slots:stats['skipped']+=1;continue
        ok,_=a.same(render(ram,slots),a.frame_image(sprite,frame))
        if not ok:stats['not exact']+=1;continue
        targets[key]=slots;stats['exact']+=1
        pieces.update(s[0] for s in slots)
    order=sorted(pieces,key=lambda k:tuple(map(int,k.split(':'))));index={k:i for i,k in enumerate(order)}
    piece_data=[]
    for key in order:
        part,stored=map(int,key.split(':'));raw=a.part_raw(ram,part,128 if stored else 0)
        piece_data.append(dict(source=key,bits=raw.hex()))
    out=dict(schema=1,note='LN1 hi-res character pieces (24x21, 63 bytes as hex) and frame recipes. Slot: [piece, x, y, flip, expand_x, expand_y, colour], back to front, in 96x96 frame pixels (origin 48,64).',
             source_sha256=hashlib.sha256(ram).hexdigest(),pieces=piece_data,
             targets={k:[[index[s[0]]]+s[1:] for s in v] for k,v in targets.items()})
    path=a.ROOT/'LNPreserve/datafiles/actors/ln1/pieces.json';path.write_text(json.dumps(out,separators=(',',':')),encoding='utf-8')
    uses=collections.Counter(s[0] for v in out['targets'].values() for s in v)
    per_sprite=collections.Counter(k.rsplit(':',1)[0] for k in targets)
    print(dict(stats),'pieces',len(order),'targets',len(targets),dict(per_sprite),'max frames per piece',max(uses.values()),'bytes',path.stat().st_size)

if __name__=='__main__':main()
