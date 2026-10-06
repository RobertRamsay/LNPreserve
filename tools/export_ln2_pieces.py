"""Export LN2 character pieces and per-frame recipes for piece-based sprite editing.

LN2 builds each actor pose from four multicolour hardware sprites (three body pieces
and a weapon piece) placed by its original compositor; mirrored poses use mirrored
copies of the same pieces. This runs that compositor offline for every player and
enemy bank of all seven levels, keeps each piece once (by its 63 data bytes, with
mirrored copies folded onto their originals), and writes a recipe for every current
character frame it rebuilds pixel for pixel. Run with py65 on PYTHONPATH (for example
build/check-deps). Writes LNPreserve/datafiles/actors/ln2/pieces.json.
"""
import collections,hashlib,json
from PIL import Image
from build_project import ROOT,read_json
from ln2_level_source import level_memory,layout,word
from export_ln1_world import call
import audit_ln1_parts as audit

def flip_mc(raw):
    """Horizontal flip of multicolour sprite data: 12 two-bit pixels per row."""
    out=bytearray(63)
    for y in range(21):
        bits=(raw[y*3]<<16)|(raw[y*3+1]<<8)|raw[y*3+2];r=0
        for i in range(12):r|=((bits>>(i*2))&3)<<((11-i)*2)
        out[y*3:y*3+3]=bytes([(r>>16)&255,(r>>8)&255,r&255])
    return bytes(out)

def slots(ram,s,frame,mirror,weapon,costume,enemy):
    """Run the original compositor; back-to-front list of (data, x, y, colour, multicolour)."""
    mem=list(ram);mem[0x200:0x250]=[0]*80;mem[0x9e]=255
    mem[0x54:0x58]=[120,120,120,120];mem[0x70]=weapon;mem[0x72]=weapon
    mem[0x7d]=costume;mem[0x7f]=costume;mem[0x280:0x282]=[0,0]
    call(mem,s['actor_enemy' if enemy else 'actor_player'],a=255 if mirror else 0,x=4 if enemy else 0,y=frame)
    out=[]
    for i in reversed(list(range(4,8) if enemy else range(4))):
        y=mem[0x210+i]
        if not y:continue
        pointer=word(bytes([mem[0x169d+i],mem[0x16a5+i]]),0)
        if mem[0x218+i]&1:pointer+=512
        out.append((bytes(mem[pointer:pointer+63]),48+mem[0x200+i]+256*mem[0x208+i]-120-24,64+y-120-50,
                    mem[0x220+i]&15,bool(mem[0x238+i])))
    return out

def render(slots_,shared):
    canvas=Image.new('RGBA',(96,96))
    for raw,x,y,colour,mc in slots_:
        canvas.alpha_composite(audit.sprite_image(raw,mc,colour,shared),(x,y))
    return canvas

def main():
    chars=read_json(ROOT/'LNPreserve/datafiles/graphics/characters.json')
    pieces={};order=[];targets={};stats=collections.Counter()
    def piece(raw,mc):
        """Index of the piece and whether this use is its mirror image."""
        if raw in pieces:return pieces[raw],0
        mirrored=flip_mc(raw) if mc else bytes(int(f'{b:08b}'[::-1],2) for b in raw)
        if not mc:mirrored=b''.join(bytes([mirrored[y*3+2],mirrored[y*3+1],mirrored[y*3]]) for y in range(21))
        if mirrored in pieces:return pieces[mirrored],1
        pieces[raw]=len(order);order.append((raw,mc));return pieces[raw],0
    for level in range(1,8):
        ram=level_memory(level);s=layout(ram)
        w=read_json(ROOT/f'LNPreserve/datafiles/play/ln2/level{level}/world.json');shared=tuple(w['shared_sprite_colours'])
        banks=[(name,False,weapon,0) for weapon,name in enumerate(w['player_banks'])]
        banks+=[(name,True,*map(int,key.split('_'))) for key,name in w['enemy_banks'].items()]
        for name,enemy,weapon,costume in banks:
            if name not in chars['banks']:stats['bank not mapped']+=1;continue
            poses=chars['banks'][name]['poses']
            for mirror in (0,1):
                for frame in range(64):
                    target=chars['poses'][poses[frame+64*mirror]];key=f"{target['sprite']}:{target['frame']}"
                    if key in targets:stats['shared frame']+=1;continue
                    used=slots(ram,s,frame,mirror,weapon,costume,enemy)
                    if not used:stats['empty']+=1;continue
                    ok,_=audit.same(render(used,shared),audit.frame_image(target['sprite'],target['frame']))
                    if not ok:stats['not exact']+=1;continue
                    recipe=[]
                    for raw,x,y,colour,mc in used:
                        index,flip=piece(raw,mc);recipe.append([index,x,y,flip,colour,int(mc)])
                    assert not any(sl[5] for sl in recipe),'LN2 character pieces are expected to be hi-res'
                    targets[key]=[[sl[0],sl[1],sl[2],sl[3],1,1,sl[4]] for sl in recipe];stats['exact']+=1;stats['mirrored uses']+=sum(sl[3] for sl in recipe)
        print('level',level,dict(stats),'pieces',len(order),flush=True)
    data=[]
    for raw,mc in order:data.append(dict(bits=raw.hex()))
    out=dict(schema=1,note='LN2 hi-res character pieces (24x21, 63 bytes as hex) and frame recipes, in the LN1 format. Slot: [piece, x, y, flip, expand_x, expand_y, colour], back to front, in 96x96 frame pixels (origin 48,64).',
             pieces=data,targets=targets)
    path=ROOT/'LNPreserve/datafiles/actors/ln2/pieces.json';path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(out,separators=(',',':')),encoding='utf-8')
    uses=collections.Counter(sl[0] for t in targets.values() for sl in t)
    print(dict(stats),'pieces',len(order),'multicolour',sum(1 for _,mc in order if mc),'targets',len(targets),
          dict(collections.Counter(k.rsplit(':',1)[0] for k in targets)),'max frames per piece',max(uses.values()),'bytes',path.stat().st_size)

if __name__=='__main__':main()
