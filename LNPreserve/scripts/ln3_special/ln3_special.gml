function ln3_earth_ritual(_s) {
    if (_s.special_wait!=0 || _s.special_scene_phase==0 || _s.special_scene_phase>=2) return 0;
    if (_s.parts[4].move_mode!=141) return 1;
    if (_s.parts[4].y>=136) {
        for (var _i=4;_i<7;_i++) _s.parts[_i].move_mode=0;
        _s.special_scene_phase=(_s.special_scene_phase+1)&255;
    }
    return 0;
}

function ln3_wind_carrier(_s,_data) {
    if (_s.room_id!=4 && _s.room_id!=6) return 0;
    var _side=_s.room_id==6?1:0;
    if ((_side==0?_s.carrier_left:_s.carrier_right)!=0 || (_s.mirror&6)==0) return 0;
    if (_s.player_action!=26 || _s.parts[1].cursor!=3 || _s.inventory[0]==0) return 0;
    var _p=_s.parts[2];
    if (_p.x<_data.carrier_x[_side] || _p.x>_data.carrier_x[_side]+16 || _p.y<_data.carrier_y[_side] || _p.y>_data.carrier_y[_side]+16) return 0;
    if (_side==0) _s.carrier_left=(_s.carrier_left+1)&255;else _s.carrier_right=(_s.carrier_right+1)&255;
    for (var _i=4;_i<8;_i++) _s.parts[_i].move_mode=_data.carrier_modes[_side];
    _s.carrier_state=_side+1;return 0;
}

function ln3_wind_damage(_s) {
    if (_s.room_id!=3 || (_s.wind_damage_wait|_s.player_dead|_s.stun)!=0 || _s.climb_flags==0 || _s.parts[2].x<192) return 0;
    _s.wind_damage_wait=5;
    if (_s.player_health!=0) {
        _s.player_health=(_s.player_health-1)&255;_s.inventory[26]=_s.player_health;if (_s.player_health!=0) return 0;
    }
    _s.input_block=0;_s.trap_flags=0;_s.climb_flags=0;_s.trap_count=4;_s.stun=(_s.stun+1)&255;return 0;
}

function ln3_water_bell(_s) {
    var _p=_s.parts[2];
    if (_s.room_id!=3 || _s.water_gate!=0 || _p.x<128 || _p.x>=144 || _p.y<80 || _p.y>=96) return 0;
    if (_s.player_action!=26 || _s.parts[1].cursor!=4 || _s.selected_item!=5) return 0;
    _s.water_gate=(_s.water_gate+1)&255;return 2;
}

function ln3_fire_cauldron_pose(_s) {
    var _p=_s.parts[2];return _p.x>=88 && _p.x<=104 && _p.y>=96 && _p.y<=112 && (_s.mirror&6)==0 && _s.player_action==27 && _s.parts[1].cursor==3;
}

function ln3_fire_ignite(_s) {
    if (_s.room_id==10 && _s.fire_cauldron==0 && _s.selected_item==23 && ln3_fire_cauldron_pose(_s)) _s.fire_cauldron=(_s.fire_cauldron+1)&255;
    return 0;
}

function ln3_fire_brew(_s,_items) {
    if (_s.room_id!=10 || _s.fire_cauldron==0 || _s.inventory[18]!=0 || _s.selected_item!=19 || _s.inventory[11]==0 || _s.inventory[16]==0 || !ln3_fire_cauldron_pose(_s)) return 0;
    _s.inventory[11]=128;_s.inventory[16]=128;_s.inventory[19]=128;_s.inventory[18]=(_s.inventory[18]+1)&255;
    ln3_item_notice(_s,_items,18);return 0;
}

function ln3_fire_poison(_s) {
    if (_s.room_id!=2 || _s.selected_item==22 || (_s.player_dead|_s.fire_damage_wait)!=0) return 0;
    _s.fire_damage_wait=2;
    if (_s.player_health!=0) {_s.player_health=(_s.player_health-1)&255;_s.inventory[26]=_s.player_health;if (_s.player_health!=0) return 0;}
    _s.death_wait=50;_s.player_dead=(_s.player_dead+1)&255;return 0;
}

function ln3_fire_gate(_s) {
    var _p=_s.parts[2];
    if (_s.room_id!=7 || _s.fire_gate!=0 || _p.x<204 || _p.x>=220 || _p.y<104 || _p.y>=120 || _s.player_action!=24 || (_s.mirror&6)==0 || _s.selected_item!=18) return 0;
    _s.fire_gate=(_s.fire_gate+1)&255;return 5;
}

function ln3_void_bolt_spawn(_s) {
    if (_s.room_id!=11 || _s.selected_item!=6 || (_s.enabled&128)!=0) return 0;
    var _p=_s.parts[7];_p.cursor=0;_s.bolt_reflected=0;
    if (_s.scene_cursor!=3) return 0;
    _p.animation=114;_p.colour=1;_s.enabled|=128;_p.x=86;_p.y=86;
    var _dy=_s.parts[1].y-90;_s.bolt_vy=(sign(_dy)*min(abs(_dy),15))&255;
    _s.bolt_vx=_p.x<_s.parts[2].x?12:244;return 0;
}

function ln3_void_bolt_move(_s) {
    var _p=_s.parts[7];if ((_s.enabled&128)==0 || _p.animation!=114 || _s.room_id!=11) return 0;
    if (_s.bolt_reflected==0) {
        _p.y=(_p.y+_s.bolt_vy)&255;
        if (_p.y>=176) {_s.enabled&=127;return 0;}
        _p.x=(_p.x+_s.bolt_vx)&255;if (_p.x>=240) _s.enabled&=127;return 0;
    }
    _p.y=(_p.y-_s.bolt_vy)&255;_p.x=(_p.x-_s.bolt_vx)&255;if (_p.x>=86) return 0;
    _s.bolt_flash=8;_s.bolt_flash_wait=8;_s.enabled&=15;_s.bolt_energy=(_s.bolt_energy-_s.honour)&65535;
    return _s.bolt_energy>=32768?3:0;
}

function ln3_void_victory(_s) {return _s.room_id==12 && _s.enemy_dead!=0?4:0;}

function ln3_void_flash_tick(_s) {
    if (_s.bolt_flash==0) return;
    if (_s.bolt_flash_wait==0) _s.bolt_flash=0;else _s.bolt_flash_wait--;
}

function ln3_play_special(_g) {
    var _s=_g.state,_event=0;
    switch (_g.level) {
        case 1:_event=ln3_earth_ritual(_s);break;
        case 2:ln3_wind_carrier(_s,_g.special);ln3_wind_damage(_s);break;
        case 3:_event=ln3_water_bell(_s);break;
        case 4:
            ln3_fire_gate(_s);ln3_fire_ignite(_s);
            var _before=_s.inventory[18];ln3_fire_brew(_s,_g.items);
            if (_s.inventory[18]!=_before) _g.found_item=18;
            ln3_fire_poison(_s);break;
    }
    if (_event!=0) ln3_special_start(_g,_event);
}

function ln3_special_start(_g,_event) {
    _g.special_sequence=_event;_g.special_step=0;
    if (_event==1 || _event==2) ln3_special_fade_step(_g);
    else {
        _g.special_request=_event;_g.state.death_wait=50;_g.transition_phase=3;_g.transition_mode=0;
        if (_event==4) {
            _g.state.player_health=44;_g.state.inventory[26]=44;_g.state.enemy_health=44;_g.transition_phase=1;
        }
    }
}

function ln3_special_fade_step(_g) {
    var _colour=_g.special.fade_colours[8-(_g.special_step mod 9)]&15;
    for (var _i=0;_i<(_g.special_sequence==1?3:8);_i++) _g.special_colours[_i]=_colour;
    _g.state.death_wait=_g.special_sequence==1?3:5;
}

function ln3_special_sequence_tick(_g) {
    if (_g.special_sequence>=3) {ln3_transition_tick(_g);return;}
    if (_g.state.death_wait!=0) return;
    if (_g.special_sequence==1 || _g.special_sequence==2) {
        _g.special_step++;
        if (_g.special_step<(_g.special_sequence==1?18:9)) {ln3_special_fade_step(_g);return;}
        if (_g.special_sequence==1) for (var _i=4;_i<7;_i++) _g.state.parts[_i].move_mode=141;
        else _g.state.inventory[5]=255;
        _g.special_sequence=0;
        // The next original sprite update restores the actor colour registers.
    }
}

function ln3_hud_tick(_g) {
    if (_g.hud_wait>0) _g.hud_wait--;
    if (_g.hud_wait==0) {
        _g.hud_player_health+=sign(_g.state.player_health-_g.hud_player_health);
        _g.hud_enemy_health+=sign(_g.state.enemy_health-_g.hud_enemy_health);_g.hud_wait=2;
    }
    _g.hud_honour+=sign(_g.state.honour-_g.hud_honour);
}

function ln3_transition_motion(_g) {
    if (_g.transition_mode==1) {
        for (var _i=0;_i<8;_i++) _g.transition_y[_i]=(_g.transition_y[_i]-2)&255;
    } else if (_g.transition_mode==2) {
        // The original IRQ tests only the leading sprite before moving all eight.
        if (_g.transition_y[7]>=176) {_g.transition_signal=15;return;}
        for (var _i=0;_i<8;_i++) _g.transition_y[_i]=(_g.transition_y[_i]+2)&255;
        _g.transition_signal=255;
    }
}

function ln3_transition_tick(_g) {
    var _s=_g.state;ln3_transition_motion(_g);
    switch (_g.transition_phase) {
        case 1:
            if (_g.hud_player_health!=44 || _g.hud_enemy_health!=44) return;
            _s.honour=40;_s.inventory[25]=40;_g.transition_phase=2;return;
        case 2:
            if (_g.hud_honour!=40) return;
            _s.death_wait=50;_g.transition_phase=3;return;
        case 3:
            if (_s.death_wait!=0 || _s.bolt_flash!=0) return;
            _g.transition_phase=4;_g.special_step=0;ln3_transition_fade(_g);return;
        case 4:
            if (_s.death_wait!=0) return;
            _g.special_step++;
            if (_g.special_step<9) {ln3_transition_fade(_g);return;}
            _g.transition_y=[];
            for (var _i=0;_i<8;_i++) _g.transition_y[_i]=_g.transition.parts[_i].y;
            _g.transition_mode=2;_g.transition_phase=5;return;
        case 5:
            if (_g.transition_y[7]<33) return;
            _g.transition_phase=6;_g.transition_wipe=2;return;
        case 6:
            _g.transition_wipe+=2;if (_g.transition_wipe<144) return;
            _g.transition_phase=_g.special_sequence==3?7:8;_s.death_wait=_g.special_sequence==3?250:100;return;
        case 7:
            if (_s.death_wait!=0) return;
            _g.transition_phase=8;_s.death_wait=100;return;
        case 8:
            if (_s.death_wait!=0) return;
            _g.transition_phase=9;_g.transition_mode=1;return;
        case 9:
            if (_g.transition_y[7]>114) return;
            _g.transition_phase=10;return;
        case 10:
            if (_g.transition_y[0]!=0) return;
            _g.transition_mode=0;
            if (_g.special_sequence==3) {
                _s.player_health=44;_s.inventory[26]=44;_s.shared_colour1=0;_s.shared_colour2=9;
                _s.climb_flags=0;_s.climb_counter=0;_s.player_action=255;
                ln3_play_enter(_g,ln3_room_record(_g.world.rooms,12).special_entry);
            } else {
                // The source requests the separately loaded ENDING program here.
                _g.transition_phase=11;_g.ending_requested=true;_g.ending=new LN3Ending();
            }
            return;
    }
}

function ln3_transition_fade(_g) {
    var _colour=_g.transition.fade_colours[8-_g.special_step]&15;
    for (var _i=0;_i<8;_i++) _g.special_colours[_i]=_colour;
    _g.state.death_wait=3;
}

function ln3_transition_draw(_g) {
    if (_g.special_sequence<3 || _g.transition_phase<5) return;
    var _phase=_g.transition_phase;
    if (_phase==6) {
        draw_set_colour(c_black);
        for (var _pair=0;_pair<_g.transition_wipe div 2;_pair++) {
            var _row=(_pair div 4)*8+6-(_pair mod 4)*2;draw_rectangle(0,_row,240,_row+2,false);
        }
        draw_set_colour(c_white);
    }
    if (_phase>=7) {
        draw_clear(c_black);
        if (_phase!=10) {
            var _frame=_g.special_sequence==4?2:(_phase==7?0:1);
            draw_sprite(asset_get_index(_g.transition.text_sprite),_frame,0,0);
        }
    }
    if (_phase<11) for (var _i=7;_i>=0;_i--) {
        var _p=_g.transition.parts[_i];
        draw_sprite_ext(asset_get_index(_g.transition.part_sprite),_p.frame,_p.x-24,_g.transition_y[_i]-50,_p.scale_x,_p.scale_y,0,c_white,1);
    }
}

function ln3_mechanism_draw(_g) {
    var _s=_g.state,_frame=-1;
    if (_g.level==4 && _g.room_id==7 && _s.fire_gate!=0) _frame=_g.mechanisms.gate;
    if (_g.level==5 && _g.room_id==11 && _s.bolt_flash!=0 && _s.bolt_flash_wait<8) {
        var _key=string(_g.scenery_frame);
        if (variable_struct_exists(_g.mechanisms.bolt,_key)) _frame=variable_struct_get(_g.mechanisms.bolt,_key)[_s.bolt_flash_wait];
    }
    if (_frame>=0) draw_sprite(asset_get_index(_g.mechanisms.sprite),_frame,0,0);
}
