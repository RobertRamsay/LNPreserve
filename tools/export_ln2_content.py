"""Recover LN2's seven source content packages; execution remains offline.

These are source-derived editable records, not a claim that the native LN2
engine or its objective handlers are complete. Unported handlers are explicit.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image
from build_project import ROOT,write_json
from ln2_level_source import level_memory,layout,locate,word
from export_ln1_world import call
from decode_graphics import PALETTE,decode_object
from extract_ln1_actors import sprite_image

NAMES=['Central Park','Street','Sewers','Basement','Office','Mansion','Final Battle']
FIELDS={
    'fraction_x':0x50,'fraction_y':0x51,'x':0x54,'y':0x55,'countdown':0x58,'duration':0x59,
    'flags':0x5c,'action_mirror':0x5d,'action_state':0x64,'frame':0x65,'heading':0x68,'facing':0x69,
    'stopped':0x6c,'combat_state':0x6d,'weapon':0x70,'depth_y':0x74,'fire_previous':0x78,
    'walk_clock':0x79,'attack_direction':0x84,'attack_clock':0x85,'attack_previous':0x88,
    'selected_weapon':0x89,'saved_heading':0x96,'redraw':0x9f,'input_lock':0xb6,
    'enemy_active':0xcb,'collision':0xcd,'height_fixed':0xef,'separation_y':0x236,
    'last_tick':0x26c,'turn_lock':0x2b8,'boundary_mode':0x80,'boundary_crossings':0x81,
    'control_rotation':0x3f3,'tick':0xe2,
}

def actions(ram,entries):
    records={};pending=list(entries)
    while pending:
        address=pending.pop()
        if address<256 or str(address) in records:continue
        p=address;flags=ram[p];p+=1
        duration=ram[p] if flags&2 else -1;p+=bool(flags&2)
        frame=ram[p];p+=1;dx=dy=0
        if flags&128:dx,dy=ram[p:p+2];p+=2
        state=ram[p] if flags&1 else -1;p+=bool(flags&1)
        following=word(ram,p) if flags&32 else p
        records[str(address)]=dict(flags=flags,duration=duration,frame=frame,dx=dx,dy=dy,state=state,next=following)
        pending.append(following)
        assert len(records)<2048,'Unexpected animation graph'
    return records

def bitmap(mem):
    image=Image.new('RGBA',(240,144));pixels=[]
    for y in range(144):
        for x in range(240):
            cell=y//8*40+x//8;code=(mem[0x2000+cell*8+y%8]>>(6-(x%8//2)*2))&3
            colour=[mem[0x32]&15,mem[0x400+cell]>>4,mem[0x400+cell]&15,mem[0x800+cell]&15][code]
            pixels.append((*PALETTE[colour],255))
    image.putdata(pixels);return image

def render_room(ram,source,room,inventory=None):
    mem=list(ram);mem[0xa2]=room
    if inventory is not None:mem[0x3d8:0x3f2]=inventory
    call(mem,0x140e);call(mem,source['scene_choose']);call(mem,source['item_enter'])
    return bitmap(mem)

def composition(ram,source,frame,mirror,weapon=0,costume=0,enemy=False,shared=(11,2)):
    """Run the actual compositor offline, then assemble its four hardware parts."""
    mem=list(ram);mem[0x200:0x250]=[0]*80;mem[0x9e]=255
    mem[0x54:0x58]=[120,120,120,120];mem[0x70]=weapon;mem[0x72]=weapon
    mem[0x7d]=costume;mem[0x7f]=costume;mem[0x280:0x282]=[0,0]
    draw=source['actor_enemy' if enemy else 'actor_player']
    call(mem,draw,a=255 if mirror else 0,x=4 if enemy else 0,y=frame)
    image=Image.new('RGBA',(96,96));slots=range(4,8) if enemy else range(4)
    for i in reversed(list(slots)):
        x=mem[0x200+i]+256*mem[0x208+i];y=mem[0x210+i]
        if not y:continue
        pointer=word(bytes([mem[0x169d+i],mem[0x16a5+i]]),0)
        if mem[0x218+i]&1:pointer+=512
        part=sprite_image(mem[pointer:pointer+63],bool(mem[0x238+i]),mem[0x220+i]&15,shared)
        image.alpha_composite(part,(48+x-120-24,64+y-120-50))
    return image

def main():
    root=ROOT/'source/local/recovered/ln2';root.mkdir(parents=True,exist_ok=True);reports=[]
    for level in range(1,8):
        ram=level_memory(level);s=layout(ram);out=root/f'level{level}';out.mkdir(exist_ok=True)
        count=s['exit_count'];tables={name:list(ram[s[name]:s[name]+count]) for name in
            ['exit_destinations','exit_thresholds','entry_x','entry_y','entry_heading']}
        groups=[];p=1
        while p<count:
            end=p
            while end<count and tables['exit_thresholds'][end]!=255:end+=1
            assert end<count,'Unterminated room exits'
            groups.append(list(range(p,end+1)));p=end+1
        reachable={tables['exit_destinations'][0]};pending=list(reachable)
        while pending:
            room=pending.pop()
            for entry in groups[room]:
                destination=tables['exit_destinations'][entry]
                if destination!=255 and destination not in reachable:reachable.add(destination);pending.append(destination)
        rooms=[]
        for room,entries in enumerate(groups):
            if ram[s['scene_data']+3+room*2]==255:continue
            mem=list(ram);mem[0xa2]=room;call(mem,s['boundary_enter']);boundaries=[]
            for p in range(s['boundary_table'],min(65530,s['boundary_table']+252),6):
                if not mem[p+1]:break
                boundaries.append(mem[p:p+6])
            # Actor drawing is intercepted only for this spawn-state oracle;
            # full source composition is recovered separately by composition().
            mem[s['actor_draw']]=0x60;mem[s['mask']]=0x60
            call(mem,s['enemy_enter'])
            enemy={name:mem[address] for name,address in {
                'active':0xcb,'x':0x56,'y':0x57,'facing':0x6b,'weapon':0x72,'costume':0x7f,
                'mode':0xcf,'traits':0xd0,'speed':0xd3,'retreat_trait':0xd6,
                'frame':0x67,'mirror':0x5f,'flags':0x5e,'duration':0x5b,'depth_y':0x76}.items()}
            enemy['action']=word(mem,0x62)
            render_room(ram,s,room).save(out/f'room-{room:02}.png')
            masks=[];mask=Image.new('RGBA',(240,144));table=word(ram,s['mask']+11);p=word(ram,table+room*2)
            while ram[p]!=255:
                part,baseline,cx,cy=ram[p:p+4];p+=4
                pointer=word(ram,s['scene_data']+0x43+part*2)
                assert pointer&0x8000,'Mask references a panel instead of a bitmap'
                obj,_=decode_object(ram,s['scene_data']+(pointer&0x7fff))
                masks.append(dict(part=part,baseline=baseline,x=cx*8-24,y=cy*8-24))
                for y in range(obj['height']):
                    for x in range(obj['width']):
                        cell=y//8*(obj['width']//8)+x//8
                        code=(obj['bitmap'][cell*8+y%8]>>(6-(x%8//2)*2))&3
                        dx=cx*8-24+x;dy=cy*8-24+y
                        if code and 0<=dx<240 and 0<=dy<144:
                            mask.putpixel((dx,dy),(255,255,255,max(baseline,mask.getpixel((dx,dy))[3])))
            mask.save(out/f'room-{room:02}-depth.png')
            rooms.append(dict(id=room,entries=entries,boundaries=boundaries,enemy=enemy,masks=masks,
                              reachable_by_perimeter_exits=room in reachable))
        items=[];p=s['item_table']
        while ram[p]<128:
            r=ram[p:p+14]
            items.append(dict(room=r[0],x_min=r[1],y_min=r[2],x_max=r[3],y_max=r[4],
                present_panel=word(r,5),removed_panel=word(r,7),handler=word(r,9),id=r[11],action=r[12],facing=r[13],source_address=p))
            p+=14;assert len(items)<32
        initial={name:ram[address] for name,address in FIELDS.items()}
        initial.update(action=word(ram,0x60),enemy_x=ram[0x56],enemy_y=ram[0x57],mirror=0)
        action_entries=[word(ram,p) for p in range(s['player_begin']+0xac,s['player_begin']+0xf4,2)]
        selector=s['enemy_select'];enemy_table=word(ram,selector+24)
        enemy_entries=[word(ram,p) for p in range(enemy_table,enemy_table+52,2)]
        special=[];begin=locate(ram,0xa4f8,24)
        for p in range(0x600,0xd000-7):
            if ram[p]==0xa2 and ram[p+2]==0xa9 and ram[p+4]==0x20 and word(ram,p+5)==begin:
                special.append(ram[p+1]+256*ram[p+3])
        graph=actions(ram,action_entries+enemy_entries+special)
        move=s['move'];movement={key:list(ram[move+offset:move+offset+4]) for key,offset in
            [('left',0x109),('right',0x10d),('up',0x111),('down',0x115),('triple_y',0x119),
             ('no_y',0x11d),('forward',0x121),('mirror',0x125)]}
        movement['speed_x']=[ram[move-20+i]+256*ram[move-10+i] for i in range(5)]
        movement['speed_y']=[ram[move-15+i]+256*ram[move-5+i] for i in range(5)]
        frames=sorted(set(range(18))|{a['frame'] for a in graph.values() if a['frame']!=255}|{r['enemy']['frame'] for r in rooms})
        # Record all objective/hazard dispatch targets for the native translation
        # audit, rather than silently treating unimplemented effects as pickups.
        hazards=sorted({b[5]&63 for room in rooms for b in room['boundaries'] if b[4]&1})
        world=dict(schema=1,game=2,level=level,title=NAMES[level-1],tables=tables,rooms=rooms,items=items,
                   initial_entry=0,initial_inventory=list(ram[0x3d8:0x3f2]),initial_lives=ram[0x3f2],
                   source_layout=s,source_sha256=hashlib.sha256(ram).hexdigest())
        gameplay=dict(initial=initial,directions=list(ram[s['player_input']+0x1ab:s['player_input']+0x1bb]),
                      action_entries=action_entries,action_classes=list(ram[s['player_begin']+0xf4:s['player_begin']+0x106]),
                      attack_delays=list(ram[s['player_input']+0x1a3:s['player_input']+0x1ab]),
                      fire_headings=list(ram[s['player_input']+0x147:s['player_input']+0x14f]),
                      actions=graph,enemy_entries=enemy_entries,frames=frames,**movement)
        write_json(out/'world.json',world);write_json(out/'gameplay.json',gameplay)
        # A small contact sheet checks source body assembly before bulk import.
        sheet=Image.new('RGB',(8*96,4*96),(172,172,172))
        shared=tuple(v&15 for v in (ROOT/f'source/local/captures/ln2-level{level}-vic.bin').read_bytes()[0x25:0x27])
        world['shared_sprite_colours']=list(shared);write_json(out/'world.json',world)
        for i in range(32):
            image=composition(ram,s,frames[i%len(frames)],i//16,shared=shared)
            sheet.paste(image,(i%8*96,i//8*96),image)
        sheet.save(out/'actor-contact.png')
        record=dict(level=level,title=NAMES[level-1],rooms=len(rooms),perimeter_reachable=len(reachable),
                    enemies=sum(r['enemy']['active']>=128 for r in rooms),item_interaction_records=len(items),
                    action_records=len(graph),hazard_types=hazards,
                    item_handlers=sorted({i['handler'] for i in items if i['handler']}),
                    source_sha256=world['source_sha256'],native_gameplay_connected=False)
        reports.append(record);print(record,flush=True)
    write_json(ROOT/'evidence/ln2_content_recovery.json',dict(levels=reports,full_gameplay_parity=False,
        source='Seven original-game loader captures from the supplied disks',offline_only=True))

if __name__=='__main__':main()
