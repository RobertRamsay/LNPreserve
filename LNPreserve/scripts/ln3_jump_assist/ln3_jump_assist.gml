/// LN3 Fire level, molten-metal room: two quick fire presses jump between the upper
/// platform, the two dark boards, the middle pathway and the lower floor, like the LN1
/// river crossings. The original records only the pool's lethal edges, so a native jump
/// onto a board kills. The facing picks the route; the flight takes the native six
/// somersault steps and lands safely. Single fire and directional jumps stay original.

/// The room's nodes and routes from jump_pads.json, or undefined.
function ln3_jump_routes(_level,_room) {
    if (!variable_global_exists("ln3_jump_route_cache")) global.ln3_jump_route_cache={};
    var _key=string(_level)+"_"+string(_room);
    if (variable_struct_exists(global.ln3_jump_route_cache,_key)) return variable_struct_get(global.ln3_jump_route_cache,_key);
    var _found=undefined,_data=ln3_data_read("play/ln3/jump_pads.json");
    for (var _i=0;_i<array_length(_data.rooms);_i++) {
        var _r=_data.rooms[_i];if (_r.level==_level && _r.room==_room) _found=_r;
    }
    variable_struct_set(global.ln3_jump_route_cache,_key,_found);return _found;
}

/// The route the facing points along from the node the ninja stands on, or undefined.
function ln3_jump_route(_g) {
    var _s=_g.state,_r=ln3_jump_routes(_g.level,_g.room_id);if (!is_struct(_r)) return undefined;
    var _x=_s.player_x,_y=_s.player_y,_node="";
    for (var _i=0;_i<array_length(_r.nodes);_i++) {
        var _n=_r.nodes[_i];if (_x>=_n.x0 && _x<=_n.x1 && _y>=_n.y0 && _y<=_n.y1) {_node=_n.name;break;}
    }
    if (_node=="") return undefined;
    // Four facings: mirror picks left or right, stance 1 faces up the screen.
    var _stance=_s.player_action==1 || _s.player_action==4 || _s.player_action==5;
    var _fx=(_s.mirror&6)?-1:1,_fz=_stance?-1:1,_best=undefined,_best_cos=cos(degtorad(67.5));
    for (var _i=0;_i<array_length(_r.routes);_i++) {
        var _route=_r.routes[_i];if (_route.from!=_node) continue;
        // Depth scaled by four, so the four facings are the screen diagonals.
        var _dx=_route.x-_x,_dz=4*(_route.y-_y),_length=point_distance(0,0,_dx,_dz);
        if (_length<1 || abs(_dx)>80 || abs(_route.y-_y)>32) continue;
        var _cos=(_dx*_fx+_dz*_fz)/(_length*sqrt(2));
        if (_cos>_best_cos) {_best=_route;_best_cos=_cos;}
    }
    return _best;
}

/// Two quick fire presses (fire alone) start the routed jump; returns the joystick to use.
function ln3_jump_assist_input(_g,_joy) {
    var _s=_g.state;
    if (!variable_struct_exists(_s,"jump_assist")) _s.jump_assist=undefined;
    if (!variable_struct_exists(_g,"jump_taps")) _g.jump_taps={previous:16,remaining:0};
    var _t=_g.jump_taps,_edge=(_joy&16)!=0 && _t.previous==0;
    _t.previous=_joy&16;_t.remaining=max(0,_t.remaining-1);
    if ((_joy&15)!=0) _t.remaining=0;
    if (is_struct(_s.jump_assist)) return _joy&15;
    if (!_edge || (_joy&15)!=0 || _s.player_action>=6 || _s.player_action_flags>=128 ||
        (_s.stun|_s.input_block|_s.player_dead|_s.climb_flags)!=0 || !is_struct(ln3_jump_routes(_g.level,_g.room_id))) return _joy;
    if (_t.remaining==0) {_t.remaining=18;return _joy;}
    _t.remaining=0;
    var _route=ln3_jump_route(_g);if (!is_struct(_route)) return _joy;
    var _action=(_s.player_action==1 || _s.player_action==4 || _s.player_action==5)?29:28;
    _s.joy=0;ln3_action_set(_s,_g.actions,_action);
    _s.jump_assist={x0:_s.player_x,y0:_s.player_y,x1:_route.x,y1:_route.y,steps:array_length(_g.animation.sequences[_s.parts[1].animation].frames),
        elapsed:0,room:_g.room_id,action:_action};
    return 0;
}

/// The jumper's place on the straight flight, for the current step.
function ln3_jump_assist_place(_s) {
    var _a=_s.jump_assist,_t=_a.elapsed/_a.steps,_nx=round(lerp(_a.x0,_a.x1,_t)),_ny=round(lerp(_a.y0,_a.y1,_t));
    var _dx=_nx-_s.player_x,_dy=_ny-_s.player_y;
    for (var _i=1;_i<=2;_i++) {_s.parts[_i].x=(_s.parts[_i].x+_dx)&255;_s.parts[_i].y=(_s.parts[_i].y+_dy)&255;}
    _s.player_x=_nx;_s.player_y=_ny;
}

/// Called after ln3_movement: advance the flight one step.
function ln3_jump_assist_move(_g) {
    var _s=_g.state;
    if (!variable_struct_exists(_s,"jump_assist") || !is_struct(_s.jump_assist)) return;
    var _a=_s.jump_assist;
    if (_a.room!=_g.room_id) {_s.jump_assist=undefined;return;}
    if (_s.player_action!=_a.action) return;
    _a.elapsed=min(_a.steps,_a.elapsed+1);ln3_jump_assist_place(_s);
}

/// Called after collision, before hazard checks. The flight passes over railings and
/// lava edges, so restore its place; on the final step the landing settles the edge
/// crossings and is safe. The record ends with the jump.
function ln3_jump_assist_land(_g) {
    var _s=_g.state;
    if (!variable_struct_exists(_s,"jump_assist") || !is_struct(_s.jump_assist)) return;
    var _a=_s.jump_assist;
    if (_s.player_action!=_a.action) {_s.jump_assist=undefined;return;}
    if ((_s.player_dead|_s.stun|_s.input_block)!=0) return;
    ln3_jump_assist_place(_s);
    if (_a.elapsed>=_a.steps) {_s.trap_contacts=0;_s.last_boundary=255;}
}

/// Stand the ninja at a point with a facing and stance, feed fire presses, and report the landing.
function ln3_jump_assist_try(_g,_base,_entry,_x,_y,_mirror,_stance,_presses,_save=false) {
    // A jump toward a scene edge can leave the room; return to it for the next attempt.
    if (_g.room_id!=_entry.destination) ln3_play_enter(_g,_entry);
    _g.state=json_parse(_base);_g.turn_request=0;_g.turn_tap=ln_tap_new();_g.pickup_previous=16;_g.jump_taps={previous:0,remaining:0};
    var _s=_g.state;
    for (var _i=0;_i<3;_i++) {_s.parts[_i].x=_x;_s.parts[_i].y=_i==2?_y:(_y-21)&255;}
    _s.player_x=_x;_s.player_y=_y;_s.mirror=_mirror;_s.enabled&=15;_s.player_health=44;_s.joy=0;_s.previous_joy=0;_s.logic_wait=0;
    ln3_action_set(_s,_g.actions,_stance);
    var _r={assisted:false,alive:true,x:_x,y:_y,target_x:-1,target_y:-1},_landed=-1;
    for (var _t=0;_t<160;_t++) {
        ln3_play_tick(_g,_t<array_length(_presses)?_presses[_t]:0);_s=_g.state;
        if (is_struct(_s.jump_assist) && !_r.assisted) {
            _r.assisted=true;_r.target_x=_s.jump_assist.x1;_r.target_y=_s.jump_assist.y1;
            if (_save) {_g=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));_s=_g.state;}
        }
        if (_s.player_dead!=0 || _s.stun!=0 || _s.input_block!=0 || _g.special_sequence!=0) {_r.alive=false;break;}
        if (_landed<0 && _t>=array_length(_presses) && !is_struct(_s.jump_assist) && _s.player_action<6) _landed=_t;
        if (_landed>=0 && _t>=_landed+40) break; // stand on the landing for ten logic steps
    }
    _r.x=_s.player_x;_r.y=_s.player_y;return _r;
}

function ln3_jump_assist_checks() {
    var _smooth=ln3_smooth_enabled(),_g=new LN3Play(4);_g.music=false;
    var _entry={destination:3,spawn_x:236,spawn_y:168,facing:6,action:1};ln3_play_enter(_g,_entry);
    var _base=json_stringify(_g.state),_routes=ln3_jump_routes(4,3),_double=[16,0,0,0,16];
    ln_check(is_struct(_routes) && array_length(_routes.routes)==14,"Fire molten-metal room lists its fourteen routes");
    // Stand on each node at the spot a route lands on, then try every facing.
    var _starts={};
    for (var _i=0;_i<array_length(_routes.routes);_i++) {
        var _route=_routes.routes[_i];
        if (!variable_struct_exists(_starts,_route.to)) variable_struct_set(_starts,_route.to,[_route.x,_route.y]);
    }
    var _reached=0,_missing="";
    for (var _mode=1;_mode>=0;_mode--) {
        global.ln_ln3_smooth=_mode==1;
        for (var _i=0;_i<array_length(_routes.routes);_i++) {
            var _route=_routes.routes[_i],_start=variable_struct_get(_starts,_route.from),_found=false;
            for (var _f=0;_f<4 && !_found;_f++) {
                var _r=ln3_jump_assist_try(_g,_base,_entry,_start[0],_start[1],(_f&1)?6:0,_f>>1,_double);
                if (!_r.assisted || _r.target_x!=_route.x || _r.target_y!=_route.y) continue;
                ln_check(_r.alive && _r.x==_route.x && _r.y==_route.y,"double-fire jump from "+_route.from+" to "+_route.to+
                    " lands and stays safe: "+string(_r.x)+","+string(_r.y)+" alive="+string(_r.alive));
                _found=true;
            }
            if (_found && _mode==1) _reached++;
            if (!_found && _mode==1) _missing+=" "+_route.from+">"+_route.to;
            if (_mode==0) ln_check(_found || string_pos(_route.from+">"+_route.to,_missing)>0,"double-fire jumps also work in Original mode");
        }
    }
    global.ln_ln3_smooth=true;
    // Four facings cannot separate every neighbour of the pathway: the west board is two hops away.
    ln_check(_missing==" middle pathway>west board","every other route has a facing: missing"+_missing);
    var _w=variable_struct_get(_starts,"west board");
    var _single=ln3_jump_assist_try(_g,_base,_entry,_w[0],_w[1],0,0,[16]);
    ln_check(!_single.assisted && _single.alive,"single fire does not jump");
    var _held=[];repeat(12) array_push(_held,16);
    ln_check(!ln3_jump_assist_try(_g,_base,_entry,_w[0],_w[1],0,0,_held).assisted,"held fire does not count as two presses");
    var _slow=[16];repeat(24) array_push(_slow,0);array_push(_slow,16);
    ln_check(!ln3_jump_assist_try(_g,_base,_entry,_w[0],_w[1],0,0,_slow).assisted,"slow separate presses do not jump");
    ln_check(!ln3_jump_assist_try(_g,_base,_entry,_w[0],_w[1],0,0,[18,0,0,0,18]).assisted,"fire with a direction keeps the original jump");
    var _saved=ln3_jump_assist_try(_g,_base,_entry,_w[0],_w[1],0,0,_double,true);
    ln_check(_saved.assisted && _saved.alive && _saved.x==_saved.target_x && _saved.y==_saved.target_y,"saved double-fire jump resumes and lands");
    var _other=new LN3Play(4);_other.music=false;
    var _other_entry={destination:0,spawn_x:120,spawn_y:150,facing:0,action:0};ln3_play_enter(_other,_other_entry);
    var _other_base=json_stringify(_other.state);
    ln_check(!ln3_jump_assist_try(_other,_other_base,_other_entry,120,150,0,0,_double).assisted,"other scenes have no double-fire jumps");
    global.ln_ln3_smooth=_smooth;
    show_debug_message("LN3_JUMP_ASSIST_PASS: "+string(_reached)+" of 14 Fire stepping routes by double fire in both modes, single/held/slow/directional fire unchanged, saves");
}
