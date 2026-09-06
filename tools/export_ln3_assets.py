"""Recover LN3 part PNGs and scene occlusion from the supplied game routines.

The offline mask comparison uses solid original sprite bytes so every occluded
pixel can be checked independently of a particular animation pose.
"""
import hashlib,json,random
from PIL import Image
from build_project import ROOT,write_json,read_json
from ln3_level_source import level_memory,layout,word
from export_ln1_world import call
from export_ln3_content import render_scene
from extract_ln1_actors import sprite_image

def depth_image(ram,room):
    image=Image.new('RGBA',(240,144))
    for mask in room['masks']:
        p=word(ram,0x843+2*mask['part'])&32767;width=ram[p]>>4;height=ram[p]&15
        assert width and height,(room['id'],mask)
        baseline=255 if mask['baseline']<0 else mask['baseline']
        for y in range(height*8):
            sy=mask['y']*8-152+y
            if not 0<=sy<144:continue
            for x in range(width*8):
                sx=mask['x']*8-128+x
                if not 0<=sx<240:continue
                cell=y//8*width+x//8;code=(ram[p+1+cell*8+y%8]>>(6-(x%8//2)*2))&3
                if code:image.putpixel((sx,sy),(255,255,255,max(baseline,image.getpixel((sx,sy))[3])))
    return image

def mask_shapes(ram,room):
    result=[]
    for record in room['masks']:
        p=word(ram,0x843+2*record['part'])&32767;width=ram[p]>>4;height=ram[p]&15
        # Include the immediately following data read by the original when a
        # part overlaps the edge of a shape. The loop can read up to four cells.
        raw=list(ram[p+1:p+1+width*height*8+32])
        result.append(dict(x=record['x'],y=record['y'],baseline=record['baseline'],width=width,height=height,bitmap=raw))
    return result

def native_mask(shapes,x,y,foot,spill,rows):
    result=[255]*63;shift=x&6;right=8-shift
    col=(x+128)//8;line=(((y-2)&255)+128)//8;phase=(y-2)&7
    for shape in shapes:
        cx=shape['x'];cy=shape['y'];width=shape['width'];height=shape['height']
        if col<cx or line<cy or (shape['baseline']>=0 and foot>=shape['baseline']):continue
        # The horizontal comparison leaves carry set: ADC #1 therefore adds 2
        # in the original vertical overlap test.
        if width+2+cx<col or height+2+cy<line:continue
        delta=col-cx;mode=min(delta,3);skip=max(delta-3,0)
        count=(width-skip)&255
        if count>=5:count=4
        row_delta=line-cy;row=max(row_delta-3,0);source_y=phase;target=0
        if row_delta<3:
            source_y=0;target=((8-phase)*3+rows[row_delta])&255
            if target>=62:continue
        pointer=(row*width+skip)*8
        while True:
            raw=[0,0,0,spill]
            for i in range(max(1,count)):raw[i]=shape['bitmap'][pointer+source_y+8*i]
            if mode==0:raw=[0,0,raw[0]>>right,raw[3]]
            elif mode==1:
                value=((raw[0]<<8)|raw[1])>>right;raw=[0,(value>>8)&255,value&255,raw[3]]
            elif mode==2:
                value=((raw[0]<<16)|(raw[1]<<8)|raw[2])>>right;raw=[(value>>16)&255,(value>>8)&255,value&255,raw[3]]
            else:
                value=((raw[0]<<24)|(raw[1]<<16)|(raw[2]<<8)|raw[3])<<shift
                raw=[(value>>24)&255,(value>>16)&255,(value>>8)&255,value&255]
            spill=raw[3]
            for i in range(3):
                opaque=0
                for bit in (0,2,4,6):
                    if raw[i]&(3<<bit):opaque|=3<<bit
                result[target+i]&=opaque^255
            target+=3
            if target>=62:break
            source_y=(source_y+1)&7
            if source_y==0:
                row+=1
                if row>=height:break
                pointer+=width*8
    return result,spill

def verify_depth(ram,s,room,image,rng,cases=32):
    checked=0;static_differences=0;shapes=mask_shapes(ram,room)
    for case in range(cases):
        x=rng.randrange(24,242);y=rng.randrange(50,194);foot=rng.choice([0,255,y+21 if y<234 else 255]+[max(0,m['baseline']) for m in room['masks']])
        mem=list(ram);mem[0xe3]=room['id'];mem[0xdc]=1;mem[0x42]=x;mem[0x43]=y;mem[0x45]=foot
        mem[0x63]=rng.randrange(256);spill=mem[0x63]
        mem[0x200:0x23f]=[255]*63;call(mem,s['mask']);raw=mem[0x200:0x23f]
        native,after_spill=native_mask(shapes,x,y,foot,spill,ram[0x58c:0x58f])
        assert native==raw and after_spill==mem[0x63],(room['id'],x,y,foot,spill,after_spill,mem[0x63],next((i for i in range(63) if native[i]!=raw[i]),-1))
        for py in range(21):
            for px in range(24):
                sx=x-24+px;sy=y-50+py
                if not(0<=sx<240 and 0<=sy<144):continue
                depth=image.getpixel((sx-(x&1),sy))[3] if sx-(x&1)>=0 else 0
                expected=not(depth>foot or (depth==255 and foot==255))
                actual=bool(raw[py*3+px//8]&(128>>(px&7)))
                if expected!=actual:static_differences+=1
                checked+=1
    return checked,static_differences

def main():
    reports=[];rng=random.Random(0x61a3)
    for level in range(1,6):
        ram=level_memory(level);s=layout(ram);out=ROOT/f'source/local/recovered/ln3/level{level}';world=read_json(out/'world.json')
        pixels=0;static_differences=0
        for room in world['rooms']:
            image=depth_image(ram,room);checked,different=verify_depth(ram,s,room,image,rng)
            pixels+=checked;static_differences+=different;image.save(out/f'room-{room["id"]:02}-depth.png')
        report=dict(level=level,mask_pixels_compared=pixels,static_depth_disagreements=static_differences,
                    rooms=len(world['rooms']),source_sha256=world['source_sha256'])
        reports.append(report);print(report,flush=True)
    write_json(ROOT/'evidence/ln3_mask_checks.json',dict(levels=reports,scope=__doc__,full_gameplay_parity=False))

if __name__=='__main__':main()
