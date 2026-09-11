/// LN3 moves its eight original sprite parts separately. The leg positions
/// also update each actor's ground position, as in the source routines.
function ln3_movement_setup(_s,_data) {
    for (var _i=7;_i>=0;_i--) {
        var _p=_s.parts[_i];if (_p.move_mode<128) continue;
        var _v=_data.motion[_p.move_mode&127];
        _p.direction=variable_struct_exists(_s,"motion_directions")?_s.motion_directions[_p.move_mode&127]:_v.direction;
        _p.dx=_v.dx;_p.dy=_v.dy;
    }
}

function ln3_movement_reverse_enemy(_s) {
    _s.enemy_turn_direction=_s.parts[4].direction^12;_s.enemy_turn_wait=4;_s.mirror^=96;
}

function ln3_movement_projectile_edge(_s,_data,_i) {
    var _p=_s.parts[_i];
    if (_p.animation!=114) return;
    _p.animation=0;_p.move_mode=0;_s.enabled&=_data.clear_masks[_i];
}

function ln3_movement_actor_collision(_s,_data) {
    if ((_data.hazard_actor_exempt && _s.parts[4].animation==138) || !(_s.player_action==28 || _s.player_action==29 || _s.player_action<6)) return;
    if (_s.enemy_dead!=0 || !(_s.enabled&96)) return;
    var _legs=_s.parts[2],_enemy_legs=_s.parts[6];
    if (abs(_enemy_legs.y-_legs.y)>=4 || abs(_enemy_legs.x-_legs.x)>=12) return;
    for (var _i=1;_i<=2;_i++) { var _p=_s.parts[_i];_p.x=_p.old_x;_p.y=_p.old_y; }
    _s.player_x=_legs.x;_s.player_y=_legs.y;
}

function ln3_movement_platform_edge(_s,_data,_direction) {
    if (_data.level!=2) return;
    var _head=_s.parts[4],_remove=false;
    if (_direction==1) _remove=_s.room_id==5 && _head.y<120;
    if (_direction==2) _remove=_s.room_id==5 && _head.y>=172;
    if (_direction==4) _remove=_s.room_id==6 && _head.x<16;
    if (_direction==8) _remove=_s.room_id==4 && _head.x>=248;
    if (!_remove) return;
    _s.enabled&=15;
    for (var _i=4;_i<8;_i++) _s.parts[_i].move_mode=_s.enabled;
}

function ln3_movement(_s,_data,_first=7,_last=0,_skip_walker=false) {
    for (var _i=_first;_i>=_last;_i--) {
        if (_skip_walker && _i<3) continue;
        var _p=_s.parts[_i];_p.old_x=_p.x;_p.old_y=_p.y;
        if (_p.move_mode<128 || _p.direction==0) continue;
        if (_p.direction&1) {
            _p.y=(_p.y-_p.dy)&255;
            if (_i==2) _s.player_y=(_s.player_y-_p.dy)&255;
            if (_i==6) _s.enemy_y=(_s.enemy_y-_p.dy)&255;
            ln3_movement_platform_edge(_s,_data,1);
        }
        if (_p.direction&2) {
            _p.y=(_p.y+_p.dy)&255;
            if (_i==2) _s.player_y=(_s.player_y+_p.dy)&255;
            if (_i==6) _s.enemy_y=(_s.enemy_y+_p.dy)&255;
            ln3_movement_platform_edge(_s,_data,2);
        }
        for (var _side=0;_side<2;_side++) {
            if (!(_p.direction&(_side==0?4:8))) continue;
            var _step=_side==0?-_p.dx:_p.dx;
            if (_i==2) _s.player_x=(_s.player_x+_step)&255;
            if (_i==6) _s.enemy_x=(_s.enemy_x+_step)&255;
            var _nx=(_p.x+_step)&255;
            var _enemy_edge=_side==0?_s.enemy_x<24:_s.enemy_x>=244;
            if (_i>=4 && !(_data.hazard_actor_exempt && _s.parts[4].animation==138) && _enemy_edge) {
                if (_i==4) ln3_movement_reverse_enemy(_s);
            } else {
                _p.x=_nx;
                if (_side==0?_nx<24:_nx>=240) ln3_movement_projectile_edge(_s,_data,_i);
            }
            if (_i==1) ln3_movement_actor_collision(_s,_data);
            ln3_movement_platform_edge(_s,_data,_side==0?4:8);
        }
    }
}

// LN2-style walking cadence: four smaller position updates per original pose.
// Original movement/animation routines retain their defaults for other actions.
function ln3_walk_tick(_g,_joy) {
    var _s=_g.state;
    if (!variable_struct_exists(_g,"walk_fraction")) {_g.walk_fraction=[0,0];_g.walk_direction=-1;}
    var _free=_s.player_action<6 && _s.player_action_flags<128 && _s.player_dead==0 && _s.player_health>0 &&
        _s.stun==0 && _s.input_block==0 && _s.climb_flags==0 && !is_struct(_g.pickup_assist) &&
        !_g.weapon_switch && (_joy&16)==0;
    if (!_free) {_g.walk_fraction=[0,0];_g.walk_direction=-1;return false;}
    var _old_action=_s.player_action,_old_mirror=_s.mirror;
    // Only plain walking/standing is polled here. Fire and weapon changes stay
    // on the original action clock, and cannot be consumed by this fast path.
    ln3_input_update(_s,_g.actions,_g.input,_joy,false);
    if (_s.player_action>=6) {_g.walk_fraction=[0,0];return false;}
    if (_joy!=_g.walk_direction) {_g.walk_fraction=[0,0];_g.walk_direction=_joy;}
    var _old_x=[],_old_y=[];
    for (var _i=0;_i<4;_i++) {_old_x[_i]=_s.parts[_i].x;_old_y[_i]=_s.parts[_i].y;}
    ln3_movement_setup(_s,_g.movement);
    if (_s.player_action>=2 && _s.player_action<=5 && _joy!=0) {
        var _dx=_s.parts[2].dx,_dy=_s.parts[2].dy;
        _g.walk_fraction[0]+=_dx/4;_g.walk_fraction[1]+=_dy/4;
        var _step_x=floor(_g.walk_fraction[0]),_step_y=floor(_g.walk_fraction[1]);
        _g.walk_fraction[0]-=_step_x;_g.walk_fraction[1]-=_step_y;
        for (var _i=1;_i<=2;_i++) {_s.parts[_i].dx=_step_x;_s.parts[_i].dy=_step_y;}
        ln3_movement(_s,_g.movement,2,1);
        ln3_collision_update(_s,_g.actions,_g.collision,_g.bounds,0);
        for (var _i=1;_i<=2;_i++) {_s.parts[_i].dx=_dx;_s.parts[_i].dy=_dy;}
        ln3_hazard_contacts(_s,_g.data);
        ln3_climb_enter(_s,_g.actions,_g.runtime_scene.climbs,_joy,_g.level);
    } else {_g.walk_fraction=[0,0];}
    // Keep the held head/weapon pose attached between animation updates.
    var _dx=_s.parts[1].x-_old_x[1],_dy=_s.parts[1].y-_old_y[1];
    _s.parts[0].x+=_dx;_s.parts[0].y+=_dy;
    if (_s.parts[3].animation!=114) {_s.parts[3].x+=_dx;_s.parts[3].y+=_dy;}
    if (_old_action!=_s.player_action || _old_mirror!=_s.mirror) {
        var _pose=json_parse(json_stringify(_s));ln3_animation_update(_pose,_g.animation);ln3_play_prepare_draw(_g,_pose);
    } else {
        var _pose=_g.display;
        for (var _i=0;_i<4;_i++) {
            _pose.draw_x[_i]+=_s.parts[_i].x-_old_x[_i];_pose.draw_y[_i]+=_s.parts[_i].y-_old_y[_i];
            _pose.parts[_i].x=_s.parts[_i].x;_pose.parts[_i].y=_s.parts[_i].y;
        }
        ln3_play_prepare_draw(_g,_pose);
    }
    return true;
}

function ln3_walk_checks() {
    for (var _level=1;_level<=5;_level++) {
        var _g=new LN3Play(_level),_s=_g.state;
        _g.bounds=[];_g.scene_record.exits=[];_g.runtime_scene.climbs=[];_s.enabled&=15;_s.enemy_dead=1;
        _s.player_action=255;ln3_action_set(_s,_g.actions,0);_s.player_action_flags=0;
        _s.player_dead=0;_s.player_health=44;_s.input_block=0;_s.stun=0;_s.climb_flags=0;_s.fire_mode=0;
        _s.player_x=100;_s.player_y=100;_s.parts[1].x=100;_s.parts[2].x=100;_s.parts[1].y=79;_s.parts[2].y=100;
        var _start=_s.parts[2].x;
        repeat(4) {
            var _before=_s.parts[2].x;ln_check(ln3_walk_tick(_g,8),"walking fast path available");
            ln_check(abs(_s.parts[2].x-_before)==1,"LN3 one source pixel per walking tick, level "+string(_level));
        }
        ln_check(abs(_s.parts[2].x-_start)==4,"LN3 original walking speed retained over four ticks");
        ln_check(_g.display.parts[2].y==_s.parts[2].y,"mask depth follows small walking steps");
        var _stop=_s.parts[2].x;ln3_walk_tick(_g,0);repeat(3) ln3_walk_tick(_g,0);
        ln_check(_s.parts[2].x==_stop,"release stops immediately without outstanding movement");
        _s.logic_wait=3;_stop=_s.parts[2].x;ln3_play_tick(_g,8);
        ln_check(abs(_s.parts[2].x-_stop)==1 && _s.logic_wait==2,"walking moves between original logic updates");
        _s.logic_wait=1;_stop=_s.parts[2].x;ln3_play_tick(_g,8);
        ln_check(abs(_s.parts[2].x-_stop)==1,"logic tick does not add a second walking step");
        var _cursor=_s.parts[1].cursor;ln3_walk_tick(_g,8);
        ln_check(_s.parts[1].cursor==_cursor,"walking position updates do not accelerate poses");
        var _before=_s.parts[2].x;ln_check(!ln3_walk_tick(_g,24) && _s.parts[2].x==_before,"fire stays on original action clock");
        _g.bounds=[[112,90,114,110,4]];repeat(20) ln3_walk_tick(_g,8);
        ln_check(_s.parts[2].x<=114,"walking respects solid boundary");
        _g.bounds=[[112,90,114,110,36,1]];_s.parts[1].x=108;_s.parts[2].x=108;_s.player_x=108;
        repeat(10) ln3_walk_tick(_g,8);
        ln_check(_s.stun!=0 || _s.input_block!=0,"small walking steps still trigger source drop boundaries");
    }
    show_debug_message("LN3_WALK_PASS: five-level small-step speed, stop response, action cadence, walls and drops");
}
