function ln_check(_condition, _message) {
    if (!_condition) throw "LNPreserve self-test failed: " + _message;
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
    ln1_player_checks();
    ln1_enemy_checks();
    ln1_combat_checks();
    ln1_world_checks();
    ln1_feedback_checks();
    show_debug_message("LN_SELFTEST_PASS: clock, input, depth and isolated player routines. Full gameplay parity is NOT established.");
}

function ln1_world_checks() {
    var _g = new LN1Play();
    for (var _i = 0; _i < 160; _i++) { _g.timer.cycle += 18433; ln1_play_tick(_g, 9); }
    ln_check(_g.room_id == 2, "Wastelands walk from the starting room reaches room 2");
    ln_check(_g.enemy.active >= 128, "room 2 original enemy spawn becomes active");
    for (var _i = 0; _i < 500; _i++) {
        _g.timer.cycle += 18433;
        ln1_play_tick(_g, _i < 100 ? 9 : ((_i mod 96) < 4 ? 0 : 17));
    }
    ln_check(_g.player_health >= 0 && _g.player_health <= 32, "encounter retains original health range");
    ln_check(_g.lives_left >= 0 && _g.lives_left <= 3, "encounter retains original life range");
    show_debug_message("LN_WORLD_PASS: 660 native game updates traverse the original first exit and exercise an enemy encounter without a runtime exception. Full-game replay parity remains open.");
}

function ln1_combat_checks() {
    var _buffer = buffer_load("verification/ln1_combat_vectors.json");
    var _tests = json_parse(buffer_read(_buffer,buffer_text)); buffer_delete(_buffer);
    var _g = new LN1Play();
    for (var _i = 0; _i < array_length(_tests.vectors); _i++) {
        var _v = _tests.vectors[_i];
        _g.player = _v.player; _g.enemy = _v.enemy;
        _g.enemy.active = _v.active; _g.enemy.attack_count = _v.attack_count;
        var _hit = ln1_combat_hit(_g, _v.enemy_attacks);
        ln_check(_hit == _v.expected, "melee hit " + string(_i) + ": " + string(_hit) + " expected " + string(_v.expected));
    }
    show_debug_message("LN_COMBAT_PASS: " + string(array_length(_tests.vectors)) + " original melee hit tests match. Damage dispatch and full combat replay require separate validation.");
}

function ln1_enemy_checks() {
    var _buf = buffer_load("verification/ln1_enemy_vectors.json");
    var _tests = json_parse(buffer_read(_buf, buffer_text)); buffer_delete(_buf);
    var _g = new LN1Play(), _fields = variable_struct_get_names(_tests.fields), _count = 0;
    for (var _i = 0; _i < array_length(_tests.vectors); _i++) {
        var _case = _tests.vectors[_i];
        _g.enemy = _case.initial; _g.player = _case.player;
        _g.enemy.mirror = false; _g.enemy.display_frame = _g.enemy.frame;
        for (var _j = 0; _j < array_length(_case.frames); _j++) {
            var _v = _case.frames[_j]; _g.player.tick = _v.tick;
            _g.random_queue = _v.randoms; _g.random_head = 0;
            ln1_enemy_decide(_g); ln1_enemy_action(_g);
            ln_check(_g.random_head == array_length(_v.randoms), _case.name + " random consumption " + string(_j));
            for (var _k = 0; _k < array_length(_fields); _k++) {
                var _field = _fields[_k], _actual = variable_struct_get(_g.enemy, _field), _expected = variable_struct_get(_v.expected, _field);
                ln_check(_actual == _expected, _case.name + " tick " + string(_j) + " " + _field + ": " + string(_actual) + " expected " + string(_expected));
            }
            ln_check(_g.enemy.action == _v.expected.action, _case.name + " action pointer " + string(_j) + ": " + string(_g.enemy.action) + " expected " + string(_v.expected.action));
            ln_check(_g.enemy.display_frame == _v.display.frame && _g.enemy.mirror == _v.display.mirror, _case.name + " enemy pose " + string(_j));
            _count++;
        }
    }
    show_debug_message("LN_ENEMY_PASS: " + string(_count) + " original-code enemy updates match with shared random bytes; full system timing excluded.");
}

function ln1_player_checks() {
    var _buf = buffer_load("verification/ln1_player_vectors.json");
    var _tests = json_parse(buffer_read(_buf, buffer_text)); buffer_delete(_buf);
    _buf = buffer_load("play/ln1/gameplay.json");
    var _data = json_parse(buffer_read(_buf, buffer_text)); buffer_delete(_buf);
    var _fields = variable_struct_get_names(_tests.fields), _count = 0;
    for (var _i = 0; _i < array_length(_tests.vectors); _i++) {
        var _case = _tests.vectors[_i], _s = _case.initial;
        _s.mirror = false; _s.display_frame = _s.frame;
        for (var _j = 0; _j < array_length(_case.frames); _j++) {
            var _v = _case.frames[_j];
            ln1_player_update(_s, _data, _v.joy, _v.tick);
            for (var _k = 0; _k < array_length(_fields); _k++) {
                var _field = _fields[_k], _actual = variable_struct_get(_s, _field), _expected = variable_struct_get(_v.expected, _field);
                ln_check(_actual == _expected, _case.name + " tick " + string(_j) + " " + _field + ": " + string(_actual) + " expected " + string(_expected));
            }
            ln_check(_s.action == _v.expected.action, _case.name + " action pointer " + string(_j));
            ln_check(_s.display_frame == _v.display.frame && _s.mirror == _v.display.mirror, _case.name + " rendered pose " + string(_j));
            _count++;
        }
    }
    show_debug_message("LN_PLAYER_PASS: " + string(_count) + " original-code player updates match native state and pose requests; system timing and world logic excluded.");
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
    surface_set_target(_surface);
    draw_clear_alpha(c_black,1);
    ln_draw_masked_actor(spr_depth_probe,0,120,60,1,1,spr_depth_fixture,0,0,256,160,0.5,70);
    surface_reset_target();
    ln_check(surface_getpixel(_surface,123,65) == _yellow, "sprite above waterline survives");
    ln_check(surface_getpixel(_surface,123,75) == c_black, "waterline clips otherwise visible sprite pixels");
    surface_save(_surface,"lnpreserve-mask-test.png");
    surface_free(_surface);
    show_debug_message("LN_MASK_PASS: real GPU pixel readback, partial coverage and transparent hole.");
}
