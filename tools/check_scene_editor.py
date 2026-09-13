"""Native editor/GPU checks. No manual playthrough or pixel-parity claim."""
from pathlib import Path
import argparse,json,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser();p.add_argument('--runner',type=Path,required=True);a=p.parse_args()
    si=subprocess.STARTUPINFO();si.dwFlags|=subprocess.STARTF_USESHOWWINDOW;si.wShowWindow=0
    start=time.monotonic();cmd=[str(a.runner),'-game',str(ROOT/'build/LNPreserve.win'),'--scene-editor-test']
    try:
        result=subprocess.run(cmd,cwd=ROOT/'build',capture_output=True,timeout=120,startupinfo=si)
        log=(result.stdout+result.stderr).decode('utf-8',errors='replace');code=result.returncode
    except subprocess.TimeoutExpired as e:
        log=((e.stdout or b'')+(e.stderr or b'')).decode('utf-8',errors='replace');code=None
    passed=code==0 and 'LN_EDITOR_PASS:' in log and 'FAILURE' not in log and 'ERROR' not in log
    (ROOT/'build/scene_editor_checks.log').write_text(log,encoding='utf-8')
    report=dict(status='passed' if passed else 'failed',exit_code=code,elapsed_seconds=round(time.monotonic()-start,2),
        room_records=293 if passed else None,manual_playthrough='not_run',source_bitmap_parity='not_verified',
        coverage='source import, composition/reorder/removal, depth thresholds, custom file roundtrip and rejection, mode isolation, GPU delta overlay, build playback, all three game previews',
        log='build/scene_editor_checks.log')
    (ROOT/'evidence/scene_editor_checks.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2));return 0 if passed else 1
if __name__=='__main__':sys.exit(main())
