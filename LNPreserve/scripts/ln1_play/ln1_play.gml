function LN1Play() constructor {
    var _buffer = buffer_load("play/ln1/gameplay.json");
    data = json_parse(buffer_read(_buffer, buffer_text)); buffer_delete(_buffer);
    _buffer = buffer_load("play/ln1/world.json");
    world = json_parse(buffer_read(_buffer, buffer_text)); buffer_delete(_buffer);
    player = data.initial;
    player.display_frame = player.frame;
    player.requests = [];
    player.previous_combat = 0;
    player.world_game = self;
    enemy = new LN1Enemy();
    player_health = 32; room_wounds = array_create(26, 0); room_id = 1;
    lives_left = world.initial_lives; last_entry = world.initial_entry; death_wait = 0; game_over = false;
    pending_events = []; random_queue = []; random_head = 0;
    inventory = world.initial_inventory; controls = undefined;
    notice_item = -1; notice_tick = 0; notice_duration = 0; notice_label = 0;
    room_age = 0; prayer_phase = 0;
    water_active = false; water_ticks = 0; water_cutoff = 173; water_x = 0;
    random_pointer = 0; random_value = 0;
    stage_surface = -1;
    timer = new LNClock();
    // CIA1 timer interrupt drives game logic separately from the VIC video frame.
    timer.cycles_per_frame = data.timer_period_cycles;
    sprites = [spr_ln1_player_weapon_0, spr_ln1_player_weapon_1, spr_ln1_player_weapon_2, spr_ln1_player_weapon_3];
    enemy_sprites = [spr_ln1_enemy_weapon_0, spr_ln1_enemy_weapon_1, spr_ln1_enemy_weapon_2, spr_ln1_enemy_weapon_3];
    ln1_play_enter(self, 1);
}

function ln1_play_enter(_g, _room_id) {
    _g.room_id = _room_id;
    var _room = _g.world.rooms[_room_id - 1];
    _g.data.boundaries = _room.boundaries;
    _g.scene = asset_get_index(_room.sprite);
    _g.mask = asset_get_index(_room.depth_sprite);
    _g.player.boundary_mode = _room.boundary_mode;
    _g.player.boundary_crossings = _room.entrance_crossings[_g.last_entry & 3];
    _g.room_age = 0;
    _g.enemy = new LN1Enemy();
    _g.enemy.action = _room.enemy_script;
    _g.enemy.action_tick = _g.player.tick;
    _g.enemy.decision_tick = _g.player.tick;
    _g.enemy.wounds = _g.room_wounds[_room_id];
    if (_g.enemy.wounds >= 32) _g.enemy.action = 0;
    _g.player.enemy_active = 0;
}

/// Source $7478: perimeter position selects one of up to four room exits.
function ln1_play_exit(_g) {
    var _p = _g.player, _perimeter;
    if (_p.y < 9) _perimeter = max(0, _p.x - 2) >> 2;
    else if (_p.y >= 189) _perimeter = (max(0, 247 - _p.x) >> 2) + 106;
    else if (_p.x >= 247) _perimeter = (max(0, _p.y - 9) >> 2) + 61;
    else if (_p.x < 2) _perimeter = (max(0, 189 - _p.y) >> 2) + 167;
    else return;
    var _room = _g.world.rooms[_g.room_id - 1], _exit = 0;
    while (_exit < 4 && _perimeter >= _room.exit_thresholds[_exit]) _exit++;
    if (_exit == 4) _exit = 0;
    var _entry = _room.exits[_exit], _room_id = _entry >> 2;
    if (_room_id == 0) { array_push(_g.pending_events, "level_complete"); return; }
    _g.last_entry = _entry;
    var _spawn = _g.world.entry_index[_entry];
    _p.x = _g.world.entry_x[_spawn]; _p.y = _g.world.entry_y[_spawn];
    _p.facing = _g.world.entry_heading[_spawn]; _p.heading = _p.facing;
    _p.frame = ((_p.facing + 2) & 4) * 2; _p.turn_lock = 255;
    ln1_play_enter(_g, _room_id);
    ln1_player_render(_p, _g.data.mirror[_p.facing >> 1] & (1 << _p.heading));
}

function ln1_play_tick(_g, _joy) {
    var _p = _g.player, _e = _g.enemy;
    if (_g.game_over) return;
    _g.room_age = min(62, _g.room_age + 1);
    if (_g.prayer_phase > 0) { ln1_prayer_tick(_g, _joy); return; }
    if (_g.water_active) { ln1_water_tick(_g); ln1_notice_update(_g); return; }
    if (_g.death_wait > 0) {
        _p.tick = (_p.tick + 1) & 255; _g.death_wait--;
        ln1_notice_update(_g);
        if (_g.death_wait == 0) {
            _g.lives_left--;
            if (_g.lives_left == 0 && _g.inventory[8] != 0) {
                _g.lives_left++; _g.inventory[8] = 0;
                if (is_struct(_g.controls)) _g.controls.inventory[8] = 0;
            }
            if (_g.lives_left == 0) { _g.game_over = true; return; }
            var _spawn = _g.world.entry_index[_g.last_entry];
            _p.x = _g.world.entry_x[_spawn]; _p.y = _g.world.entry_y[_spawn];
            _p.facing = _g.world.entry_heading[_spawn]; _p.heading = _p.facing;
            _p.frame = ((_p.facing + 2) & 4) * 2; _p.turn_lock = 255;
            _p.input_lock = 0; _p.last_tick = _p.tick; _g.player_health = 32;
            // A completed death command must not resume after the first spawn pose.
            _p.action = 0; _p.action_state = 0; _p.flags = 0; _p.countdown = 0; _p.duration = 0;
            _p.stopped = 255; _p.combat_state = _p.facing >> 1; _p.previous_combat = _p.combat_state;
            _p.saved_heading = _p.heading; _p.action_mirror = _p.facing & 2;
            _p.fraction_x = 0; _p.fraction_y = 0; _p.walk_clock = 0;
            _p.fire_previous = 0; _p.attack_direction = 255; _p.attack_previous = 255;
            _p.collision = 0; _p.requests = []; _g.water_cutoff = 173; _g.water_ticks = 0;
            ln1_play_enter(_g, _g.last_entry >> 2);
            ln1_player_render(_p, _g.data.mirror[_p.facing >> 1] & (1 << _p.heading));
        }
        return;
    }
    _p.enemy_active = _e.active; _p.enemy_x = _e.x; _p.enemy_y = _e.y;
    _p.separation_y = _e.separation_y;
    ln1_player_update(_p, _g.data, _joy, (_p.tick + 1) & 255);
    ln1_enemy_decide(_g);
    ln1_enemy_action(_g);
    ln1_combat_event(_g, _p.action_state, false); _p.action_state = 0;
    ln1_combat_event(_g, _e.action_state, true); _e.action_state = 0;
    ln1_play_exit(_g);
    ln1_play_hazards(_g);
    ln1_notice_update(_g);
    if (_g.player_health == 0 && _p.action < 256 && _g.death_wait == 0 && !_g.water_active) {
        _p.facing = ((_p.facing & 4) ^ 6) >> 1;
        _p.action = 23860; // Source death sequence $5d34.
        _p.flags = variable_struct_get(_g.data.actions, string(_p.action)).flags;
        _p.countdown = 0; _p.saved_heading = _p.heading; _p.action_mirror = _p.facing & 2;
        _p.input_lock = 255;
    }
}

function ln1_play_hazards(_g) {
    var _p = _g.player;
    if (_p.boundary_crossings == 0 || (!(_p.boundary_mode & 64) && _p.action >= 256)) return;
    if (_p.boundary_mode & 32) _p.boundary_crossings = 0;
    var _kind = _p.boundary_mode & 31;
    if (_kind == 1) {
        if ((_p.selected_weapon | _p.weapon) == 0 && _p.facing == 7) {
            _g.prayer_phase = 1; _p.input_lock = 255; _p.stopped = 255;
            if (is_struct(_g.controls)) _g.controls.weapon_locked = 255;
            ln1_special_action(_g, $ada5);
        }
        return;
    }
    if (_kind < 16 || _kind >= 20 || !(_p.boundary_crossings & 1)) return;
    var _areas = _g.world.safe_areas[_kind & 3];
    for (var _i = 0; _i < array_length(_areas); _i++) {
        var _r = _areas[_i];
        if (_p.x >= _r[0] && _p.x < _r[1] && _p.y >= _r[2] && _p.y < _r[3]) return;
    }
    _g.player_health = 0; _p.input_lock = 255;
    _g.water_active = true; _g.water_ticks = 0;
    _g.water_cutoff = min(_p.y + 24, 173); _g.water_x = _p.x;
    _p.action = 0; _p.action_state = 0; _p.flags = 0;
}

function ln1_notice_update(_g) {
    if (_g.notice_item >= 0 && ((_g.player.tick - _g.notice_tick) & 255) >= _g.notice_duration) {
        _g.notice_item = -1; _g.notice_label = 0; _g.notice_duration = 0;
    }
}

function ln1_special_action(_g, _address) {
    var _p = _g.player;
    _p.action = _address; _p.flags = variable_struct_get(_g.data.actions, string(_address)).flags;
    _p.countdown = 0; _p.saved_heading = _p.heading; _p.action_mirror = _p.facing & 2;
}

/// $be82-$bee0: approach facing northwest, empty handed; southeast leaves prayer.
function ln1_prayer_tick(_g, _joy) {
    var _p = _g.player;
    _p.tick = (_p.tick + 1) & 255; _p.last_tick = _p.tick;
    if (_g.prayer_phase != 2) {
        ln1_player_action(_p, _g.data, 1);
        ln1_enemy_action(_g);
        if (_p.action >= 256) return;
        if (_g.prayer_phase == 3) {
            _g.prayer_phase = 0; _p.input_lock = 0; _p.flags = 0; _p.stopped = 255;
            _g.notice_tick = _p.tick;
            if (is_struct(_g.controls)) _g.controls.weapon_locked = 0;
            return;
        }
        _g.prayer_phase = 2; _g.notice_item = 10;
        var _items = _g.world.prayer_hint_items;
        for (var _i = 0; _i < array_length(_items); _i++) {
            if (_g.inventory[_items[_i]] == 0) { _g.notice_item = _items[_i]; break; }
        }
        _g.notice_label = 2; _g.notice_duration = 50; _g.notice_tick = _p.tick;
    }
    if ((_joy & 15) == 10) { _g.prayer_phase = 3; ln1_special_action(_g, $adbd); }
}

/// $bef2/$bee3: sink two hardware pixels every two timer ticks, clipping at $9e.
function ln1_water_tick(_g) {
    var _p = _g.player;
    _p.tick = (_p.tick + 1) & 255; _p.last_tick = _p.tick; _g.water_ticks++;
    if ((_g.water_ticks & 1) != 0) return;
    _p.y += 2;
    ln1_player_render(_p, _g.data.mirror[_p.facing >> 1] & (1 << _p.heading));
    if (_p.y - 21 >= _g.water_cutoff) {
        _p.display_frame = 255; _g.water_active = false; _g.death_wait = 20;
    }
}

function ln1_play_actor(_g, _actor, _enemy) {
    if (_actor.display_frame == 255) return;
    var _frame = _actor.display_frame;
    var _sprites = _enemy ? _g.enemy_sprites : _g.sprites;
    var _sprite = _sprites[_actor.weapon < 4 ? _actor.weapon : 0];
    if (_frame >= 64 && _frame < 128) { _sprite = spr_ln1_actor_extra; _frame -= 64; }
    if (_frame >= 128) return; // Remaining level-specific actors require their composition bank.
    ln_draw_masked_actor(_sprite, _frame + (_actor.mirror ? 64 : 0), _actor.x, _actor.y,
        1, 1, _g.mask, 0, 0, 240, 144, max(0.001, (_actor.y - 0.25) / 255),
        _enemy ? 144 : _g.water_cutoff - 29);
}

function ln1_play_draw(_game, _paused) {
    draw_clear(c_black);
    var _scale = 3, _x = 160, _y = 84, _s = _game.player;
    draw_set_colour(c_white);
    if (!surface_exists(_game.stage_surface)) _game.stage_surface = surface_create(240,144);
    surface_set_target(_game.stage_surface);
    draw_clear(c_black); draw_sprite(_game.scene, 0, 0, 0);
    for (var _i = 0; _i < array_length(_game.world.items); _i++) {
        var _item = _game.world.items[_i];
        if (_item.room == _game.room_id && _game.inventory[_item.id] == 0) {
            var _flash = _game.room_age < 31 * _item.flashes;
            draw_sprite(asset_get_index(_flash ? _item.flash_sprite : _item.sprite),
                _flash ? (_game.room_age mod 31) : 0, _item.x, _item.y);
        }
    }
    if (_s.y < _game.enemy.y) { ln1_play_actor(_game, _s, false); ln1_play_actor(_game, _game.enemy, true); }
    else { ln1_play_actor(_game, _game.enemy, true); ln1_play_actor(_game, _s, false); }
    if (_game.water_active && _game.water_ticks < 24)
        draw_sprite(spr_ln1_water_ripple, _game.water_ticks div 6, _game.water_x - 14, _game.water_cutoff - 37);
    surface_reset_target();
    draw_surface_ext(_game.stage_surface, _x, _y, _scale, _scale, 0, c_white, 1);
    draw_sprite_ext(spr_ln1_dashboard, 0, _x, _y, _scale, _scale, 0, c_white, 1);
    draw_sprite_ext(spr_ln1_enemy_wounds, _game.room_wounds[_game.room_id], _x+248*_scale, _y+24*_scale, _scale, _scale, 0, c_white, 1);
    draw_sprite_ext(spr_ln1_status_label, _game.notice_label, _x+248*_scale, _y+64*_scale, _scale, _scale, 0, c_white, 1);
    var _icon = _game.notice_item >= 0 ? _game.notice_item : _s.selected_weapon + 10;
    draw_sprite_ext(spr_ln1_status_icon, _icon, _x+248*_scale, _y+80*_scale, _scale, _scale, 0, c_white, 1);
    if (is_struct(_game.controls))
        draw_sprite_ext(spr_ln1_status_icon, _game.controls.item, _x+248*_scale, _y+120*_scale, _scale, _scale, 0, c_white, 1);
    draw_set_colour(make_colour_rgb(180,180,180));
    draw_text(160, 36, "THE LAST NINJA — THE WASTELANDS");
    draw_text(930, 36, "Room " + string(_game.room_id));
    draw_text(160, 700, "WASD  Move    J + direction  Action    Space  Weapon    1 2 3 4  Function keys");
    draw_text(160, 732, "Wastelands gameplay in progress. Home restarts. Trilogy conversion is incomplete.");
    draw_text(160, 760, "Health " + string(_game.player_health) + "    Lives " + string(_game.lives_left));
    if (_game.prayer_phase > 0) draw_text(710, 760, "S + D  Finish prayer");
    if (_game.game_over) { draw_set_colour(c_white); draw_text(510, 54, "GAME OVER — HOME TO RESTART"); }
    if (_paused) { draw_set_colour(c_white); draw_text(594, 54, "PAUSED"); }
}
