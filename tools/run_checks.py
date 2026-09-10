"""Run native checks; a caught GML exception is a failure even with exit code zero."""
from pathlib import Path
import argparse,json,subprocess,re,sys,time,uuid
ROOT=Path(__file__).resolve().parents[1]

def classify(log,groups):
    result={name:'not_run' for name in groups}
    for event,name in re.findall(r'LN_TEST_(START|PASS|FAIL):([A-Za-z0-9_]+)',log):
        result[name]={'START':'started','PASS':'passed','FAIL':'failed'}[event]
    # A started check that never completed is an actual incomplete execution,
    # distinct from a downstream check which was never entered.
    return {name:('failed' if state=='started' else state) for name,state in result.items()}

def main():
    p=argparse.ArgumentParser();p.add_argument('--runner',type=Path,required=True)
    p.add_argument('--suite',choices=['all','ln1'],default='all')
    p.add_argument('--inject-failure',action='store_true',help='Verify fail-fast reporting with a deliberate first-check failure')
    a=p.parse_args();manifest=json.loads((ROOT/'tools/check_manifest.json').read_text())
    out=ROOT/'build';out.mkdir(exist_ok=True)
    name=('runtime_checks' if a.suite=='all' else 'ln1_runtime_checks')+('_injected' if a.inject_failure else '')
    flag='--selftest' if a.suite=='all' else '--ln1-selftest'
    cmd=[str(a.runner),'-game',str(out/'LNPreserve.win'),flag]
    if a.inject_failure:cmd.append('--selftest-fail-early')
    si=subprocess.STARTUPINFO();si.dwFlags|=subprocess.STARTF_USESHOWWINDOW;si.wShowWindow=0
    started=time.monotonic();error=None
    try:
        r=subprocess.run(cmd,cwd=out,capture_output=True,timeout=240,startupinfo=si)
        log=(r.stdout+r.stderr).decode('utf-8',errors='replace');exit_code=r.returncode
    except subprocess.TimeoutExpired as e:
        log=((e.stdout or b'')+(e.stderr or b'')).decode('utf-8',errors='replace');exit_code=None;error='runner_timeout'
    (out/(name+'.log')).write_text(log,encoding='utf-8')
    groups=manifest[a.suite+'_groups'];checks=classify(log,groups)
    markers={k:v for k,v in manifest['markers'].items() if a.suite=='all' or not k.startswith(('ln2_','ln3_'))}
    marker_results={k:('passed' if v in log else 'not_run') for k,v in markers.items()}
    failures=re.findall(r'[^\r\n]*FAILURE[^\r\n]*',log)
    passed=(exit_code==0 and not failures and not error and all(v=='passed' for v in checks.values()) and all(v=='passed' for v in marker_results.values()))
    report=dict(suite=a.suite,command=cmd,status='passed' if passed else 'failed',exit_code=exit_code,
        original_gameplay_parity='not_tested',manual_playthrough='not_run',automated_room_coverage='component/integration checks only',
        checks=checks,pass_markers=marker_results,failures=failures,error=error,elapsed_seconds=round(time.monotonic()-started,2),log=str(out/(name+'.log')))
    # Legacy fields remain available; null means not reached, never a false failure claim.
    report.update({k:(True if v=='passed' else None) for k,v in marker_results.items()})
    (ROOT/'evidence'/(name+'.json')).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:report[k] for k in ('suite','status','checks','failures','elapsed_seconds')},indent=2))
    return 0 if passed else 1

if __name__=='__main__':sys.exit(main())
