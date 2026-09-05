"""Register converted PNGs and native GML in the user's existing GameMaker project."""
from pathlib import Path
import argparse,copy,json,re,uuid,wave,shutil
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]; PROJECT=ROOT/'LNPreserve'
REFRESH_GRAPHICS=False

def read_json(path):return json.loads(re.sub(r',\s*([}\]])',r'\1',path.read_text(encoding='utf-8-sig')))
def write_json(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    # Keep GameMaker's formatting when the resource has not actually changed.
    if path.exists() and read_json(path)==data:return
    path.write_text(json.dumps(data,indent=2,sort_keys=True)+'\n',encoding='utf-8')
def uid(name):return str(uuid.uuid5(uuid.NAMESPACE_URL,'LNPreserve/'+name))
def res(kind,name,version=''):
    return {'$'+kind:version,'%Name':name,'name':name,'resourceType':kind,'resourceVersion':'2.0'}
def parent(name):return {'name':name.split('/')[-1],'path':f'folders/{name}.yy'}

def sprite_resource(name,source,folder,frames=None):
    if (PROJECT/'sprites'/name/f'{name}.yy').exists() and not REFRESH_GRAPHICS:
        return {'id':{'name':name,'path':f'sprites/{name}/{name}.yy'}}
    image=Image.open(source).convert('RGBA');w,h=image.size
    images=frames or [image]
    layer=uid(name+'/layer');out=PROJECT/'sprites'/name;out.mkdir(parents=True,exist_ok=True)
    data=res('GMSprite',name,'v2')
    data.update(bboxMode=0,bbox_bottom=h-1,bbox_left=0,bbox_right=w-1,bbox_top=0,
                collisionKind=1,collisionTolerance=0,DynamicTexturePage=False,edgeFiltering=False,For3D=False,
                frames=[],gridX=8,gridY=8,height=h,HTile=False,layers=[],nineSlice=None,origin=0,
                parent=parent(folder),preMultiplyAlpha=False,swatchColours=None,swfPrecision=2.525,
                textureGroupId={'name':'Default','path':'texturegroups/Default'},type=0,VTile=False,width=w)
    l=res('GMImageLayer',layer);l.update(blendMode=0,displayName='Original pixels',isLocked=False,opacity=100.0,visible=True)
    data['layers']=[l]
    seq=res('GMSequence',name,'v1')
    seq.update(autoRecord=True,backdropHeight=768,backdropImageOpacity=0.5,backdropImagePath='',backdropWidth=1366,
               backdropXOffset=0,backdropYOffset=0,eventStubScript=None,eventToFunction={},length=float(len(images)),
               lockOrigin=False,playback=1,playbackSpeed=0.0,playbackSpeedType=0,showBackdrop=True,
               showBackdropImage=False,timeUnits=1,visibleRange=None,volume=1.0,xorigin=0,yorigin=0)
    for key,typ in [('events','MessageEventKeyframe'),('moments','MomentsEventKeyframe')]:
        seq[key]=res(f'KeyframeStore<{typ}>','');seq[key].pop('name');seq[key].pop('%Name');seq[key]['Keyframes']=[]
    track=res('GMSpriteFramesTrack','frames')
    track.pop('%Name')
    track.update(builtinName=0,events=[],inheritsTrackColour=True,interpolation=1,isCreationTrack=False,
                 modifiers=[],spriteId=None,trackColour=0,tracks=[],traits=0)
    store=res('KeyframeStore<SpriteFrameKeyframe>','');store.pop('name');store.pop('%Name');store['Keyframes']=[]
    for index,img in enumerate(images):
        frame=uid(name+'/frame/'+str(index));data['frames'].append(res('GMSpriteFrame',frame,'v1'))
        img.save(out/f'{frame}.png');(out/'layers'/frame).mkdir(parents=True,exist_ok=True)
        img.save(out/'layers'/frame/f'{layer}.png')
        channel=res('SpriteFrameKeyframe','');channel.pop('name');channel.pop('%Name')
        channel['Id']={'name':frame,'path':f'sprites/{name}/{name}.yy'}
        key=res('Keyframe<SpriteFrameKeyframe>','');key.pop('name');key.pop('%Name')
        key.update(Channels={'0':channel},Disabled=False,id=uid(name+'/key/'+str(index)),IsCreationKey=False,
                   Key=float(index),Length=1.0,Stretch=False)
        store['Keyframes'].append(key)
    track['keyframes']=store;seq['tracks']=[track];data['sequence']=seq
    write_json(out/f'{name}.yy',data)
    return {'id':{'name':name,'path':f'sprites/{name}/{name}.yy'}}

LEVELS={1:['wastelands','wilderness','palace_gardens','dungeons','palace','inner_sanctum'],
        2:['central_park','street','sewers','basement','office','mansion','final_battle'],
        3:['earth','wind','water','fire','void']}

def main():
    yyp=PROJECT/'LNPreserve.yyp';project=read_json(yyp)
    # Preserve all user resources; generated resources use stable names and identities.
    resources={r['id']['name']:r for r in project['resources']}
    old_catalog=read_json(PROJECT/'datafiles/catalog.json') if (PROJECT/'datafiles/catalog.json').exists() else {'datasets':[]}
    old_generated={r[k] for d in old_catalog['datasets'] for role in ('objects','locations') for r in d[role]
                   for k in ('sprite_name','mask_name') if r.get(k)}
    generated=set()
    folders={f['folderPath']:f for f in project['Folders']}
    def folder(name):
        f=res('GMFolder',name.split('/')[-1]);f['folderPath']=f'folders/{name}.yy';folders[f['folderPath']]=f
    for f in ['Native','Native/Scripts','Native/Shaders','Native/Objects','Music placeholders','Graphics','Diagnostics']:
        folder(f)
    manifest=read_json(PROJECT/'datafiles/graphics/manifest.json')
    catalog=[]
    for dataset in manifest['datasets']:
        f='Graphics/'+dataset['id'];folder(f)
        item={'id':dataset['id'],'game':dataset['game'],'provenance':dataset['provenance']['status'],
              'objects':[],'locations':[]}
        for obj in dataset['objects']:
            name='spr_'+obj.get('canonical_name',obj['name']);generated.add(name)
            cf='Graphics/'+obj.get('canonical_folder',dataset['id']);folder(cf)
            resources[name]=sprite_resource(name,PROJECT/obj['path'],cf)
            existing=next((v for v in item['objects'] if v['sprite_name']==name),None)
            if existing:existing['source_ids'].append(obj['source_id'])
            else:item['objects'].append({'name':obj['name'],'sprite_name':name,'id':obj['source_id'],'source_ids':[obj['source_id']]})
        for loc in dataset['locations']:
            name='spr_'+loc.get('canonical_name',loc['name']);generated.add(name);maskname=''
            cf='Graphics/'+loc.get('canonical_folder',dataset['id']);folder(cf)
            resources[name]=sprite_resource(name,PROJECT/loc['path'],cf)
            if loc.get('mask_path'):
                maskname=name+'_mask';generated.add(maskname)
                resources[maskname]=sprite_resource(maskname,PROJECT/loc['mask_path'],cf)
            existing=next((v for v in item['locations'] if v['sprite_name']==name),None)
            if existing:existing['source_ids'].append(loc['id'])
            else:item['locations'].append({'name':loc['name'],'sprite_name':name,'mask_name':maskname,'id':loc['id'],
                                     'warnings':loc['warnings'],'source_ids':[loc['id']]})
        catalog.append(item)
    actor_manifest=PROJECT/'datafiles/actors/ln1/manifest.json'
    if actor_manifest.exists():
        actors=read_json(actor_manifest);f='Graphics/ln1_character_parts';folder(f)
        item={'id':'ln1_character_parts','game':1,'provenance':'original_6502_decoder_verified','objects':[],'locations':[]}
        seen_parts={}
        for obj in actors['parts']:
            key=tuple(obj['decoded']);name=seen_parts.setdefault(key,'spr_'+obj['name']);generated.add(name)
            resources[name]=sprite_resource(name,PROJECT/obj['path'],f)
            existing=next((v for v in item['objects'] if v['sprite_name']==name),None)
            if existing:existing['source_ids'].append(obj['id'])
            else:item['objects'].append({'name':obj['name'],'sprite_name':name,'id':obj['id'],'source_ids':[obj['id']]})
        catalog.append(item)
    # Prune only resources that the preceding generated catalog owned. GameMaker's
    # frame/layer files belong to their sprite and must never be deduplicated alone.
    gml='\n'.join(p.read_text(encoding='utf-8-sig') for p in PROJECT.rglob('*.gml'))
    sprite_root=(PROJECT/'sprites').resolve();pruned=[]
    for name in sorted(old_generated-generated):
        if re.search(r'\b'+re.escape(name)+r'\b',gml):continue
        path=(sprite_root/name).resolve()
        if path.parent!=sprite_root:raise ValueError('Generated sprite cleanup escaped sprite folder')
        resources.pop(name,None)
        if path.exists():shutil.rmtree(path)
        pruned.append(name)
    cleanup_path=ROOT/'evidence/asset_cleanup.json'
    prior=read_json(cleanup_path).get('removed_sprite_resources',[]) if cleanup_path.exists() else []
    removed=sorted((set(prior)|set(pruned))-set(resources))
    write_json(cleanup_path,dict(removed_sprite_resources=removed,removed_count=len(removed),
        canonical_scenery_images=manifest.get('image_deduplication',{}),
        source_aliases_preserved=True,game_maker_frame_and_layer_files_preserved=True))
    # Deliberately synthetic test graphics; never counted as recovered assets.
    fixtures=ROOT/'evidence/fixtures';fixtures.mkdir(parents=True,exist_ok=True)
    actor=Image.new('RGBA',(20,40));d=ImageDraw.Draw(actor);d.rectangle((2,2,17,37),fill=(255,200,60,255))
    actor.save(fixtures/'actor.png')
    mask=Image.new('RGBA',(256,160),(255,255,255,0));d=ImageDraw.Draw(mask)
    d.rectangle((124,25,134,145),fill=(255,255,255,255));d.rectangle((75,74,175,84),fill=(255,255,255,255))
    d.rectangle((124,77,134,81),fill=(255,255,255,0));mask.save(fixtures/'mask.png')
    resources['spr_depth_probe']=sprite_resource('spr_depth_probe',fixtures/'actor.png','Diagnostics')
    resources['spr_depth_fixture']=sprite_resource('spr_depth_fixture',fixtures/'mask.png','Diagnostics')
    sounds=[]
    for game,levels in LEVELS.items():
        for levelnum,level in enumerate(levels,1):
            for role in ['game','loader']:
                tune=None
                if game==1:tune=([6,7,8,9,10,11] if role=='game' else [3,1,2,11,4,5])[levelnum-1]
                if game==2:tune=([2,4,6,8,10,12,12] if role=='game' else [1,3,5,7,9,11,13])[levelnum-1]
                if game==3 and role=='game':tune=levelnum+3
                sounds.append(dict(game=game,level=level,role=role,subtune=tune))
    for role,tune in [('intro',3),('game_over',9),('outro',10),('subtune_01_unmapped',1),('subtune_02_unmapped',2)]:
        sounds.append(dict(game=3,level=role,role='cue',subtune=tune))
    for sound in sounds:
        name=f"snd_ln{sound['game']}_{sound['level']}_{sound['role']}";out=PROJECT/'sounds'/name;out.mkdir(parents=True,exist_ok=True)
        wav=out/f'{name}.wav'
        # Re-running the importer never overwrites user-supplied replacement audio.
        if not wav.exists():
            with wave.open(str(wav),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(44100);w.writeframes(bytes(88200))
        data=res('GMSound',name,'v2');data.update(audioGroupId={'name':'audiogroup_default','path':'audiogroups/audiogroup_default'},
            bitDepth=1,channelFormat=0,compression=0,compressionQuality=4,conversionMode=0,duration=1.0,exportDir='',
            parent=parent('Music placeholders'),preload=False,sampleRate=44100,soundFile=wav.name,volume=1.0)
        # Preserve edits to sound metadata in GameMaker too.
        if not (out/f'{name}.yy').exists():write_json(out/f'{name}.yy',data)
        resources[name]={'id':{'name':name,'path':f'sounds/{name}/{name}.yy'}}
        active=read_json(out/f'{name}.yy').get('soundFile',wav.name)
        active_path=out/active
        silent=False
        if active_path.suffix.lower()=='.wav' and active_path.exists():
            with wave.open(str(active_path),'rb') as stream:
                silent=(stream.getnchannels()==1 and stream.getsampwidth()==2 and
                        stream.getframerate()==44100 and stream.getnframes()==44100 and
                        not any(stream.readframes(44100)))
        sound.update(asset=name,status='silent_placeholder' if silent else 'user_replacement',
                     path=f'sounds/{name}/{active}')
    write_json(PROJECT/'datafiles/music_manifest.json',{'schema':1,'sounds':sounds})
    write_json(PROJECT/'datafiles/catalog.json',{'datasets':catalog})
    for script in sorted((PROJECT/'scripts').glob('*/*.gml')):
        name=script.stem;data=res('GMScript',name,'v1');data.update(isCompatibility=False,isDnD=False,parent=parent('Native/Scripts'))
        write_json(script.with_suffix('.yy'),data)
        resources[name]={'id':{'name':name,'path':script.with_suffix('.yy').relative_to(PROJECT).as_posix()}}
    sh=res('GMShader','sh_ln_occlusion');sh.update(parent=parent('Native/Shaders'),type=1)
    write_json(PROJECT/'shaders/sh_ln_occlusion/sh_ln_occlusion.yy',sh)
    resources['sh_ln_occlusion']={'id':{'name':'sh_ln_occlusion','path':'shaders/sh_ln_occlusion/sh_ln_occlusion.yy'}}
    name='obj_ln_preserve';obj=res('GMObject',name)
    obj.update(eventList=[],managed=True,overriddenProperties=[],parent=parent('Native/Objects'),parentObjectId=None,
               persistent=False,physicsAngularDamping=0.1,physicsDensity=0.5,physicsFriction=0.2,physicsGroup=1,
               physicsKinematic=False,physicsLinearDamping=0.1,physicsObject=False,physicsRestitution=0.1,
               physicsSensor=False,physicsShape=1,physicsShapePoints=[],physicsStartAwake=True,properties=[],solid=False,
               spriteId=None,spriteMaskId=None,visible=True)
    for typ,num in [(0,0),(3,0),(8,0),(12,0)]:
        e=res('GMEvent','','v1');e.update(collisionObjectId=None,eventNum=num,eventType=typ,isDnD=False);obj['eventList'].append(e)
    write_json(PROJECT/f'objects/{name}/{name}.yy',obj);resources[name]={'id':{'name':name,'path':f'objects/{name}/{name}.yy'}}
    room=read_json(PROJECT/'rooms/Room1/Room1.yy');room['roomSettings'].update(Width=1280,Height=800)
    room['creationCodeFile']='RoomCreationCode.gml'
    (PROJECT/'rooms/Room1/RoomCreationCode.gml').write_text('instance_create_depth(0, 0, 0, obj_ln_preserve);\n')
    write_json(PROJECT/'rooms/Room1/Room1.yy',room)
    options=read_json(PROJECT/'options/main/options_main.yy');options.update(option_remove_unused_assets=False,option_game_speed=60)
    write_json(PROJECT/'options/main/options_main.yy',options)
    options=read_json(PROJECT/'options/windows/options_windows.yy');options.update(option_windows_interpolate_pixels=False,
        option_windows_executable_name='LNPreserve.exe',option_windows_product_info='LNPreserve',option_windows_company_info='',
        option_windows_description_info='Last Ninja preservation conversion workbench',option_windows_resize_window=True)
    write_json(PROJECT/'options/windows/options_windows.yy',options)
    # Remove empty generated dataset folders, including loaders that now alias
    # one canonical picture. Keep every folder that contains a live resource.
    used_parents={read_json(PROJECT/r['id']['path']).get('parent',{}).get('path') for r in resources.values()}
    generated_folders={'folders/Graphics/'+d['id']+'.yy' for d in manifest['datasets']}
    for path in generated_folders-set(used_parents):folders.pop(path,None)
    project['resources']=list(resources.values());project['Folders']=list(folders.values());project['IncludedFiles']=[]
    # Images are editable sprite resources, not duplicated as runtime included files.
    for path in sorted((PROJECT/'datafiles').rglob('*.json')):
        inc=res('GMIncludedFile',path.name);inc.update(CopyToMask=-1,filePath=path.parent.relative_to(PROJECT).as_posix())
        project['IncludedFiles'].append(inc)
    project['TextureGroups'][0]['autocrop']=False # Full-room mask UVs must preserve transparent borders.
    write_json(yyp,project)
    print('Registered',len(resources),'resources;',len(sounds),'sound placeholders;',len(catalog),'datasets')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--refresh-graphics',action='store_true',help='Explicitly replace generated sprite edits from the decoded PNGs')
    args=parser.parse_args();REFRESH_GRAPHICS=args.refresh_graphics
    main()
