"""Decode original Integrator object records into PNGs and editable scene records.

No third-party executable or emulator is included in the game.
The Integrator 2012 reference datasets are inputs, with per-file provenance.
Scene composition remains a diagnostic until checked against emulator captures.
"""
from pathlib import Path
import hashlib,json
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
PROJECT=ROOT/'LNPreserve'
PALETTE=[(0,0,0),(255,255,255),(129,51,56),(117,206,200),(142,60,151),(86,172,77),(46,44,155),(237,241,113),(142,80,41),(85,56,0),(196,108,113),(74,74,74),(123,123,123),(169,255,159),(112,109,235),(178,178,178)]

def word(b,p): return b[p] | b[p+1]<<8
def sha(b):return hashlib.sha256(b).hexdigest()

def decode_object(data,pointer):
    width,height=data[pointer]>>4,data[pointer]&15
    cells=width*height
    if not cells or pointer+1+cells*10>len(data):
        raise ValueError(f'Invalid object at {pointer:04x}')
    bitmap=data[pointer+1:pointer+1+cells*8]
    screen=data[pointer+1+cells*8:pointer+1+cells*9]
    colour=data[pointer+1+cells*9:pointer+1+cells*10]
    pixels=[]; codes=[]
    for y in range(height*8):
        for x in range(width*8):
            cell=(y//8)*width+x//8
            code=(bitmap[cell*8+y%8]>>(6-2*((x%8)//2)))&3
            index=[0,screen[cell]>>4,screen[cell]&15,colour[cell]&15][code]
            pixels.append((*PALETTE[index],255 if code else 0))
            codes.append(code)
    image=Image.new('RGBA',(width*8,height*8));image.putdata(pixels)
    return dict(width=width*8,height=height*8,bitmap=list(bitmap),screen=list(screen),colour=list(colour),length=1+cells*10),image

def decode_dataset(raw,game):
    base=word(raw,0); payload=raw[2:]
    memory=bytearray(65536);memory[base:base+len(payload)]=payload
    if game==1:
        table,count=word(memory,0x800),word(memory,0x802)
        locations=[dict(id=i,panel=(memory[0x808+5*i]>>1)+((memory[0x809+5*i]&1)<<7),background=memory[0x80c+5*i]&15,
                        raw=list(memory[0x808+5*i:0x80d+5*i])) for i in range(1,48)]
    else:
        if base!=0x800 or word(memory,0x801)!=0x800:raise ValueError('Unexpected reference dataset header')
        table,count=0x843,memory[0x800]
        locations=[dict(id=i,panel=memory[0x803+2*i],background=memory[0x804+2*i]&15,
                        raw=list(memory[0x803+2*i:0x805+2*i])) for i in range(32) if memory[0x803+2*i]!=255]
    if count>256:raise ValueError('Invalid record count')
    pointers=[word(memory,table+i*2) for i in range(count)]
    objects,panels,issues,images={},{},[],{}
    for i,value in enumerate(pointers):
        address=value&0x7fff
        if not base<=address<base+len(payload):
            issues.append(dict(record=i,issue='pointer_outside_dataset',address=address));continue
        if value&0x8000:
            # Some entries alias a byte within a previous object, rather than a separate image.
            if i+1<count and address+9>=(pointers[i+1]&0x7fff):
                issues.append(dict(record=i,issue='overlapping_or_short_object',address=address));continue
            try:
                obj,img=decode_object(memory,address)
                obj['address']=address;obj['id']=i
                objects[str(i)]=obj;images[i]=img
            except ValueError as e:issues.append(dict(record=i,issue=str(e)))
        else:
            entries=[]; pos=address
            for _ in range(1024):
                # The terminator is one byte, and a panel entry needs only its
                # actual header plus optional colour bytes. Requiring eight
                # remaining bytes dropped the final objects of loader pictures.
                limit=base+len(payload)
                if pos>=limit:
                    issues.append(dict(record=i,issue='unterminated_panel'));break
                if game>1 and memory[pos]==255:break
                header=4 if game==1 else 3
                if pos+header>limit:
                    issues.append(dict(record=i,issue='truncated_panel_entry'));break
                n=(memory[pos+header-1]>>5)&3
                if pos+header+n>limit:
                    issues.append(dict(record=i,issue='truncated_colour_override'));break
                if game==1:
                    r=list(memory[pos:pos+4]); n=(r[3]>>5)&3
                    entry=dict(object=r[0]>>1,x=(r[2]&31)*8,y=(r[3]&31)*8,mask=False,
                               recolour=list(memory[pos+4:pos+4+n]),raw=r,address=pos)
                    end=bool(r[2]&64);pos+=4+n
                else:
                    r=list(memory[pos:pos+3]);n=(r[2]>>5)&3
                    # LN2/LN3 X bit 7 reverses bitmap pixels horizontally. It
                    # does not remove the object or make it an occlusion mask.
                    entry=dict(object=r[0],x=(r[1]&63)*8-112,y=(r[2]&31)*8-112,mask=False,flip_x=bool(r[1]&128),
                               recolour=list(memory[pos+3:pos+3+n]),raw=r,address=pos)
                    end=False;pos+=3+n
                entries.append(entry)
                if end:break
            panels[str(i)]=dict(address=address,entries=entries)
    return dict(base=base,pointer_table=table,record_count=count,objects=objects,panels=panels,locations=locations,issues=issues),images

def render_panel(dataset,panel_id,background,width=240,height=144):
    """Diagnostic composition, retaining unresolved blend cases in the report."""
    image=Image.new('RGBA',(width,height),(*PALETTE[background],255))
    occlusion=Image.new('RGBA',(width,height),(255,255,255,0))
    warnings=set()
    attributes={}
    def place(pid,ox,oy,overrides,mask,trail,flip=False):
        if pid in trail:
            warnings.add('recursive_panel');return
        obj=dataset['objects'].get(str(pid))
        if obj:
            w,h=obj['width'],obj['height'];cw=w//8;cells=cw*(h//8)
            for y in range(h):
                dy=oy+y
                if dy<0 or dy>=height:continue
                for x in range(w):
                    dx=ox+x
                    if dx<0 or dx>=width:continue
                    sx=w-1-x if flip else x
                    cell=y//8*cw+sx//8
                    code=(obj['bitmap'][cell*8+y%8]>>(6-2*((sx%8)//2)))&3
                    if mask:
                        if code:occlusion.putpixel((dx,dy),(255,255,255,255))
                        continue
                    attr=obj['colour'][cell]
                    destcell=(dx//8,dy//8)
                    oldattr=attributes.get(destcell,0)
                    if oldattr>31 and attr<=31:continue
                    blend=oldattr>31 and attr>31 and bool(attr&16)
                    palette=[background,obj['screen'][cell]>>4,obj['screen'][cell]&15,attr&15]
                    for change in overrides:
                        palette=[change>>4 if c==(change&15) and k>0 else c for k,c in enumerate(palette)]
                    if blend:warnings.add('palette_merge_not_validated')
                    if not blend or code:image.putpixel((dx,dy),(*PALETTE[palette[code]],255))
                    # Update after the last pixel in the destination character cell.
                    if x%8==7 and y%8==7:attributes[destcell]=attr|oldattr if blend else attr
            return
        panel=dataset['panels'].get(str(pid))
        if panel is None:
            warnings.add(f'unresolved_record_{pid}');return
        for item in panel['entries']:
            place(item['object'],ox+item['x'],oy+item['y'],item['recolour'] or overrides,mask or item['mask'],trail+(pid,),item.get('flip_x',False))
    place(panel_id,0,0,[],False,())
    return image,occlusion,sorted(warnings)

def export_all():
    dest=PROJECT/'datafiles/graphics';dest.mkdir(parents=True,exist_ok=True)
    previous=json.loads((dest/'manifest.json').read_text()) if (dest/'manifest.json').exists() else {'datasets':[]}
    inventory=[]; thumbnails=[]
    disk_report=json.loads((ROOT/'evidence/disk_inventory.json').read_text())
    payloads=[]
    for ar in disk_report['archives']:
        for disk in ar['disks']:
            for e in disk['entries']:
                if 'path' in e and e['file_type']==2:
                    payloads.append((e['path'],(ROOT/e['path']).read_bytes()[2:]))
    for game,tag in [(1,'ln'),(2,'ln2'),(3,'ln3')]:
        root=next((ROOT/f'tools/vendor/integrator-{tag}').glob('*/integrator-files'))
        for path in sorted(root.rglob('int-*.prg')):
            if path.name=='int-demo-patched.prg':continue
            kind='loader' if path.parent.name=='loader' else 'game'
            slug=f'ln{game}_{kind}_{path.stem.replace("int-","").replace("-tape","").replace("-","_")}'
            raw=path.read_bytes()
            matches=[p for p,b in payloads if b==raw[2:]]
            dataset,images=decode_dataset(raw,game)
            provenance=dict(reference_url=f'https://www.luigidifraia.com/hosted/software/integrator-2012-{tag}-1.5.2-windows-x86_64-portable.zip',
                            reference_file=path.relative_to(root).as_posix(),sha256=sha(raw),
                            exact_supplied_disk_payload_matches=matches,status='disk_payload_verified' if matches else 'reference_dataset_only')
            captured=ROOT/'source/local/captures/ln1-game-ram.bin'
            if game==1 and path.name=='int-level1-tape.prg' and captured.exists():
                ram=captured.read_bytes()
                if ram[0x800:0x5400]==raw[0x202:]:
                    provenance['status']='disk_memory_region_verified'
                    provenance['capture_match']={'path':captured.relative_to(ROOT).as_posix(),'start':0x800,'end_exclusive':0x5400,
                        'bytes':0x4c00,'sha256':sha(ram[0x800:0x5400]),'boot_disk':'last_ninja_the_side_a_ccs'}
            folder=dest/slug;folder.mkdir(exist_ok=True)
            records=[]
            for i,img in images.items():
                name=f'{slug}_object_{i:03d}'
                img.save(folder/f'{name}.png')
                records.append(dict(name=name,path=(folder/f'{name}.png').relative_to(PROJECT).as_posix(),
                                    width=img.width,height=img.height,source_id=i))
                if len(thumbnails)<400:thumbnails.append((name,img))
            previews=[]
            for location in dataset['locations']:
                if str(location['panel']) not in dataset['panels']:continue
                im,mask,warnings=render_panel(dataset,location['panel'],location['background'])
                verified_opening=slug=='ln3_game_level1' and location['id']==0
                if verified_opening:
                    # Only this scene's correction was approved. Other proposed
                    # palette fixes remain staged outside the GameMaker project.
                    from original_scene_renderer import OriginalSceneRenderer
                    renderer=OriginalSceneRenderer(3,raw)
                    im=renderer.render(0);warnings=[]
                    expected='653095de7697c7aa09afb69b4601fcfea917af92f19bf2f7dbc73cdcfd704f2a'
                    if sha(im.tobytes())!=expected:raise ValueError('LN3 opening differs from the verified original bitmap')
                name=f'{slug}_location_{location["id"]:02d}'
                im.save(folder/f'{name}.png');mask.save(folder/f'{name}_mask.png')
                previews.append(dict(name=name,id=location['id'],panel=location['panel'],background=location['background'],
                                     path=(folder/f'{name}.png').relative_to(PROJECT).as_posix(),
                                     mask_path=(folder/f'{name}_mask.png').relative_to(PROJECT).as_posix(),
                                     status='original_bitmap_verified' if verified_opening else 'diagnostic_unverified',warnings=warnings))
                if verified_opening:
                    previews[-1]['verification']=dict(pixel_sha256=expected,pixels_compared=34560,differing_pixels=0,
                        source_ram_sha256=renderer.provenance['source_ram_sha256'],dataset_payload_sha256=sha(raw[2:]),
                        dataset_matches_supplied_game=True)
            (folder/'scene_data.json').write_text(json.dumps(dataset,separators=(',',':'))+'\n')
            inventory.append(dict(id=slug,game=game,kind=kind,provenance=provenance,objects=records,locations=previews,
                                  issues=dataset['issues'],scene_data=(folder/'scene_data.json').relative_to(PROJECT).as_posix()))
            print(slug,len(records),'objects',len(previews),'locations',provenance['status'],flush=True)
    # Identical images have one editable resource. Source record/room identities
    # stay in the manifest and decoded tables as aliases of that image.
    known={};removed=[];before=0
    for dataset in inventory:
        for role in ('objects','locations'):
            for record in dataset[role]:
                before+=1;path=PROJECT/record['path'];img=Image.open(path).convert('RGBA')
                key=(role,img.size,sha(img.tobytes()))
                first=known.setdefault(key,(record['name'],record['path'],dataset['id']))
                record['canonical_name'],record['path'],record['canonical_folder']=first
                if path!=PROJECT/first[1]:removed.append(path)
                if role=='locations':
                    mask=PROJECT/record['mask_path']
                    if Image.open(mask).getchannel('A').getbbox() is None:
                        removed.append(mask);record['mask_path']=None
    keep={PROJECT/r['path'] for d in inventory for role in ('objects','locations') for r in d[role]}
    keep.update(PROJECT/r['mask_path'] for d in inventory for r in d['locations'] if r['mask_path'])
    for d in previous['datasets']:
        for role in ('objects','locations'):
            for r in d[role]:
                removed.append(PROJECT/r['path'])
                if r.get('mask_path'):removed.append(PROJECT/r['mask_path'])
    root=dest.resolve()
    for path in set(removed)-keep:
        if path.exists():
            if not path.resolve().is_relative_to(root):raise ValueError('Generated PNG cleanup escaped graphics folder')
            path.unlink()
    report={'schema':2,'palette':PALETTE,'datasets':inventory,'scene_validation':'not_yet_compared_to_original_game',
            'image_deduplication':dict(source_image_records=before,unique_images=len(known),alias_records=before-len(known),
                empty_masks_removed=sum(r['mask_path'] is None for d in inventory for r in d['locations']))}
    (dest/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    sheet=Image.new('RGB',(960,((len(thumbnails)+11)//12)*88),(32,34,40));draw=ImageDraw.Draw(sheet)
    for i,(name,img) in enumerate(thumbnails):
        x=i%12*80;y=i//12*88
        preview=img.copy();preview.thumbnail((76,68),Image.Resampling.NEAREST)
        sheet.paste(preview,(x,y),preview);draw.text((x,y+70),name.split('_')[-1],fill='white')
    sheet.save(ROOT/'evidence/extracted_objects.png')
    return report

if __name__=='__main__':export_all()
