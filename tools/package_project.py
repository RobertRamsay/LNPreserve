"""Package the editable project without local disks, captures or vendor tools."""
from pathlib import Path
import hashlib,json,zipfile
ROOT=Path(__file__).resolve().parents[1]

def main():
    destination=ROOT/'dist/LNPreserve-Wastelands-WIP.zip'
    destination.parent.mkdir(exist_ok=True)
    paths=[ROOT/'README.md']
    for folder in ('LNPreserve','docs','evidence'):
        paths.extend(p for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix not in ('.resource_order','.pyc'))
    paths.extend(p for p in (ROOT/'tools').iterdir() if p.is_file() and p.suffix in ('.py','.ps1','.txt'))
    with zipfile.ZipFile(destination,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as bundle:
        for path in sorted(paths):bundle.write(path,path.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(destination) as bundle:
        bad=bundle.testzip()
        if bad:raise AssertionError(f'Archive CRC failure: {bad}')
        names=set(bundle.namelist())
        project=json.loads(bundle.read('LNPreserve/LNPreserve.yyp'))
        for resource in project['resources']:
            assert 'LNPreserve/'+resource['id']['path'] in names
        assert not any(n.startswith(('source/','tools/vendor/','build/','.git/')) for n in names)
    report=dict(path=str(destination),files=len(paths),bytes=destination.stat().st_size,
        sha256=hashlib.sha256(destination.read_bytes()).hexdigest(),crc_pass=True,resource_paths_pass=True,
        scope='Partial Wastelands native gameplay prototype; not a completed level or trilogy')
    (ROOT/'dist/package-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
