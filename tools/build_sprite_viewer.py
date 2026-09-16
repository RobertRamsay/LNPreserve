"""Build a read-only viewer catalog from preserved poses and original animation traces.

No sprite pixels or gameplay data are changed. Regenerate after actor exports.
"""
from pathlib import Path
import json,re,sys
from functools import cache
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
if not (ROOT/'LNPreserve').exists(): ROOT=Path('D:/POLYTRICITY/LNPreserve')
P=ROOT/'LNPreserve'; D=P/'datafiles'
@cache
def read(p): return json.loads(re.sub(r',\s*([}\]])',r'\1',Path(p).read_text(encoding='utf-8-sig')))
chars=read(D/'graphics/characters.json');entries=[]
def pose(bank,frame,kind=''):
    profile=chars['types'].get(kind,{})
    if bank in profile.get('overrides',{}):
        x=profile['overrides'][bank];return x['sprite'],x['frames'][frame]
    if bank in chars['banks']:
        x=chars['poses'][chars['banks'][bank]['poses'][frame]];return x['sprite'],x['frame']
    return bank,frame
def part(bank,frame,x=0,y=0,colour=16777215):return [bank,frame,x,y,colour]
def clip(name,frames):return dict(name=name,frames=frames)
def raw(game,name,bank,indices=None):
    p=P/'sprites'/bank/(bank+'.yy')
    if not p.exists():return
    count=len(read(p)['frames']);ids=list(range(count)) if indices is None else list(indices)
    entries.append(dict(game=game,category=2,name=name,clips=[clip(name,[dict(seconds=.1,parts=[part(bank,i)]) for i in ids if i<count])]))
def chain(data,start):
    seen=set();frames=[];duration=4
    while str(start) in data['actions'] and start not in seen:
        seen.add(start);r=data['actions'][str(start)]
        if r['duration']>=0:duration=r['duration']
        frames.append((r,max(1,duration)));start=r['next']
    return frames
for game,levels in [(1,6),(2,7)]:
    for level in range(1,levels+1):
        folder=D/'play'/f'ln{game}'/('' if game==1 and level==1 else f'level{level}')
        data=read(folder/'gameplay.json');world=read(folder/'world.json')
        costumes=[None]+(list(range(4)) if game==1 else sorted({int(k.split('_')[1]) for k in world['enemy_banks']}))
        def mapped(frame,weapon,costume,mirror=False):
            if frame==255:return None
            if game==1:
                if frame<64:
                    if costume is not None:
                        bank=world['enemy_colour_bank'];frame=world['enemy_colour_frames'][(costume*4+min(weapon,3))*128+int(mirror)*64+frame]
                    else:bank=f'spr_ln1_player_weapon_{min(weapon,3)}';frame+=int(mirror)*64
                else:
                    r=world.get('actor_frames',{}).get(str(frame))
                    if not r:return None
                    bank=r['sprite'];frame=r['index']+int(mirror)*r['mirror_offset']
                return part(*pose(bank,frame,'ln1_ninja' if costume is None else 'ln1_guards'))
            extra=frame>=64;key=f'{weapon}_{costume}'
            ids=world.get('enemy_extra_frames',{}).get(key,world['actor_frames']) if costume is not None else world['actor_frames']
            if extra:
                if frame not in ids:return None
                frame=ids.index(frame)
            if costume is None:bank=world['player_extra_banks' if extra else 'player_banks'][weapon]
            else:
                bank=world['enemy_extra_banks' if extra else 'enemy_banks'].get(key)
                if not bank:return None
            frame+=int(mirror)*(len(ids) if extra else 64)
            return part(*pose(bank,frame,'ln2_ninja' if costume is None else f'ln2_enemy_type_{costume}'))
        change=data['action_entries'][4 if game==1 else 2]
        actions=list(dict.fromkeys(data['action_entries']))
        # Include reactions/death/entry animations with ordinary body poses.
        targets={r['next'] for r in data['actions'].values()}
        roots=[int(k) for k in data['actions'] if int(k) not in targets]
        for start in roots:
            seq=chain(data,start)
            if seq and all(r['frame']<64 for r,d in seq) and start not in actions:actions.append(start)
        for costume in costumes:
            clips=[]
            weapons=range(4) if game==1 or costume is None else sorted({int(k.split('_')[0]) for k in world['enemy_banks'] if int(k.split('_')[1])==costume})
            def sequence(start,w,label,old=None,new=None):
                frames=[];current=w
                for r,dur in chain(data,start):
                    if old is not None and r['state']==1:current=new
                    p=mapped(r['frame'],current,costume,bool(r['flags']&64))
                    if p:frames.append(dict(seconds=dur*data['timer_period_cycles']/985248,parts=[p]))
                if frames:clips.append(clip(label,frames))
            for w in weapons:
                if w:sequence(change,0,f'Draw weapon {w}',0,w)
                for side in range(2):
                    frames=[dict(seconds=.1,parts=[mapped(i,w,costume)]) for i in range(side*8,side*8+8)]
                    if all(f['parts'][0] for f in frames):clips.append(clip(f'Weapon {w} / Walk {side+1}',frames*2))
                for n,start in enumerate(actions):
                    if start in data['action_entries'][(4 if game==1 else 2):(6 if game==1 else 4)]:continue
                    sequence(start,w,f'Weapon {w} / Action {n+1}')
                if w:sequence(change,w,f'Put away weapon {w}',w,0)
            if clips:entries.append(dict(game=game,category=0 if costume is None else 1,name=f'Level {level} / '+('Ninja' if costume is None else f'Enemy {costume}'),clips=clips))
        if game==1:
            # Source-linked special actor chains: birds, dragons, smoke, dog, spider, etc.
            used=set()
            for start in roots:
                seq=chain(data,start)
                if not seq or not any(r['frame']>=64 and r['frame']!=255 for r,d in seq):continue
                frames=[]
                for r,dur in seq:
                    p=mapped(r['frame'],0,None)
                    if p:frames.append(dict(seconds=dur*data['timer_period_cycles']/985248,parts=[p]))
                signature=json.dumps(frames)
                if frames and signature not in used:
                    used.add(signature);entries.append(dict(game=1,category=2,name=f'Level {level} / Special actor {start:X}',clips=[clip('Original sequence',frames)]))
# LN3 already includes source-captured complete, assembled animation traces.
vectors=read(D/'verification/ln3_animation_vectors.json')['vectors']
lookup={(v['level'],v['action'],v['weapon']):v for v in vectors}
for level in range(1,6):
    world=read(D/f'play/ln3/level{level}/world.json');rt=read(D/f'play/ln3/level{level}/runtime.json');anim=read(D/f'play/ln3/level{level}/animation.json')
    palette=[r+g*256+b*65536 for r,g,b in rt['palette']]
    # Slot 3 belongs to level-specific encounters, not a humanoid costume.
    # Its unrelated graphics are assembled separately in MISC below.
    for costume in [None,0,1,2]:
        enemy=costume is not None;clips=[]
        def assembled(v,index,weapon_part=None,hide_weapon=False):
            f=v['frames'][index];out=[];base=4 if enemy else 0
            anchor=v['initial']['parts'][base+2];ax=anchor['x'];ay=anchor['y']
            for i in anim['order']:
                if i<base or i>=base+4 or (i==base+3 and hide_weapon):continue
                s=f if i!=base+3 or weapon_part is None else weapon_part
                physical=s['draw_frames'][i]
                if physical<0:continue
                if enemy and i==4:physical+=world['costume_offsets'][costume]
                choices=world['part_mapping'].get(str(physical))
                if not choices:continue
                choice=choices[int(bool(s['draw_mirror'][i]))]
                out.append(part(world['actor_bank'],choice['hires'],s['draw_x'][i]-ax,s['draw_y'][i]-ay,palette[s['draw_colours'][i]&15]))
            return dict(seconds=4*rt['timer_period_cycles']/985248,parts=out)
        for w in range(5):
            change_action=57 if enemy else 18
            if w:
                v=lookup[level,change_action,w if enemy else w-1];threshold=anim['weapon_change_cursors'][0]
                clips.append(clip(f'Draw weapon {w}',[assembled(v,i,hide_weapon=i<threshold) for i in range(len(v['frames'])-3)]))
            for action in range(39,61) if enemy else range(39):
                if action in [change_action,change_action+1]:continue
                v=lookup[level,action,w];count=max(1,len(v['frames'])-3)
                frames=[assembled(v,i) for i in range(count)]
                if any(f['parts'] for f in frames):clips.append(clip(f'Weapon {w} / Action {action}',frames))
            if w:
                v=lookup[level,change_action,w];threshold=anim['weapon_change_cursors'][0]
                clips.append(clip(f'Put away weapon {w}',[assembled(v,i,hide_weapon=i>=threshold) for i in range(len(v['frames'])-3)]))
        entries.append(dict(game=3,category=1 if enemy else 0,name=f'Level {level} / '+(f'Enemy {costume}' if enemy else 'Ninja'),clips=clips))
    special=rt['special']
    if 'animations' in special:
        ids=special['animations'];frames=[]
        length=max(len(anim['sequences'][i]['frames']) for i in ids)
        for cursor in range(length):
            parts=[]
            for j in range(len(ids)-1,-1,-1):
                seq=anim['sequences'][ids[j]];physical=seq['frames'][cursor%len(seq['frames'])]
                physical+=world['costume_offsets'][3]
                choices=world['part_mapping'].get(str(physical))
                if not choices:continue
                x=0;y=0;sx=1;sy=1;colour=special.get('colours',[7]*4)[j]
                if level==1:y=special['y_before'][j];sx=2;sy=2 if j==2 else 1
                elif level==3:x=special['x'][j];y=special['y'][j];sx=2 if j==0 else 1;sy=1 if j==0 else 2
                elif level==4:y=special['y'][j]
                choice=choices[0]
                if level==1 and j==2 and len(choice['multicolour'])==3:
                    for frame,colour_index in zip(choice['multicolour'],[15,colour,0]):
                        parts.append(part(world['actor_bank'],frame,x,y,palette[colour_index])+[sx,sy])
                else:parts.append(part(world['actor_bank'],choice['hires'],x,y,palette[colour])+[sx,sy])
            if parts:frames.append(dict(seconds=4*rt['timer_period_cycles']/985248,parts=parts))
        if frames:entries.append(dict(game=3,category=2,name=f'Level {level} / Special encounter',clips=[clip('Original composite',frames)]))
for g,n,b,ids in [
 (1,'Fountain','spr_ln1_level3_fountain',None),(1,'Smoke cloud','spr_ln1_projectile_cloud',None),
 (2,'Bees','spr_ln2_bee_parts',None),(2,'Thrown knives','spr_ln2_juggler_knives',None),
 (2,'Candles','spr_ln2_final_candles',None),(2,'Alarm','spr_ln2_mansion_alarm',None),
 (2,'Traffic lights','spr_ln2_street_lights',None),
 (2,'Juggler','spr_ln2_juggler',range(0,8,2)),(2,'Alligator','spr_ln2_sewer_alligator',range(0,46,2)),
 (2,'Rats','spr_ln2_sewer_rats',range(0,6,2)),(2,'Fan','spr_ln2_office_fan',range(0,6,2)),
 (2,'Trolley','spr_ln2_basement_trolley',[0]),(2,'Helicopter','spr_ln2_level6_helicopter',[0]),
 (2,'Boats','spr_ln2_park_boats',[0,2,4]),(2,'Street moving actors','spr_ln2_street_scenery',range(0,32,2)),
 (2,'Sewer flames','spr_ln2_sewer_flames',None),(2,'Projectiles','spr_ln2_projectiles',None),
 (3,'Scenery animations','spr_ln3_scenery_animation',None),(3,'Mechanisms','spr_ln3_mechanisms',None)]:raw(g,n,b,ids)
raw(2,'Shogun spirits','spr_char_ln2_spirits')
entries[-1]['category']=1
# Ground characters using the visible standing/walking pose, never canvas size.
# Keep this anchor for every action so jumps retain their original displacement.
@cache
def visible_bounds(bank, frame):
    folder=P/'sprites'/bank
    meta=read(folder/(bank+'.yy'))
    with Image.open(folder/(meta['frames'][frame]['name']+'.png')) as image:
        box=image.convert('RGBA').getchannel('A').getbbox()
    return box,meta['sequence']['xorigin'],meta['sequence']['yorigin']

for e in entries:
    if e['category'] in (0,1):
        bounds=[]
        for f in e['clips'][0]['frames']:
            for item in f['parts']:
                bank,frame,x,y=item[:4]
                box,ox,oy=visible_bounds(bank,frame)
                if box:
                    sx,sy=item[5:7] if len(item)>5 else (1,1)
                    bounds.append((x+(box[0]-ox)*sx,y+(box[1]-oy)*sy,
                                   x+(box[2]-ox)*sx,y+(box[3]-oy)*sy))
        if bounds:
            e['ground_anchor']=[(min(b[0] for b in bounds)+max(b[2] for b in bounds))/2,
                                max(b[3] for b in bounds)]
    for c in e['clips']:
        assert c['frames'],(e['name'],c['name'])
        for f in c['frames']:
            for item in f['parts']:
                b,i,x,y,col=item[:5]
                p=P/'sprites'/b/(b+'.yy');assert p.exists(),b
                assert 0<=i<len(read(p)['frames']),(b,i)
out=D/'sprite_viewer.json';out.write_text(json.dumps(dict(entries=entries),separators=(',',':')))
print(f'Sprite viewer: {len(entries)} entries, {sum(len(e["clips"]) for e in entries)} clips')
