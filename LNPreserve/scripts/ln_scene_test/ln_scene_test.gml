/// Development navigation. These keys never enter the original joystick input.
function ln_test_direction(_right, _down, _left, _up) {
    if (real(_right) + real(_down) + real(_left) + real(_up) != 1) return -1;
    return _right ? 0 : (_down ? 1 : (_left ? 2 : 3));
}

/// F11-only protection. It deliberately excludes scenery and level hazards.
function ln_test_enemy_damage_disabled() {
    return variable_global_exists("ln_test_no_enemy_damage") && global.ln_test_no_enemy_damage;
}

function ln1_test_enter(_g, _entry) {
    if (_entry < 4 || (_entry >> 2) > array_length(_g.world.rooms)) return false;
    var _p = _g.player;
    // Cancel transient activity so a jump, prayer or drowning sequence cannot
    // continue in the destination. Inventory and saved enemy wounds survive.
    _g.pickup_assist=undefined;
    _g.prayer_phase = 0; _g.water_active = false; _g.water_ticks = 0;
    _g.water_cutoff = 173; _g.death_wait = 0; _g.game_over = false;
    _g.sequence_kind = 0; _g.sequence_wait = 0; _g.water_travel = false;
    if (_g.player_health <= 0) _g.player_health = 32;
    if (_g.lives_left <= 0) _g.lives_left = 1;
    _p.action = 0; _p.action_state = 0; _p.flags = 0; _p.countdown = 0; _p.duration = 0;
    _p.input_lock = 0; _p.stopped = 255; _p.fraction_x = 0; _p.fraction_y = 0;
    _p.walk_clock = 0; _p.fire_previous = 0; _p.attack_direction = 255; _p.attack_previous = 255;
    _p.collision = 0; _p.requests = []; _p.last_tick = _p.tick;
    _g.notice_item = -1; _g.notice_label = 0; _g.notice_duration = 0;
    if (is_struct(_g.controls)) _g.controls.weapon_locked = 0;
    ln1_play_travel(_g, _entry);
    _p.combat_state = _p.facing >> 1; _p.previous_combat = _p.combat_state;
    _p.saved_heading = _p.heading; _p.action_mirror = _p.facing & 2;
    return true;
}

/// 1 = travelled; 0 = no exit; -1 = end of the game.
function ln1_test_exit(_g, _direction) {
    if (_direction < 0 || _direction > 3) return 0;
    var _room = _g.navigation.rooms[_g.room_id - 1];
    var _entry = _room.entries[_direction];
    if (variable_struct_exists(_room,"routes")) {
        // Some original rooms have two exits facing the same isometric way.
        // Use the one nearest Armakuni, including one-way secret passages.
        var _nearest = infinity;
        for (var _i=0;_i<array_length(_room.routes);_i++) {
            var _route = _room.routes[_i];
            if (_route.direction != _direction) continue;
            var _distance = point_distance(_g.player.x,_g.player.y,_route.x,_route.y);
            if (_distance < _nearest) { _nearest = _distance; _entry = _route.entry; }
        }
    }
    if (_entry == 0) return ln1_level_load(_g,_g.level+1,true) ? 1 : -1;
    if (_entry < 0) return 0;
    return ln1_test_enter(_g, _entry) ? 1 : 0;
}

function LNSceneTest(_catalog) constructor {
    menu = false; preview = false; game = 1; level_index = 0; scene_index = 0;
    message = ""; message_us = 0; levels = [];
    var _names = [["Wastelands","Wilderness","Palace Gardens","Dungeons","Palace","Inner Sanctum"],
        ["Central Park","Street","Sewers","Basement","Office","Mansion","Final Battle"],
        ["Earth","Wind","Water","Fire","Void"]];
    for (var _game = 1; _game <= 3; _game++) {
        for (var _level = 1; _level <= array_length(_names[_game-1]); _level++) {
            var _id = "ln" + string(_game) + "_game_level" + string(_level);
            for (var _i = 0; _i < array_length(_catalog.datasets); _i++) {
                var _dataset = _catalog.datasets[_i];
                if (_dataset.id != _id) continue;
                var _scenes = [];
                for (var _j = 0; _j < array_length(_dataset.locations); _j++) {
                    var _loc = _dataset.locations[_j];
                    for (var _k = 0; _k < array_length(_loc.source_ids); _k++)
                        array_push(_scenes, {id:_loc.source_ids[_k], sprite:asset_get_index(_loc.sprite_name)});
                }
                array_sort(_scenes, function(_a,_b) { return _a.id - _b.id; });
                if (_game <= 3) {
                    var _folder = _game>=2 ? "play/ln"+string(_game)+"/level"+string(_level)+"/" :
                        (_level == 1 ? "play/ln1/" : "play/ln1/level"+string(_level)+"/");
                    var _buffer=buffer_load(_folder+"world.json");
                    var _world=json_parse(buffer_read(_buffer,buffer_text));buffer_delete(_buffer);
                    _scenes=[];
                    for (var _j=0;_j<array_length(_world.rooms);_j++) {
                        if (_game==2 && _world.rooms[_j].spawn_entry<0) continue;
                        if (_game==3 && !_world.rooms[_j].playable) continue;
                        array_push(_scenes,{id:_world.rooms[_j].id,sprite:asset_get_index(_world.rooms[_j].sprite)});
                    }
                }
                array_push(levels, {game:_game, number:_level, title:_names[_game-1][_level-1],
                    playable:true, scenes:_scenes});
            }
        }
    }
}

function ln_scene_test_message(_t, _text) { _t.message = _text; _t.message_us = 3000000; }

function ln_scene_test_open(_t, _g, _scene_index) {
    var _level = _t.levels[_t.level_index];
    var _intro=_scene_index==-1;
    if ((!_intro && _scene_index < 0) || _scene_index >= array_length(_level.scenes)) return false;
    _t.scene_index = _scene_index; _t.menu = false; _t.preview = !_level.playable;
    if (_level.playable) {
        var _was_loader=ln2_loader_active(_g);
        var _new_level=_g.game_number!=_level.game || _g.level!=_level.number;
        ln_game_select(_g,_level.game,_level.number);
        if (_new_level) {
            if (_level.game==1) {
                _g.player_health=32;_g.health_display=32;
                if (_level.number==2) ln1_test_wilderness_kit(_g);
            } else if (_level.game==2) _g.player_health=44;
            else {_g.state.player_health=44;_g.state.inventory[26]=44;}
        }
        var _room = _level.scenes[_intro ? 0 : _scene_index].id;
        if (_level.game==3) return ln_frontend_selected(_g,ln3_test_enter(_g,_room),_intro,_was_loader && !_new_level);
        if (_level.game==2) {
            for (var _i=0;_i<array_length(_g.world.rooms);_i++)
                if (_g.world.rooms[_i].id==_room) {
                    var _entered=ln2_test_enter(_g,_g.world.rooms[_i].spawn_entry);
                    if (_entered && _intro) ln2_loader_begin(_g);
                    else if (_entered && _was_loader && !_new_level) {
                        ln_music_play(2,ln2_level_track(_g.level),false);
                        if (!_g.music && variable_global_exists("ln_music_voice")) audio_pause_sound(global.ln_music_voice);
                    }
                    return _entered;
                }
            return false;
        }
        return ln_frontend_selected(_g,ln1_test_enter(_g, _g.navigation.rooms[_room-1].spawn_entry),_intro,_was_loader && !_new_level);
    }
    return true;
}

function ln_scene_test_step(_t, _g) {
    _t.message_us = max(0, _t.message_us - delta_time);
    if (keyboard_check_pressed(vk_escape)) {
        if (_t.menu) _t.menu = false;
        else _t.preview = false;
        return;
    }
    if (_t.menu) {
        if (!mouse_check_button_pressed(mb_left)) return;
        var _mx = mouse_x, _my = mouse_y;
        for (var _game = 1; _game <= 3; _game++) {
            if (point_in_rectangle(_mx,_my,160+(_game-1)*320,116,464+(_game-1)*320,160)) {
                _t.game = _game;
                for (var _i = 0; _i < array_length(_t.levels); _i++) {
                    if (_t.levels[_i].game == _game) { _t.level_index = _i; _t.scene_index = 0; break; }
                }
                return;
            }
        }
        var _row = _t.game==3?1:0;
        for (var _i = 0; _i < array_length(_t.levels); _i++) {
            if (_t.levels[_i].game != _t.game) continue;
            if (point_in_rectangle(_mx,_my,160,218+_row*54,442,264+_row*54)) {
                _t.level_index = _i; _t.scene_index = 0; return;
            }
            _row++;
        }
        if (_t.game==3 && point_in_rectangle(_mx,_my,160,218,442,264)) {
            ln3_presentation_open(_t,_g,true);return;
        }
        if (_t.game==3 && point_in_rectangle(_mx,_my,160,542,442,588)) {
            ln3_presentation_open(_t,_g,false);return;
        }
        var _scenes = _t.levels[_t.level_index].scenes;
        var _offset=1;
        for (var _i = -_offset; _i < array_length(_scenes); _i++) {
            var _slot=_i+_offset;
            var _x = 480 + (_slot mod 7)*88, _y = 266 + (_slot div 7)*64;
            if (point_in_rectangle(_mx,_my,_x,_y,_x+76,_y+48)) {
                ln_scene_test_open(_t,_g,_i); return;
            }
        }
        if (point_in_rectangle(_mx,_my,480,610,854,658)) {
            global.ln_test_no_enemy_damage = !ln_test_enemy_damage_disabled();
            ln_scene_test_message(_t,global.ln_test_no_enemy_damage ?
                "Enemy damage disabled for testing." : "Enemy damage restored.");
            return;
        }
        if (point_in_rectangle(_mx,_my,160,674,442,722)) { _t.menu = false; _t.preview = false; }
        return;
    }
    var _direction = ln_test_direction(keyboard_check_pressed(vk_numpad9),keyboard_check_pressed(vk_numpad3),
        keyboard_check_pressed(vk_numpad1),keyboard_check_pressed(vk_numpad7));
    if (_t.preview) {
        if (_direction >= 0) ln_scene_test_message(_t,"Directional exits and gameplay are not connected for this level yet.");
        var _next = real(keyboard_check_pressed(vk_pagedown)) - real(keyboard_check_pressed(vk_pageup));
        if (_next) {
            var _count = array_length(_t.levels[_t.level_index].scenes);
            _t.scene_index = (_t.scene_index + _next + _count) mod _count;
        }
    } else if (_direction >= 0) {
        var _result = _g.game_number==1?ln1_test_exit(_g,_direction):(_g.game_number==2?ln2_test_exit(_g,_direction):ln3_test_exit(_g,_direction));
        var _labels = ["NE","SE","SW","NW"], _label = _labels[_direction];
        ln_scene_test_message(_t,_result == 1 ? _label + " to scene " + string(_g.room_id) :
            (_result == 0 ? "No " + _label + " exit in this scene." : "End of The Last Ninja."));
    }
}

function ln_scene_test_button(_x,_y,_w,_h,_label,_selected) {
    draw_set_colour(_selected ? make_colour_rgb(45,97,80) : make_colour_rgb(42,47,55));
    draw_rectangle(_x,_y,_x+_w,_y+_h,false);
    draw_set_colour(c_white); draw_text(_x+12,_y+14,_label);
}

function ln_scene_test_draw(_t) {
    var _level = _t.levels[_t.level_index];
    draw_clear(make_colour_rgb(20,23,28)); draw_set_colour(c_white);
    if (_t.menu) {
        draw_text(160,54,"SCENE TESTING");
        draw_text(160,82,"Choose a game, level and scene. Escape closes this menu.");
        for (var _game = 1; _game <= 3; _game++)
            ln_scene_test_button(160+(_game-1)*320,116,304,44,"Last Ninja " + string(_game),_t.game==_game);
        draw_set_colour(c_white); draw_text(160,186,"LEVEL"); draw_text(480,186,"SCENE");
        var _row = _t.game==3?1:0;
        for (var _i = 0; _i < array_length(_t.levels); _i++) {
            if (_t.levels[_i].game != _t.game) continue;
            ln_scene_test_button(160,218+_row*54,282,46,string(_t.levels[_i].number)+"  "+_t.levels[_i].title,_t.level_index==_i);
            _row++;
        }
        if (_t.game==3) {
            ln_scene_test_button(160,218,282,46,"INTRO",false);
            ln_scene_test_button(160,542,282,46,"OUTRO",false);
        }
        draw_set_colour(_level.playable ? make_colour_rgb(125,210,171) : make_colour_rgb(245,190,100));
        draw_text(480,224,"Playable prototype — movement, objects and combat");
        var _offset=1;
        for (var _i = -_offset; _i < array_length(_level.scenes); _i++) {
            var _slot=_i+_offset;
            ln_scene_test_button(480+(_slot mod 7)*88,266+(_slot div 7)*64,76,48,string(_i+1),_t.scene_index==_i);
        }
        ln_scene_test_button(480,610,374,48,ln_test_enemy_damage_disabled() ?
            "Enemy damage: OFF (test protection)" : "Enemy damage: ON",ln_test_enemy_damage_disabled());
        ln_scene_test_button(160,674,282,48,"Return to gameplay",false);
        draw_set_colour(make_colour_rgb(165,173,184));
        draw_text(480,674,"Numpad exits: 7 NW / 9 NE / 1 SW / 3 SE (Num Lock)");
        draw_text(480,700,"Collected items and enemy wounds persist; hazards stay active.");
    } else {
        var _scene = _level.scenes[_t.scene_index];
        draw_text(160,48,"LAST NINJA " + string(_level.game) + " — " + _level.title + " — Scene " + string(_t.scene_index+1));
        draw_sprite_ext(_scene.sprite,0,280,164,3,3,0,c_white,1);
        draw_set_colour(make_colour_rgb(245,190,100));
        draw_text(160,642,"SCENERY PREVIEW — movement, collision, objects and combat are not connected for this level.");
        draw_set_colour(c_white); draw_text(160,680,"Page Up / Page Down: previous / next preview    F11: choose scene    Escape: return to gameplay");
        if (_t.message_us > 0) draw_text(160,730,_t.message);
    }
    draw_set_colour(c_white);
}

/// F11 Wilderness starter equipment; normal progression still carries inventory.
function ln1_test_wilderness_kit(_g) {
    _g.inventory[2]=1; // Sack
    _g.inventory[11]=1; // Sword
    _g.inventory[13]=1; // Nunchakus
    _g.inventory[14]=5; // Throwing stars
    _g.inventory[15]=3; // Smoke bombs
    _g.lives_left=4;_g.player_health=32;_g.health_display=32;
    ln1_level_sync_controls(_g);
}
