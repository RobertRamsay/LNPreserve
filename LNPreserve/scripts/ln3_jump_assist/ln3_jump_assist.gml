/// Enhanced LN3 somersault assistance for the Fire level's molten-metal room.
/// The original records only the pool's lethal edges: landing on a stepping stone
/// after crossing one edge kills, and the one survivable crossing is a few pixels
/// wide. Enhanced jumps pick the landing pad ahead (a stone, the middle pathway,
/// the lower floor or the upper platform), travel there in the native number of
/// steps and land safely. Original mode keeps the native jump and its outcome.

/// The room's landing pads, with area pads sampled on a 4x2 grid, or undefined.
function ln3_jump_pads(_level,_room) {
    if (!variable_global_exists("ln3_jump_pad_cache")) global.ln3_jump_pad_cache={};
    var _key=string(_level)+"_"+string(_room);
    if (variable_struct_exists(global.ln3_jump_pad_cache,_key)) return variable_struct_get(global.ln3_jump_pad_cache,_key);
    var _found=undefined,_data=ln3_data_read("play/ln3/jump_pads.json");
    for (var _i=0;_i<array_length(_data.rooms);_i++) {
        var _r=_data.rooms[_i];if (_r.level!=_level || _r.room!=_room) continue;
        var _points=[];
        for (var _j=0;_j<array_length(_r.stones);_j++) array_push(_points,{x:_r.stones[_j].x,y:_r.stones[_j].y,stone:true});
        for (var _j=0;_j<array_length(_r.areas);_j++) {
            var _a=_r.areas[_j];
            for (var _y=_a.y0;_y<=_a.y1;_y+=2) for (var _x=_a.x0;_x<=_a.x1;_x+=4) array_push(_points,{x:_x,y:_y,stone:false});
        }
        _found={stones:_r.stones,points:_points};
    }
    variable_struct_set(global.ln3_jump_pad_cache,_key,_found);return _found;
}

/// Matches ln3_collision_update's containment and ln3_collision_hit's band test.
function ln3_jump_record_hit(_raw,_x,_y) {
    var _x0=(_raw[0]-2)&255,_x1=(_raw[2]+2)&255,_y0=_raw[1],_y1=_raw[3],_flags=_raw[4],_type=(_flags>>6)&3;
    if (_y0<_y1) {_y0=(_y0+1)&255;_y1=(_y1-1)&255;}
    if (_x<_x0 || _x>_x1) return false;
    if (_y0>=_y1) {if (_y>_y0 || _y<_y1) return false;}
    else if (_y<=_y0 || _y>_y1) return false;
    if (!(_flags&3)) return (_flags&12)!=0;
    if (_type==0) return true;
    var _line=(_y0+ceil((_x-_x0)/4)*(_type==1?1:-1))&255,_difference=(_flags&1)?_line-_y:_y-_line;
    return _difference>0 && _difference<9;
}

/// Any record (or only hazards/solids) touching the point, optionally within a vertical margin.
function ln3_jump_touches(_g,_x,_y,_kind,_margin=0) {
    for (var _i=0;_i<array_length(_g.bounds);_i++) {
        var _raw=_g.bounds[_i],_hazard=(_raw[4]&32)!=0;
        if ((_kind==1 && !_hazard) || (_kind==2 && _hazard)) continue;
        for (var _dy=-_margin;_dy<=_margin;_dy++) if (ln3_jump_record_hit(_raw,_x,_y+_dy)) return true;
    }
    return false;
}

/// Called after ln3_movement_setup on the first step of a somersault.
function ln3_jump_assist_begin(_g) {
    var _s=_g.state;
    if (!variable_struct_exists(_s,"jump_assist")) _s.jump_assist=undefined;
    if (is_struct(_s.jump_assist) || !ln3_smooth_enabled() || (_s.player_action!=28 && _s.player_action!=29) ||
        _s.parts[1].cursor>1 || (_s.stun|_s.input_block|_s.player_dead|_s.climb_flags)!=0) return false;
    var _pads=ln3_jump_pads(_g.level,_g.room_id);if (!is_struct(_pads)) return false;
    // Backward somersaults hold their first pose, so start on the first moving step.
    var _legs=_s.parts[2],_d=_legs.direction,_steps=array_length(_g.animation.sequences[_s.parts[1].animation].frames)-_s.parts[1].cursor;
    var _hx=((_d&8)!=0)-((_d&4)!=0),_vy=((_d&2)!=0)-((_d&1)!=0);
    if ((_hx==0 && _vy==0) || _steps<=0) return false;
    // Compare directions with depth scaled by four, so the eight jumps are 45 degrees apart.
    var _x0=_s.player_x,_y0=_s.player_y,_vx=_hx*_legs.dx*_steps,_vz=4*_vy*_legs.dy*_steps,_reach=point_distance(0,0,_vx,_vz);
    // Native landings that cross no lethal edge are left alone unless they start or end on a stone.
    var _risky=false;
    for (var _k=1;_k<=_steps && !_risky;_k++) _risky=ln3_jump_touches(_g,_x0+_hx*_legs.dx*_k,_y0+_vy*_legs.dy*_k,1);
    var _best=undefined,_best_score=infinity;
    for (var _i=0;_i<array_length(_pads.points);_i++) {
        var _p=_pads.points[_i],_wx=_p.x-_x0,_wz=4*(_p.y-_y0),_length=point_distance(0,0,_wx,_wz);
        if (_length<12 || _length>_reach*1.75) continue;
        if ((_wx*_vx+_wz*_vz)/(_length*_reach)<0.84) continue; // about 33 degrees either side
        var _score=point_distance(_wx,_wz,_vx,_vz)-(_p.stone?1000:0);
        if (_score>=_best_score || ln3_jump_touches(_g,_p.x,_p.y,0,2)) continue;
        var _clear=true;
        for (var _k=1;_k<=_steps && _clear;_k++)
            _clear=!ln3_jump_touches(_g,round(lerp(_x0,_p.x,_k/_steps)),round(lerp(_y0,_p.y,_k/_steps)),2);
        if (_clear) {_best=_p;_best_score=_score;}
    }
    if (!is_struct(_best)) return false;
    var _on_stone=false;
    for (var _i=0;_i<array_length(_pads.stones);_i++)
        if (point_distance(_x0,4*_y0,_pads.stones[_i].x,4*_pads.stones[_i].y)<=16) _on_stone=true;
    if (!_best.stone && !_risky && !_on_stone) return false;
    _s.jump_assist={x0:_x0,y0:_y0,x1:_best.x,y1:_best.y,steps:_steps,elapsed:0,room:_g.room_id,action:_s.player_action};
    return true;
}

/// Called after ln3_movement: place the jumper on the straight path to the pad.
function ln3_jump_assist_move(_g) {
    var _s=_g.state;
    if (!variable_struct_exists(_s,"jump_assist") || !is_struct(_s.jump_assist)) return;
    var _a=_s.jump_assist;
    if (_a.room!=_g.room_id) {_s.jump_assist=undefined;return;}
    if (_s.player_action!=_a.action) return;
    _a.elapsed=min(_a.steps,_a.elapsed+1);
    var _t=_a.elapsed/_a.steps,_nx=round(lerp(_a.x0,_a.x1,_t)),_ny=round(lerp(_a.y0,_a.y1,_t));
    var _dx=_nx-_s.player_x,_dy=_ny-_s.player_y;
    for (var _i=1;_i<=2;_i++) {_s.parts[_i].x=(_s.parts[_i].x+_dx)&255;_s.parts[_i].y=(_s.parts[_i].y+_dy)&255;}
    _s.player_x=_nx;_s.player_y=_ny;
}

/// Called after collision, before hazard checks. Reaching the pad on the final step
/// settles the edge crossings, so the landing is safe; the record ends with the jump.
function ln3_jump_assist_land(_g) {
    var _s=_g.state;
    if (!variable_struct_exists(_s,"jump_assist") || !is_struct(_s.jump_assist)) return;
    var _a=_s.jump_assist;
    if (_s.player_action!=_a.action) {_s.jump_assist=undefined;return;}
    if (_a.elapsed>=_a.steps && _s.player_x==_a.x1 && _s.player_y==_a.y1 && (_s.player_dead|_s.stun|_s.input_block)==0) {
        _s.trap_contacts=0;_s.last_boundary=255;
    }
}

/// Stand the ninja at a point with a facing and stance, then walk one step and fire.
function ln3_jump_assist_try(_g,_base,_entry,_x,_y,_mirror,_stance,_joy,_save=false) {
    // Jumps toward a scene edge can leave the room; return to it for the next attempt.
    if (_g.room_id!=_entry.destination) ln3_play_enter(_g,_entry);
    _g.state=json_parse(_base);_g.logic_ticks=0;_g.turn_request=0;_g.turn_tap=ln_tap_new();_g.pickup_previous=0;
    var _s=_g.state;
    for (var _i=0;_i<3;_i++) {_s.parts[_i].x=_x;_s.parts[_i].y=_i==2?_y:(_y-21)&255;}
    _s.player_x=_x;_s.player_y=_y;_s.mirror=_mirror;_s.enabled&=15;_s.player_health=44;_s.joy=0;_s.previous_joy=0;
    ln3_action_set(_s,_g.actions,_stance);
    var _result={assisted:false,jumped:false,x:_x,y:_y,alive:true,target_x:-1,target_y:-1,x0:-1,y0:-1};
    for (var _t=0;_t<24;_t++) {
        _g.state.logic_wait=0;
        ln3_play_tick(_g,_t==0?_joy&15:(_t==1?_joy:0));_s=_g.state;
        if (is_struct(_s.jump_assist) && !_result.assisted) {
            _result.assisted=true;_result.target_x=_s.jump_assist.x1;_result.target_y=_s.jump_assist.y1;
            _result.x0=_s.jump_assist.x0;_result.y0=_s.jump_assist.y0;
            if (_save) {_g=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));_s=_g.state;}
        }
        if (_s.player_action==28 || _s.player_action==29) _result.jumped=true;
        if (_s.player_dead!=0 || _s.stun!=0 || _s.input_block!=0 || _g.special_sequence!=0) {_result.alive=false;break;}
        if (_result.jumped && _s.player_action<6 && _t>=10) break;
    }
    _result.x=_s.player_x;_result.y=_s.player_y;return _result;
}

function ln3_jump_in_area(_areas,_name,_x,_y) {
    for (var _i=0;_i<array_length(_areas);_i++) {
        var _a=_areas[_i];
        if (_a.name==_name) return _x>=_a.x0 && _x<=_a.x1 && _y>=_a.y0 && _y<=_a.y1;
    }
    return false;
}

function ln3_jump_assist_checks() {
    var _smooth=ln3_smooth_enabled(),_g=new LN3Play(4);_g.music=false;
    var _entry={destination:3,spawn_x:236,spawn_y:168,facing:6,action:1};ln3_play_enter(_g,_entry);
    var _base=json_stringify(_g.state),_pads=ln3_jump_pads(4,3);
    ln_check(is_struct(_pads) && array_length(_pads.stones)==4,"Fire molten-metal room has four stepping stones");
    // Starting points: every stone and a coarse sample of each landing area.
    var _starts=[],_hop_starts=[];
    for (var _i=0;_i<array_length(_pads.points);_i++) {
        var _p=_pads.points[_i];
        if (_p.stone || (_p.x%16==0 && _p.y%8==0 && !ln3_jump_touches(_g,_p.x,_p.y,0,4))) array_push(_starts,_p);
        if (_p.stone || !ln3_jump_touches(_g,_p.x,_p.y,0,1)) array_push(_hop_starts,_p);
    }
    var _inputs=[];
    for (var _m=0;_m<=6;_m+=6) for (var _a=0;_a<2;_a++) for (var _j=17;_j<=26;_j++) if ((_j&3)!=3 && (_j&12)!=12) array_push(_inputs,[_m,_a,_j]);
    var _assisted=0,_stone_landings=0,_reached=array_create(4,false);
    var _routes={floor_stone:undefined};
    for (var _mode=1;_mode>=0;_mode--) {
        global.ln_ln3_smooth=_mode==1;
        for (var _i=0;_i<array_length(_starts);_i++) for (var _n=0;_n<array_length(_inputs);_n++) {
            var _p=_starts[_i],_in=_inputs[_n],_r=ln3_jump_assist_try(_g,_base,_entry,_p.x,_p.y,_in[0],_in[1],_in[2]);
            if (_mode==0) {ln_check(!_r.assisted,"Original mode keeps native LN3 jumps");continue;}
            if (!_r.assisted) continue;
            _assisted++;
            ln_check(_r.alive && _r.x==_r.target_x && _r.y==_r.target_y,"assisted Fire jump lands safely on its pad from "+string(_r.x0)+","+string(_r.y0)+
                " to "+string(_r.target_x)+","+string(_r.target_y)+" actual="+string(_r.x)+","+string(_r.y)+" alive="+string(_r.alive));
            for (var _k=0;_k<4;_k++) if (_r.target_x==_pads.stones[_k].x && _r.target_y==_pads.stones[_k].y) {
                _reached[_k]=true;_stone_landings++;
                if (!_p.stone && _p.y>=130 && _p.x>=136 && !is_struct(_routes.floor_stone)) _routes.floor_stone={x:_p.x,y:_p.y,input:_in};
            }
        }
    }
    global.ln_ln3_smooth=true;
    ln_check(_assisted>40,"Fire stepping-stone sweep covers many assisted jumps: "+string(_assisted));
    for (var _k=0;_k<4;_k++) ln_check(_reached[_k],"assisted jump reaches "+_pads.stones[_k].name);
    // Each hop of the crossing: floor, stones, pathway and platform, by real input.
    var _areas=ln3_data_read("play/ln3/jump_pads.json").rooms[0].areas;
    // The stones join the upper platform and the lower floor; an original wall line
    // separates them from the middle pathway, which is reached from the lower floor.
    var _pairs=[["lower floor","stump east"],["stump east","stump north"],["stump north","stump west"],["stump west","stump south"],
        ["stump south","lower floor"],["stump west","upper platform"],["upper platform","stump west"],
        ["lower floor","middle pathway"],["middle pathway","lower floor"]];
    for (var _q=0;_q<array_length(_pairs);_q++) {
        var _from=_pairs[_q][0],_to=_pairs[_q][1],_done=false,_tx=0,_ty=0,_from_list=[];
        for (var _k=0;_k<4;_k++) if (_pads.stones[_k].name==_to) {_tx=_pads.stones[_k].x;_ty=_pads.stones[_k].y;}
        for (var _k=0;_k<array_length(_areas);_k++) if (_areas[_k].name==_to) {_tx=(_areas[_k].x0+_areas[_k].x1)/2;_ty=(_areas[_k].y0+_areas[_k].y1)/2;}
        for (var _i=0;_i<array_length(_hop_starts);_i++) {
            var _p=_hop_starts[_i],_start_ok=false;
            if (_p.stone) {for (var _k=0;_k<4;_k++) if (_pads.stones[_k].name==_from && _pads.stones[_k].x==_p.x && _pads.stones[_k].y==_p.y) _start_ok=true;}
            else _start_ok=ln3_jump_in_area(_areas,_from,_p.x,_p.y);
            if (_start_ok) array_push(_from_list,{x:_p.x,y:_p.y,d:point_distance(_p.x,4*_p.y,_tx,4*_ty)});
        }
        array_sort(_from_list,function(_a,_b) {return _a.d-_b.d;});
        for (var _i=0;_i<min(24,array_length(_from_list)) && !_done;_i++) {
            var _p=_from_list[_i];
            for (var _n=0;_n<array_length(_inputs) && !_done;_n++) {
                var _in=_inputs[_n],_r=ln3_jump_assist_try(_g,_base,_entry,_p.x,_p.y,_in[0],_in[1],_in[2]);
                if (!_r.assisted || !_r.alive) continue;
                var _hit=ln3_jump_in_area(_areas,_to,_r.x,_r.y);
                for (var _k=0;_k<4;_k++) if (_pads.stones[_k].name==_to && _r.x==_pads.stones[_k].x && _r.y==_pads.stones[_k].y) _hit=true;
                _done=_hit;
            }
        }
        ln_check(_done,"real input jumps from "+_from+" to "+_to);
    }
    // Original mode keeps the C64 outcome: crossing the pool edge onto a stone kills.
    var _f=_routes.floor_stone;ln_check(is_struct(_f),"a lower-floor start reaches a stone");
    var _enhanced=ln3_jump_assist_try(_g,_base,_entry,_f.x,_f.y,_f.input[0],_f.input[1],_f.input[2]);
    global.ln_ln3_smooth=false;
    var _original=ln3_jump_assist_try(_g,_base,_entry,_f.x,_f.y,_f.input[0],_f.input[1],_f.input[2]);
    global.ln_ln3_smooth=true;
    ln_check(_enhanced.alive && !_original.assisted && (!_original.alive || _original.x!=_enhanced.x || _original.y!=_enhanced.y),
        "Original floor-to-stone jump keeps its native landing");
    // A save made mid-jump resumes the assisted flight.
    var _saved=ln3_jump_assist_try(_g,_base,_entry,_f.x,_f.y,_f.input[0],_f.input[1],_f.input[2],true);
    ln_check(_saved.alive && _saved.x==_enhanced.x && _saved.y==_enhanced.y,"saved assisted jump resumes and lands");
    // Elsewhere, Enhanced jumps follow the native path.
    var _other=new LN3Play(4);_other.music=false;
    var _other_entry={destination:0,spawn_x:120,spawn_y:150,facing:0,action:0};ln3_play_enter(_other,_other_entry);
    var _other_base=json_stringify(_other.state);
    for (var _n=0;_n<array_length(_inputs);_n++) {
        var _in=_inputs[_n];
        global.ln_ln3_smooth=true;var _e=ln3_jump_assist_try(_other,_other_base,_other_entry,120,150,_in[0],_in[1],_in[2]);
        global.ln_ln3_smooth=false;var _o=ln3_jump_assist_try(_other,_other_base,_other_entry,120,150,_in[0],_in[1],_in[2]);
        ln_check(!_e.assisted && _e.x==_o.x && _e.y==_o.y,"jumps outside the molten-metal room are unchanged");
    }
    global.ln_ln3_smooth=_smooth;
    show_debug_message("LN3_JUMP_ASSIST_PASS: "+string(_assisted)+" assisted Fire jumps, "+string(_stone_landings)+" stone landings, nine hops, Original unchanged, saves");
}
