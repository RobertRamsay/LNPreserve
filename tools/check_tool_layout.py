"""Native widescreen integration checks; not a manual playthrough."""
from pathlib import Path
import argparse,subprocess,json,sys
r=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--runner',required=True);a=p.parse_args()
si=subprocess.STARTUPINFO();si.dwFlags|=subprocess.STARTF_USESHOWWINDOW;si.wShowWindow=0
report={}
cases=[('--tool-layout-test','LN_TOOL_LAYOUT_PASS'),('--scene-editor-test','LN_EDITOR_TEST_ROOM_PASS'),('--pickup-crt-test','LN_CRT_PASS'),('--crt-live-test','LN_CRT_LIVE_PASS'),('--window-presets-test','LN_WINDOW_PRESETS_PASS'),('--fullscreen-test','LN_FULLSCREEN_PASS'),('--save-ui-test','LN_SAVE_UI_PASS')]
for flag,marker in cases:
    try:
        v=subprocess.run([a.runner,'-game',str(r/'build/LNPreserve.win'),flag],cwd=r/'build',capture_output=True,timeout=120,startupinfo=si)
        s=(v.stdout+v.stderr).decode('utf8',errors='replace');code=v.returncode
    except subprocess.TimeoutExpired as exc:
        s=((exc.stdout or b'')+(exc.stderr or b'')).decode('utf8',errors='replace');code=None
    path=r/'build'/('widescreen-'+flag[2:]+'.log');path.write_text(s,encoding='utf8')
    passed=code==0 and marker in s and 'FAILURE' not in s and 'ERROR' not in s
    report[flag]={'status':'passed' if passed else 'failed','log':str(path.relative_to(r)),'markers':[x for x in s.splitlines() if 'PASS' in x or 'FAILURE' in x]}
    print(flag,report[flag]['status'],flush=True)
passed=all(x['status']=='passed' for x in report.values())
(r/'evidence/tool_layout_checks.json').write_text(json.dumps({'status':'passed' if passed else 'failed','checks':report,'manual_playthrough':'not_run'},indent=2)+'\n',encoding='utf8')
sys.exit(0 if passed else 1)
