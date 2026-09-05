"""Recover first-level rooms using original drawing and boundary decompression.

The 6502 runs offline only. The runtime receives PNGs and decoded room tables.
"""
import json,sys
from pathlib import Path
from PIL import Image
from export_ln1_play import ROOT
from decode_graphics import PALETTE,decode_dataset,render_panel
import build_project as builder
sys.path.insert(0,str(ROOT/'tools/vendor/pydeps'))
from py65.devices.mpu6502 import MPU

def call(mem,address,a=0,x=0):
    cpu=MPU(memory=mem,pc=address);cpu.sp=0xfd;mem[0x1fe:0x200]=[0xfe,1]
    cpu.a=a;cpu.x=x
    for _ in range(2000000):
        if cpu.pc==0x1ff:return
        cpu.step()
    raise AssertionError(f'Original routine ${address:04x} did not return, PC=${cpu.pc:04x}')

def bitmap(mem,width=240,height=144):
    image=Image.new('RGBA',(width,height))
    for y in range(height):
        for x in range(width):
            cell=(y//8)*40+x//8
            code=(mem[0xe000+cell*8+y%8]>>(6-(x%8//2)*2))&3
            colours=[mem[0x32]&15,mem[0xc000+cell]>>4,mem[0xc000+cell]&15,mem[0xc400+cell]&15]
            image.putpixel((x,y),(*PALETTE[colours[code]],255))
    return image

def main():
    ram=(ROOT/'source/local/captures/ln1-game-ram.bin').read_bytes()
    # Parser is used only for raw occluder object shapes. Scenery is rendered by
    # the original routines, including their attribute-cell merge decisions.
    reference=next((ROOT/'tools/vendor/integrator-ln').rglob('int-level1-tape.prg'))
    dataset,_=decode_dataset(reference.read_bytes(),1)
    folder=ROOT/'LNPreserve/datafiles/play/ln1';project_path=ROOT/'LNPreserve/LNPreserve.yyp'
    project=builder.read_json(project_path);resources={r['id']['name']:r for r in project['resources']}
    rooms=[];spawn_scripts=[]
    for room_id in range(1,26):
        mem=list(ram);mem[0xa2]=room_id
        for entry in (0x5452,0x5dfe,0x6765,0xbdbb,0xadc6):call(mem,entry)
        boundaries=[]
        for pos in range(0x334,0x3ec,5):
            if mem[pos+1]==0:break
            boundaries.append(mem[pos:pos+5])
        name=f'spr_ln1_wastelands_room_{room_id:02d}'
        source=folder/f'{name}.png';bitmap(mem).save(source)
        resources[name]=builder.sprite_resource(name,source,'Graphics/ln1_game_level1')
        masks=[];offset=ram[0xdf00+room_id];depth_mask=Image.new('RGBA',(240,144))
        if ram[0xdf20+offset]:
            for index in range(32):
                part,baseline,cx,cy=ram[0xdf20+offset:0xdf24+offset]
                if not part:break
                obj=dataset['objects'].get(str(part))
                if obj is None:raise ValueError(f'Occlusion object {part} is not a bitmap')
                mask=Image.new('RGBA',(240,144))
                for y in range(obj['height']):
                    for x in range(obj['width']):
                        cell=y//8*(obj['width']//8)+x//8
                        code=(obj['bitmap'][cell*8+y%8]>>(6-(x%8//2)*2))&3
                        dx=cx*8+x;dy=(cy&127)*8+y
                        if code and dx<240 and dy<144:
                            mask.putpixel((dx,dy),(255,255,255,255))
                            depth_mask.putpixel((dx,dy),(255,255,255,max(baseline,depth_mask.getpixel((dx,dy))[3])))
                mask_name=f'{name}_occluder_{index}';mask_path=folder/f'{mask_name}.png';mask.save(mask_path)
                resources[mask_name]=builder.sprite_resource(mask_name,mask_path,'Graphics/ln1_game_level1')
                masks.append(dict(sprite=mask_name,baseline=baseline,source_offset=offset))
                if cy&128:break
                offset+=4
        depth_name=f'{name}_depth';depth_path=folder/f'{depth_name}.png';depth_mask.save(depth_path)
        resources[depth_name]=builder.sprite_resource(depth_name,depth_path,'Graphics/ln1_game_level1')
        enemy_script=mem[0x62]+mem[0x63]*256
        spawn_scripts.append(enemy_script)
        # $bdbb initializes the special-boundary state separately for each entrance.
        crossings=[]
        for entrance in range(4):
            mem[0x278]=entrance;call(mem,0xbdbb);crossings.append(mem[0x2b6])
        rooms.append(dict(id=room_id,sprite=name,depth_sprite=depth_name,boundaries=boundaries,occluders=masks,
            exit_thresholds=list(ram[0xaf00+room_id*8:0xaf04+room_id*8]),
            exits=list(ram[0xaf04+room_id*8:0xaf08+room_id*8]),
            boundary_mode=mem[0x2b5],entrance_crossings=crossings,enemy_script=enemy_script))
        print('Room',room_id,'boundaries',len(boundaries),'occluders',len(masks),flush=True)
    items=[]
    from extract_ln1_actors import unpack,sprite_image
    for pos in range(0x537b,0x53c1,10):
        room_id,item_id,x0,x1,y0,y1,part,flags,x,y=ram[pos:pos+10]
        raw,_=unpack(ram,ram[0x8000+part]+256*ram[0x80c0+part])
        img=sprite_image(raw,bool(flags&128),flags&15)
        if flags&32:img=img.resize((24,42),Image.Resampling.NEAREST)
        name=f'spr_ln1_pickup_{item_id}';source=folder/f'{name}.png';img.save(source)
        resources[name]=builder.sprite_resource(name,source,'Graphics/ln1_game_level1')
        # Preserve the editable base sprite; the colour ramp changes only the
        # original sprite's individual VIC colour ($5671 / $6fc1).
        flash=[]
        for index in range(31,0,-1):
            frame=sprite_image(raw,bool(flags&128),ram[0x6fc1+index])
            if flags&32:frame=frame.resize((24,42),Image.Resampling.NEAREST)
            flash.append(frame)
        flash_name=name+'_flash'
        resources[flash_name]=builder.sprite_resource(flash_name,source,'Graphics/ln1_game_level1',flash)
        items.append(dict(room=room_id,id=item_id,x_min=x0,x_max=x1,y_min=y0,y_max=y1,sprite=name,
            flash_sprite=flash_name,flashes=0 if flags&16 else 2,x=x-24,y=y-50))
    safe_areas=[]
    for region in range(4):
        address=0xdc00+ram[0xdc00+region];rectangles=[]
        for _ in range(64):
            if ram[address]==255:break
            rectangles.append(list(ram[address:address+4]));address+=4
        safe_areas.append(rectangles)
    hint=[];cursor=0x53c8+ram[0x53c2]
    while ram[cursor]<128:hint.append(ram[cursor]);cursor+=1
    world=dict(rooms=rooms,items=items,safe_areas=safe_areas,prayer_hint_items=hint,initial_entry=ram[0x278],initial_lives=ram[0x9b],initial_inventory=list(ram[0x3ec:0x3fd]),entry_index=list(ram[0xff3c:0xffb8]),entry_x=list(ram[0xffb8:0xffd8]),
        entry_y=list(ram[0xffd8:0xfff8]),entry_heading=list(ram[0xafe0:0xb000]))
    builder.write_json(folder/'world.json',world)
    project['resources']=list(resources.values());builder.write_json(project_path,project)
    # Retain original dashboard as a separate editable sprite.
    # The dashboard uses raster-dependent display attributes. Preserve its
    # captured original pixels until the dynamic dashboard is fully translated.
    ui=Image.open(ROOT/'source/local/captures/ln1_game.png').convert('RGBA').crop((32,35,352,235))
    ui.paste((0,0,0,0),(0,0,240,144))
    source=folder/'dashboard.png';ui.save(source)
    resources['spr_ln1_dashboard']=builder.sprite_resource('spr_ln1_dashboard',source,'Graphics/ln1_game_level1')
    # Render live dashboard parts with the supplied game's own drawing routines.
    for name,count,routine,box in [
        ('spr_ln1_status_label',3,None,(248,64,312,72)),
        ('spr_ln1_status_icon',16,0x63cb,(248,80,312,96)),
        ('spr_ln1_enemy_wounds',33,0x7c4c,(248,24,312,32))]:
        frames=[]
        for index in range(count):
            mem=list(ram)
            if routine==0x7c4c:mem[0x2b9]=index
            call(mem,[0x69e4,0x69dc,0x69e0][index] if routine is None else routine,a=index)
            frames.append(bitmap(mem,320,200).crop(box))
        source=folder/(name+'.png');frames[0].save(source)
        resources[name]=builder.sprite_resource(name,source,'Graphics/ln1_game_level1',frames)
    # Editable presentation approximation; no separate splash sequence has been
    # identified in the original $bef2 sinking routine. Keep provenance explicit.
    from PIL import ImageDraw
    frames=[]
    for width,rise in [(8,3),(14,5),(20,3),(24,1)]:
        frame=Image.new('RGBA',(28,12));draw=ImageDraw.Draw(frame)
        draw.ellipse((14-width//2,6,14+width//2,10),outline=(*PALETTE[3],255))
        for dx in (-width//3,width//3):draw.line((14+dx,6-rise,14+dx,7-rise),fill=(*PALETTE[1],255))
        frames.append(frame)
    name='spr_ln1_water_ripple';source=folder/(name+'.png');frames[0].save(source)
    resources[name]=builder.sprite_resource(name,source,'Graphics/ln1_game_level1',frames)
    project['resources']=list(resources.values());builder.write_json(project_path,project)

if __name__=='__main__':
    import argparse,build_project
    parser=argparse.ArgumentParser();parser.add_argument('--refresh',action='store_true');args=parser.parse_args()
    build_project.REFRESH_GRAPHICS=args.refresh
    main()
