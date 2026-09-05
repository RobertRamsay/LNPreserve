function ln_check(_condition, _message) {
    if (!_condition) show_error("LNPreserve self-test failed: " + _message, true);
}

function ln_run_checks() {
    var _clock = new LNClock();
    var _ticks = 0;
    var _tick = function(_start, _end, _frame) { };
    // One second at 60 host updates: no rounded 50 Hz timer and no drift.
    for (var _i = 0; _i < 59; _i++) _clock.advance(16667, _tick, 100);
    _clock.advance(16647, _tick, 100);
    ln_check(_clock.frame == 50, "one-second PAL frame count");
    ln_check(_clock.cycle == 982800, "one-second cycle boundary");
    ln_check(_clock.credit == int64(2448000000), "fractional PAL remainder retained");
    var _stalled = new LNClock();
    _stalled.advance(1000000, _tick, 1);
    for (var _i = 0; _i < 49; _i++) _stalled.advance(0, _tick, 1);
    ln_check(_stalled.cycle == _clock.cycle && _stalled.credit == _clock.credit, "stall debt retained");
    var _input = new LNInput();
    _input.enqueue(10, LNKey.Up, true);
    _input.enqueue(20, LNKey.Up, false);
    _input.consume(19);
    ln_check(_input.held[LNKey.Up] && _input.joystick() == 254, "input cycle boundary");
    _input.consume(20);
    ln_check(!_input.held[LNKey.Up] && _input.released[LNKey.Up], "release event");
    _input.enqueue(21, LNKey.Up, true);
    _input.enqueue(22, LNKey.Down, true);
    _input.consume(22);
    ln_check(_input.joystick() == 255, "opposite directions cancel");
    ln_check(_input.bindings[LNKey.Weapon] == vk_space, "Space remains weapon selection");
    ln_check(ln_actor_depth(120) < ln_actor_depth(100), "foot depth order");
    ln_check(ln_occluder_active(90,100) && !ln_occluder_active(110,100), "depth band activation");
    var _buf = buffer_load("actors/ln1/manifest.json");
    ln_check(_buf >= 0,"original sprite test vectors available");
    var _actors = json_parse(buffer_read(_buf,buffer_text));
    buffer_delete(_buf);
    for (var _i = 0; _i < array_length(_actors.parts); _i++) {
        var _part = _actors.parts[_i];
        var _decoded = ln1_unpack_sprite(_part.encoded,_part.pointer,_part.id);
        ln_check(_decoded.instruction_cycles == _part.instruction_cycles,"6502 sprite cycle count " + string(_i));
        for (var _b = 0; _b < 63; _b++)
            ln_check(_decoded.bytes[_b] == _part.decoded[_b],"6502 sprite byte " + string(_i) + ":" + string(_b));
    }
    show_debug_message("LN_SPRITE_PASS: 192 parts match original 6502 bytes and instruction-cycle counts. System bus timing excluded.");
    _buf = buffer_load("verification/ln1_control_vectors.json");
    ln_check(_buf >= 0,"original control test vectors available");
    var _tests = json_parse(buffer_read(_buf,buffer_text));
    buffer_delete(_buf);
    for (var _i = 0; _i < array_length(_tests.vectors); _i++) {
        var _v = _tests.vectors[_i];
        var _s = _v.initial;
        var _effects = ln1_controls_update(_s,_v.row0,_v.row7);
        var _fields = ["music","pause","item","weapon","weapon_locked","action_reset"];
        for (var _j = 0; _j < array_length(_fields); _j++)
            ln_check(variable_struct_get(_s,_fields[_j]) == variable_struct_get(_v.expected,_fields[_j]),
                "6502 control state " + string(_i) + ":" + _fields[_j]);
        for (var _j = 0; _j < 5; _j++)
            ln_check(_s.previous[_j] == _v.expected.previous[_j],"6502 control edge " + string(_i));
        ln_check(array_length(_effects) == array_length(_v.effects),"6502 control request count " + string(_i));
        for (var _j = 0; _j < array_length(_effects); _j++) {
            var _a = _effects[_j], _b = _v.effects[_j];
            ln_check(_a.kind == _b.kind && _a.a == _b.a && _a.x == _b.x,"6502 control request order " + string(_i));
        }
    }
    show_debug_message("LN_CONTROLS_PASS: all 1024 previous/current key chords match original selection state and external request order. Timing not tested.");
    show_debug_message("LN_SELFTEST_PASS: clock, input, depth. Original gameplay parity is NOT tested.");
}

function ln_run_mask_checks() {
    ln_check(shader_is_compiled(sh_ln_occlusion), "occlusion shader compiled");
    var _surface = surface_create(1280,800);
    ln_check(surface_exists(_surface), "mask test surface allocation");
    surface_set_target(_surface);
    draw_clear_alpha(c_black,1);
    ln_draw_masked_actor(spr_depth_probe,0,120,60,1,1,spr_depth_fixture,0,0,256,160);
    surface_reset_target();
    var _yellow = make_colour_rgb(255,200,60);
    ln_check(surface_getpixel(_surface,123,65) == _yellow, "unmasked sprite pixel survives");
    ln_check(surface_getpixel(_surface,130,65) == c_black, "foreground masks part of sprite");
    ln_check(surface_getpixel(_surface,130,79) == _yellow, "hole in mask remains transparent");
    surface_save(_surface,"lnpreserve-mask-test.png");
    surface_free(_surface);
    show_debug_message("LN_MASK_PASS: real GPU pixel readback, partial coverage and transparent hole.");
}
