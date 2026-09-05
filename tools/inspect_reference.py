"""Local technical inspection; output is evidence, never runtime code."""
from pathlib import Path
import argparse,re,struct,sys
sys.path.insert(0,str(Path(__file__).parent/'vendor/pydeps'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_64

def symbols(pe,data):
    start=pe.FILE_HEADER.PointerToSymbolTable
    count=pe.FILE_HEADER.NumberOfSymbols
    strings=start+count*18
    i=0
    while i<count:
        raw=data[start+i*18:start+(i+1)*18]
        if raw[:4]==bytes(4):
            off=strings+struct.unpack_from('<I',raw,4)[0]
            name=data[off:data.find(b'\0',off)].decode('utf-8','replace')
        else:
            name=raw[:8].split(b'\0')[0].decode('utf-8','replace')
        val,section,typ,cls,aux=struct.unpack_from('<IhHBB',raw,8)
        if section>0:
            rva=pe.sections[section-1].VirtualAddress+val
            yield name,rva,typ
        i+=1+aux

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('pattern')
    parser.add_argument('--game',default='ln')
    parser.add_argument('--disassemble',action='store_true')
    parser.add_argument('--data',action='store_true')
    args=parser.parse_args()
    path=next((Path(__file__).parent/f'vendor/integrator-{args.game}').rglob('int-decoder.exe'))
    data=path.read_bytes(); pe=pefile.PE(data=data); syms=list(symbols(pe,data))
    for name,rva,typ in syms:
        if re.search(args.pattern,name):
            print(name,hex(rva),typ)
            if args.data:print(pe.get_data(rva,32).hex(' '))
            if args.disassemble:
                ends=[v for n,v,t in syms if t==32 and v>rva]
                length=min(ends)-rva if ends else 256
                for ins in Cs(CS_ARCH_X86,CS_MODE_64).disasm(pe.get_data(rva,min(length,8192)),pe.OPTIONAL_HEADER.ImageBase+rva):
                    print(hex(ins.address),ins.mnemonic,ins.op_str)
