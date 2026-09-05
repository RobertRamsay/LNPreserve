/// LN2 guards retain the original state machine, fractional movement and
/// boundary-following tables. Hardware random-read timing is not yet verified.
function ln2_enemy_face(_e,_x,_y) {
    return [7,5,1,3][(real(_x>=_e.x)<<1)|real(_y>=_e.y)];
}

function ln2_enemy_combat(_e,_kind) { _e.combat_state=_kind+(_e.facing>>1); }

function ln2_enemy_select(_e,_d,_entry) {
    if (_e.facing==1 || _e.facing==7) _entry+=2;
    _e.action_mirror=_e.facing&2;_e.duration=_d.enemy_durations[_e.speed];
    _e.action=_d.enemy_entries[_entry>>1];
    _e.flags=variable_struct_get(_d.actions,string(_e.action)).flags;_e.countdown=0;
}

function ln2_enemy_random(_g) {
    if (_g.random_head<array_length(_g.random_queue)) return _g.random_queue[_g.random_head++];
    var _counter=_g.data.timer_period_cycles-1-(_g.timer.cycle mod _g.data.timer_period_cycles);
    var _lo=_counter&255,_hi=_counter>>8;
    if ((_g.random_pointer>>8)>=_g.data.random_limit)
        _g.random_pointer=(_g.data.random_base+(_lo&31))*256+_hi;
    var _value=_g.random_value+_g.data.random_data[_g.random_pointer];
    _value=(_value&255)+_lo+real(_value>255);
    _g.random_value=_value&255;_g.random_pointer=(_g.random_pointer+1)&65535;
    return _g.random_value;
}

function ln2_enemy_approach(_g) {
    var _e=_g.enemy,_p=_g.player;
    _e.mode=5;_e.facing=ln2_enemy_face(_e,_p.x,_p.y);_e.heading=_e.facing;
    ln2_enemy_select(_e,_g.data,8);ln2_enemy_combat(_e,8);
}

function ln2_enemy_stance(_g) {
    var _e=_g.enemy,_p=_g.player;
    _e.target_x=_p.x;_e.target_y=_p.y;
    _e.facing=ln2_enemy_face(_e,_p.x,_p.y);_e.heading=_e.facing;
    ln2_enemy_select(_e,_g.data,4);ln2_enemy_combat(_e,0);_e.mode=6;
}

function ln2_enemy_react(_g) {
    var _e=_g.enemy;_e.mode=8;_e.react_tick=_g.player.tick;_e.react_random=ln2_enemy_random(_g);
}

function ln2_enemy_attack(_g) {
    var _e=_g.enemy;
    if ((_g.player.combat_state&252)==36) { ln2_enemy_react(_g);return; }
    var _attack=ln2_enemy_random(_g)&(_e.weapon==0?1:3);
    ln2_enemy_select(_e,_g.data,28+_attack*4);ln2_enemy_combat(_e,20+_attack*4);
    _e.mode=7;_e.attack_count=(_e.attack_count+1)&255;
}

function ln2_enemy_patrol(_g) {
    var _e=_g.enemy,_p=_g.player;
    var _dx=(_e.facing&4)?_e.patrol_x-_e.x:_e.x-_e.patrol_x;
    if (_dx>=20) {
        _e.mode=12;_e.wait_tick=_p.tick;ln2_enemy_select(_e,_g.data,4);ln2_enemy_combat(_e,0);
    }
    if (min(255,abs(_p.x-_e.x)+abs(_p.y-_e.y))<112) ln2_enemy_approach(_g);
}

function ln2_enemy_path_turn(_g,_old_boundary,_alternate) {
    var _e=_g.enemy,_p=_g.player,_b=_g.data.boundaries[_e.last_boundary div 6];
    var _index=((_e.facing>>1)<<3)|(real(_old_boundary==255)<<2)|(real(_e.x>=_p.x)<<1)|_e.hit_side;
    _index=(_index|((_b[4]&64)>>1))^_alternate^4;
    var _facing=_g.data.path_facing[_index];
    if (_facing>=128) throw "Invalid original LN2 boundary-facing state";
    if (_old_boundary!=255 && _e.hit_side!=_e.last_side) _facing^=4;
    var _changed=_facing!=_e.facing;_e.facing=_facing;_e.heading=_facing;
    if (_changed) ln2_enemy_select(_e,_g.data,8);
    ln2_enemy_combat(_e,8);_e.last_side=_e.hit_side;
    if ((_b[4]&62)>=5) {
        _index=((_e.facing>>1)<<2)|(_e.hit_side<<1)|real((_b[4]&64)!=0);
        var _heading=_g.data.path_heading[_index];
        if (_heading>=128) throw "Invalid original LN2 boundary-heading state";
        _e.heading=_heading;
    }
}

function ln2_enemy_path_follow(_g) {
    var _e=_g.enemy,_p=_g.player;
    if (_e.last_boundary==255) { ln2_enemy_approach(_g);return; }
    var _b=_g.data.boundaries[_e.last_boundary div 6];
    if ((_b[0]-_e.x>=8) || (_e.x-_b[2]>=4)) {
        _e.last_boundary=255;ln2_enemy_approach(_g);return;
    }
    if (min(255,abs(_p.x-_e.x)+abs(_p.y-_e.y))<14) {
        _e.last_boundary=255;ln2_enemy_stance(_g);return;
    }
    if ((ln2_enemy_face(_e,_p.x,_p.y)^4)==_e.facing && abs(_p.x-_e.x)>=8 && real(_p.y>=_e.y)==_e.last_side) {
        _e.last_boundary=255;_e.turn_tick=_p.tick;ln2_enemy_approach(_g);
    }
}

function ln2_enemy_obstacle(_g) {
    var _e=_g.enemy,_p=_g.player,_hit=_e.boundary_hit;_e.boundary_hit=255;
    if (_hit!=255) {
        if (_hit!=_e.last_boundary) {
            var _old=_e.last_boundary;_e.last_boundary=_hit;
            var _alternate=0;
            if (_hit!=_e.boundary_history1) {
                if (_hit==_e.boundary_history2) _alternate=2;
                _e.boundary_history2=_e.boundary_history1;_e.boundary_history1=_hit;
            }
            ln2_enemy_path_turn(_g,_old,_alternate);
        }
        if (_e.edge_blocked!=0) {
            _e.actor_blocked=0;_e.edge_blocked=0;_e.last_boundary=255;ln2_enemy_approach(_g);return;
        }
        if (_e.actor_blocked!=0) {
            _e.actor_blocked=0;_e.last_boundary=255;ln2_enemy_stance(_g);return;
        }
        _e.mode=13;_e.actor_blocked=0;_e.edge_blocked=0;ln2_enemy_path_follow(_g);return;
    }
    var _dx=abs(_p.x-_e.x),_distance=min(255,_dx+abs(_p.y-_e.y));
    if (_distance<14) {
        _e.actor_blocked=0;_e.edge_blocked=0;_e.last_boundary=255;
        if (_dx<12) { _e.mode=5;ln2_enemy_combat(_e,8); }
        else ln2_enemy_stance(_g);
    } else if (_e.edge_blocked!=0) {
        _e.actor_blocked=0;_e.edge_blocked=0;_e.last_boundary=255;ln2_enemy_approach(_g);
    } else {
        _e.actor_blocked=0;_e.last_boundary=255;ln2_enemy_stance(_g);
    }
}

function ln2_enemy_decide(_g) {
    var _e=_g.enemy,_p=_g.player,_tick=_p.tick;
    if (_e.active<128) return;
    if ((_e.actor_blocked|_e.edge_blocked)!=0 || _e.boundary_hit!=255) { ln2_enemy_obstacle(_g);return; }
    if (((_tick-_e.decision_tick)&255)<_g.data.enemy_decision_period) return;
    _e.decision_tick=_tick;
    switch (_e.mode) {
        case 0:ln2_enemy_combat(_e,4);return;
        case 1:
            _e.mode=(_e.traits&64)?4:3;_e.wait_tick=_tick;_e.wait_duration=ln2_enemy_random(_g)&31;
            ln2_enemy_combat(_e,0);return;
        case 2:ln2_enemy_patrol(_g);return;
        case 3:
            if (((_tick-_e.wait_tick)&255)>=_e.wait_duration) ln2_enemy_approach(_g);
            return;
        case 4:
            if (((_tick-_e.wait_tick)&255)<_e.wait_duration) return;
            _e.mode=2;_e.facing=(_e.facing+((ln2_enemy_random(_g)&2)?2:-2))&7;_e.heading=_e.facing;
            _e.patrol_x=_e.x;ln2_enemy_select(_e,_g.data,24);ln2_enemy_combat(_e,8);ln2_enemy_patrol(_g);return;
        case 5:
            var _ahead=_p.x;
            if (_p.heading<128) _ahead+=_p.heading<4?-8:8;
            if (_ahead<0 || _ahead>255) { ln2_enemy_stance(_g);return; }
            var _range=_g.data.enemy_range[_e.weapon],_target=_ahead<_e.x?_p.x+_range:_p.x-_range;
            if (_target<0 || _target>255 || min(255,abs(_target-_e.x)+abs(_p.y-_e.y))<6) {
                ln2_enemy_stance(_g);return;
            }
            if (_e.x<4) { _e.x=4;ln2_enemy_stance(_g);return; }
            if (_e.x>=248) { _e.x=247;ln2_enemy_stance(_g);return; }
            if (_e.active==128 && min(255,abs(_p.x-_e.x)+abs(_p.y-_e.y))>=56) {
                var _pd=(abs(_p.x-_e.origin_x)>>1)+(abs(_p.y-_e.origin_y)>>1);
                var _ed=(abs(_e.x-_e.origin_x)>>1)+(abs(_e.y-_e.origin_y)>>1);
                if (_pd>=_ed) {
                    _e.facing=ln2_enemy_face(_e,_p.x,_p.y);_e.heading=_e.facing;
                    ln2_enemy_select(_e,_g.data,48);_e.mode=9;ln2_enemy_combat(_e,0);
                    _e.origin_x=_p.x;_e.origin_y=_p.y;return;
                }
            }
            var _direct=ln2_enemy_face(_e,_p.x,_p.y),_facing=ln2_enemy_face(_e,_target,_p.y);
            if ((_direct^_facing)&4) {
                if (ln2_enemy_random(_g)<16 && abs(_p.y-_e.y)<8) { ln2_enemy_stance(_g);return; }
            }
            if (_facing!=_e.facing && (!((_facing^_e.facing)&4) || ((_tick-_e.turn_tick)&255)>=20)) {
                _e.facing=_facing;_e.turn_tick=_tick;ln2_enemy_select(_e,_g.data,8);ln2_enemy_combat(_e,8);
            }
            var _dx=abs(_target-_e.x),_dy=abs(_p.y-_e.y);
            if ((_dx>>2)<_dy || _dy<4) _e.heading=_g.data.enemy_steer[_e.facing-((_dx>>2)>=_dy?0:1)];
            else _e.heading=_e.facing;
            return;
        case 6:ln2_enemy_attack(_g);return;
        case 7:if (_e.action<256) ln2_enemy_react(_g);return;
        case 8:
            ln2_enemy_combat(_e,0);
            if (abs(_p.x-_e.target_x)>=8 || abs(_p.y-_e.target_y)>=4 || _e.attack_count>=2) {
                ln2_enemy_approach(_g);return;
            }
            if (((_tick-_e.react_tick)&255)>=((_e.react_random&31)+16)) ln2_enemy_attack(_g);
            return;
        case 9:if (_e.action<256 && _e.projectile_active==0) ln2_enemy_approach(_g);return;
        case 10:return;
        case 11:
            if (_e.knockouts==255) return;
            var _elapsed=((_g.tick_epoch*256+_tick)-_e.recovery_time)&65535;
            _e.health=clamp((_elapsed>>_g.data.enemy_recovery_shift)-2,0,44);
            if (_e.health==44 && (abs(_p.x-_e.x)>=12 || abs(_p.y-_e.y)>=6)) {
                _e.knockouts&=127;_e.mode=7;_e.action=_g.data.enemy_recovery[(_e.facing&4)?1:0];
                _e.flags=0;_e.countdown=0;_e.separation_y=6;
            }
            return;
        case 12:
            if (((_tick-_e.wait_tick)&255)<12) return;
            _e.wait_tick=_tick;_e.mode=15;_e.facing=(_e.facing+2)&7;_e.heading=_e.facing;
            ln2_enemy_select(_e,_g.data,4);ln2_enemy_combat(_e,0);return;
        case 13:ln2_enemy_path_follow(_g);return;
        case 15:
            if (((_tick-_e.wait_tick)&255)<6) return;
            _e.mode=2;_e.facing=(_e.facing+2)&7;_e.heading=_e.facing;
            ln2_enemy_select(_e,_g.data,24);ln2_enemy_combat(_e,8);return;
    }
}

function ln2_enemy_move(_g,_ticks) {
    var _e=_g.enemy,_p=_g.player,_d=_g.data,_speed=_e.speed+1,_group=_e.facing>>1,_mask=1<<_e.heading;
    var _old_x=_e.x,_old_y=_e.y,_old_fx=_e.fraction_x,_old_fy=_e.fraction_y;
    _e.unconsumed=min(8,_ticks);
    while (_e.unconsumed>0) {
        var _fx=_e.x*256+_e.fraction_x,_fy=_e.y*256+_e.fraction_y;
        if (_d.left[_group]&_mask) _fx-=_d.speed_x[_speed];
        if (_d.right[_group]&_mask) _fx+=_d.speed_x[_speed];
        _e.fraction_x=_fx&255;var _nx=_fx<0?0:(_fx>65535?254:(_fx>>8));
        if (!(_d.no_y[_group]&_mask)) {
            var _step=_d.speed_y[_speed]*((_d.triple_y[_group]&_mask)?3:1);
            if (_d.up[_group]&_mask) _fy-=_step;
            if (_d.down[_group]&_mask) _fy+=_step;
        }
        _fy&=65535;_e.fraction_y=_fy&255;var _ny=_fy>>8;
        _e.collision=ln2_player_boundary(_e,_d,_e.x,_e.y,_nx,_ny,true);
        if (_e.collision!=0) { _e.boundary_hit=_e.hit_boundary*6;break; }
        if (_e.active>=128 && abs(_p.x-_nx)<12 && abs(_p.y-_ny)<_e.separation_y) {
            _e.collision=127;_e.actor_blocked=(_e.actor_blocked+1)&255;break;
        }
        _e.x=_nx;_e.y=_ny;_e.unconsumed--;
    }
    if (_e.x<2 || _e.x>=247 || _e.y<9 || _e.y>=189) {
        _e.edge_blocked=(_e.edge_blocked+1)&255;
        _e.x=_old_x;_e.y=_old_y;_e.fraction_x=_old_fx;_e.fraction_y=_old_fy;return;
    }
    _e.height_fixed=_p.height_fixed;ln2_player_depth(_e,(_e.y-_old_y)&255);
}

function ln2_enemy_action(_g) {
    var _e=_g.enemy,_ticks=(_g.player.tick-_e.action_tick)&255;
    if (_ticks==0) return;
    _e.action_tick=_g.player.tick;
    if (_e.action<256) return;
    if (_e.countdown>_ticks) {
        _e.countdown-=_ticks;if (_e.flags&4) ln2_enemy_move(_g,_ticks);return;
    }
    if (!variable_struct_exists(_g.data.actions,string(_e.action)))
        throw "Missing LN2 action "+string(_e.action)+" in level "+string(_g.data.level)+" scene "+string(_g.player.room_id);
    var _record=variable_struct_get(_g.data.actions,string(_e.action));_e.flags=_record.flags;
    if (_record.duration>=0) _e.duration=_record.duration;
    _e.countdown=_e.duration;_e.frame=_record.frame;
    if (_e.flags&128) {
        var _x=_e.x+_record.dx;_e.x=_x&255;
        if (_record.dx<128 && _x>255) { _e.action&=255;_e.display_frame=255;return; }
        _e.y=(_e.y+_record.dy)&255;_e.height_fixed=_g.player.height_fixed;ln2_player_depth(_e,_record.dy);
    }
    if (_record.state>=0) _e.action_state=_record.state;
    _e.action=_record.next;
    if (_e.action>=256 && (_e.flags&4)) {
        ln2_enemy_move(_g,_ticks);
        if (_e.active<128) return;
    }
    _e.display_frame=_e.frame;_e.mirror=((_e.flags&16)?_e.action_mirror:(_e.flags&64))!=0;
}
