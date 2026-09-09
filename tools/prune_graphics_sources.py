"""Remove unused included PNG copies only when identical editable art survives."""
import re
from cleanup_graphics import rgba
from build_project import PROJECT, ROOT, read_json, write_json

def main():
    hashes={}
    for path in (PROJECT/'sprites').glob('*/*.png'):hashes.setdefault(rgba(path),path.relative_to(PROJECT).as_posix())
    texts='\n'.join(p.read_text() for p in (PROJECT/'datafiles').rglob('*.json'))
    removed={}
    for path in (PROJECT/'datafiles/play').rglob('*.png'):
        if path.name in texts:continue
        key=rgba(path)
        if key in hashes:removed[path.relative_to(PROJECT).as_posix()]=hashes[key]
    path=PROJECT/'LNPreserve.yyp';text=path.read_text()
    def included(match):
        record=read_json_text(match[0].rstrip(',').strip())
        key=record['filePath']+'/'+record['name']
        return '' if key in removed else match[0]
    text=re.sub(r'\{[^{}]*"resourceType"\s*:\s*"GMIncludedFile"[^{}]*\}\s*,?',included,text)
    path.write_text(re.sub(r'^[ \t]+$','',text,flags=re.M))
    for name in removed:(PROJECT/name).unlink()
    report=read_json(ROOT/'evidence/graphics_cleanup.json');report['removed_redundant_included_pngs']=removed
    write_json(ROOT/'evidence/graphics_cleanup.json',report)
    mapping=PROJECT/'datafiles/graphics/characters.json';data=read_json(mapping)
    for profile in data['types'].values():profile.setdefault('overrides',{})
    write_json(mapping,data)
    print('Removed',len(removed),'unused PNG copies with identical surviving sprite pixels')

def read_json_text(text):
    import json
    return json.loads(re.sub(r',\s*([}\]])',r'\1',text))

if __name__=='__main__':main()
