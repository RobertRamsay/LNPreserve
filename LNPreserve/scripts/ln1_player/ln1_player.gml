/// Native translation of LN1's player routines ($5727, $5a12, $5b69, $7540).
/// Animation commands are decoded game data, not emulated CPU instructions.
function ln1_player_render(_s, _mirror) {
    _s.mirror = _mirror != 0;
    _s.display_frame = _s.frame;
    _s.redraw = 0;
}

function ln1_player_begin_action(_s, _d, _kind) {
    _s.combat_state = (_s.facing >> 1) + _d.action_classes[_kind >> 2];
    var _entry = (((_s.facing + 2) & 4) >> 1) + _kind;
    _s.action = _d.action_entries[_entry >> 1];
    _s.flags = variable_struct_get(_d.actions, string(_s.action)).flags;
    _s.countdown = 0;
    _s.saved_heading = _s.heading;
    _s.action_mirror = _s.facing & 2;
}

function ln1_player_fire_move(_s, _d, _heading) {
    if (_heading >= 128) {
        _s.stopped = 255;
        _s.combat_state = _s.facing >> 1;
        return;
    }
    if (_heading == _s.facing || ((_heading + 1) & 7) == _s.facing || ((_heading - 1) & 7) == _s.facing) {
        _s.stopped = 255;
        if ((_s.combat_state & 252) != 16) ln1_player_begin_action(_s, _d, 4);
    } else {
        // The original checks for an interactable before entering this action.
        // World interaction consumes this request when the room logic is run.
        array_push(_s.requests, "interact");
        if (variable_struct_exists(_s, "world_game")) ln1_item_interact(_s.world_game);
        _s.fire_previous = 0;
        ln1_player_begin_action(_s, _d, 0);
    }
}

function ln1_player_input(_s, _d, _joy) {
    if (_s.input_lock != 0) return;
    var _heading = _d.directions[_joy & 15];
    if ((_joy & 16) == 0) {
        _s.fire_previous = 0;
        _s.attack_direction = 255;
        if (_heading >= 128) {
            _s.stopped = _heading;
            _s.turn_lock = 0;
            if (_s.action < 256) {
                _s.combat_state = _s.facing >> 1;
                if (_s.weapon != _s.selected_weapon) ln1_player_begin_action(_s, _d, 8);
            }
            return;
        }
        _s.heading = _heading;
        if (_s.turn_lock != 0) {
            if (abs(_s.heading - _s.facing) >= 2) {
                _s.stopped = 255;
                _s.combat_state = _s.facing >> 1;
                return;
            }
            _s.turn_lock = 0;
        }
        if ((_heading & 1) && _heading != _s.facing && (_heading ^ 4) != _s.facing) {
            _s.facing = _heading;
            _s.redraw = 255;
        }
        _s.stopped = 0;
        _s.frame = (_s.frame & 7) | (((_s.facing + 2) & 4) ? 8 : 0);
        _s.combat_state = (_s.facing >> 1) + 8;
        return;
    }
    var _new_fire = _s.fire_previous != 16;
    _s.fire_previous = 16;
    if (_new_fire) {
        if (_s.stopped != 0) {
            _s.frame = 16 + (((_s.facing + 2) & 4) >> 2);
            _s.redraw = 255;
        } else ln1_player_fire_move(_s, _d, _heading);
        return;
    }
    if (_heading < 128) {
        var _changed = _heading != _s.attack_direction;
        _s.attack_direction = _heading;
        if (_changed) _s.attack_clock = _s.tick;
        else {
            if (_heading == _s.attack_previous) {
                if ((_s.combat_state & 252) != 16) {
                    _s.combat_state = _s.facing >> 1;
                    return;
                }
                _s.attack_clock = (_s.tick - 16) & 255;
            }
            _s.attack_previous = _heading;
            if (((_s.tick - _s.attack_clock) & 255) >= 4) {
                if (_s.boundary_mode >= 16 && _s.boundary_mode < 20) {
                    _s.stopped = 0;
                    _s.heading = _s.attack_direction;
                    ln1_player_fire_move(_s, _d, _s.attack_direction);
                } else {
                    if (_s.attack_direction & 1) {
                        array_push(_s.requests, "interact");
                        if (variable_struct_exists(_s, "world_game")) ln1_item_interact(_s.world_game);
                    }
                    var _kind = _s.attack_direction * 4 + 12;
                    if (_s.weapon == 0 || _s.weapon >= 4) _kind += 32;
                    ln1_player_begin_action(_s, _d, _kind);
                }
                return;
            }
        }
    }
    _s.attack_previous = 255;
    _s.combat_state = _s.facing >> 1;
}

/// The original room boundaries are sloping lines with 4-bit fractional slope.
function ln1_player_boundary(_s, _d, _nx, _ny) {
    var _crossed = 0, _collision = 0;
    for (var _i = 0; _i < array_length(_d.boundaries); _i++) {
        var _b = _d.boundaries[_i];
        if (_s.x < _b[0] || _s.x > _b[2] || _nx < _b[0] || _nx > _b[2]) continue;
        var _sign = _b[4] >= 64 ? -1 : 1;
        var _old_line = (_b[1] + _sign * (((_s.x - _b[0]) * (_b[4] & 62)) div 16)) & 255;
        var _new_line = (_b[1] + _sign * (((_nx - _b[0]) * (_b[4] & 62)) div 16)) & 255;
        if ((_s.y >= _old_line) == (_ny >= _new_line)) continue;
        if (_b[4] & 1) {
            _crossed = 1;
            if (_s.boundary_mode < 128) continue;
        }
        _collision = 255;
        break;
    }
    _s.boundary_crossings = (_s.boundary_crossings + _crossed) & 255;
    return _collision;
}

function ln1_player_move(_s, _d, _ticks) {
    var _group = _s.facing >> 1, _mask = 1 << _s.heading;
    _s.unconsumed = _ticks;
    while (_s.unconsumed > 0) {
        var _nx = _s.x, _ny = _s.y;
        // Player X is one pixel per timer tick. Y retains its original fraction.
        if (_d.left[_group] & _mask) _nx = max(0, _nx - 1);
        if (_d.right[_group] & _mask) _nx = _nx == 255 ? 254 : _nx + 1;
        if (!(_d.no_y[_group] & _mask)) {
            var _step = (_d.double_y[_group] & _mask) ? 128 : 64;
            var _fixed_y = _ny * 256 + _s.fraction_y;
            if (_d.up[_group] & _mask) _fixed_y = (_fixed_y - _step) & 65535;
            if (_d.down[_group] & _mask) _fixed_y = (_fixed_y + _step) & 65535;
            _s.fraction_y = _fixed_y & 255;
            _ny = _fixed_y >> 8;
        }
        _s.collision = ln1_player_boundary(_s, _d, _nx, _ny);
        if (_s.collision != 0) return;
        if (_s.enemy_active >= 128 && abs(_s.enemy_x - _nx) < 12 && abs(_s.enemy_y - _ny) < _s.separation_y) {
            _s.collision = 127;
            return;
        }
        _s.x = _nx; _s.y = _ny;
        _s.unconsumed--;
    }
    _s.collision = 0;
}

function ln1_player_action(_s, _d, _ticks) {
    if (_s.action < 256) return;
    if (_s.countdown > _ticks) {
        _s.countdown -= _ticks;
        if (_s.flags & 4) {
            _s.heading = _s.saved_heading;
            ln1_player_move(_s, _d, _ticks);
        }
        return;
    }
    var _record = variable_struct_get(_d.actions, string(_s.action));
    _s.flags = _record.flags;
    if (_record.duration >= 0) _s.duration = _record.duration;
    _s.countdown = _s.duration;
    _s.frame = _record.frame;
    if (_s.flags & 128) {
        _s.x = (_s.x + _record.dx) & 255;
        _s.y = (_s.y + _record.dy) & 255;
    }
    if (_record.state >= 0) {
        _s.action_state = _record.state;
        array_push(_s.requests, {kind: "action_state", value: _record.state, combat_data: _record.combat_data});
    }
    _s.action = _record.next;
    if (_s.action >= 256 && (_s.flags & 4)) {
        _s.heading = _s.saved_heading;
        ln1_player_move(_s, _d, _ticks);
    }
    ln1_player_render(_s, (_s.flags & 16) ? _s.action_mirror : (_s.flags & 64));
}

function ln1_player_update(_s, _d, _joy, _tick) {
    _s.requests = [];
    _s.tick = _tick & 255;
    var _ticks = (_s.tick - _s.last_tick) & 255;
    if (_ticks == 0) return;
    _s.last_tick = _s.tick;
    if (_s.action < 256) ln1_player_input(_s, _d, _joy);
    if (_s.action >= 256) {
        ln1_player_action(_s, _d, _ticks);
        if (_s.action < 256 || (_s.flags & 8)) return;
        _ticks = 1;
        ln1_player_input(_s, _d, _joy);
        if (_s.flags & 8) return;
    }
    if (_s.stopped != 0) {
        if (_s.redraw) ln1_player_render(_s, _d.mirror[_s.facing >> 1] & (1 << _s.heading));
        return;
    }
    _s.action &= 255;
    ln1_player_move(_s, _d, _ticks);
    _s.walk_clock = (_s.walk_clock + _ticks - _s.unconsumed) & 255;
    if (_s.walk_clock >= 4 || _s.redraw != 0) {
        _s.walk_clock = 0;
        var _mask = 1 << _s.heading, _group = _s.facing >> 1;
        var _advance = (_d.forward[_group] & _mask) ? 1 : -1;
        _s.frame = (_s.frame & 248) | ((_s.frame + _advance) & 7);
        ln1_player_render(_s, _d.mirror[_group] & _mask);
    }
}
