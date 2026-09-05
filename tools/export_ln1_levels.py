"""Export real LN1 level packages for editable native gameplay.

Original 6502 routines run during extraction/verification only. Runtime records
contain room topology, boundaries, animation commands and object definitions.
Existing sprite resources and the previously approved scenery edits are kept.
"""
import hashlib
import json
import re
from PIL import Image
import build_project as builder
from build_project import ROOT, PROJECT, read_json, write_json
from decode_graphics import decode_dataset
from export_ln1_world import call, bitmap
from export_ln1_play import FIELDS, composition
from extract_ln1_actors import unpack, sprite_image
from ln1_level_source import level_memory, layout, word

NAMES = ['Wastelands', 'Wilderness', 'Palace Gardens', 'Dungeons', 'Palace', 'Inner Sanctum']


def garden_water_frames(ram):
    """Source $4e19 rotates the fountain's original 21 sprite rows."""
    frames=[]
    for mirror in range(2):
        for phase in range(21):
            mem=bytearray(ram);pixels=bytes(mem[0xa180:0xa1bf]);offset=(21-phase)*3
            mem[0xa180:0xa1bf]=pixels[offset:]+pixels[:offset]
            frames.append(composition(mem,135,mirror,0,True))
    return frames


def register_project(resources, included):
    """Add records without rewriting GameMaker/user formatting or file choices."""
    project_path = PROJECT / 'LNPreserve.yyp'
    data = read_json(project_path); text = project_path.read_text(encoding='utf-8-sig')
    known = {row['id']['name'] for row in data['resources']}
    additions = [row for name, row in resources.items() if name not in known]
    if additions:
        payload = '\n' + ''.join('    ' + json.dumps(row, separators=(',', ':')) + ',\n' for row in additions)
        text = re.sub(r'"resources"\s*:\s*\[', lambda m: m[0]+payload, text, count=1)
    known = {(row['filePath'], row['name']) for row in data['IncludedFiles']}
    additions = []
    for path in included:
        relative = path.relative_to(PROJECT)
        folder = relative.parent.as_posix()
        if (folder, path.name) in known:
            continue
        additions.append(dict(**{'$GMIncludedFile':'', '%Name':path.name}, CopyToMask=-1,
                              filePath=folder, name=path.name, resourceType='GMIncludedFile', resourceVersion='2.0'))
    if additions:
        payload = '\n' + ''.join('    '+json.dumps(row,separators=(',', ':'))+',\n' for row in additions)
        text = re.sub(r'"IncludedFiles"\s*:\s*\[', lambda m: m[0]+payload, text, count=1)
    project_path.write_text(text, encoding='utf-8')


def active(room):
    # $7478 produces perimeter values 0..212. Later slots after a threshold
    # above 212 are padding, even when the sentinel is $f7 instead of $ff.
    count = next((i+1 for i, value in enumerate(room['exit_thresholds']) if value > 212), 4)
    return room['exits'][:count]


def room_ids(ram):
    found = {ram[0xaf04] >> 2}; pending = list(found)
    while pending:
        room = pending.pop()
        thresholds = list(ram[0xaf00+room*8:0xaf04+room*8])
        exits = list(ram[0xaf04+room*8:0xaf08+room*8])
        for entry in active(dict(exit_thresholds=thresholds, exits=exits)):
            destination = entry >> 2
            if destination and destination not in found:
                assert destination < 28, 'Exit outside original room table'
                found.add(destination); pending.append(destination)
    result = sorted(found)
    assert result == list(range(1, max(result)+1)), 'Non-contiguous room IDs need explicit runtime indexing'
    return result


def navigation(ram, world):
    def original(room, x, y):
        mem = list(ram); mem[0xa2] = room; mem[0x54] = x; mem[0x55] = y
        call(mem, 0x7478)
        return dict(entry=mem[0x278], room=mem[0xa2], x=mem[0x54], y=mem[0x55],
                    facing=mem[0x69], heading=mem[0x68], frame=mem[0x65], turn_lock=mem[0x2b8])
    rooms = []; vectors = []
    for room in world['rooms']:
        entries = [-1]*4; spawn = None; routes = []
        for entry in dict.fromkeys(active(room)):
            dest = entry >> 2
            if dest == 0:
                continue
            for back in active(world['rooms'][dest-1]):
                if back >> 2 != room['id']:
                    continue
                index = world['entry_index'][back]
                x = world['entry_x'][index]; y = world['entry_y'][index]
                direction = ((world['entry_heading'][index]+4)&7)//2
                edge = min([(x-1,0,y),(247-x,247,y),(y-8,x,8),(189-y,x,189)])
                expected = original(room['id'], edge[1], edge[2])
                if expected['entry'] != entry:
                    continue
                if spawn is None:
                    spawn = back
                if not any(r['entry'] == entry for r in routes):
                    routes.append(dict(direction=direction, entry=entry, x=x, y=y))
                    if entries[direction] < 0:
                        entries[direction] = entry
                    vectors.append(dict(room=room['id'], direction=direction, boundary_point=list(edge[1:]), expected=expected))
        # Secret passages can be one-way. A reciprocal entrance does not exist
        # for the garden-to-dungeon drop, so recover its actual outgoing entry
        # directly and use the destination's inward heading for test navigation.
        for entry in dict.fromkeys(active(room)):
            if entry < 4 or any(route['entry'] == entry for route in routes):
                continue
            index = world['entry_index'][entry]
            direction = world['entry_heading'][index] // 2
            ideal = [(247,60),(247,152),(0,133),(0,56)][direction]
            perimeter = [(x,y) for x in range(0,248,4) for y in (8,189)]
            perimeter += [(x,y) for x in (0,247) for y in range(9,190,4)]
            perimeter.sort(key=lambda p:(p[0]-ideal[0])**2+(p[1]-ideal[1])**2)
            for point in perimeter:
                expected = original(room['id'],*point)
                if expected['entry'] != entry:
                    continue
                routes.append(dict(direction=direction,entry=entry,x=point[0],y=point[1]))
                if entries[direction] < 0:
                    entries[direction] = entry
                vectors.append(dict(room=room['id'],direction=direction,boundary_point=list(point),expected=expected))
                break
            else:
                raise AssertionError(f'Original exit {entry} in room {room["id"]} is unreachable at its perimeter')
        for direction, (x,y) in enumerate([(247,60),(247,152),(0,133),(0,56)]):
            expected = original(room['id'], x,y)
            if entries[direction] < 0 and expected['room'] == 0:
                entries[direction] = 0
                routes.append(dict(direction=direction,entry=0,x=x,y=y))
                vectors.append(dict(room=room['id'],direction=direction,boundary_point=[x,y],expected=expected))
        if spawn is None:
            incoming = [entry for source in world['rooms'] for entry in active(source) if entry >> 2 == room['id']]
            if world['initial_entry'] >> 2 == room['id']:
                incoming.insert(0, world['initial_entry'])
            assert incoming, f'No original entrance for room {room["id"]}'
            spawn = incoming[0]
        rooms.append(dict(id=room['id'],entries=entries,spawn_entry=spawn,routes=routes))
    return dict(schema=1,directions=['NE','SE','SW','NW'],rooms=rooms), vectors


def actions(ram, entries):
    pending = list(entries); records = {}
    while pending:
        address = pending.pop()
        if address < 256 or str(address) in records:
            continue
        cursor = address; flags = ram[cursor]; cursor += 1
        duration = ram[cursor] if flags & 2 else -1; cursor += bool(flags&2)
        frame = ram[cursor]; cursor += 1; dx = dy = 0
        if flags & 128:
            dx,dy = ram[cursor:cursor+2]; cursor += 2
        state = combat_data = -1
        if flags & 1:
            state = ram[cursor]; cursor += 1
            if 16 <= state < 32:
                combat_data = ram[cursor]; cursor += 1
        following = word(ram,cursor) if flags&32 else cursor
        records[str(address)] = dict(flags=flags,duration=duration,frame=frame,dx=dx,dy=dy,
                                     state=state,combat_data=combat_data,next=following)
        pending.append(following)
        assert len(records) < 2048, 'Unexpected action graph'
    return records


def main():
    original = (ROOT/'source/local/captures/ln1-game-ram.bin').read_bytes()
    base_gameplay = read_json(PROJECT/'datafiles/play/ln1/gameplay.json')
    resources = {}; included = []; report = []
    for name in ['ln1_levels','ln1_level_checks','ln1_projectiles']:
        resources[name]={'id':{'name':name,'path':f'scripts/{name}/{name}.yy'}}
    projectile={}
    for role,count,start,colour_start in [('flight',7,0x7797,0x779f),('cloud',8,0x77c4,0x77cc)]:
        frames=[]
        for index in range(count):
            part=original[start+index]
            if part==255:frame=Image.new('RGBA',(24,21))
            else:
                decoded,_=unpack(original,original[0x8000+part]+256*original[0x80c0+part])
                frame=sprite_image(decoded,False,original[colour_start+index]&15)
            frames.append(frame)
        name=f'spr_ln1_projectile_{role}';path=PROJECT/f'datafiles/play/ln1/{name}.png';frames[0].save(path)
        resources[name]=builder.sprite_resource(name,path,'Graphics/ln1_game_level1',frames)
        projectile[role+'_sprite']=name
    projectile.update(launch=list(original[0x77ab:0x77b4]),step=list(original[0x77b3:0x77c4]),
                      draw_x=list(original[0x77a5:0x77a9]),draw_y=list(original[0x77a8:0x77ac]),
                      animation_periods=list(original[0x5720:0x5722]))
    path=PROJECT/'datafiles/play/ln1/projectiles.json';write_json(path,projectile);included.append(path)
    # The first prototype omitted the dragon's triggered sequences and the high
    # composition bank used by flames and Buddha birds. Recover those too.
    base_gameplay['actions']=actions(original,list(map(int,base_gameplay['actions']))+[0x4f10,0x4f66,0x4f76])
    base_gameplay['dragon_smoke_action']=0x4f66
    write_json(PROJECT/'datafiles/play/ln1/gameplay.json',base_gameplay)
    high=sorted({r['frame'] for r in base_gameplay['actions'].values() if 128<=r['frame']<192})
    images=[composition(original,frame,mirror,0,True) for mirror in range(2) for frame in high]
    name='spr_ln1_world_actors';path=PROJECT/f'datafiles/play/ln1/{name}.png';images[0].save(path)
    resources[name]=builder.sprite_resource(name,path,'Graphics/ln1_game_level1',images)
    yy=PROJECT/f'sprites/{name}/{name}.yy';meta=read_json(yy)
    meta['origin']=9;meta['sequence']['xorigin']=48;meta['sequence']['yorigin']=64;write_json(yy,meta)
    path=PROJECT/'datafiles/play/ln1/world.json';world=read_json(path)
    world['actor_frames']={str(frame):dict(sprite=name,index=i,mirror_offset=len(high)) for i,frame in enumerate(high)}
    write_json(path,world)
    for level in range(2,7):
        raw, banks = level_memory(level)
        ram = (ROOT/f'source/local/captures/ln1-level{level}-ram.bin').read_bytes()
        source = layout(ram); folder = PROJECT/f'datafiles/play/ln1/level{level}'
        folder.mkdir(parents=True,exist_ok=True)
        dataset,_ = decode_dataset(bytes([0,6])+ram[0x600:0x5400],1)
        def sprite(name, images, origin=False):
            path = folder/f'{name}.png'; images[0].save(path)
            resources[name] = builder.sprite_resource(name,path,f'Graphics/ln1_game_level{level}',images)
            if origin:
                yy = PROJECT/f'sprites/{name}/{name}.yy'; meta=read_json(yy)
                meta['origin']=9;meta['sequence']['xorigin']=48;meta['sequence']['yorigin']=64;write_json(yy,meta)
            return name
        rooms = []
        for room in room_ids(ram):
            mem=list(ram);mem[0xa2]=room
            for address in (0x5452,0x5dfe,0x6765,source['boundary_enter'],source['enemy_spawn']):
                call(mem,address)
            boundaries=[]
            for pos in range(0x334,0x3ec,5):
                if mem[pos+1]==0:break
                boundaries.append(mem[pos:pos+5])
            name=f'spr_ln1_level{level}_room_{room:02d}'
            sprite(name,[bitmap(mem)])
            depth=Image.new('RGBA',(240,144));offset=ram[0xdf00+room]
            if ram[0xdf20+offset]:
                for _ in range(32):
                    part,baseline,cx,cy=ram[0xdf20+offset:0xdf24+offset]
                    if not part:break
                    obj=dataset['objects'].get(str(part))
                    assert obj is not None, f'Invalid mask bitmap {part}'
                    for y in range(obj['height']):
                        for x in range(obj['width']):
                            cell=y//8*(obj['width']//8)+x//8
                            code=(obj['bitmap'][cell*8+y%8]>>(6-(x%8//2)*2))&3
                            dx=cx*8+x;dy=(cy&127)*8+y
                            if code and dx<240 and dy<144:
                                depth.putpixel((dx,dy),(255,255,255,max(baseline,depth.getpixel((dx,dy))[3])))
                    if cy&128:break
                    offset+=4
            depth_name=sprite(name+'_depth',[depth])
            enemy_script=word(mem,0x62);crossings=[]
            for entrance in range(4):
                mem[0x278]=entrance;call(mem,source['boundary_enter']);crossings.append(mem[0x2b6])
            rooms.append(dict(id=room,sprite=name,depth_sprite=depth_name,boundaries=boundaries,occluders=[],
                              exit_thresholds=list(ram[0xaf00+room*8:0xaf04+room*8]),
                              exits=list(ram[0xaf04+room*8:0xaf08+room*8]),boundary_mode=mem[0x2b5],
                              entrance_crossings=crossings,enemy_script=enemy_script))
        items=[]; pos=source['item_table']+ram[source['item_offsets']+level-1]
        while ram[pos]!=255:
            room,item,x0,x1,y0,y1,part,flags,x,y=ram[pos:pos+10]
            assert room in room_ids(ram) and item<20, (level,pos,room,item)
            name='';flash_name=''
            if part:
                decoded,_=unpack(ram,ram[0x8000+part]+256*ram[0x80c0+part])
                image=sprite_image(decoded,bool(flags&128),flags&15)
                if flags&32:image=image.resize((24,42),Image.Resampling.NEAREST)
                name=sprite(f'spr_ln1_level{level}_pickup_{item}',[image])
                flash=[]
                for index in range(31,0,-1):
                    frame=sprite_image(decoded,bool(flags&128),ram[0x6fc1+index])
                    if flags&32:frame=frame.resize((24,42),Image.Resampling.NEAREST)
                    flash.append(frame)
                flash_name=sprite(name+'_flash',flash)
            items.append(dict(room=room,id=item,x_min=x0,x_max=x1,y_min=y0,y_max=y1,sprite=name,
                              flash_sprite=flash_name,flashes=0 if flags&16 else 2,x=x-24,y=y-50,source_address=pos))
            pos+=10
            assert len(items)<32
        safe=[]
        for region in range(4):
            address=0xdc00+ram[0xdc00+region];rects=[]
            for _ in range(64):
                if ram[address]==255:break
                rects.append(list(ram[address:address+4]));address+=4
            safe.append(rects)
        world=dict(schema=2,level=level,title=NAMES[level-1],rooms=rooms,items=items,safe_areas=safe,
                   initial_entry=ram[0x278],initial_lives=ram[0x9b],initial_water_clock=ram[0x26f],
                   initial_inventory=list(ram[0x3ec:0x400]),prayer_hint_items=[],
                   entry_index=list(ram[0xff3c:0xffb8]),entry_x=list(ram[0xffb8:0xffd8]),
                   entry_y=list(ram[0xffd8:0xfff8]),entry_heading=list(ram[0xafe0:0xb000]),
                   source_layout=source,source_banks=banks)
        if level==6:
            vision=list(ram);vision[0xa2]=16
            for address in (0x5452,0x5dfe,source['enemy_spawn']):call(vision,address)
            world['vision_sprite']=sprite('spr_ln1_level6_vision',[bitmap(vision)])
            world['vision_enemy']=word(vision,0x62)
        # Shared movement/animation code is literally unchanged in these banks.
        assert ram[0x5400:0x8000] == original[0x5400:0x8000]
        data=json.loads(json.dumps(base_gameplay))
        data.pop('dragon_smoke_action',None)
        state={name:ram[address] for name,address in FIELDS.items()}
        state.update(action=word(ram,0x60),enemy_x=ram[0x56],enemy_y=ram[0x57],mirror=0,tick=ram[0x1b])
        data['initial']=state;data['source_sha256']=hashlib.sha256(ram).hexdigest()
        if level==6:data['boss_damage']=list(ram[0x783f:0x7854])
        entry_bytes=84 if level==4 else (80 if level==6 else 56)
        data['enemy_entries']=[word(ram,a) for a in range(source['enemy_entries'],source['enemy_entries']+entry_bytes,2)]
        if level in (4,6):
            table=0x5315 if level==4 else 0x4f6e
            data['special_enemy']=dict(type=133 if level==4 else 136,mirror_xor=4 if level==4 else 0,
                                       action_map=list(ram[table:table+14]))
        data['reactions']=[word(ram,a) for a in range(source['reactions'],source['reactions']+24,2)]
        special=[]
        for key,address,length in [('pray_kneel',0xada5,12),('pray_stand',0xadbd,9)]:
            found=ram.find(original[address:address+length],0x600,0xc000)
            world[key]=found
            if found>=0:special.append(found)
        if level==3:
            hint=0xae4b+ram[0xae45+level-1]
            while ram[hint]<128:
                world['prayer_hint_items'].append(ram[hint]);hint+=1
        if level==6:special.append(world['vision_enemy'])
        # Include all sequences directly referenced by the original level code.
        # JSR $7e00 (enemy) passes X/Y; JSR $583a (player) passes X/A.
        for start,end in [(0x600,0x800),(0x4a00,0x5400),(0xa700,0xaf00),(0xbc60,0xc000)]:
            for address in range(start,end-7):
                if ram[address]==0xa2 and ram[address+2] in (0xa0,0xa9) and ram[address+4]==0x20:
                    target=word(ram,address+5)
                    if target in (0x7e00,0x583a):
                        special.append(ram[address+1]+256*ram[address+3])
        data['actions']=actions(ram,data['action_entries']+data['enemy_entries']+data['reactions']+
                                [0x5d34,0x5dce,0x5de1]+special+[r['enemy_script'] for r in rooms])
        used=sorted({r['frame'] for r in data['actions'].values() if 64<=r['frame']<255})
        assert all(frame<192 for frame in used), used
        images=[composition(ram,frame,mirror,0,True) for mirror in range(2) for frame in used]
        extra=sprite(f'spr_ln1_level{level}_actors',images,True)
        world['actor_frames']={str(frame):dict(sprite=extra,index=i,mirror_offset=len(used)) for i,frame in enumerate(used)}
        if level==3:
            world['actor_frames']['135']['spin_sprite']=sprite('spr_ln1_level3_fountain',garden_water_frames(ram),True)
        # Regular human compositions use the shared bank, including editable weapons.
        for enemy in (False,True):
            for weapon in range(4):
                for frame in range(64):
                    assert composition(ram,frame,0,weapon,enemy).tobytes()==composition(original,frame,0,weapon,enemy).tobytes()
        nav,vectors=navigation(ram,world)
        selectors=[]
        for active_type in [128,129,133,136]:
            for facing in [1,3,5,7]:
                for speed in [0,4,8,12]:
                    for entry in range(0,56,4):
                        mem=list(ram);mem[0xcb]=active_type;mem[0x6b]=facing;mem[0xd3]=speed
                        call(mem,source['enemy_begin'],x=entry)
                        selectors.append(dict(active=active_type,facing=facing,speed_traits=speed,entry=entry,
                                              action=word(mem,0x62),flags=mem[0x5e],mirror=mem[0x5f],countdown=mem[0x5a]))
        for name,value in [('world',world),('gameplay',data),('navigation',nav),('navigation_vectors',dict(vectors=vectors)),
                           ('selector_vectors',dict(vectors=selectors))]:
            path=folder/f'{name}.json';write_json(path,value);included.append(path)
        record=dict(level=level,title=NAMES[level-1],rooms=len(rooms),items=len(items),
                    encounters=sum(bool(r['enemy_script']) for r in rooms),actions=len(data['actions']),
                    navigation_vectors=len(vectors),selector_vectors=len(selectors),source_sha256=data['source_sha256'],layout=source,
                    special_boundary_types=sorted({r['boundary_mode']&31 for r in rooms if r['boundary_mode']}))
        report.append(record);print(record,flush=True)
    register_project(resources,included)
    from deduplicate_ln1_levels import main as share_identical_assets
    share_identical_assets()
    write_json(ROOT/'evidence/ln1_level_content.json',dict(method='Original disk banks and offline original drawing/room routines',
               full_gameplay_parity=False,levels=report))


if __name__=='__main__':main()
