"""Focused compiled-GML scene regression run; does not replace the full suite."""
import subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
runner=Path('C:/ProgramData/GameMakerStudio2-LTS2026/Cache/runtimes/runtime-2026.0.0.23/windows/x64/Runner.exe')
flag='--ln2-sequences-only' if '--sequences' in sys.argv else '--ln2-world-only'
marker='LN2_EFFECTS_PASS' if '--sequences' in sys.argv else 'LN2_WORLD_PASS'
info=subprocess.STARTUPINFO();info.dwFlags|=subprocess.STARTF_USESHOWWINDOW;info.wShowWindow=0
result=subprocess.run([str(runner),'-game',str(ROOT/'build/LNPreserve.win'),flag],cwd=ROOT/'build',
                      capture_output=True,text=True,timeout=60,startupinfo=info)
log=result.stdout+result.stderr;(ROOT/('build/'+flag[2:]+'.log')).write_text(log)
for line in log.splitlines():
    if 'LN2_' in line:print(line)
sys.exit(0 if result.returncode==0 and marker in log else 1)
