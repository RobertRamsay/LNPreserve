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
        r=subprocess.run(cmd,cwd=out,capture_output=True,text=True,timeout=180,startupinfo=info)
        log=r.stdout+r.stderr
        if debuglog.exists():log+='\n'+debuglog.read_text(errors='replace')
        (out/'runner-console.log').write_text(log)
        report.update(exit_code=r.returncode,native_checks_pass='LN_SELFTEST_PASS' in log,
                      runtime_pass='LN_RUNTIME_PASS' in log,mask_gpu_pass='LN_MASK_PASS' in log,
                      sprite_decoder_pass='LN_SPRITE_PASS' in log,ln1_control_vectors_pass='LN_CONTROLS_PASS' in log,
                      ln1_player_vectors_pass='LN_PLAYER_PASS' in log,ln1_enemy_vectors_pass='LN_ENEMY_PASS' in log,
                      ln1_combat_vectors_pass='LN_COMBAT_PASS' in log,ln1_world_smoke_pass='LN_WORLD_PASS' in log,
                      ln1_feedback_pass='LN_FEEDBACK_PASS' in log,ln1_water_vectors_pass='LN_WATER_PASS' in log,
                      scene_navigation_pass='LN_NAVIGATION_PASS' in log,
                      ln1_levels_pass='LN_LEVELS_PASS' in log,
                      ln1_projectiles_pass='LN_PROJECTILES_PASS' in log,
                      ln2_player_vectors_pass='LN2_PLAYER_PASS' in log,
                      ln2_enemy_vectors_pass='LN2_ENEMY_PASS' in log,
                      ln2_entrances_pass='LN2_ENTRANCES_PASS' in log,
                      ln2_helicopter_pass='LN2_HELICOPTER_PASS' in log,
                      ln2_vehicles_pass='LN2_VEHICLES_PASS' in log,
                      ln2_effects_pass='LN2_EFFECTS_PASS' in log,
                      ln2_combat_vectors_pass='LN2_COMBAT_PASS' in log,
                      ln2_world_pass='LN2_WORLD_PASS' in log,
                      ln2_keypad_pass='LN2_KEYPAD_PASS' in log,
                      ln2_candles_pass='LN2_CANDLES_PASS' in log,
                      ln2_boss_release_pass='LN2_BOSS_RELEASE_PASS' in log,
                      ln2_object_integration_pass='LN2_OBJECT_INTEGRATION_PASS' in log,
                      ln2_item_flow_pass='LN2_ITEM_FLOW_PASS' in log,
                      ln2_final_gpu_pass='LN2_FINAL_GPU_PASS' in log,
                      ln2_status_pass='LN2_STATUS_PASS' in log,
                      ln2_ending_pass='LN2_ENDING_PASS' in log,
                      ln2_ending_gpu_pass='LN2_ENDING_GPU_PASS' in log,
                      ln3_movement_pass='LN3_MOVEMENT_PASS' in log,
                      ln3_actions_pass='LN3_ACTION_PASS' in log,
                      ln3_input_pass='LN3_INPUT_PASS' in log,
                      ln3_animation_pass='LN3_ANIMATION_PASS' in log,
                      ln3_masks_pass='LN3_MASK_PASS' in log,
                      ln3_collision_pass='LN3_COLLISION_PASS' in log,
                      ln3_enemy_pass='LN3_ENEMY_PASS' in log,
                      ln3_combat_pass='LN3_COMBAT_PASS' in log,
                      ln3_scenes_pass='LN3_SCENES_PASS' in log,
                      ln3_items_pass='LN3_ITEMS_PASS' in log,
                      ln3_scenery_pass='LN3_SCENERY_PASS' in log,
                      ln3_scenery_gpu_pass='LN3_SCENERY_GPU_PASS' in log,
                      ln3_special_pass='LN3_SPECIAL_PASS' in log,
                      ln3_transition_pass='LN3_TRANSITION_PASS' in log,
                      ln3_ending_pass='LN3_ENDING_PASS' in log,
                      ln3_ending_gpu_pass='LN3_ENDING_GPU_PASS' in log,
                      ln3_mechanism_gpu_pass='LN3_MECHANISM_GPU_PASS' in log,
                      ln3_world_pass='LN3_WORLD_PASS' in log,
                      ln3_gpu_pass='LN3_GPU_PASS' in log)
        match=re.search(r'LN_CAPTURE_DIRECTORY:([^\r\n]+)',log)
        if match:
            capture_dir=Path(match.group(1).strip())
            for name in ('lnpreserve-mask-test.png','lnpreserve-workbench.png','lnpreserve-player.png','lnpreserve-encounter.png',
                         'lnpreserve-found.png','lnpreserve-wounded.png','lnpreserve-prayer.png','lnpreserve-water.png',
                         'lnpreserve-scene-picker.png','lnpreserve-scene-preview.png','lnpreserve-ln2-ending.png') + tuple(f'lnpreserve-level{level}.png' for level in range(1,7)) + tuple(f'lnpreserve-ln2-level{level}.png' for level in range(1,8)) + tuple(f'lnpreserve-ln3-level{level}.png' for level in range(1,6)):
                if (capture_dir/name).is_file():shutil.copy2(capture_dir/name,ROOT/'evidence'/name)
    except subprocess.TimeoutExpired as exc:
        report.update(native_checks_pass=False,runtime_pass=False,error='runner_timeout')
        log=''
        for part in (exc.stdout,exc.stderr):
            if part:log+=part.decode(errors='replace') if isinstance(part,bytes) else part
        (out/'runner-console.log').write_text(log)
        failure=re.search(r'LN_(?:RUNTIME|SELFTEST)_FAILURE:[^\r\n]*',log)
        if failure:report['reported_runtime_failure']=failure.group(0)
    (ROOT/'evidence/runtime_checks.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
    sys.exit(0 if report.get('exit_code')==0 and all(report.get(key) for key in ('native_checks_pass','runtime_pass','mask_gpu_pass','sprite_decoder_pass','ln1_control_vectors_pass','ln1_player_vectors_pass','ln1_enemy_vectors_pass','ln1_combat_vectors_pass','ln1_world_smoke_pass','ln1_feedback_pass','ln1_water_vectors_pass','scene_navigation_pass','ln1_levels_pass','ln1_projectiles_pass','ln2_player_vectors_pass','ln2_enemy_vectors_pass','ln2_entrances_pass','ln2_helicopter_pass','ln2_vehicles_pass','ln2_effects_pass','ln2_combat_vectors_pass','ln2_world_pass','ln2_keypad_pass','ln2_candles_pass','ln2_boss_release_pass','ln2_object_integration_pass','ln2_item_flow_pass','ln2_final_gpu_pass','ln2_status_pass','ln2_ending_pass','ln2_ending_gpu_pass','ln3_movement_pass','ln3_actions_pass','ln3_input_pass','ln3_animation_pass','ln3_masks_pass','ln3_collision_pass','ln3_enemy_pass','ln3_combat_pass','ln3_scenes_pass','ln3_items_pass','ln3_scenery_pass','ln3_scenery_gpu_pass','ln3_special_pass','ln3_transition_pass','ln3_ending_pass','ln3_ending_gpu_pass','ln3_mechanism_gpu_pass','ln3_world_pass','ln3_gpu_pass')) else 1)
