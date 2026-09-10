item_use_test=false;
street_snags_test=false;
ninja_transitions_test=false;
lives_pickup_test=false;
gap_landing_test=false;
fence_gap_boat_test=false;
water_knife_test=false;
reported_encounters_test=false;
gpu_set_texfilter(false);
global.ln_crt_enabled=false;
global.ln_crt_blur=0.15;
global.ln_crt_honeycomb=0.35;
global.ln_crt_scanlines=0.20;
global.ln_crt_drag=-1;
crt_surface=-1;
global.ln_test_no_enemy_damage=false;
ln3_only=false;
presentation_test=false;
crt_live_test=false;
window_presets_test=false;save_ui_test=false;save_ui_frame=-1;
crt_live_frame=-1;
crt_live_baseline=0;
ln2_final_only=false;
ln2_hud_only=false;ln2_keypad_visual_only=false;
ln2_switch_only=false;
ln2_spirits_only=false;
ln2_projectile_only=false;
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
selftest = false;ln1_only=false;selftest_inject_failure=false;
host_frames = 0;
for (var _i = 1; _i <= parameter_count(); _i++) {
    if(parameter_string(_i)=="--ln2-item-use-test") item_use_test=true;
    if(parameter_string(_i)=="--ln2-street-snags-test") street_snags_test=true;
    if(parameter_string(_i)=="--ninja-transitions-test") ninja_transitions_test=true;
    if(parameter_string(_i)=="--ln2-lives-pickup-test") lives_pickup_test=true;
    if(parameter_string(_i)=="--function-keys-test") {
        try {ln_function_key_checks();}
        catch(_failure) {show_debug_message("LN_FUNCTION_KEYS_FAILURE: "+string(_failure));}
        game_end();exit;
    }

    if(parameter_string(_i)=="--ln2-gap-landing-test") gap_landing_test=true;
    if(parameter_string(_i)=="--ln2-fence-gap-boat-test") fence_gap_boat_test=true;
    if(parameter_string(_i)=="--ln2-water-knife-test") water_knife_test=true;
    if (parameter_string(_i)=="--ln2-reported-encounters-test") reported_encounters_test=true;
    if (parameter_string(_i) == "--save-ui-test") save_ui_test=true;
    if (parameter_string(_i) == "--window-presets-test") {window_presets_test=true;global.ln_crt_enabled=true;}
    if (parameter_string(_i) == "--crt-live-test") crt_live_test=true;
    if (parameter_string(_i) == "--jump-assist-test") {
        try {ln1_jump_assist_checks();}
        catch (_failure) {show_debug_message("LN_JUMP_ASSIST_FAILURE: "+string(_failure));}
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln2-keypad-visual-test") ln2_keypad_visual_only=true;
    if (parameter_string(_i) == "--ln1-magic-test") {
        try {ln1_magic_checks();ln1_weapon_lock_checks();}
        catch (_failure) {show_debug_message("LN1_MAGIC_FAILURE: "+string(_failure));}
        game_end();exit;
    }
    if (parameter_string(_i) == "--xbox-test") {
        try {ln_xbox_checks();}
        catch (_failure) {show_debug_message("LN_XBOX_FAILURE: "+string(_failure));}
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln2-candle-body-test") {
        try {ln2_candle_body_checks();}
        catch (_failure) {show_debug_message("LN2_CANDLE_BODY_FAILURE: "+string(_failure));}
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln2-testing-aids-test") {
        try {ln2_testing_aid_checks();}
        catch (_failure) {show_debug_message("LN2_TESTING_AIDS_FAILURE: "+string(_failure));}
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln2-final-room-test") {
        try {ln2_final_room_checks();}
        catch (_failure) {show_debug_message("LN2_FINAL_ROOM_FAILURE: "+string(_failure));}
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln2-safe-code-test") {
        try {ln2_safe_code_checks();}
        catch (_failure) {show_debug_message("LN2_SAFE_CODE_FAILURE: "+string(_failure));}
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln2-burger-test") {
        try {ln2_burger_checks();}
        catch (_failure) {show_debug_message("LN2_BURGER_FAILURE: "+string(_failure));}
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln2-routes-test") {
        try {ln2_routes_checks();}
        catch (_failure) {show_debug_message("LN2_ROUTES_FAILURE: "+string(_failure));}
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln2-curtain-test") {
        try {ln2_curtain_checks();}
        catch (_failure) {show_debug_message("LN2_CURTAIN_FAILURE: "+string(_failure));}
        game_end();exit;
    }
    if (parameter_string(_i) == "--reverse-roll-test") {
        try {ln1_reverse_roll_checks();}
        catch (_failure) {show_debug_message("LN_REVERSE_ROLL_FAILURE: "+string(_failure));}
        game_end();exit;
    }
    if (parameter_string(_i) == "--pickup-crt-test") {
        presentation_test=true;
        try {ln1_pickup_assist_checks();show_debug_message("LN_PICKUP_PASS");}
        catch (_failure) {show_debug_message("LN_PICKUP_FAILURE: "+string(_failure));game_end();exit;}
    }
    if (parameter_string(_i) == "--selftest") selftest = true;
    if (parameter_string(_i) == "--selftest-fail-early") selftest_inject_failure=true;
    if (parameter_string(_i) == "--ln1-selftest") {selftest=true;ln1_only=true;}
    if (parameter_string(_i) == "--ln2-hud-test") ln2_hud_only=true;
    if (parameter_string(_i) == "--ln2-switch-test") ln2_switch_only=true;
    if (parameter_string(_i) == "--ln2-spirits-test") ln2_spirits_only=true;
    if (parameter_string(_i) == "--ln2-final-gpu-only") ln2_final_only=true;
    if (parameter_string(_i) == "--ln2-projectile-gpu-only") ln2_projectile_only=true;
    if (parameter_string(_i) == "--ln2-projectiles-only") {
        try {ln2_projectile_checks();}
        catch (_failure) {show_debug_message("LN2_PROJECTILE_FAILURE: "+string(_failure));}
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln2-objects-only") {
        try {ln2_keypad_checks();}
        catch (_failure) {show_debug_message("LN2_OBJECT_FAILURE: "+string(_failure));}
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln3-movement-only") {
        try { ln3_movement_checks(); }
        catch (_failure) { show_debug_message("LN3_MOVEMENT_FAILURE: "+string(_failure)); }
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln3-actions-only") {
        try { ln3_action_checks(); }
        catch (_failure) { show_debug_message("LN3_ACTION_FAILURE: "+string(_failure)); }
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln3-input-only") {
        try { ln3_input_checks(); }
        catch (_failure) { show_debug_message("LN3_INPUT_FAILURE: "+string(_failure)); }
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln3-animation-only") {
        try { ln3_animation_checks(); }
        catch (_failure) { show_debug_message("LN3_ANIMATION_FAILURE: "+string(_failure)); }
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln3-masks-only") {
        try { ln3_mask_checks(); }
        catch (_failure) { show_debug_message("LN3_MASK_FAILURE: "+string(_failure)); }
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln3-collision-only") {
        try { ln3_collision_checks(); }
        catch (_failure) { show_debug_message("LN3_COLLISION_FAILURE: "+string(_failure)); }
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln3-enemy-only") {
        try { ln3_enemy_checks(); }
        catch (_failure) { show_debug_message("LN3_ENEMY_FAILURE: "+string(_failure)); }
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln3-scenes-only") {
        try { ln3_scene_checks(); }
        catch (_failure) { show_debug_message("LN3_SCENES_FAILURE: "+string(_failure)); }
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln3-items-only") {
        try {ln3_item_checks();}
        catch (_failure) {show_debug_message("LN3_ITEMS_FAILURE: "+string(_failure));}
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln3-scenery-only") {
        try {ln3_scenery_checks();}
        catch (_failure) {show_debug_message("LN3_SCENERY_FAILURE: "+string(_failure));}
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln3-special-only") {
        try {ln3_special_checks();}
        catch (_failure) {show_debug_message("LN3_SPECIAL_FAILURE: "+string(_failure));}
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln3-world-only") {
        try {ln3_world_checks();ln3_only=true;}
        catch (_failure) {show_debug_message("LN3_WORLD_FAILURE: "+string(_failure));game_end();exit;}
    }
    if (parameter_string(_i) == "--ln3-combat-only") {
        try { ln3_combat_checks(); }
        catch (_failure) { show_debug_message("LN3_COMBAT_FAILURE: "+string(_failure)); }
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln2-sequences-only") {
        try { ln2_sequence_checks(); }
        catch (_failure) { show_debug_message("LN2_SEQUENCE_FAILURE: "+string(_failure)); }
        game_end();exit;
    }
    if (parameter_string(_i) == "--ln2-world-only") {
        try { ln2_world_checks(); }
        catch (_failure) { show_debug_message("LN2_WORLD_FAILURE: "+string(_failure)); }
        game_end();exit;
    }
}
if (selftest) {
    try {
        if (selftest_inject_failure) ln_test_run("ln1_core_checks",function(){ln_check(false,"deliberate reporting test");});
        ln_run_checks(ln1_only);
    }
    catch (_failure) {
        show_debug_message("LN_SELFTEST_FAILURE: " + string(_failure));
        game_end(); exit;
    }
}
workbench = false;
scene_test = new LNSceneTest(catalog);
play = new LN1Play();
var _control_buffer = buffer_load("actors/ln1/initial_control_state.json");
control_state_ln1 = json_parse(buffer_read(_control_buffer,buffer_text));
buffer_delete(_control_buffer);
play.controls = control_state_ln1;
saves = new LNSaves();
if (save_ui_test) {
    // In-memory display fixtures only: never add, restore or overwrite a save.
    saves.slots=[{name:"LN1_SAVE_12345",game:1},{name:"LN2_SAVE_12345",game:2},{name:"LN3_SAVE_12345",game:3}];
}
if (selftest) {
    try {ln_test_run("save_serialization",function(){ln_save_checks(ln1_only);});}
    catch (_failure) {show_debug_message("LN_SELFTEST_FAILURE: "+string(_failure));game_end();exit;}
    show_debug_message("LN_TEST_START:runtime");
}
ln_music_play(1, "wastelands", false);
tick_native = function(_from, _to, _frame) {
    input_state.consume(_to);
    var _rows = ln1_control_rows(input_state);
    // Keep the existing workbench probe responsive while gameplay is paused.
    probe_x = clamp(probe_x + 2 * (input_state.held[LNKey.Right] - input_state.held[LNKey.Left]), 0, 236);
    probe_y = clamp(probe_y + (input_state.held[LNKey.Down] - input_state.held[LNKey.Up]), 40, 160);
    probe_jump = input_state.held[LNKey.Fire] ? 16 : 0;
    if (input_state.pressed[LNKey.Weapon]) weapon_presses++;
    for (var _i = 0; _i < 4; _i++) {
        if (input_state.pressed[LNKey.F1 + _i]) function_presses[_i]++;
    }
    if (workbench || scene_test.menu || scene_test.preview) {
        // Browsing pauses gameplay and consumes selection edges, so closing the
        // picker cannot replay keys that were pressed while a preview was open.
        control_state_ln1.previous = [_rows[0]&16,_rows[0]&32,_rows[0]&64,_rows[0]&8,_rows[1]&16];
        if (play.game_number==2) play.control_previous=control_state_ln1.previous;
        return;
    }
    if(input_state.pressed[LNKey.CRT]) ln_crt_toggle();
    if(input_state.pressed[LNKey.WeaponPrev]) ln_controller_previous_weapon(play,control_state_ln1);
    if (play.game_number==2) {
        ln2_controls_update(play,_rows[0],_rows[1]);
        if (!play.paused) ln2_play_tick(play,input_state.joystick()^255);
        return;
    }
    if (play.game_number==3) {
        ln3_controls_update(play,input_state);
        if (!play.paused) ln3_play_tick(play,input_state.joystick()^255);
        return;
    }
    var _music_before = control_state_ln1.music;
    ln1_control_effects = ln1_controls_update(control_state_ln1,_rows[0],_rows[1],ln1_weapon_changing(play.player,play.data));
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
};
