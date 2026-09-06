function ln3_control_choice(_s,_data,_action,_direction) {
    if (_action>=39) _action-=39;
    var _row=_data.control_rows[2*_action+((_s.joy&16)!=0)];
    if ((_s.player_weapon&3)==0 && _row>=2 && _row<4) _row+=13;
    return _data.control_choices[_row][_direction];
}

function ln3_climb_leave(_s,_actions) {
    if (_s.joy==0 || _s.climb_flags==0) return;
    var _exit=-1;
    if (_s.climb_flags&1) {
        if (_s.joy&1) {if (_s.climb_goal>=_s.parts[2].y) _exit=0;}
        else if (_s.joy&2) {if (_s.parts[2].y>=_s.climb_start) _exit=1;}
    } else if (_s.climb_flags&2) {
        if (_s.joy&1) {if (((_s.climb_start+24)&255)>=_s.parts[2].y) _exit=0;}
        else if (_s.joy&2) {if (_s.parts[2].y>=_s.climb_goal) _exit=1;}
    }
    if (_exit<0) return;
    var _x=_exit==0?_s.climb_end_x:_s.climb_return_x,_y=_exit==0?_s.climb_end_y:_s.climb_return_y;
    _s.parts[1].x=_x;_s.parts[2].x=_x;_s.parts[1].y=(_y-21)&255;_s.parts[2].y=_y;
    if (_exit==1) _s.climb_counter=0;
    _s.climb_flags=0;_s.joy=0;_s.player_x=_x;_s.player_y=_y;
    ln3_action_set(_s,_actions,_exit==0?34:1);
}

function ln3_weapon_select(_s,_actions,_data,_raw_joy,_switch) {
    if (_s.player_dead|_s.stun|_s.input_block|_s.climb_flags) return;
    if (!_switch) {
        if (_s.fire_mode!=0) {
            if (!(_raw_joy&16) || _s.fire_latch<128) return;
        } else if (_s.fire_latch>=128 || (_raw_joy&16)) return;
    }
    if ((_s.inventory[0]|_s.inventory[1]|_s.inventory[2]|_s.inventory[3])==0) return;
    var _next=_s.player_weapon;
    do {_next++;if (_next>=5) _next=0;} until (_next==0 || _s.inventory[_next-1]!=0);
    _s.pending_weapon=_next;_s.weapon_notice_timer=100;_s.notice_icon=_next==0?24:_next-1;
    var _action=18;
    for (var _i=15;_i>=0;_i--) if (_s.player_action==_data.weapon_kneel_actions[_i]) {_action=19;break;}
    ln3_action_set(_s,_actions,_action);
}

function ln3_input_update(_s,_actions,_data,_raw_joy,_weapon_switch=false) {
    var _repeat_value=_s.input_block;_s.joy=_raw_joy&31;
    if (_s.fire_mode!=0) {
        _s.joy&=15;_repeat_value=_s.fire_latch;
        if (_s.fire_latch<128) _s.joy|=16;
    }
    var _read=_s.joy;
    if (_read>=16 && _read==_s.previous_joy && _s.player_action!=22 && _s.player_action!=24) _s.joy=_repeat_value;
    _s.previous_joy=_read;
    ln3_climb_leave(_s,_actions);
    var _relative=_s.joy;
    if ((_s.mirror&6)!=0 && (_relative&12)!=0) _relative^=12;
    var _direction=0;
    for (var _i=8;_i>=0;_i--) if (_actions.directions[_i]==(_relative&15)) {_direction=_i;break;}
    if (_s.player_action_flags>=128) return;
    var _from=_s.player_action;
    if (_s.stun==0 && _s.player_dead!=0 && _from!=20) _from=20;
    var _choice=ln3_control_choice(_s,_data,_from,_direction);
    if (_choice!=3 && _choice!=5 && _s.joy<16 && (_s.joy&3)!=0 && (_s.joy&12)!=0) {
        for (var _i=3;_i>=0;_i--) if (_s.player_action==_data.diagonal_actions[_i]) {
            if (_s.joy&4) _s.mirror|=6;else _s.mirror&=249;break;
        }
    }
    ln3_weapon_select(_s,_actions,_data,_raw_joy,_weapon_switch);
    if (_s.player_action_flags<128) ln3_action_set(_s,_actions,_choice);
}
