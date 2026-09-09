"""Consolidate exact generated sprite pixels; retain logical character banks.

Run on a clean checkpoint. The saved map preserves every original frame index.
GameMaker composite/layer pairs are required and deliberately retained.
"""
import copy, hashlib, json, re, shutil
from collections import defaultdict
from pathlib import Path
from PIL import Image
from build_project import ROOT, PROJECT, read_json, write_json, uid
from export_ln1_levels import register_project

def rgba(path):
    with Image.open(path) as im:return (im.size,hashlib.sha256(im.convert('RGBA').tobytes()).hexdigest())

def main():
    output=PROJECT/'datafiles/graphics/characters.json'
    if output.exists():raise SystemExit('Already consolidated; use the saved logical banks for further edits.')
    project_path=PROJECT/'LNPreserve.yyp';project=read_json(project_path)
    sprites={r['id']['name']:PROJECT/r['id']['path'] for r in project['resources'] if r['id']['path'].startswith('sprites/')}
    metadata={n:read_json(p) for n,p in sprites.items()}
    usage=defaultdict(set);types={}
    for role in ('ninja','guards'):
        names=[f'spr_ln1_{"player" if role=="ninja" else "enemy"}_weapon_{i}' for i in range(4)]
        types['ln1_'+role]={'weapon_banks':names}
        for n in names:usage[n].add('ln1_'+role)
    for level in range(1,8):
        w=read_json(PROJECT/f'datafiles/play/ln2/level{level}/world.json')
        for field in ('player_banks','player_extra_banks','enemy_banks','enemy_extra_banks'):
            rows=w[field]
            for key,name in (enumerate(rows) if isinstance(rows,list) else rows.items()):
                kind='ln2_ninja' if field.startswith('player') else 'ln2_enemy_type_'+key.split('_')[1]
                types.setdefault(kind,{}).setdefault('levels',{}).setdefault(str(level),{}).setdefault(field,{})[str(key)]=name
                usage[name].add(kind)
    # Ensure every removed bank is a plain, single editable layer with no
    # custom animation timing/events. Refuse instead of flattening user edits.
    for name in usage:
        m=metadata[name]
        assert len(m['layers'])==1 and m['layers'][0]['opacity']==100 and m['layers'][0]['blendMode']==0,name
        assert m['sequence']['playbackSpeed']==0 and not m['sequence']['events']['Keyframes'] and not m['sequence']['moments']['Keyframes'],name
        for f in m['frames']:
            paths=list((sprites[name].parent/'layers'/f['name']).glob('*.png'))
            assert len(paths)==1 and rgba(paths[0])==rgba(sprites[name].parent/(f['name']+'.png')),name
    pools={};pose_lookup={};poses=[];banks={};before=[];old_frames=0
    for name in sorted(usage,key=lambda n:('ninja' not in ' '.join(usage[n]),n)):
        m=metadata[name];game='ln1' if name.startswith('spr_ln1_') else 'ln2'
        kind=game+'_ninja' if game+'_ninja' in usage[name] else sorted(usage[name])[0] if len(usage[name])==1 else game+'_shared_enemies'
        target='spr_char_'+kind;indices=[]
        for f in m['frames']:
            path=sprites[name].parent/(f['name']+'.png');signature=rgba(path)
            key=(game,m['sequence']['xorigin'],m['sequence']['yorigin'],signature)
            if key not in pose_lookup:
                pool=pools.setdefault(target,{'template':name,'images':[]})
                pose_lookup[key]=len(poses);poses.append({'sprite':target,'frame':len(pool['images'])})
                pool['images'].append(path)
            indices.append(pose_lookup[key]);before.append((name,len(indices)-1,signature));old_frames+=1
        banks[name]={'types':sorted(usage[name]),'poses':indices}
    resources={}
    for name,pool in pools.items():
        old=pool['template'];m=copy.deepcopy(metadata[old]);out=PROJECT/'sprites'/name;out.mkdir()
        oldlayer=m['layers'][0]['name'];layer=uid(name+'/layer')
        m['name']=m['%Name']=name;m['layers'][0]['name']=m['layers'][0]['%Name']=layer
        m['sequence']['name']=m['sequence']['%Name']=name;m['sequence']['length']=float(len(pool['images']))
        m['parent']={'name':'Characters','path':'folders/Graphics/Characters.yy'}
        sample_frame=copy.deepcopy(m['frames'][0]);sample_key=copy.deepcopy(m['sequence']['tracks'][0]['keyframes']['Keyframes'][0])
        m['frames']=[];keys=[]
        for i,source in enumerate(pool['images']):
            frame=uid(name+'/frame/'+str(i));record=copy.deepcopy(sample_frame);record['name']=record['%Name']=frame;m['frames'].append(record)
            key=copy.deepcopy(sample_key);key['id']=uid(name+'/key/'+str(i));key['Key']=float(i);key['Length']=1.0
            key['Channels']['0']['Id']={'name':frame,'path':f'sprites/{name}/{name}.yy'};keys.append(key)
            (out/'layers'/frame).mkdir(parents=True)
            shutil.copyfile(source,out/(frame+'.png'));shutil.copyfile(source,out/'layers'/frame/(layer+'.png'))
        m['sequence']['tracks'][0]['keyframes']['Keyframes']=keys
        write_json(out/(name+'.yy'),m);resources[name]={'id':{'name':name,'path':f'sprites/{name}/{name}.yy'}}
    # Verify every logical frame against its new physical target before removal.
    newmeta={n:read_json(PROJECT/f'sprites/{n}/{n}.yy') for n in pools}
    for name,bank in banks.items():
        for target in {poses[i]['sprite'] for i in bank['poses']}:
            old,new=metadata[name],newmeta[target]
            for key in ('width','height','origin','bboxMode','bbox_bottom','bbox_left','bbox_right','bbox_top','collisionKind','preMultiplyAlpha','textureGroupId','edgeFiltering'):
                assert old[key]==new[key],(name,target,key)
            for key in ('xorigin','yorigin'):assert old['sequence'][key]==new['sequence'][key]
    for name,index,expected in before:
        pose=poses[banks[name]['poses'][index]];frame=newmeta[pose['sprite']]['frames'][pose['frame']]['name']
        assert rgba(PROJECT/'sprites'/pose['sprite']/(frame+'.png'))==expected,(name,index)
    # Whole-resource sharing requires all settings, timing and layer pixels to
    # match, not merely the rendered silhouette.
    def fingerprint(name):
        m=copy.deepcopy(metadata[name]);replacements={name:'SPRITE'}
        for i,f in enumerate(m['frames']):replacements[f['name']]='FRAME'+str(i)
        for i,l in enumerate(m['layers']):replacements[l['name']]='LAYER'+str(i)
        for i,k in enumerate(m['sequence']['tracks'][0]['keyframes']['Keyframes']):replacements[k['id']]='KEY'+str(i)
        m.pop('parent',None)
        def normal(v):
            if isinstance(v,str):
                for a,b in replacements.items():v=v.replace(a,b)
                return v
            if isinstance(v,list):return [normal(x) for x in v]
            if isinstance(v,dict):return {k:normal(x) for k,x in v.items()}
            return v
        pixels=[]
        for f in metadata[name]['frames']:
            pixels.append(rgba(sprites[name].parent/(f['name']+'.png')))
            for l in metadata[name]['layers']:
                p=sprites[name].parent/'layers'/f['name']/(l['name']+'.png')
                if not p.exists():return ('unshareable',name)
                pixels.append(rgba(p))
        return json.dumps(normal(m),sort_keys=True),tuple(pixels)
    seen={};aliases={}
    for name in sorted(set(sprites)-set(usage)):
        key=fingerprint(name)
        if key in seen:aliases[name]=seen[key]
        else:seen[key]=name
    # Remap only exact sprite-name tokens and sprite paths in project sources.
    pattern=re.compile(r'(?<![A-Za-z0-9_])('+'|'.join(map(re.escape,aliases))+r')(?![A-Za-z0-9_])') if aliases else None
    if pattern:
        for path in PROJECT.rglob('*'):
            if path.suffix not in ('.gml','.json','.yy') or path.is_relative_to(PROJECT/'sprites'):continue
            text=path.read_text(encoding='utf-8-sig');changed=pattern.sub(lambda m:aliases[m[0]],text)
            if changed!=text:path.write_text(changed,encoding='utf-8')
    removed=set(usage)|set(aliases);text=project_path.read_text()
    for name in removed:
        pattern=r'\{\s*"id"\s*:\s*\{\s*"name"\s*:\s*"'+re.escape(name)+r'"\s*,\s*"path"\s*:\s*"sprites/[^"\n]+"\s*,?\s*\}\s*,?\s*\}\s*,?'
        text,count=re.subn(pattern,'',text);assert count==1,name
    if 'folders/Graphics/Characters.yy' not in text:
        folder={'$GMFolder':'','%Name':'Characters','folderPath':'folders/Graphics/Characters.yy','name':'Characters','resourceType':'GMFolder','resourceVersion':'2.0'}
        text=re.sub(r'"Folders"\s*:\s*\[',lambda m:m[0]+json.dumps(folder)+',',text,count=1)
    project_path.write_text(re.sub(r'^[ \t]+$', '', text, flags=re.M))
    # Existing LN1 special banks and LN3's shared part bank stay indexed as-is.
    for level in range(1,7):
        path=PROJECT/('datafiles/play/ln1/world.json' if level==1 else f'datafiles/play/ln1/level{level}/world.json')
        world=read_json(path)
        types.setdefault('ln1_specials',{})[str(level)]={k:world[k] for k in ('actor_frames','enemy_colour_bank') if k in world}
    for level in range(1,6):
        world=read_json(PROJECT/f'datafiles/play/ln3/level{level}/world.json')
        types.setdefault('ln3_shared_parts',{})[str(level)]={'actor_bank':world['actor_bank']}
    for profile in types.values():profile['overrides']={}
    write_json(output,{'schema':1,'types':types,'banks':banks,'poses':poses})
    register_project(resources,[output])
    for name in removed:shutil.rmtree(sprites[name].parent)
    write_json(ROOT/'evidence/graphics_cleanup.json',{'character_banks_consolidated':len(usage),'new_character_pools':len(pools),
        'logical_character_frames_verified':old_frames,'unique_character_poses':len(poses),
        'duplicate_character_frames_removed':old_frames-len(poses),'whole_resource_aliases':aliases,
        'removed_sprite_directories':sorted(removed),'pixels_preserved':True,'native_gpu_tested':False})
    print('Character banks',len(usage),'->',len(pools),'frames',old_frames,'->',len(poses),'whole-resource duplicates',len(aliases))

if __name__=='__main__':main()
