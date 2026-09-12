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
    ln3_wheel_tick(_g);
    ln3_hud_eye_tick(_g);
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
            if (_g.special_sequence==5) {
                _s.lives=max(0,_s.lives-1);_s.inventory[27]=_s.lives;
                _g.transition_phase=8;_s.death_wait=50;return;
            }
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
            if (_g.special_sequence==5) {
                _g.ordinary_death=false;
                if (_s.lives<=0) {_g.game_over=true;_g.transition_phase=11;return;}
                _s.player_health=44;_s.inventory[26]=44;_s.player_action=255;_s.climb_flags=0;_s.climb_counter=0;
                _s.shared_colour1=0;_s.shared_colour2=9;
                for (var _part=0;_part<4;_part++) _s.parts[_part].colour=_g.data.initial.parts[_part].colour;
                ln3_play_enter(_g,_g.last_entry);
            } else if (_g.special_sequence==3) {
                _s.player_health=44;_s.inventory[26]=44;_s.shared_colour1=0;_s.shared_colour2=9;
                _s.climb_flags=0;_s.climb_counter=0;_s.player_action=255;
                ln3_play_enter(_g,ln3_room_record(_g.world.rooms,12).special_entry);
            } else {
                // The source requests the separately loaded ENDING program here.
                _g.transition_phase=11;_g.ending_requested=true;_g.ending=new LN3Ending();ln3_presentation_music(_g,false);
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
        // $70d7 erases rows 0,1 then 2,3, continuously from the top.
        // Reversing each eight-row block exposes flickering strips below the blade.
        draw_rectangle(0,0,240,_g.transition_wipe,false);
        draw_set_colour(c_white);
    }
    if (_phase>=7) {
        draw_clear(c_black);
        if (_phase!=10) {
            var _frame=_g.special_sequence==4?2:(_phase==7?0:1);
            if (_g.special_sequence==5) {
                var _lives=_g.state.lives;
                var _text=_lives==0?"GAME OVER":string(_lives)+(_lives==1?" LIFE REMAINING":" LIVES REMAINING");
                var _left=floor((240-string_length(_text)*8)/2);
                for (var _letter=1;_letter<=string_length(_text);_letter++)
                    draw_sprite(spr_ln3_lives_font,ord(string_char_at(_text,_letter))-32,_left+(_letter-1)*8,64);
            } else draw_sprite(asset_get_index(_g.transition.text_sprite),_frame,0,0);
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

// Original LN3 $6ae3: nine wheel stages, four PAL ticks between changes.
function ln3_wheel_tick(_g) {
    if (!variable_struct_exists(_g,"hud_wheel_wait")) _g.hud_wheel_wait=0;
    if (_g.hud_wheel_wait>0) _g.hud_wheel_wait--;
    var _s=_g.state;
    if (_s.weapon_fx_request!=0 && _g.hud_wheel_wait>0) return;
    if (_s.weapon_fx_request!=0) {
        _g.hud_wheel_wait=4;
        _s.weapon_fx_state++;
        if (_s.weapon_fx_state>=9) {_s.weapon_fx_state=0;_s.weapon_fx_request=0;}
    }
    if (_s.weapon_fx_state==5) _s.weapon_fx_request=_s.inventory[clamp(_s.enemy_pending_weapon,0,24)];
}
function ln3_status_item(_g) {
    var _s=_g.state;
    if (_s.weapon_notice_timer>0) {
        if (_g.found_item>=0) return _g.found_item;
        return _s.notice_icon>=0 && _s.notice_icon<25?_s.notice_icon:-1;
    }
    var _item=_s.selected_item;
    if (_item<4 || _item>=24) return -1;
    return _s.inventory[_item]>0 && _s.inventory[_item]<128?_item:-1;
}
function ln3_status_sprite(_sprite,_frame,_x,_y) {
    draw_sprite_ext(_sprite,_frame,160+_x*3,84+_y*3,3,3,0,c_white,1);
}
function ln3_status_draw(_g) {
    var _s=_g.state;draw_set_colour(c_white);
    ln3_status_sprite(spr_ln3_hud_panel,0,0,0);
    ln3_status_sprite(spr_ln3_hud_player,clamp(round(_g.hud_player_health),0,44),8,152);
    ln3_status_sprite(spr_ln3_hud_enemy,clamp(round(_g.hud_enemy_health),0,44),56,152);
    if (_g.hud_eye_left>=0) ln3_status_sprite(spr_ln3_hud_eye_flash,_g.hud_eye_left,248,176);
    if (_g.hud_eye_right>=0) ln3_status_sprite(spr_ln3_hud_eye_flash,4+_g.hud_eye_right,288,176);
    ln3_status_sprite(spr_ln3_hud_bushido,clamp(round(_g.hud_honour),0,40),112,176);
    for(var _i=0;_i<6;_i++) ln3_status_sprite(spr_ln3_hud_digits,clamp(_s.score_digits[_i]&15,0,9),128+_i*8,160);
    var _wheel=clamp(_s.enemy_pending_weapon,0,24),_phase=(_s.weapon_fx_state+8) mod 9;
    ln3_status_sprite(spr_ln3_hud_wheel,_wheel*9+_phase,256,0);
    ln3_status_sprite(spr_ln3_hud_notice,(_s.weapon_notice_timer>0 && _g.found_item>=0)?1:0,256,56);
    draw_set_colour(c_black);draw_rectangle(160+264*3,84+72*3,160+296*3,84+88*3,false);draw_set_colour(c_white);
    var _item=ln3_status_item(_g);
    if (_item>=0 && _item<25) ln3_status_sprite(spr_ln3_hud_items,_item,264,72);
}

function ln3_status_checks() {
    ln3_consumable_checks();
    ln3_reverse_roll_checks();
    ln3_followup_checks();
    var _v=ln3_data_read("verification/ln3_hud_vectors.json").vectors;
    for(var _i=0;_i<array_length(_v);_i++) {
        var _r=_v[_i],_fixture_state={weapon_fx_state:_r.phase,weapon_fx_request:_r.request,enemy_pending_weapon:4,inventory:array_create(30,0)};
        _fixture_state.inventory[4]=_r.owned;var _fixture={state:_fixture_state,hud_wheel_wait:_r.wait};ln3_wheel_tick(_fixture);
        ln_check(_fixture_state.weapon_fx_state==_r.expected[0] && _fixture_state.weapon_fx_request==_r.expected[1] && _fixture.hud_wheel_wait==_r.expected[2],"LN3 original prayer wheel vector "+string(_i));
    }
    for(var _level=1;_level<=5;_level++) {
        var _g=new LN3Play(_level),_s=_g.state;
        _s.score_digits=[49,50,51,52,53,54];_s.player_health=22;_s.enemy_health=33;_s.honour=20;
        repeat(100) ln3_hud_tick(_g);
        ln_check(_g.hud_player_health==22 && _g.hud_enemy_health==33 && _g.hud_honour==20,"LN3 health and Bushido converge "+string(_level));
        _s.enemy_flash=3;repeat(40) ln3_hud_eye_tick(_g);
        ln_check(_s.enemy_flash==0 && _g.hud_eye_left==3,"LN3 original portrait flash completes");
        // A real level record is passed through the original pickup handler.
        var _picked=false;
        for(var _room=0;_room<array_length(_g.items.rooms) && !_picked;_room++) {
            var _records=_g.items.rooms[_room].items;
            for(var _j=0;_j<array_length(_records) && !_picked;_j++) {
                var _record=_records[_j],_id=_record[0];if(_id==25 || _id==6 || _id==12) continue;
                _s.inventory[_id]=0;_s.room_id=_g.items.rooms[_room].id;_s.player_action=26;_s.parts[1].cursor=3;
                _s.parts[2].x=_record[1];_s.parts[2].y=_record[3];_s.ammo_pile=1;
                var _found=ln3_items_update(_s,_g.items,[_record]);
                if (_found>=0) {_g.found_item=_found;_picked=true;ln_check(ln3_status_item(_g)==_found,"LN3 pickup icon "+string(_level));}
            }
        }
        ln_check(_picked,"LN3 pickup fixture reached "+string(_level));
        _s.inventory[4]=1;_s.selected_item=4;_s.weapon_notice_timer=0;
        ln_check(ln3_status_item(_g)==4,"LN3 selected item shown");_s.inventory[4]=128;
        ln_check(ln3_status_item(_g)==-1,"LN3 consumed item cleared");
        _g.found_item=-1;_s.weapon_notice_timer=100;_s.notice_icon=2;
        ln_check(ln3_status_item(_g)==2,"LN3 weapon change icon");
        _s.weapon_notice_timer=0;_s.inventory[4]=1;_s.weapon_fx_state=5;_s.enemy_pending_weapon=4;
        var _restored=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));
        ln_check(_restored.state.score_digits[5]==_s.score_digits[5] && _restored.state.honour==_s.honour && ln3_status_item(_restored)==4 && _restored.state.weapon_fx_state==5,"LN3 HUD save state");
        // Draw representative live values using the native renderer.
        var _surface=surface_create(1280,800);surface_set_target(_surface);ln3_play_draw(_g);surface_reset_target();
        surface_save(_surface,"ln3-hud-level"+string(_level)+".png");surface_free(_surface);
        _g.game_over=true;_s.player_health=0;var _ticks_before=_g.logic_ticks;
        repeat(100) ln3_play_tick(_g,0);
        ln_check(_g.hud_player_health==0 && _g.logic_ticks==_ticks_before,"LN3 game-over meter settles without advancing gameplay");
        ln3_ending_free(_g);ln3_ending_free(_restored);
        if(surface_exists(_g.stage_surface)) surface_free(_g.stage_surface);
        if(surface_exists(_g.part_surface)) surface_free(_g.part_surface);
    }
    show_debug_message("LN3_HUD_PASS: "+string(array_length(_v))+" original wheel vectors, five-level pickups, live meters, weapon/item selection, consumed items and saves; manual playthrough pending.");
}

// Original $7b2a portrait flash, requested by the existing combat logic.
function ln3_hud_eye_tick(_g) {
    if (_g.hud_eye_wait>0) _g.hud_eye_wait--;
    if (_g.hud_eye_wait!=0 || _g.state.enemy_flash==0) return;
    _g.hud_eye_wait=10;
    if ((_g.state.enemy_flash&1)!=0) _g.hud_eye_left=_g.hud_eye_phase;
    else if ((_g.state.enemy_flash&2)!=0) _g.hud_eye_right=_g.hud_eye_phase;
    _g.hud_eye_phase=(_g.hud_eye_phase+1)&3;
    if (_g.hud_eye_phase==0) _g.state.enemy_flash=0;
}

function ln3_followup_checks() {
    for(var _level=1;_level<=5;_level++) {
        var _g=new LN3Play(_level),_s=_g.state;
        _s.parts[2].colour=10;_s.player_dead=1;_s.death_wait=1;_s.logic_wait=0;
        ln3_play_tick(_g,0);
        ln_check(_g.special_sequence==5,"LN3 ordinary death starts sword transition");
        repeat(650) if (_g.special_sequence==5 && !_g.game_over) ln3_play_tick(_g,0);
        for(var _part=0;_part<4;_part++) ln_check(_s.parts[_part].colour==_g.data.initial.parts[_part].colour,"LN3 respawn source colours "+string(_level));
        _s.room_id=0;_s.enemy_health=44;_s.enemy_dead=0;_s.player_weapon=0;
        ln3_combat_damage_enemy(_s,_g.combat);ln_check(_s.enemy_health>0,"LN3 normal damage remains default");
        _s.enemy_health=44;_s.one_hit_kills=true;_g.one_hit_kills=true;
        ln3_combat_damage_enemy(_s,_g.combat);ln_check(_s.enemy_health==0 && _s.enemy_dead!=0,"LN3 F8 normal defeat handling");
        _s.room_id=13;_s.enemy_health=44;_s.enemy_dead=0;_s.boss_honour=0;_s.level_requested=false;
        ln3_combat_damage_enemy(_s,_g.combat);ln_check(_s.enemy_health==0 && _s.level_requested,"LN3 F8 boss defeat request");
        _s.room_id=_g.room_id;
        var _saved=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));
        ln_check(_saved.one_hit_kills,"LN3 F8 save persistence");
        if (_level<5) {ln3_level_load(_g,_level+1);ln_check(_g.one_hit_kills,"LN3 F8 level persistence");}
    }
    var _ln1=new LN1Play(1),_found=false;
    _ln1.player.combat_state=20;_ln1.player.weapon=0;_ln1.player.x=100;_ln1.player.y=100;
    _ln1.enemy.active=128;_ln1.enemy.combat_state=0;_ln1.enemy.wounds=0;
    for(var _x=80;_x<121 && !_found;_x++) for(var _y=80;_y<121 && !_found;_y++) {
        _ln1.enemy.x=_x;_ln1.enemy.y=_y;
        _found=ln1_combat_hit(_ln1,false)>=0;
    }
    ln_check(_found,"LN1 damaging strike reached");
    ln1_combat_event(_ln1,14,false);ln_check(_ln1.enemy.wounds<32,"LN1 normal damage remains default");
    _ln1.enemy.combat_state=0;_ln1.enemy.wounds=0;_ln1.one_hit_kills=true;
    ln1_combat_event(_ln1,14,false);ln_check(_ln1.enemy.wounds==32 && _ln1.room_wounds[_ln1.room_id]==32,"LN1 F8 defeat persists in room");
    ln1_level_load(_ln1,2);ln_check(_ln1.one_hit_kills,"LN1 F8 level persistence");
    var _loaded=ln_save_restore(json_parse(json_stringify(ln_save_capture(_ln1))));ln_check(_loaded.one_hit_kills,"LN1 F8 save persistence");
    show_debug_message("LN3_FOLLOWUP_PASS: five-level respawn colours, LN1/LN3 one-hit defeats and preference persistence");
}
