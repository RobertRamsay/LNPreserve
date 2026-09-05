"""Recover LN1 sprite parts using its original $7e36 decompressor as a test oracle.

py65 runs only in this offline verification tool. The GameMaker game uses PNGs
and native GML. Instruction-cycle counts exclude VIC DMA and interrupt delays.
"""
from pathlib import Path
import hashlib,json,sys
from PIL import Image,ImageDraw
from decode_graphics import PALETTE
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/vendor/pydeps'))
from py65.devices.mpu6502 import MPU

def unpack(data,pointer):
    result=[];cursor=pointer
    while len(result)<63:
        value=data[cursor];cursor+=1
        if value==0xa0:
            result.append(data[cursor]);cursor+=1
        elif 0xa0<value<0xb0:result.extend([0]*(value&15))
        else:result.append(value)
        if cursor-pointer>255:raise ValueError('Encoded sprite exceeds original 8-bit cursor')
    # Parts 189/190 deliberately end with a zero run extending past the sprite.
    # The original routine writes that padding, then tests X >= 63.
    return bytes(result[:63]),cursor-pointer

def original_decode(ram,index):
    memory=list(ram);cpu=MPU(memory=memory,pc=0x7e36);cpu.x=index
    cpu.sp=0xfd;memory[0x1fe]=0xfe;memory[0x1ff]=0x01
    for _ in range(3000):
        if cpu.pc==0x1ff:return bytes(memory[0x2c0:0x2ff]),cpu.processorCycles
        cpu.step()
    raise ValueError(f'Original decompressor failed to return for {index}')

def sprite_image(raw,multicolour=False,colour=0,shared=(7,8)):
    image=Image.new('RGBA',(24,21))
    for y in range(21):
        for x in range(24):
            value=raw[y*3+x//8]
            code=(value>>(6-2*((x%8)//2)))&3 if multicolour else (value>>(7-x%8))&1
            index=[0,shared[0],colour,shared[1]][code] if multicolour else colour
            image.putpixel((x,y),(*PALETTE[index],255 if code else 0))
    return image

def main():
    capture=ROOT/'source/local/captures/ln1-game-ram.bin';ram=capture.read_bytes()
    out=ROOT/'LNPreserve/datafiles/actors/ln1';out.mkdir(parents=True,exist_ok=True)
    parts=[];imgs={}
    for index in range(192):
        pointer=ram[0x8000+index]+256*ram[0x80c0+index]
        decoded,length=unpack(ram,pointer)
        original,cycles=original_decode(ram,index)
        if decoded!=original:raise AssertionError(f'Original decoder disagrees at part {index}')
        name=f'ln1_actor_part_{index:03d}';img=sprite_image(decoded)
        img.save(out/f'{name}.png');imgs[index]=img
        parts.append(dict(id=index,name=name,path=f'datafiles/actors/ln1/{name}.png',pointer=pointer,
            encoded=list(ram[pointer:pointer+length]),decoded=list(decoded),instruction_cycles=cycles,
            status='matches_original_6502_decompressor',palette='black_alpha_hires_part'))
    # Keep all 128 composition records as data. Their full interpretation remains
    # separate from the proven part decoder; these are not animation timings.
    compositions=[dict(id=i,address=0xd800+i*16,raw=list(ram[0xd800+i*16:0xd810+i*16])) for i in range(128)]
    report=dict(schema=1,game=1,source_ram_sha256=hashlib.sha256(ram).hexdigest(),
        source_disk='last_ninja_the_side_a_ccs',parts=parts,compositions=compositions,
        composition_status='raw_records_recovered_not_validated',animation_timing_status='not_recovered',
        cycle_scope='6502 instruction cycles only; excludes bus steals and interrupts')
    (out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    sheet=Image.new('RGB',(768,((len(parts)+23)//24)*38),(180,180,180));draw=ImageDraw.Draw(sheet)
    for i,img in imgs.items():
        x=i%24*32;y=i//24*38;sheet.paste(img,(x,y),img);draw.text((x,y+23),str(i),fill='black')
    sheet.save(ROOT/'evidence/ln1_character_parts.png')
    (ROOT/'evidence/ln1_actor_decoder_checks.json').write_text(json.dumps(dict(
        parts_checked=len(parts),pixel_payload_matches=True,oracle='py65 executing supplied-game bytes at $7e36',
        c64_system_cycle_parity='not_tested',source_ram_sha256=report['source_ram_sha256']),indent=2)+'\n')
    print(f'{len(parts)} PNG sprite parts match the original 6502 decompressor')

if __name__=='__main__':main()
