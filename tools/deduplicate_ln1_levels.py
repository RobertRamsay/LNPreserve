"""Share identical newly exported LN1 resources without changing existing art.

Only the generated spr_ln1_level2..6 resources are candidates for removal.
Existing resources can be reuse targets, never removal targets.
"""
import hashlib
import json
import re
import shutil
from PIL import Image
from build_project import ROOT, PROJECT, read_json, write_json


def fingerprint(row):
    name=row['id']['name'];path=PROJECT/row['id']['path']
    if not row['id']['path'].startswith('sprites/'):return None
    meta=read_json(path);digest=hashlib.sha256()
    digest.update(json.dumps([meta['width'],meta['height'],meta['sequence']['xorigin'],meta['sequence']['yorigin'],
                              len(meta['frames'])]).encode())
    for frame in meta['frames']:
        with Image.open(path.parent/(frame['name']+'.png')) as image:digest.update(image.convert('RGBA').tobytes())
    return digest.hexdigest()


def main():
    project_path=PROJECT/'LNPreserve.yyp';project=read_json(project_path)
    generated=lambda name:bool(re.fullmatch(r'spr_ln1_level[2-6]_.*',name))
    pool={};aliases={}
    ordered=sorted(project['resources'],key=lambda row:generated(row['id']['name']))
    for row in ordered:
        name=row['id']['name'];key=fingerprint(row)
        if key is None:continue
        if generated(name) and key in pool:aliases[name]=pool[key]
        else:pool.setdefault(key,name)
    def remap(value):
        if isinstance(value,str):return aliases.get(value,value)
        if isinstance(value,list):return [remap(v) for v in value]
        if isinstance(value,dict):return {k:remap(v) for k,v in value.items()}
        return value
    for level in range(2,7):
        path=PROJECT/f'datafiles/play/ln1/level{level}/world.json'
        write_json(path,remap(read_json(path)))
    text=project_path.read_text()
    for name in aliases:
        # Generated registration rows are deliberately single-line records.
        pattern=r'^\s*\{"id":\{"name":"'+re.escape(name)+r'","path":"sprites/[^\n]+\n'
        text,count=re.subn(pattern,'',text,count=1,flags=re.M)
        assert count==1, f'Unexpected resource row format: {name}'
    project_path.write_text(text)
    for name in aliases:
        target=(PROJECT/'sprites'/name).resolve()
        assert target.parent==(PROJECT/'sprites').resolve() and generated(target.name)
        shutil.rmtree(target)
        for folder in (PROJECT/'datafiles/play/ln1').glob('level[2-6]'):
            source=folder/(name+'.png')
            if source.is_file():source.unlink()
    write_json(ROOT/'evidence/ln1_level_asset_sharing.json',dict(removed_duplicate_resources=len(aliases),aliases=aliases,
               policy='Existing editable artwork retained; identical newly generated level images reuse existing sprites'))
    print('Shared',len(aliases),'duplicate level resources')


if __name__=='__main__':main()
