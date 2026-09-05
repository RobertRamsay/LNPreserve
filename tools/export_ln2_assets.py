"""Import source-rendered LN2 rooms and actor banks without duplicate resources.

Old preview resources and user edits are preserved. Identical original images
share an existing sprite; new gameplay art uses the supplied game compositor.
"""
import hashlib,json,subprocess
import build_project as builder
from PIL import Image
from build_project import ROOT,PROJECT,read_json,write_json,sprite_resource
from export_ln1_levels import register_project
from export_ln1_world import call
from export_ln2_content import composition,render_room
from ln2_level_source import level_memory,layout,word
from make_ln2_enemy_vectors import state as enemy_state

def digest(images,origin):
    h=hashlib.sha256(str(origin).encode())
    for image in images:h.update(str(image.size).encode());h.update(image.tobytes())
    return h.hexdigest()

def write_import_report():
    references=[];levels=[]
    for level in range(1,8):
        path=PROJECT/f'datafiles/play/ln2/level{level}/world.json'
        if not path.exists():continue
        w=read_json(path);refs=[]
        for room in w['rooms']:refs.extend([room['sprite'],room['depth_sprite']]+room['variants'])
        refs.extend(w['player_banks']+w['player_extra_banks'])
        refs.extend(w['enemy_banks'].values());refs.extend(w['enemy_extra_banks'].values())
        references.extend(refs)
        levels.append(dict(level=level,scene_records=len(w['rooms']),selectable_scenes=sum(r['spawn_entry']>=0 for r in w['rooms']),
                           unique_referenced_sprites=len(set(refs)),source_sha256=w['source_sha256']))
    write_json(ROOT/'evidence/ln2_asset_import.json',dict(levels=levels,
        sprite_references=len(references),unique_referenced_sprites=len(set(references)),
        shared_references=len(references)-len(set(references)),method=__doc__,full_gameplay_parity=False))

def navigation(ram,s,world):
    tables=world['tables'];rooms={r['id']:r for r in world['rooms']};vectors=[]
    def original(room,x,y):
        mem=list(ram);mem[0xa2]=room;mem[0x54]=x;mem[0x55]=y;mem[0x234]=0;mem[0x2af]=0
        call(mem,s['exit'])
        return dict(entry=mem[0x278],room=mem[0xa2],x=mem[0x54],y=mem[0x55],facing=mem[0x69],
                    heading=mem[0x68],frame=mem[0x65],crossings=mem[0x81],level_end=mem[0x2af]==255)
    for room in world['rooms']:
        room['routes']=[];incoming=[i for i,dest in enumerate(tables['exit_destinations']) if dest==room['id']]
        room['spawn_entry']=incoming[0] if incoming else -1
        for entry in room['entries']:
            dest=tables['exit_destinations'][entry]
            direction=(tables['entry_heading'][entry]&7)//2
            if dest!=255:
                assert dest in rooms,(room['id'],dest)
                for back in rooms[dest]['entries']:
                    if tables['exit_destinations'][back]!=room['id']:continue
                    x=tables['entry_x'][back];y=tables['entry_y'][back]
                    edge=min([(x-1,0,y),(247-x,247,y),(y-8,x,8),(189-y,x,189)])
                    result=original(room['id'],edge[1],edge[2])
                    if result['entry']==entry and not result['level_end']:
                        direction=(((tables['entry_heading'][back]&7)+4)&7)//2;break
            ideal=[(247,60),(247,152),(0,133),(0,56)][direction]
            points=[(x,y) for x in range(0,248,4) for y in (8,189)]+[(x,y) for x in (0,247) for y in range(9,190,4)]
            points.sort(key=lambda p:(p[0]-ideal[0])**2+(p[1]-ideal[1])**2)
            for point in points:
                result=original(room['id'],*point)
                if (dest==255 and result['level_end']) or (not result['level_end'] and result['entry']==entry):
                    room['routes'].append(dict(entry=entry,direction=direction,x=point[0],y=point[1]))
                    vectors.append(dict(room=room['id'],point=list(point),expected=result));break
            else:raise AssertionError(f'LN2 exit {entry} not found on scene {room["id"]} perimeter')
    return vectors

def main(levels=range(1,8)):
    resources={};included=[];known={};reused=0
    tracked=set(subprocess.check_output(['git','ls-files'],cwd=ROOT,text=True).splitlines())
    project=read_json(PROJECT/'LNPreserve.yyp')
    # Only import existing resources with ordinary origins. Metadata and image
    # pixels participate in matching, so an edited sprite is never overwritten.
    for row in project['resources']:
        path=PROJECT/row['id']['path']
        if path.parent.parent.name!='sprites':continue
        meta=read_json(path)
        if not meta['frames']:continue
        origin=(meta['sequence']['xorigin'],meta['sequence']['yorigin'])
        if origin not in ((0,0),(48,64)):continue
        images=[Image.open(path.parent/(frame['name']+'.png')).convert('RGBA') for frame in meta['frames']]
        known.setdefault(digest(images,origin),meta['name'])
    def sprite(name,images,level,actor=False):
        nonlocal reused
        origin=(48,64) if actor else (0,0);key=digest(images,origin)
        if key in known:reused+=1;return known[key]
        source=ROOT/'build/ln2-asset.png';images[0].save(source)
        path=PROJECT/f'sprites/{name}/{name}.yy'
        for old_key in [k for k,v in known.items() if v==name]:del known[old_key]
        # Refresh only this import's new, uncommitted banks while its recovered
        # graph is being expanded. Committed/user artwork remains preserved.
        builder.REFRESH_GRAPHICS=path.relative_to(ROOT).as_posix() not in tracked
        resources[name]=sprite_resource(name,source,f'Graphics/ln2_game_level{level}',images)
        builder.REFRESH_GRAPHICS=False
        if actor:
            path=PROJECT/f'sprites/{name}/{name}.yy';meta=read_json(path)
            meta['origin']=9;meta['sequence']['xorigin']=48;meta['sequence']['yorigin']=64;write_json(path,meta)
        known[key]=name;return name
    for level in levels:
        ram=level_memory(level);s=layout(ram);folder=ROOT/f'source/local/recovered/ln2/level{level}'
        w=read_json(folder/'world.json');d=read_json(folder/'gameplay.json')
        for room in w['rooms']:
            room['sprite']=sprite(f'spr_ln2_level{level}_room_{room["id"]:02}',[Image.open(folder/f'room-{room["id"]:02}.png').convert('RGBA')],level)
            room['depth_sprite']=sprite(f'spr_ln2_level{level}_depth_{room["id"]:02}',[Image.open(folder/f'room-{room["id"]:02}-depth.png').convert('RGBA')],level)
            mem=list(ram);mem[0xa2]=room['id'];mem[s['actor_draw']]=0x60;mem[s['mask']]=0x60
            call(mem,s['enemy_enter']);mem[0x22a]=mem[0x3f90+room['id']]
            extra=room['enemy'];room['enemy']=enemy_state(mem,d);room['enemy'].update(costume=extra['costume'],retreat_trait=extra['retreat_trait'])
            flags={i['id'] for i in w['items'] if i['room']==room['id']}
            if level==1 and room['id'] in (1,13):flags.add(18 if room['id']==1 else 17)
            if level==6 and room['id']==10:flags.add(19)
            room['variant_flags']=sorted(flags);room['variants']=[]
            for bits in range(1<<len(flags)):
                inventory=w['initial_inventory'].copy()
                for i,flag in enumerate(room['variant_flags']):inventory[flag]=255 if bits&(1<<i) else 0
                image=render_room(ram,s,room['id'],inventory)
                room['variants'].append(sprite(f'spr_ln2_level{level}_room_{room["id"]:02}_state{bits}',[image],level))
        nav=navigation(ram,s,w)
        frames=sorted(f for f in d['frames'] if f>=64);w['actor_frames']=frames
        w['player_banks']=[];w['enemy_banks']={};w['player_extra_banks']=[];w['enemy_extra_banks']={}
        shared=tuple(w['shared_sprite_colours'])
        for enemy in (False,True):
            kinds=sorted({(r['enemy']['weapon'],r['enemy']['costume']) for r in w['rooms'] if r['enemy']['active']>=128}) if enemy else [(i,0) for i in range(5)]
            for weapon,costume in kinds:
                for suffix,poses,field in [('body',range(64),'enemy_banks' if enemy else 'player_banks'),
                                           ('effects',frames,'enemy_extra_banks' if enemy else 'player_extra_banks')]:
                    images=[composition(ram,s,f,m,weapon,costume,enemy,shared) for m in (False,True) for f in poses]
                    name=sprite(f'spr_ln2_level{level}_{"enemy" if enemy else "player"}_{weapon}_{costume}_{suffix}',images,level,True)
                    if enemy:w[field][f'{weapon}_{costume}']=name
                    else:w[field].append(name)
                print('LN2 bank',level,'enemy' if enemy else 'player',weapon,costume,'ready',flush=True)
        for name,value in [('world',w),('gameplay',d),('navigation_vectors',dict(vectors=nav))]:
            path=PROJECT/f'datafiles/play/ln2/level{level}/{name}.json';write_json(path,value);included.append(path)
        register_project(resources,included)
        print('LN2 level',level,len(w['rooms']),'rooms',len(nav),'source exit comparisons',flush=True)
    write_import_report()

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--levels',type=int,nargs='+',default=list(range(1,8)))
    args=parser.parse_args();assert all(1<=level<=7 for level in args.levels)
    main(args.levels)
