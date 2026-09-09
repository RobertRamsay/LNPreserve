"""Refresh dungeon poses and recover source $777e uniform selection.

Only the dungeon package is changed. PNG frames are shared by pixel content.
"""
import hashlib
import random
from build_project import ROOT, PROJECT, read_json, write_json
import build_project as builder
from export_ln1_play import composition
from export_ln1_levels import register_project
from export_ln1_world import call
from extract_ln1_actors import sprite_image
from PIL import Image


def original_pose(ram,frame,mirror,weapon=0,trait=0,active=133):
    """Execute the supplied $7655 sprite compositor at an unclipped position."""
    mem=list(ram)
    for address,value in [(0x56,120),(0x57,120),(0x72,weapon),(0x9e,255),
                          (0xd4,trait),(0xcb,active),(0x281,0)]:mem[address]=value
    mem[0x218:0x220]=[0]*8;mem[0x210:0x218]=[0]*8
    call(mem,0x7655,a=mirror,x=4,y=frame)
    image=Image.new('RGBA',(96,96))
    for slot in [7,6,5,4]:
        if not mem[0x210+slot]:continue
        address=mem[0x7e0b+slot]+256*mem[0x7e13+slot]
        part=sprite_image(mem[address:address+63],bool(mem[0x238+slot]),mem[0x220+slot]&15)
        if mem[0x228+slot] or mem[0x230+slot]:
            part=part.resize((24*(2 if mem[0x228+slot] else 1),21*(2 if mem[0x230+slot] else 1)),Image.Resampling.NEAREST)
        image.alpha_composite(part,(mem[0x200+slot]+256*mem[0x208+slot]-96,mem[0x210+slot]-106))
    return image


def main():
    ram = (ROOT/'source/local/captures/ln1-level4-ram.bin').read_bytes()
    folder = PROJECT/'datafiles/play/ln1/level4'
    world = read_json(folder/'world.json')
    builder.REFRESH_GRAPHICS = True
    resources = {}
    frames = sorted(world['actor_frames'], key=lambda f: world['actor_frames'][f]['index'])
    images = [original_pose(ram, int(f), mirror) for mirror in range(2) for f in frames]
    name = 'spr_ln1_level4_actors'
    path = folder/(name+'.png'); images[0].save(path)
    resources[name] = builder.sprite_resource(name, path, 'Graphics/ln1_game_level4', images)
    for i, frame in enumerate(frames):
        world['actor_frames'][frame] = dict(sprite=name,index=i,mirror_offset=len(frames))
    unique = []; lookup = {}; indices = []; checks = 0
    for trait in range(8):
        probe = list(ram); probe[0xd4] = trait; probe[0xcb] = 128; probe[0x224] = 0x88
        call(probe, 0x777e)
        colour = probe[0x224] & 15
        assert colour == (ram[0x6ff1+trait] if trait else 8)
        for weapon in range(4):
            for mirror in range(2):
                for frame in range(64):
                    im = original_pose(ram,frame,mirror,weapon,trait,128)
                    digest = hashlib.sha256(im.tobytes()).hexdigest()
                    if digest not in lookup:
                        lookup[digest] = len(unique); unique.append(im)
                    indices.append(lookup[digest]); checks += 1
    name = 'spr_ln1_dungeon_uniforms'
    path = folder/(name+'.png'); unique[0].save(path)
    resources[name] = builder.sprite_resource(name,path,'Graphics/ln1_game_level4',unique)
    for sprite in resources:
        path = PROJECT/f'sprites/{sprite}/{sprite}.yy'; meta = read_json(path)
        meta['origin']=9;meta['sequence']['xorigin']=48;meta['sequence']['yorigin']=64
        write_json(path,meta)
    world['enemy_colour_bank'] = name
    world['enemy_colour_frames'] = indices
    rng=random.Random(10420); vectors=[]
    for i in range(1024):
        mode=4 if i<256 else 6
        px,py,ex,ey=[rng.randrange(1,190) for _ in range(4)]
        if i%8==0: px=ex;py=ey
        mem=list(ram)
        for address,value in [(0x77,mode),(0x54,px),(0x55,py),(0x56,ex),(0x57,ey),
                              (0x6b,1),(0x6a,1),(0x62,0x45),(0x63,0x51),(0xb6,0),(0xd2,0)]:
            mem[address]=value
        call(mem,0xbe75)
        vectors.append(dict(mode=mode,px=px,py=py,ex=ex,ey=ey,
            expected=[mem[0x77],mem[0x6b],mem[0x6a],mem[0x62]+256*mem[0x63],mem[0xb6],mem[0xd2]]))
    world['dungeon_spider_vectors']=vectors
    write_json(folder/'world.json',world)
    register_project(resources,[])
    # Verify the actual saved resource, including all mirrored special poses.
    meta=read_json(PROJECT/'sprites/spr_ln1_level4_actors/spr_ln1_level4_actors.yy')
    for i, expected in enumerate(images):
        path=PROJECT/'sprites/spr_ln1_level4_actors'/(meta['frames'][i]['name']+'.png')
        assert Image.open(path).convert('RGBA').tobytes()==expected.tobytes()
    write_json(ROOT/'evidence/ln1_dungeon_art_checks.json',dict(
        special_pose_pngs_checked=len(images),uniform_pose_selections=checks,
        unique_uniform_pngs=len(unique),source_colour_routine='$777e',spider_source_vectors=len(vectors),
        source_sha256=hashlib.sha256(ram).hexdigest(),full_playthrough_verified=False))
    print('Dungeon special PNGs verified:',len(images),'uniform selections:',checks,'unique PNGs:',len(unique))


if __name__=='__main__':main()
