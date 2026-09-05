/// Native LN1 enemy decisions ($6a48), animation ($5b54), movement ($5ae9).
function LN1Enemy() constructor {
    x = 0; y = 0; fraction_x = 0; fraction_y = 0;
    facing = 1; heading = 1; frame = 255; display_frame = 255; mirror = false;
    action = 0; action_state = 0; flags = 0; action_mirror = 0;
    countdown = 0; duration = 0; weapon = 0;
    active = 0; mode = 0; combat_state = 0; previous_combat = 0;
    traits = 0; speed = 0; speed_traits = 0; colour_traits = 0;
    origin_x = 0; origin_y = 0; target_x = 0; target_y = 0; patrol_x = 0;
    decision_tick = 0; action_tick = 0; wait_tick = 0; wait_duration = 255;
    turn_tick = 0; react_tick = 0; react_random = 0; attack_count = 0;
    wounds = 0; separation_y = 10; unconsumed = 0; collision = 0;
    projectile_active = 0;
}

function ln1_enemy_face(_e, _x, _y) {
    if (_x < _e.x) return _y < _e.y ? 7 : 5;
    return _y < _e.y ? 1 : 3;
}

function ln1_enemy_combat(_e, _base) { _e.combat_state = _base + (_e.facing >> 1); }

function ln1_enemy_begin(_e, _d, _entry) {
    if (_e.facing == 1 || _e.facing == 7) _entry += 2;
    _e.action_mirror = _e.facing & 2;
    if (_entry == 8 || _entry == 10) _entry += _e.speed_traits;
    _e.action = _d.enemy_entries[_entry >> 1];
    _e.flags = variable_struct_get(_d.actions, string(_e.action)).flags;
    _e.countdown = 0;
}

function ln1_enemy_approach(_g) {
    var _e = _g.enemy, _p = _g.player;
    _e.mode = 5;
    _e.facing = ln1_enemy_face(_e, _p.x, _p.y);
    _e.heading = _e.facing;
    _e.speed = _e.speed_traits >> 2;
    ln1_enemy_begin(_e, _g.data, 8);
    ln1_enemy_combat(_e, 8);
}

function ln1_enemy_react(_g) {
    var _e = _g.enemy;
    _e.mode = 8; _e.react_tick = _g.player.tick;
    _e.react_random = ln1_enemy_random(_g);
}

function ln1_enemy_patrol(_g) {
    var _e = _g.enemy;
    _e.mode = 2;
    _e.facing = (_e.facing + ((ln1_enemy_random(_g) & 2) ? 2 : -2)) & 7;
    _e.heading = _e.facing; _e.patrol_x = _e.x; _e.speed = 0;
    ln1_enemy_begin(_e, _g.data, 24); ln1_enemy_combat(_e, 8);
    if (min(255, abs(_g.player.x - _e.x) + abs(_g.player.y - _e.y)) < 112) ln1_enemy_approach(_g);
}

function ln1_enemy_attack_stance(_g) {
    var _e = _g.enemy, _p = _g.player;
    _e.target_x = _p.x; _e.target_y = _p.y;
    _e.facing = ln1_enemy_face(_e, _p.x, _p.y); _e.heading = _e.facing;
    ln1_enemy_begin(_e, _g.data, 4); ln1_enemy_combat(_e, 0);
    _e.mode = 6;
}

function ln1_enemy_decide(_g) {
    var _e = _g.enemy, _p = _g.player, _tick = _p.tick;
    if (_e.active < 128 || ((_tick - _e.decision_tick) & 255) < 4) return;
    _e.decision_tick = _tick;
    switch (_e.mode) {
        case 0: ln1_enemy_combat(_e, 4); return;
        case 1:
            if ((_e.traits & 64) && ln1_enemy_random(_g) >= 96) {
                _e.mode = 4; _e.wait_tick = _tick;
                _e.wait_duration = ln1_enemy_random(_g) & 31;
            } else {
                _e.mode = 3; _e.wait_duration = (ln1_enemy_random(_g) & 31) + (_e.weapon ? 16 : 0);
                _e.wait_tick = _tick;
            }
            ln1_enemy_combat(_e, 0); return;
        case 2:
            var _travel = _e.facing >= 4 ? _e.patrol_x - _e.x : _e.x - _e.patrol_x;
            if (_travel >= 32) {
                _e.facing ^= 4; _e.heading = _e.facing; _e.speed = 0;
                ln1_enemy_begin(_e, _g.data, 24); ln1_enemy_combat(_e, 8);
            }
            if (min(255, abs(_p.x - _e.x) + abs(_p.y - _e.y)) < 112) ln1_enemy_approach(_g);
            return;
        case 3:
        case 4:
            if (((_tick - _e.wait_tick) & 255) >= _e.wait_duration) {
                if (_e.mode == 4) ln1_enemy_patrol(_g); else ln1_enemy_approach(_g);
            }
            return;
        case 5:
            var _ahead = _p.x;
            if (_p.heading < 128) _ahead += _p.heading < 4 ? -8 : 8;
            if (_ahead < 0 || _ahead > 255) { ln1_enemy_attack_stance(_g); return; }
            var _range = [18,22,28,24,0,0,20][_e.weapon];
            var _target = _ahead < _e.x ? ((_p.x + _range) & 255) : _p.x - _range;
            if (_target < 0) _target = (_p.x + _range) & 255;
            if (min(255, abs(_target - _e.x) + abs(_p.y - _e.y)) < 6) { ln1_enemy_attack_stance(_g); return; }
            if (_e.active == 136) {
                if (_e.x < 4) { _e.x = 4; ln1_enemy_attack_stance(_g); return; }
                if (_e.x >= 248) { _e.x = 247; ln1_enemy_attack_stance(_g); return; }
            }
            var _distance = min(255, abs(_p.x - _e.x) + abs(_p.y - _e.y));
            if (abs(_p.x - _e.origin_x) >= 176 && _distance >= 48) {
                if (_e.active == 128) {
                    _e.facing = ln1_enemy_face(_e, _p.x, _p.y); _e.heading = _e.facing;
                    ln1_enemy_begin(_e, _g.data, 52); _e.mode = 9; ln1_enemy_combat(_e, 0);
                    _e.origin_x = _p.x; _e.origin_y = _p.y; return;
                }
                if (_e.active == 129) {
                    _e.action = _e.facing & 4 ? 24014 : 24033;
                    _e.countdown = 0; _e.mode = 7; ln1_enemy_combat(_e, 36); _e.separation_y = 4; return;
                }
            }
            var _direct = ln1_enemy_face(_e, _p.x, _p.y), _facing = ln1_enemy_face(_e, _target, _p.y);
            if ((_facing ^ _direct) & 4) {
                if (ln1_enemy_random(_g) < 16 && abs(_p.y - _e.y) < 8) { ln1_enemy_attack_stance(_g); return; }
            }
            if (_facing != _e.facing && (!((_facing ^ _e.facing) & 4) || ((_tick - _e.turn_tick) & 255) >= 20)) {
                _e.facing = _facing; _e.turn_tick = _tick;
                ln1_enemy_begin(_e, _g.data, 8); ln1_enemy_combat(_e, 8);
            }
            var _dx = abs(_target - _e.x), _dy = abs(_p.y - _e.y);
            if ((_dx >> 2) < _dy || _dy < 4) {
                var _index = _e.facing - ((_dx >> 2) >= _dy ? 0 : 1);
                _e.heading = [0,2,4,2,4,6,0,6][_index];
            } else _e.heading = _e.facing;
            return;
        case 6:
            if ((_p.combat_state & 252) == 36) { ln1_enemy_react(_g); return; }
            var _attack = ln1_enemy_random(_g) & (_e.weapon == 0 ? 1 : 3);
            ln1_enemy_begin(_e, _g.data, 28 + _attack * 4); ln1_enemy_combat(_e, 20 + _attack * 4);
            _e.mode = 7; _e.attack_count = (_e.attack_count + 1) & 255; return;
        case 7: return;
        case 8:
            ln1_enemy_combat(_e, 0);
            if (abs(_p.x - _e.target_x) >= 8 || abs(_p.y - _e.target_y) >= 4 || _e.attack_count >= 3) {
                ln1_enemy_approach(_g); return;
            }
            if (((_tick - _e.react_tick) & 255) >= ((_e.react_random & 31) + 16)) {
                _e.mode = 6;
                // Source jumps directly into case 6, without another decision wait.
                _e.decision_tick = (_tick - 4) & 255; ln1_enemy_decide(_g);
            }
            return;
        case 9:
            if (_e.action < 256 && !_e.projectile_active) ln1_enemy_approach(_g);
            return;
    }
}

function ln1_enemy_move(_g, _ticks) {
    var _e = _g.enemy, _p = _g.player, _d = _g.data;
    var _group = _e.facing >> 1, _mask = 1 << _e.heading, _speed = _e.speed + 1;
    _e.unconsumed = _ticks;
    while (_e.unconsumed > 0) {
        var _fx = _e.x * 256 + _e.fraction_x, _fy = _e.y * 256 + _e.fraction_y;
        if (_d.left[_group] & _mask) _fx -= _d.speed_x[_speed];
        if (_d.right[_group] & _mask) _fx += _d.speed_x[_speed];
        _e.fraction_x = _fx & 255;
        var _nx = _fx < 0 ? 0 : (_fx > 65535 ? 254 : (_fx >> 8));
        if (!(_d.no_y[_group] & _mask)) {
            var _step = _d.speed_y[_speed] * ((_d.double_y[_group] & _mask) ? 2 : 1);
            if (_d.up[_group] & _mask) _fy -= _step;
            if (_d.down[_group] & _mask) _fy += _step;
        }
        _fy &= 65535; _e.fraction_y = _fy & 255;
        var _ny = _fy >> 8;
        if (_e.active >= 128 && abs(_p.x - _nx) < 12 && abs(_p.y - _ny) < _e.separation_y) {
            _e.collision = 127; return;
        }
        _e.collision = 0;
        if (abs(_nx - _e.x) >= 128 || _nx < 2 || _nx >= 247 || _ny < 9 || _ny >= 189) {
            _e.active = 0; _e.action = 0; _e.frame = 255;
        }
        _e.x = _nx; _e.y = _ny; _e.unconsumed--;
    }
}

function ln1_enemy_action(_g) {
    var _e = _g.enemy, _ticks = (_g.player.tick - _e.action_tick) & 255;
    if (_ticks == 0) return;
    _e.action_tick = _g.player.tick;
    if (_e.action < 256) return;
    if (_e.countdown > _ticks) {
        _e.countdown -= _ticks;
        if (_e.flags & 4) ln1_enemy_move(_g, _ticks);
        return;
    }
    var _record = variable_struct_get(_g.data.actions, string(_e.action));
    _e.flags = _record.flags;
    if (_record.duration >= 0) _e.duration = _record.duration;
    _e.countdown = _e.duration; _e.frame = _record.frame;
    if (_e.flags & 128) {
        if (_record.dx < 128 && _e.x + _record.dx > 255) {
            _e.active = 0; _e.action = 0; _e.frame = 255; _e.display_frame = 255; return;
        }
        _e.x = (_e.x + _record.dx) & 255; _e.y = (_e.y + _record.dy) & 255;
    }
    if (_record.state >= 0) _e.action_state = _record.state;
    if (_record.combat_data >= 0) {
        _e.traits = _record.combat_data;
        _e.speed_traits = (_e.traits & 3) << 2;
        _e.colour_traits = (_e.traits >> 2) & 7;
    }
    _e.action = _record.next;
    if (_e.action >= 256 && (_e.flags & 4)) ln1_enemy_move(_g, _ticks);
    _e.display_frame = _e.frame; _e.mirror = ((_e.flags & 16) ? _e.action_mirror : (_e.flags & 64)) != 0;
}

/// Original random-byte algorithm. CIA read phase still needs system-trace parity.
/// Test vectors inject original random returns through random_queue.
function ln1_enemy_random(_g) {
    if (_g.random_head < array_length(_g.random_queue)) return _g.random_queue[_g.random_head++];
    var _counter = 18432 - (_g.timer.cycle mod 18433);
    var _lo = _counter & 255, _hi = _counter >> 8;
    var _carry = 0;
    if (_g.random_pointer < 21504 || _g.random_pointer >= 32512) {
        _g.random_pointer = (84 + (_lo & 31)) * 256 + _hi; _carry = 0;
    }
    var _value = _g.random_value + _g.data.random_table[_g.random_pointer - 21504] + _carry;
    _value = (_value & 255) + _lo + (_value > 255 ? 1 : 0);
    _g.random_value = _value & 255;
    _g.random_pointer = (_g.random_pointer + 1) & 65535;
    return _g.random_value;
}
