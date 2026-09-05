/// Native LN2 player rules. Addresses in the exported tables are source labels,
/// not CPU instructions. The original routines run only in offline test tools.
function ln2_player_render(_s,_mirror) {
    _s.mirror=_mirror!=0;_s.display_frame=_s.frame;_s.redraw=0;
}

function ln2_player_special_state(_s,_d,_address) {
    _s.action=_address;_s.flags=variable_struct_get(_d.actions,string(_address)).flags;
    _s.countdown=0;_s.saved_heading=_s.heading;_s.action_mirror=_s.facing&2;
}

/// Original entrance attachment/climbing sequence ($9f56 in Central Park).
function ln2_player_vehicle(_s,_d) {
    if (_s.action>=256) return;
    if (_d.level==6 && _s.vehicle==5) {
        _s.vehicle=0;ln2_player_special_state(_s,_d,_d.vehicle_actions.release);return;
    }
    _s.vehicle_limit=(_s.vehicle_limit-1)&255;
    if (_s.vehicle_limit==0) { _s.vehicle=0;return; }
    var _v=_d.vehicle_actions,_action;
    if (_s.vehicle>=3 && !(_s.vehicle==4 && _s.vehicle_limit<6 && _s.vehicle_limit!=1))
        _action=_s.vehicle_limit==1?_v.descend_end:_v.descend;
    else if (_s.vehicle==2) _action=_s.vehicle_limit==1?_v.ascend_end:_v.ascend;
    else if (_s.vehicle_limit==1) _action=(_s.facing&4)?_v.step_end_right:_v.step_end_left;
    else _action=((_s.facing+2)&4)?_v.step_right:_v.step_left;
    ln2_player_special_state(_s,_d,_action);
}

function ln2_player_begin(_s,_d,_kind) {
    _s.combat_state=(_s.facing>>1)+_d.action_classes[_kind>>2];
    var _entry=(((_s.facing+2)&4)>>1)+_kind;
    _s.action=_d.action_entries[_entry>>1];
    _s.flags=variable_struct_get(_d.actions,string(_s.action)).flags;
    _s.countdown=0;_s.saved_heading=_s.heading;_s.action_mirror=_s.facing&2;
}

function ln2_player_fire_held(_s,_d,_heading) {
    if (_heading<128) {
        var _changed=_heading!=_s.attack_direction;
        _s.attack_direction=_heading;
        if (_changed) _s.attack_clock=_s.tick;
        else {
            if (_heading==_s.attack_previous) {
                if ((_s.combat_state&252)!=16) { _s.combat_state=_s.facing>>1;return; }
                _s.attack_clock=(_s.tick-16)&255;
            }
            _s.attack_previous=_heading;
            if (((_s.tick-_s.attack_clock)&255)>=_d.attack_delays[_heading]) {
                var _kind=_heading*4+8;
                if (_s.weapon==0 || _s.weapon>=4) _kind+=32;
                ln2_player_begin(_s,_d,_kind);return;
            }
        }
    } else _s.attack_clock=_s.tick;
    _s.attack_previous=255;_s.combat_state=_s.facing>>1;
}

function ln2_player_input(_s,_d,_joy) {
    if (_s.input_lock!=0) return;
    var _heading=_d.directions[_joy&15];
    if ((_joy&16)==0) {
        _s.fire_previous=0;_s.attack_direction=255;
        if (_heading>=128) {
            _s.stopped=_heading;_s.turn_lock=0;
            if (_s.action>=256) return;
            _s.combat_state=_s.facing>>1;
            if (_s.weapon!=_s.selected_weapon) { ln2_player_begin(_s,_d,4);return; }
            if (_s.frame<16) { _s.frame=16+((_s.frame>>3)&1);_s.redraw=255; }
            return;
        }
        _heading=(_heading+_s.control_rotation-1)&7;_s.heading=_heading;
        if ((_heading&1) && _heading!=_s.facing && (_heading^4)!=_s.facing) {
            _s.facing=_heading;_s.redraw=255;
        }
        _s.stopped=0;_s.frame=(_s.frame&7)|(((_s.facing+2)&4)?8:0);
        _s.combat_state=(_s.facing>>1)+8;return;
    }
    var _new_fire=_s.fire_previous!=16;_s.fire_previous=16;
    if (_new_fire) {
        if (_s.stopped!=0) {
            _s.frame=16+(((_s.facing+2)&4)>>2);_s.redraw=255;return;
        }
        if (_heading>=128) { _s.stopped=255;_s.combat_state=_s.facing>>1;return; }
        var _relative=(_heading-_s.facing)&7;
        _s.stopped=255;
        if (_relative<2 || _relative==7) {
            if ((_s.combat_state&252)==16) return;
            _s.heading=_heading;
            if ((_heading&3)==0) _s.heading=_d.fire_headings[((_heading<<1)&8|_s.facing)>>1];
            ln2_player_begin(_s,_d,0);return;
        }
    }
    ln2_player_fire_held(_s,_d,_heading);
}

/// Six-byte source boundary records include the crossed line's hazard kind.
function ln2_player_boundary(_s,_d,_old_x,_old_y,_nx,_ny,_enemy=false) {
    var _crossed=0,_collision=0;
    for (var _i=0;_i<array_length(_d.boundaries);_i++) {
        var _b=_d.boundaries[_i];
        if (_old_x<_b[0] || _old_x>_b[2] || _nx<_b[0] || _nx>_b[2]) continue;
        var _sign=_b[4]>=64?-1:1;
        var _old_line=(_b[1]+_sign*(((_old_x-_b[0])*(_b[4]&62)) div 16))&255;
        var _new_line=(_b[1]+_sign*(((_nx-_b[0])*(_b[4]&62)) div 16))&255;
        if ((_old_y>=_old_line)==(_ny>=_new_line)) continue;
        if ((_b[4]&1) && !_enemy) {
            _crossed=1;_s.boundary_mode=_b[5];
            if (_b[5]<128) continue;
        }
        _collision=255;_s.hit_boundary=_i;_s.hit_side=real(_old_y>=_old_line);break;
    }
    if (!_enemy && _crossed) _s.boundary_crossings=((_s.boundary_crossings+1)&255)|128;
    return _collision;
}

function ln2_player_depth(_s,_dy) {
    if (_s.height_fixed!=0 || _s.depth_y==0 || _s.depth_y==255) return;
    _dy&=255;
    _s.depth_y=_dy<128?min(255,_s.depth_y+_dy):((_s.depth_y+_dy)&255);
}

function ln2_player_move(_s,_d,_ticks) {
    var _group=_s.facing>>1,_mask=1<<_s.heading,_old_y=_s.y;
    _s.unconsumed=min(8,_ticks);
    while (_s.unconsumed>0) {
        var _fx=_s.x*256+_s.fraction_x,_fy=_s.y*256+_s.fraction_y;
        if (_d.left[_group]&_mask) _fx-=_d.speed_x[0];
        if (_d.right[_group]&_mask) _fx+=_d.speed_x[0];
        _s.fraction_x=_fx&255;
        var _nx=_fx<0?0:(_fx>65535?254:(_fx>>8));
        if (!(_d.no_y[_group]&_mask)) {
            var _step=_d.speed_y[0]*((_d.triple_y[_group]&_mask)?3:1);
            if (_d.up[_group]&_mask) _fy-=_step;
            if (_d.down[_group]&_mask) _fy+=_step;
        }
        _fy&=65535;_s.fraction_y=_fy&255;var _ny=_fy>>8;
        _s.collision=ln2_player_boundary(_s,_d,_s.x,_s.y,_nx,_ny);
        if (_s.collision!=0) break;
        if (_s.enemy_active>=128 && abs(_s.enemy_x-_nx)<12 && abs(_s.enemy_y-_ny)<_s.separation_y) {
            _s.collision=127;break;
        }
        _s.x=_nx;_s.y=_ny;_s.unconsumed--;
    }
    if (_d.level==4 && _s.room_id==13 && _s.gate_open==0 && _s.gate_mode==2)
        _s.x=min(_s.x,_s.enemy_x);
    if (_d.level==5 && (_s.boundary_crossings&1) && (_s.boundary_mode&63)==49) {
        var _ox=_s.x,_oy=_s.y;
        repeat(_ticks) {
            _s.x-=4;
            if (_s.x<0) { _s.x=0;_s.input_lock=255; }
            _s.y=(_s.y+1)&255;
        }
        ln2_player_boundary(_s,_d,_ox,_oy,_s.x,_s.y);
    }
    ln2_player_depth(_s,(_s.y-_old_y)&255);
}

function ln2_player_action(_s,_d,_ticks) {
    if (_s.action<256) return;
    if (_s.countdown>_ticks) {
        _s.countdown-=_ticks;
        if (_s.flags&4) { _s.heading=_s.saved_heading;ln2_player_move(_s,_d,_ticks); }
        return;
    }
    var _record=variable_struct_get(_d.actions,string(_s.action));_s.flags=_record.flags;
    if (_record.duration>=0) _s.duration=_record.duration;
    _s.countdown=_s.duration;_s.frame=_record.frame;
    if (_s.flags&128) {
        _s.x=(_s.x+_record.dx)&255;_s.y=(_s.y+_record.dy)&255;
        ln2_player_depth(_s,_record.dy);
    }
    if (_record.state>=0) _s.action_state=_record.state;
    _s.action=_record.next;
    if (_s.action>=256 && (_s.flags&4)) { _s.heading=_s.saved_heading;ln2_player_move(_s,_d,_ticks); }
    ln2_player_render(_s,(_s.flags&16)?_s.action_mirror:(_s.flags&64));
}

function ln2_player_update(_s,_d,_joy,_tick) {
    _s.tick=_tick&255;var _ticks=(_s.tick-_s.last_tick)&255;
    if (_ticks==0) return;
    _s.last_tick=_s.tick;
    if (variable_struct_exists(_s,"vehicle") && _s.vehicle!=0) {
        ln2_player_vehicle(_s,_d);ln2_player_action(_s,_d,_ticks);return;
    }
    if (_s.action<256) ln2_player_input(_s,_d,_joy);
    if (_s.action>=256) {
        ln2_player_action(_s,_d,_ticks);
        if (_s.action<256 || (_s.flags&8)) return;
        _ticks=1;ln2_player_input(_s,_d,_joy);
        if (_s.flags&8) return;
    }
    if (_s.stopped!=0) {
        if (_s.redraw) ln2_player_render(_s,_d.mirror[_s.facing>>1]&(1<<_s.heading));
        return;
    }
    _s.action&=255;ln2_player_move(_s,_d,_ticks);
    _s.walk_clock=(_s.walk_clock+_ticks-_s.unconsumed)&255;
    if (_s.walk_clock>=4 || _s.redraw) {
        _s.walk_clock=0;
        var _advance=(_d.forward[_s.facing>>1]&(1<<_s.heading))?1:-1;
        _s.frame=(_s.frame&248)|((_s.frame+_advance)&7);
        ln2_player_render(_s,_d.mirror[_s.facing>>1]&(1<<_s.heading));
    }
}
