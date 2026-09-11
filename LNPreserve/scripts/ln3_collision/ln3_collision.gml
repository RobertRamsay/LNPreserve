function ln3_collision_restore(_s,_base,_horizontal,_vertical) {
    for (var _i=1;_i<=2;_i++) {
        var _p=_s.parts[_base+_i];
        if (_horizontal) _p.x=_p.old_x;
        if (_vertical) _p.y=_p.old_y;
    }
}

function ln3_collision_finish(_s,_base) {
    var _legs=_s.parts[_base+2];
    if (_base==4) {_s.enemy_x=_legs.x;_s.enemy_y=_legs.y;return;}
    _s.player_x=_legs.x;_s.player_y=_legs.y;
    if (!(_s.collision_flags&32)) return;
    if (_s.trap_flags&64) {
        if (_s.boundary_index==_s.last_boundary) return;
        _s.last_boundary=_s.boundary_index;_s.trap_contacts=(_s.trap_contacts+1)&255;
    } else {
        _s.stun=(_s.stun+1)&255;
        if (_s.collision_flags&16) _s.waterline=_legs.y;
    }
}

function ln3_collision_pair_step(_s,_base,_axis,_step) {
    var _first=_s.parts[_base+1],_second=_s.parts[_base+2];
    var _a=variable_struct_get(_first,"old_"+_axis),_b=variable_struct_get(_second,"old_"+_axis),_sum=_a+_step;
    variable_struct_set(_first,_axis,_sum&255);
    var _carry=_step<0?(_sum<0?-1:0):(_sum>255?1:0);
    variable_struct_set(_second,_axis,(_b+_step+_carry)&255);
}

function ln3_collision_slide(_s,_actions,_type) {
    _s.joy=_s.parts[1].direction;
    for (var _down=0;_down<2;_down++) {
        var _active=_s.joy&1;_s.joy=_s.joy>>1;if (!_active) continue;
        var _mirror=(_s.mirror&6)!=0,_stop=-1,_action=_s.player_action;
        if (_down==0) {
            if (_action==4 && _mirror==(_type==2)) _stop=1;
            if (_action==3 && _mirror==(_type==1)) _stop=0;
        } else {
            if (_action==2 && _mirror==(_type==1)) _stop=0;
            if (_action==5 && _mirror==(_type==2)) _stop=1;
        }
        if (_stop>=0) {
            ln3_action_set(_s,_actions,_stop);ln3_collision_restore(_s,0,true,true);break;
        }
        ln3_collision_pair_step(_s,0,"y",_down==0?-1:1);
        var _left=(_type==1 && _down==0)||(_type==2 && _down==1);
        ln3_collision_pair_step(_s,0,"x",_left?-4:4);
    }
    ln3_collision_finish(_s,0);
}

function ln3_collision_enemy_turn(_s,_type,_x0,_x1) {
    var _left=(_s.enemy_x-_x0+16)&255,_right=(_x1-_s.enemy_x+16)&255,_amount,_direction;
    if (_type==1) {
        var _choose_left=_s.enemy_x<_s.player_x || (_s.enemy_x==_s.player_x && _left<_right);
        _amount=_choose_left?_left:_right;_direction=_choose_left?5:10;
    } else {
        var _choose_left=_s.enemy_x>_s.player_x || (_s.enemy_x==_s.player_x && _left<_right);
        _amount=_choose_left?_left:_right;_direction=_choose_left?6:9;
    }
    _s.enemy_turn_wait=(_amount>>2)+4;_s.enemy_turn_direction=_direction;
}

function ln3_collision_hit(_s,_actions,_base,_x0,_x1,_y0,_y1,_type) {
    var _flags=_s.collision_flags,_legs=_s.parts[_base+2],_torso=_s.parts[_base+1];
    var _no_clamp=_base==0 && (_flags&32)!=0 && (_s.trap_flags&64)!=0;
    if (!(_flags&3)) {
        var _left=(_flags&4)!=0;
        if (!_left && !(_flags&8)) return false;
        if (!_no_clamp) {
            _legs.x=(_left?_x1-2:_x0+2)&255;_torso.x=_legs.x;
            ln3_collision_restore(_s,_base,false,true);
        }
        ln3_collision_finish(_s,_base);
        if (_base==4 && _s.enemy_turn_wait==0) {
            _s.enemy_turn_direction=(_s.parts[6].direction&3)|(_left?8:4);_s.enemy_turn_wait=8;
        }
        return false;
    }
    var _up=(_flags&1)!=0;
    if (_type==0) {
        var _value=_up?_y1+2:_y0-1;_legs.y=_value&255;
        _torso.y=(_legs.y-21-(!_up && _value<0?1:0))&255;
        ln3_collision_restore(_s,_base,true,false);ln3_collision_finish(_s,_base);return false;
    }
    var _actor_x=_base==0?_s.player_x:_s.enemy_x,_actor_y=_base==0?_s.player_y:_s.enemy_y;
    var _line=(_y0+ceil((_actor_x-_x0)/4)*(_type==1?1:-1))&255;
    var _difference=_up?_line-_actor_y:_actor_y-_line;
    if (_difference<=0 || _difference>=9) return false;
    if (_no_clamp) {ln3_collision_finish(_s,_base);return false;}
    if (_base==4) ln3_collision_enemy_turn(_s,_type,_x0,_x1);
    if (_base==4 || _s.collision_retried!=0 || _s.player_action==28 || _s.player_action==29 || _s.parts[2].move_mode==128) {
        ln3_collision_restore(_s,_base,true,true);ln3_collision_finish(_s,_base);return false;
    }
    _s.collision_retried=(_s.collision_retried+1)&255;_s.boundary_index=0;_s.collision_extended=0;
    ln3_collision_slide(_s,_actions,_type);return true;
}

function ln3_collision_update(_s,_actions,_data,_bounds) {
    for (var _pass=1;_pass>=0;_pass--) {
        _s.collision_pass=_pass;_s.collision_retried=0;_s.boundary_index=0;
        var _base=_data.actor_order[1-_pass],_skip=0;
        if (_data.level==1 && _pass==0 && _s.player_action!=34) {
            if (_s.room_id==4 && _s.climb_counter==0) _skip=10;
            if (_s.room_id==8 && _s.special_scene_phase>=2) _skip=11;
        }
        if (_data.level==4 && _s.room_id==7 && _s.fire_gate!=0) _skip=5;
        var _first=0,_offset=0;
        while (_first<array_length(_bounds) && _offset<_skip) {_offset+=array_length(_bounds[_first]);_first++;}
        var _index=_first,_guard=0;
        while (_index<array_length(_bounds)) {
            _guard++;if (_guard>512) {show_error("LN3 boundary walk did not terminate",true);return;}
            var _raw=_bounds[_index],_x0=(_raw[0]-2)&255,_x1=(_raw[2]+2)&255,_y0=_raw[1],_y1=_raw[3];
            _s.collision_flags=_raw[4];_s.collision_type=(_raw[4]>>6)&3;_s.collision_extended=(_raw[4]>>5)&1;
            if (_s.collision_extended && _s.stun==0) {_s.trap_flags=_raw[5];_s.trap_count=_raw[5]&63;}
            if (_y0<_y1) {_y0=(_y0+1)&255;_y1=(_y1-1)&255;}
            var _test=true;
            if (_base==0 && (_s.stun|_s.input_block|_s.climb_flags)) _test=false;
            if (_base==4 && ((!(_s.enabled&96)) || (_data.hazard_actor_exempt && _s.parts[4].animation==138))) _test=false;
            var _retry=false;
            if (_test) {
                var _ax=_base==0?_s.player_x:_s.enemy_x,_ay=_base==0?_s.player_y:_s.enemy_y;
                var _inside=_ax>=_x0 && _ax<=_x1;
                if (_y0>=_y1) _inside=_inside && _ay<=_y0 && _ay>=_y1;
                else _inside=_inside && _ay>_y0 && _ay<=_y1;
                if (_inside) _retry=ln3_collision_hit(_s,_actions,_base,_x0,_x1,_y0,_y1,_s.collision_type);
            }
            _s.boundary_index=(_s.boundary_index+1)&255;
            _index=_retry?_first:_index+1;
        }
    }
    _s.collision_pass=255;
}
