"""Execute only the reference decoder's rendering code in an offline x64 sandbox.

GTK model access is supplied from decoded records. No Windows executable, GUI,
file access, or emulator becomes part of GameMaker. This checks rendering, not
the parser or identity with a supplied C64 disk edition.
"""
from pathlib import Path
import hashlib,struct,sys
from PIL import Image
from decode_graphics import ROOT,PALETTE
sys.path.insert(0,str(ROOT/'tools/vendor/pydeps'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
from inspect_reference import symbols

class SceneOracle:
    def __init__(self,game):
        tag='ln' if game==1 else f'ln{game}'
        path=next((ROOT/f'tools/vendor/integrator-{tag}').rglob('int-decoder.exe'))
        raw=path.read_bytes();pe=pefile.PE(data=raw)
        self.sha256=hashlib.sha256(raw).hexdigest();self.game=game
        self.base=pe.OPTIONAL_HEADER.ImageBase
        self.names={n:self.base+a for n,a,t in symbols(pe,raw)}
        mapped=pe.get_memory_mapped_image()
        self.uc=Uc(UC_ARCH_X86,UC_MODE_64);self.uc.mem_map(self.base,(len(mapped)+4095)&~4095)
        self.uc.mem_write(self.base,mapped)
        self.uc.mem_map(0x200000000,0x200000)
        self.uc.mem_map(0x300000000,0x400000)
        self.stop=0x200001000;self.resume=0x200001010
        self.uc.mem_write(self.stop,b'\x90'*32)
        self.uc.hook_add(UC_HOOK_CODE,self.on_resume,begin=self.resume,end=self.resume)
        handlers={'gtk_tree_model_get':self.model_get,'gtk_tree_model_foreach':self.foreach,
            'objects_get_data_at_index':self.object_data,'panels_is_panel_empty_at_index':self.panel_empty,
            'panels_get_from_array_at_index':self.panel_get,'pixbufs_fill_from_hires_data_opaque':self.ignore}
        for name,handler in handlers.items():
            address=self.names[name]
            self.uc.hook_add(UC_HOOK_CODE,lambda uc,a,s,u,h=handler:h(),begin=address,end=address)
        self.uc.mem_write(self.names['options_incremental_rendering'],bytes(4))

    def reg(self,reg):return self.uc.reg_read(reg)
    def set(self,reg,value):self.uc.reg_write(reg,value)
    def qword(self,address):return struct.unpack('<Q',self.uc.mem_read(address,8))[0]
    def alloc(self,data):
        pointer=self.heap;self.heap+=(len(data)+15)&~15
        if self.heap>=0x300400000:raise ValueError('Reference heap exhausted')
        self.uc.mem_write(pointer,bytes(data));return pointer
    def ret(self,value=0):
        sp=self.reg(UC_X86_REG_RSP);pc=self.qword(sp)
        self.set(UC_X86_REG_RAX,value);self.set(UC_X86_REG_RSP,sp+8);self.set(UC_X86_REG_RIP,pc)
    def ignore(self):self.ret()
    def panel_empty(self):self.ret(int(self.reg(UC_X86_REG_RCX) not in self.panels))
    def panel_get(self):self.ret(self.panels[self.reg(UC_X86_REG_RCX)])
    def object_data(self):
        pointer=self.objects[self.reg(UC_X86_REG_RCX)]
        self.uc.mem_write(self.reg(UC_X86_REG_RDX),struct.pack('<Q',pointer));self.ret()
    def model_get(self):
        row=self.rows[self.reg(UC_X86_REG_RDX)]
        values={0:row['object'],1:int(str(row['object']) in self.dataset['objects']),2:1,
            3:int(row.get('flip_x',False)),4:int(bool(row['recolour'])),5:row['x'],6:row['y'],7:len(row['recolour'])}
        values.update({8+i:v for i,v in enumerate(row['recolour'])})
        if self.game==1:
            values={0:row['object'],1:int(str(row['object']) in self.dataset['objects']),2:1,
                3:int(bool(row['recolour'])),4:row['x'],5:row['y'],6:len(row['recolour'])}
            values.update({7+i:v for i,v in enumerate(row['recolour'])})
        args=[self.reg(UC_X86_REG_R8),self.reg(UC_X86_REG_R9)]
        sp=self.reg(UC_X86_REG_RSP)
        args.extend(self.qword(sp+0x28+i*8) for i in range(24))
        for i in range(0,len(args)-1,2):
            column=args[i]&0xffffffff
            if column==0xffffffff:break
            self.uc.mem_write(args[i+1],struct.pack('<i',values.get(column,0)))
        self.ret()
    def foreach(self):
        sp=self.reg(UC_X86_REG_RSP)
        frame=dict(model=self.reg(UC_X86_REG_RCX),function=self.reg(UC_X86_REG_RDX),
            context=self.reg(UC_X86_REG_R8),sp=sp,return_pc=self.qword(sp),index=0)
        self.calls.append(frame);self.next_row()
    def next_row(self):
        frame=self.calls[-1];rows=self.models[frame['model']]
        if frame['index']>=len(rows):
            self.calls.pop();self.set(UC_X86_REG_RSP,frame['sp']+8)
            self.set(UC_X86_REG_RIP,frame['return_pc']);self.set(UC_X86_REG_RAX,0);return
        row=rows[frame['index']];frame['index']+=1
        self.set(UC_X86_REG_RCX,frame['model']);self.set(UC_X86_REG_RDX,0)
        self.set(UC_X86_REG_R8,row);self.set(UC_X86_REG_R9,frame['context'])
        self.set(UC_X86_REG_RSP,frame['sp']);self.uc.mem_write(frame['sp'],struct.pack('<Q',self.resume))
        self.set(UC_X86_REG_RIP,frame['function'])
    def on_resume(self,uc,address,size,user):self.next_row()

    def render(self,dataset,panel,background):
        self.dataset=dataset;self.heap=0x300000000;self.objects={};self.panels={};self.models={};self.rows={};self.calls=[]
        for key,obj in dataset['objects'].items():
            raw=bytes([(obj['width']//8)<<4 | obj['height']//8]+obj['bitmap']+obj['screen']+obj['colour'])
            self.objects[int(key)]=self.alloc(raw)
        for key,p in dataset['panels'].items():
            model=self.alloc(bytes(16));self.panels[int(key)]=model;rows=[]
            for row in p['entries']:
                pointer=self.alloc(bytes(16));self.rows[pointer]=row;rows.append(pointer)
            self.models[model]=rows
        bitmap=self.alloc(bytes(8000));screen=self.alloc(bytes(1000));colour=self.alloc(bytes(1000))
        context=bytearray(0x48);struct.pack_into('<I',context,0x18,1)
        pointer_offset=0x20 if self.game==1 else 0x28
        struct.pack_into('<QQQ',context,pointer_offset,bitmap,screen,colour);context[pointer_offset+24]=background
        context=self.alloc(context);sp=0x2001fff00-8
        self.uc.mem_write(sp,struct.pack('<Q',self.stop))
        self.set(UC_X86_REG_RSP,sp);self.set(UC_X86_REG_RCX,self.panels[panel])
        self.set(UC_X86_REG_RDX,self.names['foreach_render_panel_defs']);self.set(UC_X86_REG_R8,context)
        try:self.uc.emu_start(self.names['gtk_tree_model_foreach'],self.stop,count=20000000)
        except Exception as error:raise RuntimeError(f'Reference stopped at {self.reg(UC_X86_REG_RIP):x}: {error}') from error
        if self.reg(UC_X86_REG_RIP)!=self.stop:raise RuntimeError('Reference instruction bound reached')
        width=struct.unpack('<I',self.uc.mem_read(self.names['location_width'],4))[0]
        height=struct.unpack('<I',self.uc.mem_read(self.names['location_height'],4))[0]
        bits=self.uc.mem_read(bitmap,8000);scr=self.uc.mem_read(screen,1000);col=self.uc.mem_read(colour,1000)
        pixels=[]
        for y in range(height):
            for x in range(width):
                cell=y//8*(width//8)+x//8;code=(bits[cell*8+y%8]>>(6-(x%8//2)*2))&3
                pixels.append([background,scr[cell]>>4,scr[cell]&15,col[cell]&15][code])
        result=Image.new('RGBA',(width,height));result.putdata([(*PALETTE[p],255) for p in pixels])
        return result

if __name__=='__main__':
    import argparse
    from decode_graphics import decode_dataset
    parser=argparse.ArgumentParser();parser.add_argument('--game',type=int,default=3)
    parser.add_argument('--level',type=int,default=1);parser.add_argument('--scene',type=int,default=0);args=parser.parse_args()
    tag='ln' if args.game==1 else f'ln{args.game}'
    p=next((ROOT/f'tools/vendor/integrator-{tag}').rglob(f'int-level{args.level}-tape.prg'))
    dataset,_=decode_dataset(p.read_bytes(),args.game);loc=next(r for r in dataset['locations'] if r['id']==args.scene)
    oracle=SceneOracle(args.game);im=oracle.render(dataset,loc['panel'],loc['background'])
    out=ROOT/f'build/reference-ln{args.game}-level{args.level}-scene{args.scene}.png';im.save(out);print(out)
