try {
elapsed_us += int64(delta_time);
// Input is stamped at observation time, not retroactively applied to host-stall debt.
input_state.sample((elapsed_us div 1000000) * clock.hz + ((elapsed_us mod 1000000) * clock.hz) div 1000000);
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
if (keyboard_check_pressed(vk_home)) {
    if (play.game_number==2) ln2_ending_free(play);
    if (play.game_number==3) ln3_ending_free(play);
    var _transport = play.timer;
    if (surface_exists(play.stage_surface)) surface_free(play.stage_surface);
    if (variable_struct_exists(play,"part_surface") && surface_exists(play.part_surface)) surface_free(play.part_surface);
    play = play.game_number==1?new LN1Play():(play.game_number==2?new LN2Play():new LN3Play()); play.timer = _transport;
    play.timer.cycles_per_frame=play.data.timer_period_cycles;
    var _control_buffer = buffer_load("actors/ln1/initial_control_state.json");
    control_state_ln1 = json_parse(buffer_read(_control_buffer,buffer_text)); buffer_delete(_control_buffer);
    play.controls = control_state_ln1;
    scene_test.menu = false; scene_test.preview = false; scene_test.message_us = 0;
}
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
    show_debug_message("LN_RUNTIME_PASS: project initialized and rendered eight host frames, including the second room and its enemy.");
    game_end();
}

} catch (_runtime_failure) {
    if (!selftest) throw _runtime_failure;
    show_debug_message("LN_RUNTIME_FAILURE: " + string(_runtime_failure));
    game_end();
}
