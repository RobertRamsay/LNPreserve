/// Source hit test $7ecc: directional ranges and defending-state checks.
function ln1_combat_hit(_g, _enemy_attacks) {
    var _a = _enemy_attacks ? _g.enemy : _g.player;
    var _b = _enemy_attacks ? _g.player : _g.enemy;
    if (_g.enemy.active < 128 || (_b.combat_state & 252) == 12) return -1;
    var _dx = (_a.combat_state & 3) < 2 ? _b.x - _a.x : _a.x - _b.x;
    if (_dx < 0) return -1;
    var _index;
    if (_enemy_attacks && _g.enemy.active == 133) {
        _index = 20;
        if (_a.combat_state & 1) _dx = max(0, _dx - 3);
    }
    else {
        _index = ((_a.combat_state - 20) & 255) >> 2;
        if (_a.weapon >= 6) _index |= 16;
        else {
            _index |= (_a.weapon < 4 ? _a.weapon : 0) * 4;
            if (_a.combat_state & 1) _dx = max(0, _dx - 3);
        }
    }
    var _d = _g.data;
    if (_index >= array_length(_d.attack_x_min)) return -1;
    if (_dx < _d.attack_x_min[_index] || _dx >= _d.attack_x_max[_index]) return -1;
    var _direction = _a.combat_state & 3;
    var _dy = ((_direction == 0 || _direction == 3) ? _a.y - _b.y : _b.y - _a.y) + 8;
    if (_dy < 0 || _dy > 255 || _dy < _d.attack_y_min[_index] || _dy >= _d.attack_y_max[_index]) return -1;
    if ((_b.combat_state & 252) == 16 && ((_b.combat_state ^ _a.combat_state) & 2) && _g.enemy.attack_count < 4) return -1;
    return _index;
}

function ln1_combat_hurt(_g, _enemy_hurt) {
    var _actor = _enemy_hurt ? _g.enemy : _g.player, _other = _enemy_hurt ? _g.player : _g.enemy;
    if ((_actor.combat_state & 252) != 36) {
        _actor.previous_combat = _actor.combat_state;
        _actor.combat_state = 36 + (_actor.facing >> 1);
    }
    if (!_enemy_hurt && _g.player_health == 0) { _g.enemy.attack_count = 0; return; }
    var _index = (_actor.facing & 4) | (((_actor.facing >> 1) ^ _other.combat_state) & 2);
    if (_enemy_hurt && _g.enemy.wounds >= 32) {
        _index = 8 + ((_actor.facing & 4) >> 2);
        _actor.action = _g.data.reactions[_index];
        _actor.countdown = 0; _actor.mode = 7; _actor.separation_y = 4;
    } else {
        _actor.action = _g.data.reactions[(_enemy_hurt ? 4 : 0) + (_index >> 1)];
        _actor.countdown = 0;
        if (!_enemy_hurt) {
            _actor.flags = variable_struct_get(_g.data.actions, string(_actor.action)).flags;
            _actor.saved_heading = _actor.heading; _actor.action_mirror = _actor.facing & 2;
            _g.enemy.attack_count = 0;
        }
    }
}

/// Native subset of the original action dispatcher ($aac0), expanded as world
/// mechanisms are recovered. Unknown events remain visible in pending_events.
function ln1_combat_event(_g, _event, _enemy_event) {
    var _p = _g.player, _e = _g.enemy;
    if (_event == 0) return;
    if (_event == 1) { _p.weapon = _p.selected_weapon; return; }
    if (_event == 3) { _g.death_wait = 20; return; }
    if (_event >= 16 && _event < 32) {
        _e.active = 128 | (_event - 16);
        if (_e.wounds >= 32) {
            _e.active = 0; _e.action = 0; _e.display_frame = 255; return;
        }
        _e.facing = ln1_enemy_face(_e, _p.x, _p.y); _e.heading = _e.facing;
        if ((_e.facing == 7 || _e.facing == 1) && _e.active >= 132 && _e.active != 133) { _e.active = 0; return; }
        _e.origin_x = _p.x; _e.origin_y = _p.y;
        if (_e.active < 132) {
            _e.mode = _e.active == 128 ? 1 : 0;
            ln1_enemy_begin(_e, _g.data, _e.active == 128 ? 4 : 0);
        }
        return;
    }
    if (_event == 9) { _e.weapon = _e.active & 3; return; }
    if (_event == 10) { _e.mode = 1; return; }
    if (_event == 11) {
        var _hit = ln1_combat_hit(_g, true);
        if (_hit >= 0) {
            _g.player_health = max(0, _g.player_health - _g.data.player_damage[_hit]);
            if (_g.player_health == 0) { _p.combat_state = 36 + (_p.facing >> 1); _p.input_lock = 255; }
            ln1_combat_hurt(_g, false);
        }
        return;
    }
    if (_event == 12) { ln1_enemy_react(_g); return; }
    if (_event == 13 || _event == 14) {
        var _hit = ln1_combat_hit(_g, false);
        if (_hit >= 0 && (_e.combat_state & 252) != 36 && _e.active != 137) {
            _e.wounds = min(32, _e.wounds + _g.data.enemy_damage[_hit]);
            _g.room_wounds[_g.room_id] = _e.wounds;
            if (_e.wounds == 32) ln1_enemy_combat(_e, 36);
            ln1_combat_hurt(_g, true);
        }
        // Projectile requests (event 13) are separate from the melee hit test.
        if (_event == 13 && _p.weapon >= 4) array_push(_g.pending_events, _event);
        return;
    }
    if (_event == 32) {
        _p.action_mirror = _p.facing & 2; _p.combat_state = _p.previous_combat;
        _p.frame = ((_p.facing + 2) & 4) * 2;
        if ((_p.combat_state & 252) == 0) _p.frame = 16 + (((_p.facing + 2) & 4) >> 2);
        _p.redraw = 255; return;
    }
    if (_event == 33) {
        _e.action_mirror = _e.facing & 2; _e.combat_state = _e.previous_combat;
        _e.frame = ((_e.facing + 2) & 4) * 2;
        if ((_e.combat_state & 252) == 0) _e.frame = 16 + (((_e.facing + 2) & 4) >> 2);
        ln1_enemy_combat(_e, 0); _e.mode = 8; return;
    }
    if (_event == 36) {
        // A defeated guard stays defeated for this run, including room re-entry.
        // Original recoverable knockouts will need a separate state when ported.
        if (_g.room_wounds[_g.room_id] >= 32) {
            _e.active = 0; _e.action = 0; _e.display_frame = 255;
        }
        return;
    }
    if (_event == 38) { ln1_enemy_approach(_g); return; }
    array_push(_g.pending_events, _event);
}
