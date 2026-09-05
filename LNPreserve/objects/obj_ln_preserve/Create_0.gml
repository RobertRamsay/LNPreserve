gpu_set_texfilter(false);
window_set_caption("LNPreserve | The Last Ninja");
clock = new LNClock();
input_state = new LNInput();
elapsed_us = int64(0);
catalog_buffer = buffer_load("catalog.json");
catalog = json_parse(buffer_read(catalog_buffer, buffer_text));
buffer_delete(catalog_buffer);
dataset_index = 0;
asset_index = 0;
view_mode = 0;
probe_x = 120;
probe_y = 100;
probe_jump = 0;
mask_enabled = true;
test_fixture = false;
weapon_presses = 0;
function_presses = [0,0,0,0];
selftest = false;
host_frames = 0;
for (var _i = 1; _i <= parameter_count(); _i++) {
    if (parameter_string(_i) == "--selftest") selftest = true;
}
if (selftest) {
    try { ln_run_checks(); }
    catch (_failure) {
        show_debug_message("LN_SELFTEST_FAILURE: " + string(_failure));
        game_end(); exit;
    }
}
workbench = false;
play = new LN1Play();
var _control_buffer = buffer_load("actors/ln1/initial_control_state.json");
control_state_ln1 = json_parse(buffer_read(_control_buffer,buffer_text));
buffer_delete(_control_buffer);
play.controls = control_state_ln1;
ln_music_play(1, "wastelands", false);
tick_native = function(_from, _to, _frame) {
    input_state.consume(_to);
    var _rows = ln1_control_rows(input_state);
    var _music_before = control_state_ln1.music;
    ln1_control_effects = ln1_controls_update(control_state_ln1,_rows[0],_rows[1]);
    for (var _i = 0; _i < array_length(ln1_control_effects); _i++) {
        if (ln1_control_effects[_i].kind == "weapon_panel") {
            play.notice_item = -1; play.notice_label = 0; play.notice_duration = 0;
        }
    }
    if (_music_before != control_state_ln1.music) {
        if (control_state_ln1.music != 0) audio_resume_sound(global.ln_music_voice);
        else audio_pause_sound(global.ln_music_voice);
    }
    play.player.selected_weapon = control_state_ln1.weapon;
    if (control_state_ln1.pause == 0)
        ln1_play_tick(play, input_state.joystick() ^ 255);
    // This movable rectangle is a mask probe, not reconstructed Armakuni logic.
    probe_x = clamp(probe_x + 2 * (input_state.held[LNKey.Right] - input_state.held[LNKey.Left]), 0, 236);
    probe_y = clamp(probe_y + (input_state.held[LNKey.Down] - input_state.held[LNKey.Up]), 40, 160);
    if (input_state.pressed[LNKey.Weapon]) weapon_presses++;
    for (var _i = 0; _i < 4; _i++) {
        if (input_state.pressed[LNKey.F1 + _i]) function_presses[_i]++;
    }
    probe_jump = input_state.held[LNKey.Fire] ? 16 : 0;
};
