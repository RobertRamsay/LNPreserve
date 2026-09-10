"""Rebuild complete LN2 spirit poses from original final-level RAM.

The normal 96x96 actor canvas clips the outward spirits. Keep the original
hardware positions on 160x128 with origin (80,96), and redirect logical poses
without reindexing the editable ninja sheet or changing animation timings.
"""
import hashlib
from decode_graphics import PALETTE
from PIL import Image
import build_project as builder
from build_project import ROOT,PROJECT,read_json,write_json
from export_ln2_content import composition
from export_ln1_levels import register_project

def main():
    ram=(ROOT/'source/local/captures/ln2-level7-ram.bin').read_bytes()
    world=read_json(PROJECT/'datafiles/play/ln2/level7/world.json')
    mapping=PROJECT/'datafiles/graphics/characters.json';assets=read_json(mapping)
    bank=world['enemy_extra_banks']['1_2'];frames=world['enemy_extra_frames']['1_2']
    name='spr_char_ln2_spirits';images=[];vectors=[];redirect={};restored=0
    for mirror in (False,True):
        for frame in range(100,124):
            im=composition(ram,world['source_layout'],frame,mirror,1,2,True,
                tuple(world['shared_sprite_colours']),canvas=(160,128),origin=(80,96))
            # A second, oversized extraction proves the new canvas loses no pixels.
            full=composition(ram,world['source_layout'],frame,mirror,1,2,True,
                tuple(world['shared_sprite_colours']),canvas=(320,256),origin=(160,160))
            assert full.getbbox() and full.crop((80,64,240,192)).tobytes()==im.tobytes()
            assert sum(full.getchannel('A').tobytes())==sum(im.getchannel('A').tobytes())
            pose_id=assets['banks'][bank]['poses'][frames.index(frame)+len(frames)*mirror]
            old=assets['poses'][pose_id]
            if old['sprite']!=name:
                meta=read_json(PROJECT/f"sprites/{old['sprite']}/{old['sprite']}.yy")
                path=PROJECT/'sprites'/old['sprite']/(meta['frames'][old['frame']]['name']+'.png')
                assert Image.open(path).convert('RGBA').tobytes()==im.crop((32,32,128,128)).tobytes()
            new={'sprite':name,'frame':len(images)}
            assert pose_id not in redirect or redirect[pose_id]==new
            redirect[pose_id]=new
            for y in range(128):
                for x in range(160):
                    if not(32<=x<128 and 32<=y<128) and im.getpixel((x,y))[3]:restored+=1
            # Full RGBA fixture catches missing shapes, extra copies and stray pixels.
            rows=[''.join('.' if im.getpixel((x,y))[3]==0 else format(PALETTE.index(im.getpixel((x,y))[:3]),'x') for x in range(160)) for y in range(128)]
            vectors.append(dict(frame=frame,mirror=mirror,rows=rows))
            images.append(im)
    assert restored>0
    builder.REFRESH_GRAPHICS=True
    source=ROOT/'build/ln2-spirit-import.png';images[0].save(source)
    resource=builder.sprite_resource(name,source,'Graphics/Characters',images)
    path=PROJECT/f'sprites/{name}/{name}.yy';meta=read_json(path)
    meta['origin']=9;meta['sequence']['xorigin']=80;meta['sequence']['yorigin']=96;write_json(path,meta)
    for pose_id,new in redirect.items():assets['poses'][pose_id]=new
    write_json(mapping,assets)
    fixture=PROJECT/'datafiles/verification/ln2_spirits_gpu.json'
    write_json(fixture,dict(source_sha256=hashlib.sha256(ram).hexdigest(),restored_pixels=restored,palette=PALETTE,vectors=vectors))
    register_project({name:resource},[fixture])
    print('Rebuilt',len(images),'spirit poses; restored',restored,'clipped opaque pixels')

if __name__=='__main__':main()
