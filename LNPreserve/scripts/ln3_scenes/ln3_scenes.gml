/// Native translations of LN3's room reset, encounters and exit windows.
function ln3_scene_reset(_s) {
    if (_s.weapon_fx_state!=0) {
        if (_s.weapon_fx_state<5) _s.weapon_fx_state=9-_s.weapon_fx_state;
        _s.weapon_fx_request=(_s.weapon_fx_request+1)&255;
    }
    _s.enabled=6;_s.waterline=173;_s.last_boundary=255;_s.parts[0].animation=255;
    _s.enemy_throw_wait=1000;_s.near_enemy=0;_s.player_dead=0;_s.stun=0;
    _s.trap_contacts=0;_s.input_block=0;_s.enemy_weapon=0;_s.joy=0;_s.scene_cursor=0;
    _s.enemy_dodge_direction=0;_s.enemy_dodge_wait=0;_s.enemy_turn_wait=0;
    _s.drawn_mask=0;_s.parts[7].animation=0;
}

function ln3_special_enter(_s,_data) {
    var _level=_data.level,_r=_s.room_id,_d=_data.special,_count=0;
    if (_level==1 && _r==8) {
        _count=3;
        for (var _i=0;_i<_count;_i++) {
            var _p=_s.parts[4+_i];_p.animation=_d.animations[_i];_p.cursor=0;_p.move_mode=0;_p.colour=_d.colours[_i];
            _p.x=_s.special_scene_phase==0?128:101;_p.y=_s.special_scene_phase==0?_d.y_before[_i]:_d.y_after[_i];
        }
        _s.shared_colour1=15;_s.shared_colour2=0;_s.expand_y=64;_s.multicolour=64;_s.expand_x=112;
        _s.enabled|=112;_s.enemy_costume=3;
    } else if (_level==2 && _r>=4 && _r<=6) {
        var _mode=0,_x=0,_y=0;
        if (_r==4) { _mode=_s.carrier_left==0?0:141;_x=88;_y=128;if (_s.carrier_left!=0) _s.carrier_state=1; }
        if (_r==6) { _mode=_s.carrier_right==0?0:143;_x=80;_y=128;if (_s.carrier_right!=0) _s.carrier_state=2; }
        if (_r==5) {
            if (_s.carrier_state==0) return;
            var _index=_s.carrier_state-1;_mode=_d.modes[_index];_x=_d.x[_index];_y=_d.y[_index];
        }
        for (var _i=0;_i<4;_i++) {
            var _p=_s.parts[4+_i];_p.animation=_d.animations[_i];_p.cursor=0;_p.move_mode=_mode;
            _p.colour=_d.colours[_i];_p.x=_x;_p.y=_y;
        }
        _s.shared_colour1=3;_s.shared_colour2=9;_s.enabled|=240;_s.mirror&=15;_s.enemy_costume=3;
    } else if (_level==3 && _r==6 && _s.water_gate==0) {
        for (var _i=0;_i<4;_i++) {
            var _p=_s.parts[4+_i];_p.animation=_d.animations[_i];_p.cursor=0;_p.move_mode=0;
            _p.colour=_d.colours[_i];_p.x=_d.x[_i];_p.y=_d.y[_i];
        }
        _s.expand_x=16;_s.expand_y=224;_s.enabled|=240;_s.enemy_costume=3;
    } else if (_level==4 && _r==3) {
        for (var _i=0;_i<2;_i++) {
            var _p=_s.parts[4+_i];_p.animation=_d.animations[_i];_p.cursor=0;_p.move_mode=0;
            _p.colour=7;_p.x=194;_p.y=_d.y[_i];
        }
        _s.enabled|=48;_s.enemy_costume=3;
    }
}

function ln3_enemy_enter(_s,_actions,_data,_record) {
    ln3_special_enter(_s,_data);_s.patrol_index=0;_s.patrol_remaining=0;
    var _r=_record.enemy;if (array_length(_r)==0) return;
    if (_s.enemy_dead==0) {
        _s.enemy_x=_r[0];_s.parts[5].x=_r[0];_s.parts[6].x=_r[0];
        _s.enemy_y=_r[1];_s.parts[6].y=_r[1];_s.parts[5].y=(_r[1]-21)&255;
        _s.mirror=(_s.mirror&159)|(_r[2]&96);
    }
    _s.enemy_costume=_r[2]&15;_s.enemy_behavior=_r[3];
    _s.parts[4].colour=_r[4]&15;_s.parts[6].colour=_r[4]&15;_s.parts[5].colour=_r[4]>>4;
    _s.enabled|=96;_s.multicolour=0;_s.expand_x=0;_s.expand_y=0;_s.enemy_action=0;
    ln3_action_set(_s,_actions,_s.enemy_dead==0?_r[5]:59,true);
    if (_s.enemy_dead!=0) {_s.parts[4].cursor=2;_s.parts[6].cursor=2;}
}

function ln3_exit_matches(_s,_raw) {
    var _flag=_raw[0],_p=_s.parts[2];
    if ((_flag&_p.direction&15)==0) return false;
    var _index=1;
    if (_flag<128 && (_flag&12)!=0) {
        if (_flag&4) {if (_p.x>16) return false;}
        else if (_p.x<244) return false;
    } else {
        if (_p.x<_raw[1] || _p.x>_raw[2]) return false;_index=3;
    }
    return _p.y>=_raw[_index] && _p.y<=_raw[_index+1];
}

function ln3_hazard_tick(_s,_actions,_data) {
    if (_s.stun==0 || _s.input_block!=0 || _s.player_action_flags>=128) return;
    var _action=array_contains(_data.hazard_kneel_actions,_s.player_action)?36:35;
    if (_action!=_s.player_action) ln3_action_set(_s,_actions,_action);
    _s.trap_count=(_s.trap_count-1)&255;if (_s.trap_count<128) return;
    if (_s.trap_flags<128 || _data.level==4) {
        _s.player_dead=(_s.player_dead+1)&255;_s.death_wait=0;
        if (_s.trap_flags>=128) ln3_action_set(_s,_actions,20);
    } else _s.input_block=(_s.input_block+1)&255;
}

function ln3_hazard_contacts(_s,_data) {
    var _v=_s.trap_contacts|_s.input_block;
    if (_v==0 || _s.player_action==28 || _s.player_action==29) return;
    if ((_v&1)==0) {_s.trap_contacts=0;_s.last_boundary=255;return;}
    if (_data.level!=2 || _s.room_id!=5) {_s.stun=1;return;}
    if (_s.carrier_state!=0) {
        var _dx=_s.parts[2].x-_s.parts[4].x,_dy=_s.parts[4].y-_s.parts[2].y;
        if (abs(_dx)<_data.special.contact_widths[_dx<0?1:0] && _dy>=5 && _dy<12) return;
    }
    _s.input_block=(_s.input_block+1)&255;
}

function ln3_climb_enter(_s,_actions,_records,_raw_joy,_level) {
    if ((_s.climb_flags|_s.stun)!=0 || _s.player_action>=6) return;
    if (_level==1 && _s.selected_item!=17) return;
    if (_level==4 && _s.selected_item!=15) return;
    if (_level==2 && _s.room_id==3 && _s.parts[2].x<192 && _s.selected_item!=20) return;
    var _p=_s.parts[2];
    for (var _i=0;_i<array_length(_records);_i++) {
        var _r=_records[_i];
        if (_p.x<_r[0] || _p.x>=_r[1] || _p.y<_r[2] || _p.y>=_r[3]) continue;
        _s.climb_start=_p.y;_s.joy=_raw_joy&15;
        if (((_s.joy^_r[4])&15)!=0) continue;
        _s.climb_request=_r[4];_s.mirror=(_s.mirror&249)|((_r[4]&128)?6:0);
        var _action=(_r[4]&1)?30:32;_s.climb_goal=_r[5];
        if (_action==_s.player_action) return;
        if (_level==1 && (_r[4]&2)!=0 && _s.climb_counter==0) return;
        _s.climb_flags=_r[4];_p.x=_r[6];_s.parts[1].x=_r[6];_p.y=_r[7];_s.parts[1].y=(_r[7]-21)&255;
        _s.climb_end_x=_r[8];_s.climb_end_y=_r[9];_s.climb_return_x=_r[10];_s.climb_return_y=_r[11];
        if (_r[4]&1) _s.climb_counter=(_s.climb_counter+1)&255;
        ln3_action_set(_s,_actions,_action);return;
    }
}

function ln3_fall_tick(_s,_actions,_data) {
    if (_s.input_block==0 || _data.level==1) return;
    var _action=array_contains(_data.hazard_kneel_actions,_s.player_action)?38:37;
    if (_action==_s.player_action) {
        _s.fall_count=(_s.fall_count-1)&255;
        if (_s.fall_count>=128) {_s.player_dead=(_s.player_dead+1)&255;if (_s.player_dead!=0) return;}
        _s.parts[2].y=(_s.parts[2].y+10)&255;_s.parts[3].y=_s.parts[2].y;return;
    }
    ln3_action_set(_s,_actions,_action);_s.fall_count=3;
    _s.parts[2].animation=_s.parts[0].animation;_s.parts[3].animation=_s.parts[1].animation;
    _s.parts[0].animation=115;_s.parts[1].animation=115;
    _s.parts[0].colour=_data.level==4?7:1;_s.parts[1].colour=_s.parts[0].colour;
    _s.parts[2].colour=10;_s.parts[3].colour=0;
    for (var _i=0;_i<4;_i++) _s.parts[_i].cursor=0;
    _s.mirror&=243;_s.mirror|=(_s.mirror<<2)&12;
    var _x=_s.parts[1].x;_s.parts[0].x=_x;_s.parts[2].x=_x;_s.parts[3].x=_x;
    var _sum=_s.parts[1].y+8;_s.parts[2].y=_sum&255;_s.parts[3].y=_sum&255;
    _sum=(_sum&255)+10+(_sum>255);_s.waterline=_sum&255;
    _sum=(_sum&255)+2+(_sum>255);_s.parts[0].y=_sum&255;
    _sum=(_sum&255)+8+(_sum>255);_s.parts[1].y=_sum&255;
    _s.enabled=(_s.enabled&251)|11;if (_action==37) _s.enabled|=4;
    if (_s.waterline>=173) _s.waterline=173;
}
