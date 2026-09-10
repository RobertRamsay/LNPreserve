"""Recover LN2's complete HUD and dynamic panels from original C64 RAM."""
import argparse,hashlib
from pathlib import Path
from PIL import Image,ImageDraw
import build_project as builder
from build_project import ROOT,PROJECT,read_json,write_json
from export_ln1_world import call
from export_ln2_ending import picture
from export_ln1_levels import register_project
from make_ln2_status_vectors import run_until

def screen(mem):
    copy=mem.copy();copy[0xd800:0xdbe8]=copy[0x800:0xbe8];copy[0xd021]=copy[0x32]&15
    return picture(copy)

def main():
    p=argparse.ArgumentParser();p.add_argument('capture',type=Path);a=p.parse_args();ram=a.capture.read_bytes();base=list(ram)
    base[0xd011]=128;base[0x1cc3:0x1cc9]=[27]*6;base[0x292]=255;call(base,0x1cb2)
    for offset in (0,1,10,11,20,21):base[0x1c9a+offset]=27
    base[0x22f]=255;call(base,0x1c88)
    call(base,0xb307,a=0,x=0);call(base,0xb307,a=0,x=1)
    builder.REFRESH_GRAPHICS=True;resources={};data=dict(source_sha256=hashlib.sha256(ram).hexdigest())
    def sprite(name,images):
        path=ROOT/'build/ln2-hud-import.png';images[0].save(path)
        resources[name]=builder.sprite_resource(name,path,'Graphics/ln2_game_level1',images)
        return name
    im=screen(base);ImageDraw.Draw(im).rectangle((0,0,239,143),fill=(0,0,0,0))
    data['dashboard']=sprite('spr_ln2_dashboard',[im])
    icons=[]
    for i in range(17):
        mem=base.copy();call(mem,0xb307,a=i,x=0);icons.append(screen(mem).crop((264,24,304,56)))
    for icon in icons:
        icon.putdata([(r,g,b,0 if (r,g,b)==(0,0,0) else a) for r,g,b,a in icon.convert('RGBA').getdata()])
    data['icons']=sprite('spr_ln2_status_icons',icons)
    labels=[screen(base).crop((248,56,312,64))]
    mem=base.copy();mem[0xa0]=1;mem[0x279]=0;call(mem,0xc1a4);labels.append(screen(mem).crop((248,56,312,64)))
    data['labels']=sprite('spr_ln2_status_labels',labels)
    digits=[]
    for i in range(10):
        mem=base.copy();mem[0x1cc3]=27+i;mem[0x292]=255;call(mem,0x1cb2);digits.append(screen(mem).crop((136,160,144,168)))
    data['digits']=sprite('spr_ln2_status_digits',digits)
    for who,rect in [('player',(64,152,104,192)),('enemy',(16,152,56,192))]:
        images=[]
        for health in range(45):
            mem=base.copy();mem[0xe2]=0;mem[0x2b7]=0;mem[0x229:0x22d]=[0,0,44,44]
            for _ in range(44):run_until(mem,0x1ec7,0x1f2d)
            mem[0x229:0x22b]=[health,health]
            for _ in range(health):run_until(mem,0x1ec7,0x1f2d)
            images.append(screen(mem).crop(rect))
        data[who+'_health']=sprite('spr_ln2_'+who+'_health',images)
        assert images[0].tobytes()!=images[44].tobytes()
    target=PROJECT/'datafiles/play/ln2/hud.json';write_json(target,data);register_project(resources,[target])
    print('Recovered dashboard, 17 icons, 2 labels, 10 digits and 90 health panels')

if __name__=='__main__':main()
