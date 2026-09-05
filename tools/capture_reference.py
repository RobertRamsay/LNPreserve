"""Run portable VICE as an offline reference, never embedded in GameMaker."""
from pathlib import Path
import argparse,subprocess,re,sys
ROOT=Path(__file__).resolve().parents[1]
if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('disk',type=Path)
    p.add_argument('--cycles',type=int,default=60000000)
    p.add_argument('--name',default='boot')
    p.add_argument('--commands',type=Path)
    a=p.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]+',a.name):p.error('Use letters, numbers, underscores or hyphens for --name')
    if a.cycles<1:p.error('--cycles must be positive')
    out=ROOT/'source/local/captures';out.mkdir(parents=True,exist_ok=True)
    exe=next((ROOT/'tools/vendor/vice').rglob('x64sc.exe'))
    if not a.disk.is_file():raise FileNotFoundError(a.disk)
    cmd=[str(exe),'-default','-console','-pal','+sound','-warp','-limitcycles',str(a.cycles),
         '-logfile',str(out/f'{a.name}-vice.log'),'-8',str(a.disk.resolve()),'-attach8ro',
         '-exitscreenshot',str(out/f'{a.name}.png')]
    if a.commands:
        cmd.extend(['-initbreak','ready','-moncommands',str(a.commands.resolve())])
    else:
        cmd.extend(['-autostart',str(a.disk.resolve())])
    with (out/f'{a.name}.log').open('w') as f:
        try:
            result=subprocess.run(cmd,cwd=exe.parent,stdout=f,stderr=subprocess.STDOUT,
                                  creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0),timeout=90)
            print('VICE exit:',result.returncode,'capture:',out/f'{a.name}.png')
            if result.returncode:sys.exit(1)
        except subprocess.TimeoutExpired:
            print('VICE reference run timed out; inspect the capture log.')
            sys.exit(1)
