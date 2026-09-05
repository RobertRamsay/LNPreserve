"""Extract the first game's actor composition and gameplay tables for native GML.

This does not execute a C64 inside GameMaker. Addresses are provenance for data
tables and named state fields; gameplay is implemented in ln1_player.gml.
"""
from pathlib import Path
import hashlib,json
from PIL import Image,ImageDraw
from extract_ln1_actors import unpack,sprite_image,ROOT
from build_project import sprite_resource,read_json,write_json

FIELDS={
 'fraction_x':0x50,'fraction_y':0x51,'x':0x54,'y':0x55,
 'countdown':0x58,'duration':0x59,'flags':0x5c,'action_mirror':0x5d,
 'action_state':0x64,'frame':0x65,'heading':0x68,'facing':0x69,
 'stopped':0x6c,'combat_state':0x6d,'weapon':0x70,'fire_previous':0x78,
 'walk_clock':0x7b,'saved_heading':0x96,'redraw':0x9f,
 'attack_direction':0xa6,'attack_clock':0xa7,'attack_previous':0xa8,
 'input_lock':0xb6,'enemy_active':0xcb,'collision':0xcd,'selected_weapon':0xd6,
 'separation_y':0xd9,'last_tick':0x26c,'turn_lock':0x2b8,
 'boundary_mode':0x2b5,'boundary_crossings':0x2b6,
}

def composition(ram,frame,mirror,weapon=0,enemy=False):
    canvas=Image.new('RGBA',(96,96))
    if frame==255:return canvas
    base=0xd000+frame*32 if frame<64 else (0xd700+(frame-64)*16 if frame<128 else 0xd800+(frame&127)*16)
    width=ram[base+3]*2 if frame<64 else (ram[base+1]*2 if ram[base]==255 else 16)
    # Hardware sprite 0 wins overlap over sprite 1, so composite back to front.
    offsets=([16 if enemy else 4,8,12]+([16+weapon*4] if weapon else [])) if frame<64 else [0,4,8,12]
    for offset in reversed(offsets):
        part,xb,yb,flags=ram[base+offset:base+offset+4]
        if part==255:continue
        if xb&128:raw=ram[0x9e00+part*64:0x9e00+part*64+63]
        else:raw,_=unpack(ram,ram[0x8000+part]+256*ram[0x80c0+part])
        img=sprite_image(raw,bool(flags&128),flags&15)
        if flags&96:img=img.resize((24*(2 if flags&64 else 1),21*(2 if flags&32 else 1)),Image.Resampling.NEAREST)
        dx=(xb&127)-48
        if mirror:
            dx=width-dx-(24 if flags&64 else 0)
            img=img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        dy=yb if yb<128 else yb-256
        canvas.alpha_composite(img,(48+dx-24,64+dy-50))
    return canvas

def main():
    ram=(ROOT/'source/local/captures/ln1-game-ram.bin').read_bytes()
    out=ROOT/'LNPreserve/datafiles/play/ln1';out.mkdir(parents=True,exist_ok=True)
    state={name:ram[address] for name,address in FIELDS.items()}
    state.update(action=ram[0x60]+256*ram[0x61],enemy_x=ram[0x56],enemy_y=ram[0x57],mirror=0,
                 tick=ram[0x1b])
    boundaries=[]
    for address in range(0x334,0x3ec,5):
        if ram[address+1]==0:break
        boundaries.append(list(ram[address:address+5]))
    # Decode the game's animation command stream into editable records.
    # Follow every action entry and branch. No CPU opcodes enter the runtime.
    entries=[ram[a]+256*ram[a+1] for a in range(0x58d4,0x5920,2)]
    enemy_entries=[ram[a]+256*ram[a+1] for a in range(0x4fc2,0x4ffa,2)]
    reactions=[ram[a]+256*ram[a+1] for a in range(0x5118,0x5130,2)]
    world=read_json(out/'world.json')
    pending=entries+enemy_entries+reactions+[0x5d34,0xada5,0xadbd]+[r['enemy_script'] for r in world['rooms']];records={}
    while pending:
        address=pending.pop()
        if address==0 or str(address) in records:continue
        cursor=address;flags=ram[cursor];cursor+=1
        duration=ram[cursor] if flags&2 else -1;cursor+=bool(flags&2)
        frame=ram[cursor];cursor+=1
        dx=dy=0
        if flags&128:dx,dy=ram[cursor:cursor+2];cursor+=2
        state_id=-1;combat_data=-1
        if flags&1:
            state_id=ram[cursor];cursor+=1
            if 16<=state_id<32:combat_data=ram[cursor];cursor+=1
        following=ram[cursor]+256*ram[cursor+1] if flags&32 else cursor
        records[str(address)]=dict(flags=flags,duration=duration,frame=frame,dx=dx,dy=dy,
            state=state_id,combat_data=combat_data,next=following)
        pending.append(following)
        if len(records)>512:raise ValueError('Unexpected animation graph')
    data=dict(schema=1,source_sha256=hashlib.sha256(ram).hexdigest(),initial=state,boundaries=boundaries,
        directions=list(ram[0x58c4:0x58d4]),action_entries=entries,action_classes=list(ram[0x5920:0x5933]),
        actions=records,left=list(ram[0x7635:0x7639]),right=list(ram[0x7639:0x763d]),
        up=list(ram[0x763d:0x7641]),down=list(ram[0x7641:0x7645]),
        double_y=list(ram[0x7645:0x7649]),no_y=list(ram[0x7649:0x764d]),
        forward=list(ram[0x764d:0x7651]),mirror=list(ram[0x7651:0x7655]),
        timer_period_cycles=18433,enemy_entries=enemy_entries,reactions=reactions,
        speed_x=[ram[0x7536+i]*256+ram[0x752c+i] for i in range(5)],
        speed_y=[ram[0x753b+i]*256+ram[0x7531+i] for i in range(5)],
        attack_x_min=list(ram[0x7e78:0x7e8d]),attack_x_max=list(ram[0x7e8d:0x7ea2]),
        attack_y_min=list(ram[0x7ea2:0x7eb7]),attack_y_max=list(ram[0x7eb7:0x7ecc]),
        player_damage=list(ram[0x781b:0x7830]),enemy_damage=list(ram[0x782f:0x7844]),
        random_table=list(ram[0x5400:0x8000]))
    write_json(out/'gameplay.json',data)
    project_path=ROOT/'LNPreserve/LNPreserve.yyp';project=read_json(project_path)
    resources={r['id']['name']:r for r in project['resources']}
    sheet=Image.new('RGB',(16*96,8*96),(174,174,174))
    for enemy in [False,True]:
        for weapon in range(4):
            images=[composition(ram,frame,mirror,weapon,enemy) for mirror in range(2) for frame in range(64)]
            name=f"spr_ln1_{'enemy' if enemy else 'player'}_weapon_{weapon}"
            source=out/f'{name}.png';images[0].save(source)
            resources[name]=sprite_resource(name,source,'Graphics/ln1_character_parts',images)
            yy=ROOT/'LNPreserve/sprites'/name/f'{name}.yy';meta=read_json(yy)
            meta['origin']=9;meta['sequence']['xorigin']=48;meta['sequence']['yorigin']=64;write_json(yy,meta)
            if not enemy and weapon==0:
                for index,img in enumerate(images):sheet.paste(img,(index%16*96,index//16*96),img)
    sheet.save(ROOT/'evidence/ln1_assembled_player.png')
    extras=[composition(ram,frame,mirror,0,True) for mirror in range(2) for frame in range(64,128)]
    name='spr_ln1_actor_extra';source=out/f'{name}.png';extras[0].save(source)
    resources[name]=sprite_resource(name,source,'Graphics/ln1_character_parts',extras)
    yy=ROOT/'LNPreserve/sprites'/name/f'{name}.yy';meta=read_json(yy)
    meta['origin']=9;meta['sequence']['xorigin']=48;meta['sequence']['yorigin']=64;write_json(yy,meta)
    project['resources']=list(resources.values());write_json(project_path,project)
    print(f'Exported 1024 assembled actor poses, {len(records)} action records, {len(boundaries)} room boundaries.')

if __name__=='__main__':
    import argparse,build_project
    parser=argparse.ArgumentParser();parser.add_argument('--refresh',action='store_true');args=parser.parse_args()
    build_project.REFRESH_GRAPHICS=args.refresh
    main()
