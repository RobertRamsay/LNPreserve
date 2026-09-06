"""Import original LN3 scenes and editable sprite-part PNGs into one project.

Parts are white alpha images tinted with the original per-part VIC colour at
draw time. Multicolour parts use three editable alpha layers. Identical images
share a frame; identical scenery reuses an existing sprite resource.
"""
import hashlib,json,subprocess
from PIL import Image
import build_project as builder
from build_project import ROOT,PROJECT,read_json,write_json,sprite_resource
from ln3_level_source import level_memory,layout,word
from export_ln1_world import call
from export_ln1_levels import register_project
from make_ln3_action_vectors import action_layout
from make_ln3_animation_vectors import state as animation_state

def original_part(ram,s,frame,part,costume,mirror):
    mem=list(ram);mem[0x2ae+part]=frame;mem[0xdc]=part;mem[0x318]=costume
    mem[0xde]=255 if mirror else 0;call(mem,s['sprite_unpack'],x=part)
    return bytes(mem[0x200:0x23f])

def alpha_image(raw,code=None):
    image=Image.new('RGBA',(24,21));pixels=[]
    for y in range(21):
        for x in range(24):
            byte=raw[y*3+x//8]
            visible=bool(byte&(128>>(x&7))) if code is None else ((byte>>(6-(x%8//2)*2))&3)==code
            pixels.append((255,255,255,255 if visible else 0))
    image.putdata(pixels);return image

def main():
    resources={};included=[];known={};frames=[];frame_ids={};worlds=[];reports=[]
    tracked=set(subprocess.check_output(['git','ls-files'],cwd=ROOT,text=True).splitlines())
    project=read_json(PROJECT/'LNPreserve.yyp')
    for row in project['resources']:
        path=PROJECT/row['id']['path']
        if path.parent.parent.name!='sprites':continue
        meta=read_json(path)
        if len(meta['frames'])!=1 or (meta['sequence']['xorigin'],meta['sequence']['yorigin'])!=(0,0):continue
        with Image.open(path.parent/(meta['frames'][0]['name']+'.png')) as im:
            rgba=im.convert('RGBA');key=(rgba.size,hashlib.sha256(rgba.tobytes()).hexdigest())
        known.setdefault(key,meta['name'])
    def scene_sprite(name,image,folder):
        key=(image.size,hashlib.sha256(image.tobytes()).hexdigest())
        if key in known:return known[key]
        path=ROOT/'build/ln3-import.png';image.save(path)
        builder.REFRESH_GRAPHICS=f'LNPreserve/sprites/{name}/{name}.yy' not in tracked
        resources[name]=sprite_resource(name,path,folder);builder.REFRESH_GRAPHICS=False
        known[key]=name;return name
    def part_frame(image):
        key=hashlib.sha256(image.tobytes()).hexdigest()
        if key not in frame_ids:frame_ids[key]=len(frames);frames.append(image)
        return frame_ids[key]
    for level in range(1,6):
        ram=level_memory(level);s=layout(ram);a=action_layout(ram,s)
        folder=ROOT/f'source/local/recovered/ln3/level{level}';world=read_json(folder/'world.json')
        world['initial']=animation_state(ram,a)
        world['initial'].update(mask_spill=ram[0x63],waterline=ram[0x2f5],multicolour=ram[0x2d4],expand_x=ram[0x2d5],expand_y=ram[0x2d6])
        special=[8,4,6,3,-1][level-1]
        world.update(actor_bank='spr_ln3_actor_parts',part_mapping={},costume_offsets=[0,44,88,132],
                     special_costume_scene=special,special_costume_by_animation=level==2)
        raw_parts={}
        for frame in range(210):raw_parts[frame]=[original_part(ram,s,frame,0,0,m) for m in (False,True)]
        for costume in (1,2):
            for frame in range(166,210):raw_parts[frame+costume*44]=[original_part(ram,s,frame,4,costume,m) for m in (False,True)]
        if level<5:
            sequences=read_json(PROJECT/f'datafiles/play/ln3/level{level}/animation.json')['sequences']
            for frame in sorted({f for seq in sequences[138:] for f in seq['frames']}):
                raw_parts[frame+132]=[original_part(ram,s,frame,4,3,m) for m in (False,True)]
        for physical,raw_pair in sorted(raw_parts.items()):
            choices=[]
            for raw in raw_pair:
                choices.append(dict(hires=part_frame(alpha_image(raw)),
                    multicolour=[part_frame(alpha_image(raw,code)) for code in (1,2,3)] if physical>=298 else []))
            world['part_mapping'][str(physical)]=choices
        for room in world['rooms']:
            room['sprite']=scene_sprite(f'spr_ln3_level{level}_room_{room["id"]:02}',Image.open(folder/f'room-{room["id"]:02}.png').convert('RGBA'),f'Graphics/ln3_game_level{level}')
            # Static depth images are retained only as editable diagnostic art.
            # Native LN3 gameplay uses the verified fragment masking routine.
        worlds.append(world)
        report=dict(level=level,scene_records=len(world['rooms']),physical_parts=len(raw_parts),
                    original_decoder_calls=2*len(raw_parts),source_sha256=world['source_sha256'])
        reports.append(report);print(report,flush=True)
    source=ROOT/'build/ln3-part-import.png';frames[0].save(source);name='spr_ln3_actor_parts'
    builder.REFRESH_GRAPHICS=f'LNPreserve/sprites/{name}/{name}.yy' not in tracked
    resources[name]=sprite_resource(name,source,'Graphics/ln3_game_actors',frames);builder.REFRESH_GRAPHICS=False
    for world in worlds:
        path=PROJECT/f'datafiles/play/ln3/level{world["level"]}/world.json';write_json(path,world);included.append(path)
    register_project(resources,included)
    project=read_json(PROJECT/'LNPreserve.yyp');folder_path='folders/Graphics/ln3_game_actors.yy'
    if not any(f['folderPath']==folder_path for f in project['Folders']):
        item=builder.res('GMFolder','ln3_game_actors');item['folderPath']=folder_path;project['Folders'].append(item)
        write_json(PROJECT/'LNPreserve.yyp',project)
    write_json(ROOT/'evidence/ln3_asset_import.json',dict(levels=reports,unique_part_frames=len(frames),
        scene_sprite_resources_added=len(resources)-1,method=__doc__,native_gameplay_connected=False,full_gameplay_parity=False))
    print(len(frames),'unique editable sprite-part frames',len(resources)-1,'new scene resources')

if __name__=='__main__':main()
