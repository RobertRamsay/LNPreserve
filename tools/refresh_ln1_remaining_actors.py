"""Repair the remaining stale LN1 special bank and share original guard colours."""
from build_project import ROOT,PROJECT,read_json,write_json
import build_project as builder
from fix_ln1_dungeon_art import original_pose
from export_ln1_levels import register_project


def main():
    dungeon=read_json(PROJECT/'datafiles/play/ln1/level4/world.json')
    reference=(ROOT/'source/local/captures/ln1-level4-ram.bin').read_bytes()
    builder.REFRESH_GRAPHICS=True
    records=[]
    for level in range(1,7):
        folder=PROJECT/('datafiles/play/ln1' if level==1 else f'datafiles/play/ln1/level{level}')
        world=read_json(folder/'world.json')
        ram=(ROOT/('source/local/captures/ln1-game-ram.bin' if level==1 else f'source/local/captures/ln1-level{level}-ram.bin')).read_bytes()
        # All these bank bytes drive the shared ordinary guard compositor.
        for lo,hi in [(0x7655,0x7796),(0x6ff1,0x6ff9),(0x8000,0x9e00),(0xd000,0xd700)]:
            assert ram[lo:hi]==reference[lo:hi],(level,hex(lo))
        world['enemy_colour_bank']=dungeon['enemy_colour_bank']
        world['enemy_colour_frames']=dungeon['enemy_colour_frames']
        if level==6:
            frames=sorted(map(int,world['actor_frames']))
            images=[original_pose(ram,f,mirror) for mirror in range(2) for f in frames]
            name='spr_ln1_level6_actors';path=folder/(name+'.png');images[0].save(path)
            resource=builder.sprite_resource(name,path,'Graphics/ln1_game_level6',images)
            yy=PROJECT/f'sprites/{name}/{name}.yy';meta=read_json(yy)
            meta['origin']=9;meta['sequence']['xorigin']=48;meta['sequence']['yorigin']=64;write_json(yy,meta)
            world['actor_frames']={str(f):dict(sprite=name,index=i,mirror_offset=len(frames)) for i,f in enumerate(frames)}
            register_project({name:resource},[])
            from PIL import Image
            for i,im in enumerate(images):
                saved=Image.open(yy.parent/(meta['frames'][i]['name']+'.png')).convert('RGBA')
                assert im.tobytes()==saved.tobytes()
            records.append(dict(level=level,original_special_pose_pngs_verified=len(images)))
        write_json(folder/'world.json',world)
    write_json(ROOT/'evidence/ln1_remaining_actor_refresh.json',dict(
        original_uniform_bank_shared_by_levels=[1,2,3,4,5,6],special_banks=records,
        full_playthrough_verified=False))
    print(records)


if __name__=='__main__':main()
