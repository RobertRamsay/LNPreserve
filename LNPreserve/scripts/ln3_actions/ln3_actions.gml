/// Action definitions and movement directions are writable state in LN3.
/// Keep them per game session so starting/restarting a game restores its data.
function ln3_action_state_init(_s,_actions,_movement) {
    _s.action_flags=[];_s.motion_directions=[];
    for (var _i=0;_i<array_length(_actions.actions);_i++) _s.action_flags[_i]=_actions.actions[_i][3];
    for (var _i=0;_i<array_length(_movement.motion);_i++) _s.motion_directions[_i]=_movement.motion[_i].direction;
    _s.joy=0;
}

function ln3_action_set(_s,_data,_action,_enemy=false) {
    var _base=_enemy?4:0,_old=_enemy?_s.enemy_action:_s.player_action;
    var _def=_data.actions[_action];
    if (_old!=_action) {
        for (var _i=0;_i<3;_i++) {
            _s.parts[_base+_i].animation=_def[_i];_s.parts[_base+_i].cursor=0;
        }
        var _head_bit=_enemy?16:1;
        _s.enabled&=255^_head_bit;
        if (_s.parts[_base].animation!=0) _s.enabled|=_head_bit;
    }
    if (_enemy) _s.enemy_action=_action;else _s.player_action=_action;
    var _walk=_enemy?(_action>=41 && _action<45):(_action>=2 && _action<6);
    if (_walk) {
        for (var _i=8;_i>=0;_i--) if (_data.directions[_i]==(_s.joy&15)) {
            _s.action_flags[_action]=(_s.action_flags[_action]&128)|(_enemy?_data.enemy_modes[_i]:_data.player_modes[_i]);break;
        }
    }
    var _flags=_s.action_flags[_action],_mode=_flags|128;
    if (_enemy) _s.enemy_action_flags=_flags;else _s.player_action_flags=_flags;
    for (var _i=0;_i<3;_i++) _s.parts[_base+_i].move_mode=_mode;
    if ((_mode&127)==0 || (!_enemy && _mode==133)) return;
    if (_enemy) _s.joy|=((_s.mirror>>3)&12)^8;
    else {
        var _horizontal=((_s.mirror<<1)&12)^8;
        if (_action==3 || _action==5 || _horizontal==0) _horizontal=((_s.mirror<<1)&12)^4;
        _s.joy|=_horizontal;
    }
    var _vertical=2;
    for (var _i=5;_i>=0;_i--) if (_data.upward_actions[_i]==_action) {_vertical=1;break;}
    _s.motion_directions[_mode&127]=_s.joy|_vertical;
}
