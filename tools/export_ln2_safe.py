"""Recover final-room interaction drawing from the supplied LN2 capture.

Room entry alone cannot show these panels. Replay the original successful
interaction panel pointers in order; do not infer their pixels from previews.
"""
from build_project import ROOT, PROJECT, read_json, write_json, sprite_resource
from ln2_level_source import level_memory, layout
from export_ln1_world import call
from export_ln2_content import bitmap
from export_ln1_levels import register_project
from PIL import Image
import hashlib

def main():
    ram=level_memory(7);source=layout(ram)
    world=read_json(PROJECT/'datafiles/play/ln2/level7/world.json')
    assert hashlib.sha256(ram).hexdigest()==world['source_sha256']
    mem=list(ram);mem[0xa2]=1;mem[0x3d8:0x3f2]=[0]*26
    for address in (0x140e,source['scene_choose'],source['item_enter']):call(mem,address)
    # The first original reveal step is the lowered curtain, not the bare wall.
    lowered=mem.copy();lowered[0x700:0x707]=list(ram[0xb452:0xb458])+[255]
    lowered[2]=0;lowered[3]=7;call(lowered,0x7e8a)
    images=[bitmap(lowered)];changes=[]
    for item_id in (17,18,16,23):
        item=next(i for i in world['items'] if i['id']==item_id)
        pointer=item['removed_panel'];mem[2]=pointer&255;mem[3]=pointer>>8
        # $b160 calls the panel renderer at $7e8a after successful interaction.
        assert ram[0xb162:0xb165]==bytes.fromhex('20 8a 7e')
        call(mem,0x7e8a);image=bitmap(mem)
        changes.append(sum(a!=b for a,b in zip(images[-1].get_flattened_data(),image.get_flattened_data())))
        images.append(image)
    assert changes==[1192,244,42,42],changes
    name='spr_ln2_safe_states';temp=ROOT/'build/ln2-safe.png';temp.parent.mkdir(exist_ok=True)
    images[0].save(temp)
    resource=sprite_resource(name,temp,'Graphics/ln2_game_level7',images)
    register_project({name:resource},[])
    meta=read_json(PROJECT/f'sprites/{name}/{name}.yy')
    for record,expected in zip(meta['frames'],images):
        with Image.open(PROJECT/f'sprites/{name}'/(record['name']+'.png')) as saved:
            assert saved.convert('RGBA').tobytes()==expected.tobytes()
    write_json(ROOT/'evidence/ln2_safe_recovery.json',dict(source_sha256=world['source_sha256'],
        interaction_order=[17,18,16,23],changed_pixels=changes,frames_verified=len(images),
        method='Original $7e8a panel drawing after successful interactions',gpu_tested=False))
    print('Verified five original safe stages:',changes)

if __name__=='__main__':main()
