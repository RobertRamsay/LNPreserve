"""Recover the original punched Central Park switch panel, omitted on room entry."""
from pathlib import Path
import argparse
import build_project as builder
from build_project import ROOT,PROJECT,read_json,write_json
from export_ln2_content import bitmap
from export_ln1_world import call
from export_ln1_levels import register_project
from PIL import Image,ImageChops

def main():
    parser=argparse.ArgumentParser();parser.add_argument('capture',type=Path);args=parser.parse_args()
    ram=args.capture.read_bytes();world_path=PROJECT/'datafiles/play/ln2/level1/world.json';w=read_json(world_path)
    source=w['source_layout'];item=next(i for i in w['items'] if i['id']==18 and i['room']==2)
    mem=list(ram);mem[0xa2]=2;mem[0x3d8:0x3f2]=w['initial_inventory'];mem[0x3ea]=0
    call(mem,0x140e);call(mem,source['scene_choose']);call(mem,source['item_enter']);before=bitmap(mem)
    room=next(r for r in w['rooms'] if r['id']==2);meta=read_json(PROJECT/f"sprites/{room['sprite']}/{room['sprite']}.yy")
    old=Image.open(PROJECT/'sprites'/room['sprite']/(meta['frames'][0]['name']+'.png')).convert('RGBA')
    assert old.tobytes()==before.tobytes(),'Current room differs from recovered source'
    pointer=item['removed_panel'];mem[2:4]=[pointer&255,pointer>>8];call(mem,0x8914);after=bitmap(mem)
    changed=[(x,y,before.getpixel((x,y)),after.getpixel((x,y))) for y in range(144) for x in range(240) if before.getpixel((x,y))!=after.getpixel((x,y))]
    assert changed and all(p[3]==(0,0,0,255) for p in changed)
    name='spr_ln2_park_switch_pressed';builder.REFRESH_GRAPHICS=True
    path=ROOT/'build/park-switch-import.png';after.save(path)
    resource=builder.sprite_resource(name,path,'Graphics/ln2_game_level1',[after])
    room['variants'][1]=name;write_json(world_path,w);register_project({name:resource},[])
    print('Restored original black switch:',len(changed),'pixels; bounds',ImageChops.difference(before,after).convert('RGB').getbbox(),flush=True)

if __name__=='__main__':main()
