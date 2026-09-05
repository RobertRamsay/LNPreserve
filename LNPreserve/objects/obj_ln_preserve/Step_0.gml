elapsed_us += int64(delta_time);
// Input is stamped at observation time, not retroactively applied to host-stall debt.
input_state.sample((elapsed_us div 1000000) * clock.hz + ((elapsed_us mod 1000000) * clock.hz) div 1000000);
clock.advance(delta_time, tick_native);
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
host_frames++;
if (selftest && host_frames >= 5) {
    show_debug_message("LN_RUNTIME_PASS: project initialized and rendered five host frames.");
    game_end();
}
