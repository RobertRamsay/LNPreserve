"""Original final-room candle fragments as shared editable PNG overlays."""
import hashlib,random
from PIL import Image,ImageChops
import build_project as builder
from build_project import ROOT,PROJECT,read_json,write_json
from ln2_level_source import level_memory,layout
from export_ln1_world import call
from export_ln1_levels import register_project
from export_ln2_content import bitmap


def main():
    ram=level_memory(7);s=layout(ram);d=read_json(PROJECT/'datafiles/play/ln2/final_mechanisms.json')
    mem=list(ram);mem[0xa2]=1;call(mem,0x140e);call(mem,s['scene_choose']);call(mem,s['item_enter']);base=bitmap(mem)
    frames=[];ids={};gpu=[];data=dict(sprite='spr_ln2_final_candles',candles=[])
    for candle in range(5):
        phases=[]
        for command in (32,33,34):
            copy=mem.copy();copy[0xb485:0xb488]=[command,d['x'][candle],d['y'][candle]];copy[2:4]=[0x85,0xb4];call(copy,0x7e8a);phases.append(bitmap(copy))
        union=Image.new('L',base.size)
        for im in phases:
            r,g,b,_=ImageChops.difference(base,im).split();union=ImageChops.lighter(union,ImageChops.lighter(r,ImageChops.lighter(g,b)))
        union=union.point(lambda v:255 if v else 0);record=[]
        for phase,im in enumerate(phases):
            overlay=im.copy();overlay.putalpha(union);key=hashlib.sha256(overlay.tobytes()).hexdigest()
            if key not in ids:ids[key]=len(frames);frames.append(overlay)
            record.append(ids[key]);points=[(x,y) for y in range(144) for x in range(240) if union.getpixel((x,y))]
            points=random.Random(candle*3+phase).sample(points,min(96,len(points)))
            gpu.append(dict(candle=candle,phase=phase,samples=[[x,y,*im.getpixel((x,y))[:3]] for x,y in points]))
        data['candles'].append(record)
    source=ROOT/'build/ln2-candle-import.png';frames[0].save(source);name=data['sprite']
    resources={name:builder.sprite_resource(name,source,'Graphics/ln2_game_level7',frames)};included=[]
    for relative,value in [('play/ln2/final_art.json',data),('verification/ln2_candle_gpu.json',dict(vectors=gpu,scope=__doc__))]:
        path=PROJECT/'datafiles'/relative;write_json(path,value);included.append(path)
    register_project(resources,included);print(len(frames),'unique original candle overlays,',sum(len(v['samples']) for v in gpu),'original bitmap samples')


if __name__=='__main__':main()
