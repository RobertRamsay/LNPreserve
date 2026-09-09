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
    if (_kind==4 && variable_struct_exists(_d,"forward_roll_entries")) _s.action=_d.forward_roll_entries[((_s.facing+2)&4)>>2];
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
        if (_joy==16 && variable_struct_exists(_s,"world_game") && ln1_jump_assist_start(_s.world_game)) return;
        var _relative=(_heading-_s.facing)&7;
        if (_heading<128 && _s.stopped==0 && _relative>=3 && _relative<=5 &&
            variable_struct_exists(_d,"reverse_roll_entries")) {
            _s.heading=_heading;_s.stopped=255;
            ln1_player_begin_action(_s,_d,4);
            _s.action=_d.reverse_roll_entries[((_s.facing+2)&4)>>2];
            _s.flags=variable_struct_get(_d.actions,string(_s.action)).flags;
            return;
        }
        if (_heading>=128 && variable_struct_exists(_s,"world_game") && ln1_pickup_assist_start(_s.world_game)) return;
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
    if (variable_struct_exists(_s,"jump_assist") && is_struct(_s.jump_assist)) {
        if (_s.action>=256) {ln1_jump_assist_tick(_s,_d,_ticks);return;}
        _s.jump_assist=undefined;
    }
    if (_s.action < 256) ln1_player_input(_s, _d, _joy);
    if (variable_struct_exists(_s,"jump_assist") && is_struct(_s.jump_assist)) {ln1_jump_assist_tick(_s,_d,_ticks);return;}
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

/// Requested LN1 control enhancement. Build separate reverse tracks from the
/// recovered roll; original action entries and reference vectors remain intact.
function ln1_reverse_roll_prepare(_d) {
    _d.reverse_roll_entries=[];
    _d.forward_roll_entries=[];
    for (var _side=0;_side<2;_side++) {
        var _records=[],_address=_d.action_entries[2+_side],_duration=0;
        while (_address>=256) {
            var _r=variable_struct_get(_d.actions,string(_address));
            if (_r.duration>=0) _duration=_r.duration;
            array_push(_records,{frame:_r.frame,duration:_duration});
            _address=_r.next;
        }
        var _base=65536+_side*32,_count=array_length(_records);
        array_push(_d.reverse_roll_entries,_base);
        for (var _i=0;_i<=_count;_i++) {
            // Start on the forward roll's final pose, then reverse every pose.
            // A final standing command releases the action cleanly after landing.
            var _last=_i==_count,_pose=_records[_last?_count-1:_count-1-_i];
            variable_struct_set(_d.actions,string(_base+_i),{
                frame:_pose.frame,duration:_pose.duration,flags:_last?56:(_i==0?26:28),
                dx:0,dy:0,state:-1,combat_data:-1,next:_last?0:_base+_i+1});
        }
        // Keep the forward landing pose for its full duration without travel.
        // Use a separate track so original-data regression vectors stay intact.
        var _forward=65664+_side*32;
        array_push(_d.forward_roll_entries,_forward);
        for (var _i=0;_i<=_count;_i++) {
            var _release=_i==_count,_landing=_i>=_count-1;
            var _pose=_records[min(_i,_count-1)];
            variable_struct_set(_d.actions,string(_forward+_i),{
                frame:_pose.frame,duration:_pose.duration,flags:_landing?56:(_i==0?30:28),
                dx:0,dy:0,state:-1,combat_data:-1,next:_release?0:_forward+_i+1});
        }
    }
}

function ln1_reverse_roll_checks() {
    for (var _facing=1;_facing<8;_facing+=2) for (var _weapon=0;_weapon<=2;_weapon+=2) {
        var _g=new LN1Play(),_p=_g.player,_d=_g.data;
        _d.boundaries=[];_p.x=120;_p.y=100;_p.facing=_facing;_p.heading=_facing;
        _p.turn_lock=0;_p.action=0;_p.input_lock=0;_p.fire_previous=0;
        _p.weapon=_weapon;_p.selected_weapon=_weapon;_p.enemy_active=0;
        var _back=(_facing+4)&7,_joy=0;
        for (var _j=0;_j<16;_j++) if (_d.directions[_j]==_back) {_joy=_j;break;}
        // Walk backwards first, then press fire while keeping that direction.
        ln1_player_update(_p,_d,_joy,(_p.tick+1)&255);
        var _x=_p.x,_y=_p.y,_frames=[],_previous=-1;
        ln1_player_update(_p,_d,_joy|16,(_p.tick+1)&255);
        ln_check(_p.action>=65536,"backward walking plus fire starts reverse roll");
        if (_facing==1 && _weapon==0) {
            var _snapshot=json_parse(json_stringify(ln_save_capture(_g)));
            variable_struct_remove(_snapshot.state.data,"reverse_roll_entries");
            var _loaded=ln_save_restore(_snapshot);
            ln_check(variable_struct_exists(_loaded.data,"reverse_roll_entries"),"loading older saves enables backward rolls");
            repeat(64) {if (_loaded.player.action<256) break;ln1_player_update(_loaded.player,_loaded.data,0,(_loaded.player.tick+1)&255);}
            ln_check(_loaded.player.action<256 && _p.action>=65536,"saved mid-roll resumes independently and lands");
        }
        var _side=((_facing+2)&4)>>2;
        repeat(64) {
            if (_p.display_frame!=_previous) {array_push(_frames,_p.display_frame);_previous=_p.display_frame;}
            if (_p.action<256) break;
            ln1_player_update(_p,_d,_joy|16,(_p.tick+1)&255);
        }
        var _expected=_side==0?[0,18,23,22,21,20,0]:[8,19,27,26,25,24,8];
        ln_check(json_stringify(_frames)==json_stringify(_expected),"reverse roll displays original poses in reverse order and lands");
        ln_check(_p.facing==_facing && _p.weapon==_weapon && _p.input_lock==0 && _p.action<256,"reverse roll preserves facing/weapon and releases control");
        var _probe={x:_x,y:_y,heading:_back,facing:_facing,unconsumed:0,fraction_y:0,
            boundary_mode:128,boundary_crossings:0,enemy_active:0};
        ln1_player_move(_probe,_d,4);
        ln_check(sign(_p.x-_x)==sign(_probe.x-_x) && sign(_p.y-_y)==sign(_probe.y-_y),"reverse roll travels backwards");
        // The same roll cannot cross a blocking line behind the player.
        _p.x=120;_p.y=100;_p.action=0;_p.fire_previous=0;_p.stopped=0;
        _p.fraction_y=0;var _line=sign(_probe.y-_y)>0?102:98;
        _d.boundaries=[[0,_line,255,_line,0]];
        ln1_player_update(_p,_d,_joy|16,(_p.tick+1)&255);
        repeat(64) {if (_p.action<256) break;ln1_player_update(_p,_d,_joy|16,(_p.tick+1)&255);}
        ln_check(_line>100?_p.y<_line:_p.y>=_line,"backward roll respects walls");
    }
    ln1_roll_landing_checks();
    show_debug_message("LN_REVERSE_ROLL_PASS: reverse poses, facing, weapons, backward movement and walls");
}

function ln1_roll_landing_checks() {
    for (var _facing=1;_facing<8;_facing+=2) for (var _reverse=0;_reverse<2;_reverse++) {
        var _g=new LN1Play(),_p=_g.player,_d=_g.data;
        _d.boundaries=[];_p.x=120;_p.y=100;_p.fraction_y=0;
        _p.facing=_facing;_p.heading=_reverse?(_facing+4)&7:_facing;
        _p.stopped=255;_p.enemy_active=0;
        ln1_player_begin_action(_p,_d,4);
        var _side=((_facing+2)&4)>>2;
        if (_reverse) {_p.action=_d.reverse_roll_entries[_side];_p.flags=variable_struct_get(_d.actions,string(_p.action)).flags;}
        var _landing=_side?8:0,_held=0,_travel=0;
        repeat(64) {
            var _x=_p.x,_y=_p.y,_fraction=_p.fraction_y;
            ln1_player_update(_p,_d,0,(_p.tick+1)&255);
            if (_p.display_frame==_landing) {
                ln_check(_p.x==_x && _p.y==_y && _p.fraction_y==_fraction,"landing pose never moves, including fractional movement");
                _held++;
            } else if (_p.x!=_x || _p.y!=_y) _travel++;
            if (_p.action<256) break;
        }
        ln_check(_held>=7 && _travel>0 && _p.action<256,"landing is held stationary while airborne roll still travels");
    }
    show_debug_message("LN_ROLL_LANDING_PASS: stationary first backward / last forward pose for every facing");
}

/// Fire-only convenience for the recovered river/log/rock safe rectangles.
function ln1_jump_assist_target(_g) {
    var _p=_g.player,_kind=_p.boundary_mode&31;
    if (_kind<16 || _kind>=20) return undefined;
    var _areas=_g.world.safe_areas[_kind&3];
    var _direction={x:120,y:100,facing:_p.facing,heading:_p.facing,fraction_y:0,
        boundary_mode:0,boundary_crossings:0,enemy_active:0};
    var _empty={boundaries:[],left:_g.data.left,right:_g.data.right,no_y:_g.data.no_y,
        double_y:_g.data.double_y,up:_g.data.up,down:_g.data.down};
    ln1_player_move(_direction,_empty,8);
    var _fx=_direction.x-120,_fy=2*(_direction.y-100),_best=undefined,_nearest=100000;
    for (var _i=0;_i<array_length(_areas);_i++) {
        var _r=_areas[_i];
        if (_p.x>=_r[0] && _p.x<_r[1] && _p.y>=_r[2] && _p.y<_r[3]) continue;
        var _x=floor((_r[0]+_r[1]-1)/2),_y=floor((_r[2]+_r[3]-1)/2);
        var _dx=_x-_p.x,_dy=_y-_p.y,_distance=_dx*_dx+4*_dy*_dy;
        var _dot=_dx*_fx+2*_dy*_fy,_cross=_dx*_fy-2*_dy*_fx;
        if (_dot<=0 || abs(_cross)>_dot || abs(_dx)>64 || abs(_dy)>40 || _distance>=_nearest) continue;
        var _probe={x:_p.x,y:_p.y,boundary_mode:0,boundary_crossings:0},_clear=true;
        var _steps=max(1,ceil(max(abs(_dx),abs(_dy))));
        for (var _step=1;_step<=_steps;_step++) {
            var _nx=round(_p.x+_dx*_step/_steps),_ny=round(_p.y+_dy*_step/_steps);
            // Water boundaries may be crossed in flight; solid boundaries may not.
            if (ln1_player_boundary(_probe,_g.data,_nx,_ny)!=0) {_clear=false;break;}
            _probe.x=_nx;_probe.y=_ny;
        }
        if (_clear) {_nearest=_distance;_best={x:_x,y:_y,area:_i};}
    }
    return _best;
}

function ln1_jump_assist_start(_g) {
    var _p=_g.player;
    if (_p.action>=256 || _p.input_lock!=0 || _g.player_health<=0 || _g.water_active ||
        _g.sequence_kind!=0 || _g.prayer_phase!=0 || _g.death_wait>0) return false;
    var _target=ln1_jump_assist_target(_g);
    if (!is_struct(_target)) return false;
    _p.jump_assist={x0:_p.x,y0:_p.y,x1:_target.x,y1:_target.y,elapsed:0,room:_g.room_id};
    _p.heading=_p.facing;_p.stopped=255;_p.fraction_x=0;_p.fraction_y=0;
    ln1_player_begin_action(_p,_g.data,4);
    return true;
}

function ln1_jump_assist_tick(_p,_d,_ticks) {
    var _a=_p.jump_assist,_g=_p.world_game;
    if (_a.room!=_g.room_id || _g.player_health<=0) {_p.jump_assist=undefined;_p.action=0;return;}
    repeat(_ticks) {
        _a.elapsed++;
        var _t=min(1,_a.elapsed/35),_nx=round(lerp(_a.x0,_a.x1,_t)),_ny=round(lerp(_a.y0,_a.y1,_t));
        var _probe={x:_p.x,y:_p.y,boundary_mode:0,boundary_crossings:_p.boundary_crossings};
        if (ln1_player_boundary(_probe,_d,_nx,_ny)!=0) {
            _p.jump_assist=undefined;_p.action=0;return;
        }
        _p.x=_nx;_p.y=_ny;_p.boundary_crossings=_probe.boundary_crossings;
        var _side=((_p.facing+2)&4)>>2,_frames=_side==0?[20,21,22,23,18,0]:[24,25,26,27,19,8];
        _p.frame=_frames[min(5,(_a.elapsed-1) div 7)];
        ln1_player_render(_p,_p.facing&2);
        if (_a.elapsed>=42) {
            _p.jump_assist=undefined;_p.action=0;_p.flags=0;_p.countdown=0;
            _p.combat_state=_p.facing>>1;_p.stopped=255;return;
        }
    }
}

function ln1_jump_assist_checks() {
    var _g=new LN1Play();ln1_play_enter(_g,11);
    var _p=_g.player;_p.action=0;_p.input_lock=0;_p.fire_previous=0;_p.facing=1;
    // Controlled fixtures isolate nearest/ahead selection from scene geometry.
    _g.data.boundaries=[];_p.x=80;_p.y=110;
    _g.world.safe_areas[0]=[[76,85,106,115],[99,108,96,105],[119,128,86,95],[59,68,116,125]];
    var _target=ln1_jump_assist_target(_g);
    ln_check(is_struct(_target) && _target.area==1,"jump chooses nearest platform ahead and skips current/behind platforms");
    ln1_player_update(_p,_g.data,16,(_p.tick+1)&255);
    ln_check(is_struct(_p.jump_assist),"fire alone starts assisted jump");
    repeat(48) {if (!is_struct(_p.jump_assist)) break;ln1_player_update(_p,_g.data,16,(_p.tick+1)&255);ln1_play_hazards(_g);}
    ln_check(_p.x==_target.x && _p.y==_target.y && _g.player_health==32 && !_g.water_active && _p.action==0,"assisted jump lands safely and finishes");
    _p.x=80;_p.y=110;_p.action=0;_p.fire_previous=0;_p.stopped=0;
    ln1_player_update(_p,_g.data,25,(_p.tick+1)&255);
    ln_check(!is_struct(_p.jump_assist),"fire plus direction retains manual jump");
    _p.action=0;_p.x=80;_p.y=110;_p.facing=1;_g.data.boundaries=[[0,105,255,105,0]];
    ln_check(!is_struct(ln1_jump_assist_target(_g)),"jump assistance rejects a solid wall");
    _g.data.boundaries=[];_g.world.safe_areas[0]=[[59,68,116,125]];
    ln_check(!is_struct(ln1_jump_assist_target(_g)),"jump assistance never chooses a platform behind");
    var _tested=0;
    for (var _level=1;_level<=3;_level++) {
        var _real=new LN1Play(_level);
        for (var _room=1;_room<=array_length(_real.world.rooms);_room++) {
            var _kind=_real.world.rooms[_room-1].boundary_mode&31;
            if (_kind<16 || _kind>=20) continue;
            ln1_play_enter(_real,_room);
            var _areas=_real.world.safe_areas[_kind&3],_n=_real.player;
            for (var _area=0;_area<array_length(_areas);_area++) for (var _face=1;_face<8;_face+=2) {
                var _rect=_areas[_area];
                _n.x=floor((_rect[0]+_rect[1]-1)/2);_n.y=floor((_rect[2]+_rect[3]-1)/2);
                _n.facing=_face;_n.action=0;_n.input_lock=0;_n.fire_previous=0;_n.boundary_crossings=1;
                _n.jump_assist=undefined;_real.player_health=32;_real.water_active=false;
                var _landing=ln1_jump_assist_target(_real);
                if (!is_struct(_landing)) continue;
                ln1_player_update(_n,_real.data,16,(_n.tick+1)&255);
                ln_check(is_struct(_n.jump_assist),"real river/log room fire starts jump");
                repeat(48) {
                    if (!is_struct(_n.jump_assist)) break;
                    ln1_player_update(_n,_real.data,16,(_n.tick+1)&255);ln1_play_hazards(_real);
                }
                ln_check(_n.x==_landing.x && _n.y==_landing.y && _real.player_health==32 && !_real.water_active,
                    "assisted jump lands safely using original room boundaries and platform rectangles");
                _tested++;
            }
        }
    }
    ln_check(_tested>20,"real crossing regression covers multiple levels and platforms");
    show_debug_message("LN_JUMP_REAL_PASS: "+string(_tested)+" original-room platform approaches");
    show_debug_message("LN_JUMP_ASSIST_PASS: nearest ahead, fire-only, safe landing, manual controls and walls");
}
