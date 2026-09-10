if (save_ui_test) {
    save_ui_frame++;
    if (save_ui_frame mod 3==0) {
        var _case=save_ui_frame div 3;global.ln_crt_enabled=bool(_case&1);
        var _factor=_case<2?1:2;window_set_size(1280*_factor,800*_factor);
    }
    exit;
}
try {
if (window_presets_test) {
    crt_live_frame++;
    if (crt_live_frame==0) ln_window_preset(1);
    if (crt_live_frame==2) ln_window_preset(2);
    if (crt_live_frame==4) ln_window_preset(0);
    exit;
}
if (crt_live_test) {
    crt_live_frame++;
    if (crt_live_frame==1 || crt_live_frame==2) ln_crt_toggle();
    exit;
}
if (presentation_test) exit;
if (!selftest && !workbench && !scene_test.menu && !scene_test.preview) ln_crt_step();
if (!selftest && ln_saves_step(self)) exit;
elapsed_us += int64(delta_time);
// Input is stamped at observation time, not retroactively applied to host-stall debt.
input_state.sample((elapsed_us div 1000000) * clock.hz + ((elapsed_us mod 1000000) * clock.hz) div 1000000);
if (play.game_number==2 && !workbench && keyboard_check_pressed(vk_f8)) play.one_hit_kills=!play.one_hit_kills;
if (keyboard_check_pressed(vk_f12)) { workbench = !workbench; scene_test.menu = false; }
if (keyboard_check_pressed(vk_f11)) {
    workbench = false; scene_test.menu = !scene_test.menu;
    if (scene_test.menu && !scene_test.preview) {
        scene_test.game = play.game_number;
        for (var _i=0;_i<array_length(scene_test.levels);_i++) {
            var _level=scene_test.levels[_i];
            if (_level.game!=play.game_number || _level.number!=play.level) continue;
            scene_test.level_index=_i;
            for (var _j=0;_j<array_length(_level.scenes);_j++) if (_level.scenes[_j].id==play.room_id) scene_test.scene_index=_j;
            break;
        }
    }
}
var _quick_game=keyboard_check_pressed(vk_home)?play.game_number:0;
if (!selftest) for(var _game_key=1;_game_key<=3;_game_key++)
    if (keyboard_check_pressed(ord("0")+_game_key)) {_quick_game=_game_key;break;}
if (_quick_game>0) ln_quick_start(self,_quick_game);
play.timer.advance(delta_time, tick_native);
if (!workbench) ln_scene_test_step(scene_test, play);
if (workbench) {
var _datasets = array_length(catalog.datasets);
if (keyboard_check_pressed(ord("Q"))) { dataset_index = (dataset_index + _datasets - 1) mod _datasets; asset_index = 0; }
if (keyboard_check_pressed(ord("E"))) { dataset_index = (dataset_index + 1) mod _datasets; asset_index = 0; }
if (keyboard_check_pressed(vk_tab)) { view_mode = 1 - view_mode; asset_index = 0; }
if (keyboard_check_pressed(ord("M"))) mask_enabled = !mask_enabled;
if (keyboard_check_pressed(ord("T"))) test_fixture = !test_fixture;
var _dataset = catalog.datasets[dataset_index];
if (array_length(_dataset.locations) == 0) view_mode = 1;
var _assets = view_mode == 0 ? _dataset.locations : _dataset.objects;
var _count = array_length(_assets);
if (_count > 0) {
    if (keyboard_check_pressed(vk_left)) asset_index = (asset_index + _count - 1) mod _count;
    if (keyboard_check_pressed(vk_right)) asset_index = (asset_index + 1) mod _count;
}
}
host_frames++;
if (selftest && host_frames == 4) {
    for (var _i = 0; _i < 160; _i++) { play.timer.cycle += 18433; ln1_play_tick(play, 9); }
}
if (selftest && host_frames >= 8) {
    show_debug_message("LN_TEST_PASS:runtime");
    show_debug_message("LN_RUNTIME_PASS: project initialized and rendered eight host frames, including the second room and its enemy.");
    game_end();
}

} catch (_runtime_failure) {
    if (!selftest) throw _runtime_failure;
    show_debug_message("LN_TEST_FAIL:runtime");
    show_debug_message("LN_RUNTIME_FAILURE: " + string(_runtime_failure));
    game_end();
}
