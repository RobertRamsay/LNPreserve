"""Run actual compiled GML checks in the installed GameMaker Windows runner."""
from pathlib import Path
import argparse,json,subprocess,uuid,re,shutil,sys
ROOT=Path(__file__).resolve().parents[1]
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--runner',type=Path,required=True);a=p.parse_args()
    out=ROOT/'build';out.mkdir(exist_ok=True)
    debuglog=out/f'gml-runtime-{uuid.uuid4().hex}.log'
    cmd=[str(a.runner),'-game',str(out/'LNPreserve.win'),'-debugoutput',str(debuglog),'--selftest']
    info=subprocess.STARTUPINFO();info.dwFlags|=subprocess.STARTF_USESHOWWINDOW;info.wShowWindow=0
    report={'command':'GameMaker VM --selftest','original_gameplay_parity':'not_tested'}
    try:
        r=subprocess.run(cmd,cwd=out,capture_output=True,text=True,timeout=30,startupinfo=info)
        log=r.stdout+r.stderr
        if debuglog.exists():log+='\n'+debuglog.read_text(errors='replace')
        (out/'runner-console.log').write_text(log)
        report.update(exit_code=r.returncode,native_checks_pass='LN_SELFTEST_PASS' in log,
                      runtime_pass='LN_RUNTIME_PASS' in log,mask_gpu_pass='LN_MASK_PASS' in log,
                      sprite_decoder_pass='LN_SPRITE_PASS' in log,ln1_control_vectors_pass='LN_CONTROLS_PASS' in log)
        match=re.search(r'LN_CAPTURE_DIRECTORY:([^\r\n]+)',log)
        if match:
            capture_dir=Path(match.group(1).strip())
            for name in ('lnpreserve-mask-test.png','lnpreserve-workbench.png'):
                if (capture_dir/name).is_file():shutil.copy2(capture_dir/name,ROOT/'evidence'/name)
    except subprocess.TimeoutExpired as exc:
        report.update(native_checks_pass=False,runtime_pass=False,error='runner_timeout')
        log=''
        for part in (exc.stdout,exc.stderr):
            if part:log+=part.decode(errors='replace') if isinstance(part,bytes) else part
        (out/'runner-console.log').write_text(log)
    (ROOT/'evidence/runtime_checks.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
    sys.exit(0 if report.get('exit_code')==0 and all(report.get(key) for key in ('native_checks_pass','runtime_pass','mask_gpu_pass','sprite_decoder_pass','ln1_control_vectors_pass')) else 1)
