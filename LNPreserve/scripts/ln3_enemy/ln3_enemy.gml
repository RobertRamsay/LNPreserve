function ln3_enemy_mirror(_s,_input) {
    for (var _i=3;_i>=0;_i--) if (_s.enemy_action==_input.diagonal_actions[_i]) {
        if ((_s.joy&3)!=0 && (_s.joy&12)!=0) {
            if (_s.joy&4) _s.mirror|=96;else _s.mirror&=159;
        }
        return;
    }
}

function ln3_enemy_relative(_s,_joy) {
    return ((_s.mirror&96)!=0 && (_joy&12)!=0)?_joy^12:_joy;
}

function ln3_enemy_probe(_s) {
    var _hint=0;
    if (_s.enemy_dodge_wait!=0) return _hint;
    if (_s.enemy_probe_wait==0) {
        _s.enemy_probe_wait=16;
        if (abs(_s.enemy_x-_s.enemy_probe_x)<2) {
            var _direction=_s.parts[6].direction;
            if (_direction&12) _hint=(_direction^12)&12;
            if (_direction&3) _hint|=(_direction^3)&3;
            if (_hint!=0) {_s.enemy_turn_direction=_hint;_s.enemy_turn_wait=16;}
            else {_s.enemy_probe_wait=(_s.enemy_probe_wait-1)&255;return _hint;}
        }
        _s.enemy_probe_x=_s.enemy_x;
    }
    _s.enemy_probe_wait=(_s.enemy_probe_wait-1)&255;return _hint;
}

function ln3_enemy_steer(_s,_hint) {
    var _direction=_s.enemy_turn_direction;
    if (_s.enemy_turn_wait==0) {
        var _dy=_s.player_y-_s.enemy_y,_vertical=_dy<0?1:2;
        if (_dy!=0) _hint=_vertical;
        if (abs(_dy)>=4) _s.joy=_vertical;
        var _dx=_s.player_x-_s.enemy_x;_direction=_dx<0?4:8;
        if (abs(_dx)>=16) {
            _s.joy=_hint;
            if (_s.enemy_dodge_wait!=0) _direction=_s.enemy_dodge_direction;
        } else if (abs(_dx)>=9) {
            if (_s.joy==0) return _s.joy;
        } else if (_s.enemy_dodge_wait!=0) _direction=_s.enemy_dodge_direction;
        else {_s.enemy_dodge_wait=8;_s.enemy_dodge_direction=_direction;}
    }
    _s.joy|=_direction;return ln3_enemy_relative(_s,_s.joy);
}

function ln3_enemy_draw_weapon(_s,_actions,_data) {
    if (_s.near_enemy!=0 && _s.enemy_weapon==0) {
        var _action=57;
        for (var _i=8;_i>=0;_i--) if (_s.enemy_action==_data.kneel_actions[_i]) {_action=58;break;}
        ln3_action_set(_s,_actions,_action,true);
        _s.enemy_pending_weapon=_data.room_weapons[_s.room_id];
        _s.enemy_weapon=(_s.enemy_pending_weapon+1)&255;_s.weapon_fx_request=_s.enemy_weapon;
    } else if (_s.weapon_fx_state==5 && _data.room_weapons[_s.room_id]==_s.enemy_pending_weapon)
        _s.weapon_fx_request=(_s.weapon_fx_request+1)&255;
}

function ln3_enemy_prepare_throw(_s,_data,_direction) {
    if (_s.enemy_weapon!=4 || _s.parts[7].animation==114 || _s.near_enemy!=0 || _s.enemy_throw_wait!=0) return _direction;
    if (abs(_s.player_y-_s.enemy_y)<16) return _direction;
    var _old=_s.enemy_action;_s.enemy_action=39;
    for (var _i=8;_i>=0;_i--) if (_data.kneel_actions[_i]==_old) {_s.enemy_action=40;break;}
    _s.joy=17;_s.enemy_throw_wait=1000;return 1;
}

function ln3_enemy_decide(_s,_actions,_input,_data) {
    var _skip=(_data.hazard_actor_exempt && _s.parts[4].animation==138) || _s.enemy_behavior>=128 || !(_s.enabled&96);
    if (!_skip) {
        var _relative=0;
        if ((_s.enemy_dead|_s.player_dead|_s.climb_counter)==0) {
            _s.joy=0;_s.near_enemy=0;
            if (abs(_s.player_y-_s.enemy_y)<4 && abs(_s.player_x-_s.enemy_x)<24 && _s.climb_counter==0) _s.near_enemy=1;
            _relative=ln3_enemy_steer(_s,ln3_enemy_probe(_s));
        }
        var _direction=0;
        for (var _i=8;_i>=0;_i--) if (_actions.directions[_i]==_relative) {_direction=_i;break;}
        if (_s.enemy_action_flags<128) {
            ln3_enemy_mirror(_s,_input);ln3_enemy_draw_weapon(_s,_actions,_data);
            if (_s.enemy_action_flags<128) {
                _direction=ln3_enemy_prepare_throw(_s,_data,_direction);
                var _action=39+ln3_control_choice(_s,_input,_s.enemy_action,_direction);
                if (_action==42) _action=43;else if (_action==44) _action=41;
                ln3_action_set(_s,_actions,_action,true);
            }
        }
    }
    if (_s.enemy_turn_wait!=0) _s.enemy_turn_wait--;
    if (_s.enemy_dodge_wait!=0) _s.enemy_dodge_wait--;
}

function ln3_enemy_attack(_s,_actions,_data,_random) {
    if ((_data.hazard_actor_exempt && _s.parts[4].animation==138) || _s.enemy_behavior>=128 || !(_s.enabled&96)) return;
    if ((_s.enemy_attack_wait|_s.player_dead|_s.enemy_dead)!=0) return;
    _s.joy=0;
    if (_s.near_enemy==0 || _s.enemy_action_flags>=128) return;
    var _action=_s.parts[2].y<_s.parts[6].y?49:45;
    _s.mirror&=159;if (_s.parts[2].x<_s.parts[6].x) _s.mirror|=96;
    _s.joy=_random&3;ln3_action_set(_s,_actions,_action+_s.joy,true);
    _s.enemy_attack_wait=_data.attack_wait[_s.enemy_costume];
}

function ln3_enemy_recover_action(_s,_actions) {
    if (_s.enemy_dead==0) return;
    if (_s.enemy_action!=59) {ln3_action_set(_s,_actions,59,true);return;}
    if (_s.enemy_health<44) return;
    if (abs(_s.parts[2].x-_s.parts[6].x)<8 && abs(_s.parts[2].y-_s.parts[6].y)<8) return;
    _s.enemy_behavior=0;_s.enemy_dead=0;ln3_action_set(_s,_actions,60,true);
}

function ln3_enemy_patrol(_s,_actions,_input,_data) {
    if ((_data.hazard_actor_exempt && _s.parts[4].animation==138) || !(_s.enabled&96) || (_s.enemy_dead|_s.player_dead)!=0) return;
    var _dy=abs(_s.player_y-_s.enemy_y),_dx=abs(_s.player_x-_s.enemy_x);
    if (_dy<64 && _dx<64) _s.enemy_behavior=_dx;
    if (_s.enemy_behavior<128) return;
    var _path=_data.patrols[_s.enemy_behavior&127];
    if (_s.patrol_remaining==0) {
        if (_s.patrol_index>=array_length(_path)) _s.patrol_index=0;
        var _step=_path[_s.patrol_index];_s.patrol_remaining=_step[0];_s.patrol_joy=_step[1];_s.patrol_index++;
    }
    _s.joy=_s.patrol_joy;var _relative=ln3_enemy_relative(_s,_s.joy),_direction=0;
    for (var _i=8;_i>=0;_i--) if (_actions.directions[_i]==_relative) {_direction=_i;break;}
    if (_s.enemy_action_flags>=128) return;
    ln3_enemy_mirror(_s,_input);
    ln3_action_set(_s,_actions,39+ln3_control_choice(_s,_input,_s.enemy_action,_direction),true);
    _s.patrol_remaining=(_s.patrol_remaining-1)&255;
}
