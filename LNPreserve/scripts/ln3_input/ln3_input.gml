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
    do {_next+=_switch==2?-1:1;if (_next>=5) _next=0;if(_next<0) _next=4;} until (_next==0 || _s.inventory[_next-1]!=0);
    _s.pending_weapon=_next;_s.weapon_notice_timer=100;_s.notice_icon=_next==0?24:_next-1;
    var _action=18;
    for (var _i=15;_i>=0;_i--) if (_s.player_action==_data.weapon_kneel_actions[_i]) {_action=19;break;}
    ln3_action_set(_s,_actions,_action);
}

function ln3_input_update(_s,_actions,_data,_raw_joy,_weapon_switch=false) {
    var _previous_read=_s.previous_joy;
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
    if (variable_struct_exists(_s,"reverse_roll_enabled") && _s.reverse_roll_enabled &&
        (_from==3 || _from==5) && (_s.joy&16)!=0 && (_previous_read&16)==0 &&
        (_s.joy&15)!=0 && (_previous_read&15)==(_s.joy&15) && !_weapon_switch &&
        (_s.stun|_s.player_dead|_s.input_block|_s.climb_flags)==0) {
        var _back_direction=_s.joy&15,_roll=_from==3?28:29;
        ln3_action_set(_s,_actions,_roll);
        _s.reverse_roll={action:_roll,direction:_back_direction};return;
    }
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

function ln3_reverse_roll_checks() {
    var _tested=0;
    for(var _level=1;_level<=5;_level++) for(var _mirror=0;_mirror<=6;_mirror+=6)
    for(var _standing=0;_standing<2;_standing++) {
        var _g=new LN3Play(_level),_s=_g.state,_back=_standing==0?3:5,_joy=0;
        _s.enabled=7;_s.player_dead=0;_s.stun=0;_s.input_block=0;_s.climb_flags=0;_s.fire_mode=0;
        _s.player_weapon=0;_s.mirror=_mirror;_s.previous_joy=0;
        for(var _j=1;_j<16;_j++) {
            var _trial=json_parse(json_stringify(_s));ln3_action_set(_trial,_g.actions,_standing);
            ln3_input_update(_trial,_g.actions,_g.input,_j);
            if (_trial.player_action==_back) {_joy=_j;break;}
        }
        ln_check(_joy!=0,"LN3 backward walk fixture has a real input direction");
        ln3_action_set(_s,_g.actions,_standing);ln3_input_update(_s,_g.actions,_g.input,_joy);
        _s.player_x=120;_s.player_y=110;
        for(var _part=0;_part<3;_part++) {_s.parts[_part].x=120;_s.parts[_part].y=_part==2?110:89;}
        ln3_input_update(_s,_g.actions,_g.input,_joy|16);
        ln_check(is_struct(_s.reverse_roll) && _s.player_action==(_back==3?28:29),"backward walk then fire starts reverse somersault");
        var _frames=[],_sequence=_g.animation.sequences[_s.parts[1].animation],_legs=_g.animation.sequences[_s.parts[2].animation];
        for(var _tick=0;_tick<array_length(_sequence.frames);_tick++) {
            ln3_movement_setup(_s,_g.movement);ln3_movement(_s,_g.movement);ln3_animation_update(_s,_g.animation);
            if (_tick==0) ln_check(_s.player_x==120 && _s.player_y==110,"LN3 first reversed landing pose is stationary");
            var _index=array_length(_sequence.frames)-1-_tick;
            ln_check(_s.draw_frames[1]==_sequence.frames[_index] && _s.draw_frames[2]==_legs.frames[_index],"LN3 torso and legs reverse together");
            if (_tick==1) {
                _g=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));_s=_g.state;
                ln_check(is_struct(_s.reverse_roll) && _s.parts[1].cursor==2,"LN3 saved reverse roll retains animation progress");
            }
        }
        ln_check((_s.mirror&6)==_mirror && sign(_s.player_x-120)==((_joy&4)?-1:((_joy&8)?1:0)) &&
            sign(_s.player_y-110)==((_joy&1)?-1:((_joy&2)?1:0)),"LN3 reverse roll keeps facing and travels backward");
        ln3_input_update(_s,_g.actions,_g.input,0);
        ln_check(!is_struct(_s.reverse_roll) && _s.player_action<2,"LN3 reverse roll releases to standing");
        _tested++;
    }
    show_debug_message("LN3_REVERSE_ROLL_PASS: "+string(_tested)+" level/facing cases, paired parts, stationary first pose and saves");
}
