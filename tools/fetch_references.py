"""Download hash-pinned offline references. Never run downloaded executables."""
from pathlib import Path
import hashlib,urllib.request,zipfile
ROOT=Path(__file__).resolve().parents[1]
REFERENCES=[
 ('integrator-ln','https://www.luigidifraia.com/hosted/software/integrator-2012-ln-1.5.2-windows-x86_64-portable.zip','8ddb61414170ea0f0d002baf41f504ca56c70e7b1badea5c30f3b4de23ca5b03'),
 ('integrator-ln2','https://www.luigidifraia.com/hosted/software/integrator-2012-ln2-1.5.2-windows-x86_64-portable.zip','c43923f680ff809fab46874d86bb37ba7bf84e253b0d83d95fb21f5a7e4d316d'),
 ('integrator-ln3','https://www.luigidifraia.com/hosted/software/integrator-2012-ln3-1.5.2-windows-x86_64-portable.zip','d5914a00584f167327794e7a605b3178cbb2454660fb02b66ede484e5624687f'),
 ('vice','https://github.com/VICE-Team/svn-mirror/releases/download/3.10.0/SDL2VICE-3.10-win64.zip','dfa7e0223ea1357bae988b5c88b332c3b8f80dc3c7a2b51233f50bab5263dca5')]
def main():
    vendor=ROOT/'tools/vendor';vendor.mkdir(parents=True,exist_ok=True)
    for name,url,expected in REFERENCES:
        archive=vendor/f'{name}.zip'
        if not archive.exists():
            request=urllib.request.Request(url,headers={'User-Agent':'LNPreserve reference setup'})
            with urllib.request.urlopen(request,timeout=60) as response:data=response.read()
            if hashlib.sha256(data).hexdigest()!=expected:raise ValueError(f'Unexpected download hash: {name}')
            archive.write_bytes(data)
        if hashlib.sha256(archive.read_bytes()).hexdigest()!=expected:raise ValueError(f'Unexpected archive hash: {name}')
        destination=(vendor/name).resolve();destination.mkdir(exist_ok=True)
        with zipfile.ZipFile(archive) as zipped:
            for entry in zipped.infolist():
                target=(destination/entry.filename.replace('\\','/')).resolve()
                if not target.is_relative_to(destination):raise ValueError('Unsafe archive member')
            zipped.extractall(destination)
        print(name,'verified and extracted')
if __name__=='__main__':main()
