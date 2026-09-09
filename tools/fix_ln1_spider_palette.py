"""Refresh only dungeon spider poses from original compositor/shared colours.

Requires private inputs described by check_ln1_encounters.py. Geometry must
match the committed pose before any image is replaced. No new art is drawn.
"""
from check_ln1_encounters import bank, ROOT
from fix_ln1_dungeon_art import original_pose
from build_project import read_json
from PIL import Image

def main():
    ram=bank(4)
    folder=ROOT/'LNPreserve/sprites/spr_ln1_level4_actors'
    meta=read_json(folder/'spr_ln1_level4_actors.yy')
    world=read_json(ROOT/'LNPreserve/datafiles/play/ln1/level4/world.json')
    pending=[]
    for frame in range(141,145):
        record=world['actor_frames'][str(frame)]
        for mirror in range(2):
            index=record['index']+mirror*record['mirror_offset']
            name=meta['frames'][index]['name']
            expected=original_pose(ram,frame,mirror)
            paths=[folder/(name+'.png')]+list((folder/'layers'/name).glob('*.png'))
            for path in paths:
                with Image.open(path) as old:
                    assert old.getchannel('A').tobytes()==expected.getchannel('A').tobytes(),path
                pending.append((path,expected))
    for path,expected in pending:
        expected.save(path)
        with Image.open(path) as actual:assert actual.tobytes()==expected.tobytes()
    print(f'Verified and refreshed {len(pending)} PNGs (eight poses), geometry unchanged')

if __name__=='__main__':main()
