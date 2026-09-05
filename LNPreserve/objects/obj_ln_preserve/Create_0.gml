gpu_set_texfilter(false);
window_set_caption("LNPreserve | conversion workbench");
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
if (selftest) ln_run_checks();
var _control_buffer = buffer_load("actors/ln1/initial_control_state.json");
control_state_ln1 = json_parse(buffer_read(_control_buffer,buffer_text));
buffer_delete(_control_buffer);
tick_native = function(_from, _to, _frame) {
    input_state.consume(_to);
    var _rows = ln1_control_rows(input_state);
    ln1_control_effects = ln1_controls_update(control_state_ln1,_rows[0],_rows[1]);
    // This movable rectangle is a mask probe, not reconstructed Armakuni logic.
    probe_x = clamp(probe_x + 2 * (input_state.held[LNKey.Right] - input_state.held[LNKey.Left]), 0, 236);
    probe_y = clamp(probe_y + (input_state.held[LNKey.Down] - input_state.held[LNKey.Up]), 40, 160);
    if (input_state.pressed[LNKey.Weapon]) weapon_presses++;
    for (var _i = 0; _i < 4; _i++) {
        if (input_state.pressed[LNKey.F1 + _i]) function_presses[_i]++;
    }
    probe_jump = input_state.held[LNKey.Fire] ? 16 : 0;
};
