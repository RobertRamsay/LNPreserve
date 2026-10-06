"""Export LN3 actor pieces for piece-based sprite editing.

LN3 stores each original 24x21 actor sprite as several masks in spr_ln3_actor_parts:
the hi-res reading, three multicolour masks, and mirrored copies made by reversing the
data bits. Different levels sometimes number a sprite and its mirror the other way
round. This groups every stored frame by the piece it comes from, records how it is
derived (role and flip), and keeps only frames that the piece data reproduces pixel
for pixel. Writes LNPreserve/datafiles/actors/ln3/pieces.json.
"""
import collections,glob,json,re
import numpy as np
from PIL import Image
from build_project import ROOT

SPRITE=ROOT/'LNPreserve/sprites/spr_ln3_actor_parts'

def main():
    text=(SPRITE/'spr_ln3_actor_parts.yy').read_text(encoding='utf-8-sig')
    names=re.findall(r'\{"\$GMSpriteFrame":"[^"]*","%Name":"([0-9a-f-]{36})"',text)
    masks=[np.array(Image.open(SPRITE/f'{n}.png').convert('RGBA'))[...,3]>0 for n in names]
    claims=collections.defaultdict(set)  # frame -> {(role, mirrored, base)}
    for path in sorted(glob.glob(str(ROOT/'LNPreserve/datafiles/play/ln3/level*/world.json'))):
        for un,mi in json.loads(open(path,encoding='utf-8').read())['part_mapping'].values():
            for mirrored,choice in ((0,un),(1,mi)):
                claims[choice['hires']].add(('h',mirrored,un['hires']))
                for j,frame in enumerate(choice['multicolour']):claims[frame].add((j,mirrored,un['hires']))
    # Orientation of each base relative to its group's canonical base, via shared frames.
    parent={};orient={}
    def find(b):
        while parent[b]!=b:b=parent[b]
        return b
    bases={b for c in claims.values() for _,_,b in c}
    for b in bases:parent[b]=b
    links=collections.defaultdict(list)
    for c in claims.values():
        c=sorted(c,key=str)
        for (r1,m1,b1),(r2,m2,b2) in zip(c,c[1:]):links[b1].append((b2,m1^m2));links[b2].append((b1,m1^m2))
    groups=[];seen=set()
    for start in sorted(bases):
        if start in seen:continue
        members={start:0};queue=[start]
        while queue:
            b=queue.pop()
            for o,f in links[b]:
                if o not in members:members[o]=members[b]^f;queue.append(o)
        seen.update(members);groups.append(members)
    def decode(bits,role,flip):
        if flip:bits=bits[:,::-1]
        if role=='h':return bits
        pairs=bits[:,0::2].astype(int)*2+bits[:,1::2].astype(int)
        return np.repeat(pairs==role+1,2,axis=1)
    pieces=[];frames={};stats=collections.Counter()
    for members in groups:
        canonical=min(b for b,o in members.items() if o==0);bits=masks[canonical];index=len(pieces);count=0
        for frame,c in claims.items():
            mine=[(r,m^members[b]) for r,m,b in c if b in members]
            if not mine:continue
            if len({x for x in mine})>1 or any(b not in members for _,_,b in c):stats['ambiguous frame']+=1;continue
            role,flip=mine[0]
            if not np.array_equal(decode(bits,role,flip),masks[frame]):stats['not exact']+=1;continue
            frames[str(frame)]=[index,-1 if role=='h' else role,flip];count+=1
        pieces.append(dict(base=canonical,frames=count));stats['exact frames']+=count
    out=dict(schema=1,note='LN3 actor pieces. pieces[i].base is the spr_ln3_actor_parts frame holding piece i unmirrored (hi-res). frames: frame -> [piece, role, flip]; role -1 is the hi-res mask, 0..2 the multicolour masks for codes 1..3; flip reverses the data bits first (the original mirroring).',
             pieces=pieces,frames=frames)
    path=ROOT/'LNPreserve/datafiles/actors/ln3/pieces.json';path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(out,separators=(',',':')),encoding='utf-8')
    print(dict(stats),'pieces',len(pieces),'frames',len(frames),'of',len(masks),'bytes',path.stat().st_size)

if __name__=='__main__':main()
