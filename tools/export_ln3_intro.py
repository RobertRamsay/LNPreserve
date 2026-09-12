"""Encode original indexed PAL intro captures. Args: capture directory, source disk. No emulator in the game."""
from pathlib import Path
import sys,json,struct,hashlib
import numpy as np
root=Path(__file__).resolve().parents[1];project=root/'LNPreserve'
sys.path.insert(0,str(root/'tools'))
import build_project as b
from decode_graphics import PALETTE
src=Path(sys.argv[1]);raw=(src/'frames.bin').read_bytes();timeline=json.loads((src/'timeline.json').read_text())
palette=np.array([(*c,255) for c in PALETTE],dtype=np.uint8)
out=bytearray(struct.pack('<II',0x33494e4c,len(timeline)))
previous=np.zeros((64000,4),dtype=np.uint8);previous[:,3]=255
checks=[]
for tick,frame in enumerate(timeline):
 rgba=palette[np.frombuffer(raw,dtype=np.uint8,count=64000,offset=frame*64000)]
 changed=np.flatnonzero(np.any(previous!=rgba,axis=1))
 runs=[]
 if len(changed):
  start=last=int(changed[0])
  for pos in changed[1:]:
   pos=int(pos)
   if pos-last>5:runs.append((start,last+1));start=pos
   last=pos
  runs.append((start,last+1))
 out.extend(struct.pack('<H',len(runs)))
 for start,end in runs:
  out.extend(struct.pack('<HH',start,end-start));out.extend(rgba[start:end].tobytes());previous[start:end]=rgba[start:end]
 assert np.array_equal(previous,rgba),tick
 if tick%500==0 or tick==len(timeline)-1:checks.append(dict(tick=tick+1,md5=hashlib.md5(rgba.tobytes()).hexdigest()))
dest=project/'datafiles/play/ln3/intro.bin';dest.write_bytes(out)
meta=dict(ticks=len(timeline),unique_frames=len(raw)//64000,source='Last_Ninja_3_(MSR).d81, original INTRO, entry $0400 to exit $10c5; PAL IRQ $0ef3 display samples',
 source_sha256=hashlib.sha256(Path(sys.argv[2]).read_bytes()).hexdigest(),
 format='LNI3 little endian: magic u32, ticks u32; each tick: run count u16, then pixel offset u16, pixel count u16, RGBA bytes. Initial image opaque black. Captured VIC palette indices mapped to project Pepto palette.',checks=checks)
from ln3_intro_audio_source import audio_events
meta['audio']=audio_events(json.loads((src/'audio-trace.json').read_text()))
meta['audio_source']='Original $a600 (A=0/1), $b200 (A=0), volume bytes $69/$66 at captured PAL boundaries.'
b.write_json(project/'datafiles/play/ln3/intro.json',meta)
yyp=project/'LNPreserve.yyp';p=b.read_json(yyp)
for name in ['intro.bin','intro.json']:
 entry=dict(CopyToMask=-1,filePath='datafiles/play/ln3',name=name,resourceType='GMIncludedFile',resourceVersion='2.0')
 entry.update({'$GMIncludedFile':'','%Name':name})
 if not any(x.get('filePath')==entry['filePath'] and x.get('name')==name for x in p['IncludedFiles']):p['IncludedFiles'].append(entry)
b.write_json(yyp,p)
