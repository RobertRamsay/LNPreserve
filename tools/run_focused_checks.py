"""Seven focused regressions from Ninja-fix-handoff.md, plus disposable save UI captures."""
from pathlib import Path
import argparse,subprocess,json,time,sys
ROOT=Path(__file__).resolve().parents[1]
CASES={
 '--ln2-sewer-flames-test':['LN2_SEWER_FLAMES_PASS'],
 '--ln2-item-use-test':['LN2_ITEM_USE_PASS'],
 '--ln2-street-snags-test':['LN2_STREET_SNAGS_PASS'],
 '--ninja-transitions-test':['LN_NINJA_TRANSITIONS_PASS','LN_NINJA_TRANSITION_RENDER_PASS'],
 '--ln2-lives-pickup-test':['LN2_LIVES_PICKUP_PASS'],
 '--function-keys-test':['LN_FUNCTION_KEYS_PASS'],
 '--ln2-gap-landing-test':['LN2_GAP_LANDING_PASS'],
 '--ln2-fence-gap-boat-test':['LN2_FENCE_GAP_BOAT_PASS'],
 '--ln2-water-knife-test':['LN2_WATER_KNIFE_PASS'],
 '--ln2-reported-encounters-test':['LN2_REPORTED_ENCOUNTERS_PASS'],
 '--ln1-magic-test':['LN1_MAGIC_PASS','LN1_WEAPON_LOCK_PASS'],
 '--pickup-crt-test':['LN_PICKUP_PASS','LN_CRT_PASS'],
 '--jump-assist-test':['LN_JUMP_ASSIST_PASS'],
 '--reverse-roll-test':['LN_REVERSE_ROLL_PASS'],
 '--crt-live-test':['LN_CRT_LIVE_PASS'],
 '--window-presets-test':['LN_WINDOW_PRESETS_PASS'],
 '--xbox-test':['LN_XBOX_PASS'],
 '--save-ui-test':['LN_SAVE_UI_PASS'],
}
def main():
 p=argparse.ArgumentParser();p.add_argument('--runner',type=Path,required=True);a=p.parse_args()
 si=subprocess.STARTUPINFO();si.dwFlags|=subprocess.STARTF_USESHOWWINDOW;si.wShowWindow=0
 report={};out=ROOT/'build'
 for flag,markers in CASES.items():
  started=time.monotonic()
  try:
   r=subprocess.run([str(a.runner),'-game',str(out/'LNPreserve.win'),flag],cwd=out,capture_output=True,timeout=120,startupinfo=si)
   log=(r.stdout+r.stderr).decode('utf-8',errors='replace');code=r.returncode;error=None
  except subprocess.TimeoutExpired as e:
   log=((e.stdout or b'')+(e.stderr or b'')).decode('utf-8',errors='replace');code=None;error='timeout'
  path=out/(flag[2:]+'.log');path.write_text(log,encoding='utf-8')
  passed=code==0 and not error and 'FAILURE' not in log and all(m in log for m in markers)
  report[flag]=dict(status='passed' if passed else 'failed',exit_code=code,markers={m:m in log for m in markers},error=error,log=str(path),elapsed_seconds=round(time.monotonic()-started,2))
  print(flag,report[flag]['status'],flush=True)
 (ROOT/'evidence/focused_checks.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
 return 0 if all(v['status']=='passed' for v in report.values()) else 1
if __name__=='__main__':sys.exit(main())
