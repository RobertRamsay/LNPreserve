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

function ln3_movement(_s,_data) {
    for (var _i=7;_i>=0;_i--) {
        var _p=_s.parts[_i];_p.old_x=_p.x;_p.old_y=_p.y;
        if (_p.move_mode<128 || _p.direction==0) continue;
        if (_p.direction&1) {
            _p.y=(_p.y-_p.dy)&255;
            if (_i==2) _s.player_y=(_s.player_y-_p.dy)&255;
            if (_i==6) _s.enemy_y=(_s.enemy_y-_p.dy)&255;
        }
        if (_p.direction&2) {
            _p.y=(_p.y+_p.dy)&255;
            if (_i==2) _s.player_y=(_s.player_y+_p.dy)&255;
            if (_i==6) _s.enemy_y=(_s.enemy_y+_p.dy)&255;
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
        }
    }
}
