function ln3_item_proximity(_s,_record) {
    var _item=_record[0];if (_s.weapon_fx_request!=0 || _item==25) return;
    var _dx=abs(_record[1]-_s.parts[2].x),_dy=abs(_record[3]-_s.parts[2].y);
    if (_dx<24 && _dy<24) {
        if (_s.weapon_fx_state==5) return;
        _s.weapon_fx_request=(_s.weapon_fx_request+1)&255;_s.enemy_pending_weapon=_item;
        return;
    }
    if (_s.weapon_fx_state==5 && _s.enemy_pending_weapon==_item) _s.weapon_fx_request=(_s.weapon_fx_request+1)&255;
}

function ln3_item_notice(_s,_data,_item) {
    _s.portrait_visible=1;_s.weapon_notice_timer=200;_s.notice_icon=255;
    ln3_score_add(_s,_data,0);return _item;
}

function ln3_items_update(_s,_data,_records,_defer_potion=false) {
    for (var _i=0;_i<array_length(_records);_i++) {
        var _r=_records[_i],_item=_r[0];
        if (_data.level==1 && _item==25) { }
        else {
            if (_s.inventory[_item]!=0) continue;
            if (_data.level==1 && _item==6 && _s.special_scene_phase<2) {ln3_item_proximity(_s,_r);continue;}
            if (_data.level==1 && _item==3 && _s.room_id==2 && _s.ammo_pile>=128) continue;
        }
        var _p=_s.parts[2];
        if (_p.x<_r[1] || _p.x>_r[2] || _p.y<_r[3] || _p.y>_r[4]) {ln3_item_proximity(_s,_r);continue;}
        if (_s.player_action<26 || _s.player_action>=28 || _s.parts[1].cursor!=3) continue;
        if (_data.level==1 && _item==25) {
            if (_s.special_scene_phase!=0 || _s.selected_item!=13) continue;
            _s.inventory[13]=128;_s.special_wait=50;_s.special_scene_phase=(_s.special_scene_phase+1)&255;return -1;
        }
        if (_item==21 && !_defer_potion) {
            _s.lives=(_s.lives+1)&255;_s.inventory[27]=_s.lives;
            _s.inventory[21]=128;_s.player_health=44;_s.inventory[26]=44;
        } else if (_data.level==1) {
            if (_item==9 || _item==10) {
                _s.inventory[_item]=(_s.inventory[_item]+1)&255;
                if ((_s.inventory[9]^_s.inventory[10])!=0) return ln3_item_notice(_s,_data,_item);
                _s.inventory[9]=128;_s.inventory[10]=128;_item=2;
            } else if (_item==3) {
                _s.ammo=4;_s.inventory[28]=4;
                if (_s.room_id==2) _s.ammo_pile=(_s.ammo_pile-1)&255;
            } else if (_item==12) {
                if (_s.inventory[4]==0) continue;
                _s.inventory[12]=(_s.inventory[12]+1)&255;_s.inventory[12]=128;_s.inventory[4]=128;_item=13;
            } else if (_item==7 || _item==8) {
                _s.inventory[_item]=(_s.inventory[_item]+1)&255;
                if ((_s.inventory[7]^_s.inventory[8])!=0) return ln3_item_notice(_s,_data,_item);
                _s.inventory[7]=128;_s.inventory[8]=128;_item=17;
            }
        } else if (_data.level==3 && _item==14) {
            _s.inventory[14]=128;_s.ammo=4;_s.inventory[28]=4;_item=3;
        }
        _s.inventory[_item]=(_s.inventory[_item]+1)&255;
        return ln3_item_notice(_s,_data,_item);
    }
    return -1;
}


function ln3_item_assist_input(_g,_joy) {
    var _s=_g.state;
    var _free=_s.player_dead==0 && _s.player_health>0 && _s.stun==0 && _s.input_block==0 && _s.climb_flags==0 &&
        _s.player_action!=18 && _s.player_action!=19 && !_g.weapon_switch;
    var _food=_free && _s.selected_item==21 && _s.inventory[21]>0 && _s.inventory[21]<128;
    if (ln_consumable_tap(_g,_joy,_food)) {
        _s.inventory[21]=128;_s.selected_item=0;_s.player_health=44;_s.inventory[26]=44;
        _s.lives=min(255,_s.lives+1);_s.inventory[27]=_s.lives;_g.found_item=-1;_s.weapon_notice_timer=0;
    }
    if (!variable_struct_exists(_g,"pickup_previous")) _g.pickup_previous=16;
    var _edge=_joy==16 && _g.pickup_previous==0;_g.pickup_previous=_joy&16;
    if (_food && (_joy&15)==0) return 0;
    if (is_struct(_g.pickup_assist)) return 0;
    if (!_edge || !_free || _s.player_action_flags>=128) return _joy;
    if ((_s.enabled&96)!=0 && _s.enemy_dead==0 && point_distance(_s.player_x,_s.player_y,_s.enemy_x,_s.enemy_y)<=20) return _joy;
    var _reach=18*LN_PICKUP_ASSIST_SCALE;
    var _best=undefined,_distance=sqr(_reach)+1;
    for (var _i=0;_i<array_length(_g.item_records);_i++) {
        var _r=_g.item_records[_i],_id=_r[0];
        if (_id==25 || _s.inventory[_id]!=0 || (_g.level==1 && _id==6 && _s.special_scene_phase<2) ||
            (_g.level==1 && _id==12 && _s.inventory[4]==0) ||
            (_g.level==1 && _id==3 && _s.room_id==2 && _s.ammo_pile>=128)) continue;
        var _x=clamp(_s.player_x,_r[1],_r[2]),_y=clamp(_s.player_y,_r[3],_r[4]);
        var _dx=_x-_s.player_x,_dy=_y-_s.player_y,_dist=_dx*_dx+_dy*_dy;
        if (_dist>sqr(_reach) || _dist>=_distance) continue;
        // Probe the complete short path with source collision and hazard handling.
        var _probe=json_parse(json_stringify(_s)),_clear=true,_steps=max(1,ceil(max(abs(_dx),abs(_dy))));
        for (var _step=1;_step<=_steps;_step++) {
            var _nx=round(_s.player_x+_dx*_step/_steps),_ny=round(_s.player_y+_dy*_step/_steps);
            for (var _part=1;_part<=2;_part++) {
                var _p=_probe.parts[_part];_p.old_x=_p.x;_p.old_y=_p.y;_p.x=_nx;_p.y=_ny-(_part==1?21:0);
            }
            _probe.player_x=_nx;_probe.player_y=_ny;
            ln3_collision_update(_probe,_g.actions,_g.collision,_g.bounds);
            if (_probe.stun!=0 || _probe.trap_contacts!=_s.trap_contacts || _probe.player_x!=_nx || _probe.player_y!=_ny) {_clear=false;break;}
        }
        if (_clear) {_best={x:_x,y:_y,health:_s.player_health,elapsed:0};_distance=_dist;}
    }
    if (!is_struct(_best)) return _joy;
    _g.pickup_assist=_best;_s.player_x=_best.x;_s.player_y=_best.y;
    for (var _part=1;_part<=2;_part++) {
        _s.parts[_part].x=_best.x;_s.parts[_part].y=_best.y-(_part==1?21:0);
        _s.parts[_part].old_x=_s.parts[_part].x;_s.parts[_part].old_y=_s.parts[_part].y;
    }
    _s.joy=0;ln3_action_set(_s,_g.actions,26);return 0;
}


function ln3_consumable_checks() {
    var _g=new LN3Play(),_s=_g.state;
    _g.item_records=[[21,0,255,0,255]];_s.inventory[21]=0;_s.player_action=26;_s.parts[1].cursor=3;
    _s.lives=2;_s.player_health=7;ln3_play_items(_g);
    ln_check(_s.inventory[21]==1 && _s.lives==2 && _s.player_health==7,"potion pickup banks reward");
    _s.selected_item=21;_s.player_dead=0;_s.stun=0;_s.input_block=0;_s.climb_flags=0;
    ln3_item_assist_input(_g,0);ln3_item_assist_input(_g,16);repeat(24) ln3_item_assist_input(_g,16);
    ln_check(_s.lives==2,"held fire cannot consume potion");
    ln3_item_assist_input(_g,0);ln3_item_assist_input(_g,16);ln3_item_assist_input(_g,0);ln3_item_assist_input(_g,16);
    ln_check(_s.inventory[21]==128 && _s.player_health==44 && _s.lives==3 && _s.selected_item==0,"potion double fire heals and grants one life");
    ln3_play_items(_g);ln_check(_s.inventory[21]==128 && _s.lives==3,"consumed potion cannot be collected again");
    _s.inventory[21]=1;ln3_level_load(_g,2,true);ln_check(_g.state.inventory[21]==1,"unused potion carries to next level");
    _g=new LN3Play();_s=_g.state;_s.lives=1;_s.player_dead=1;_s.death_wait=0;_s.logic_wait=0;
    ln3_play_tick(_g,0);repeat(650) if (!_g.game_over) ln3_play_tick(_g,0);
    ln_check(_g.game_over && _s.lives==0 && _g.transition_phase==11,"final life completes sword/game-over transition once");
    // Render the actual transition, including the original font, in its playfield.
    _g=new LN3Play();_s=_g.state;_s.lives=4;_s.player_dead=1;_s.death_wait=0;_s.logic_wait=0;
    ln3_play_tick(_g,0);
    repeat(500) if (_g.transition_phase!=8) {
        ln3_play_tick(_g,0);
        if (_g.transition_phase==6 && array_contains([16,48,80,112],_g.transition_wipe)) {
            var _capture=surface_create(1280,800);surface_set_target(_capture);ln3_play_draw(_g);surface_reset_target();
            surface_save(_capture,"ln3-sword-descent-"+string(_g.transition_wipe)+".png");surface_free(_capture);
        }
    }
    ln_check(_g.transition_phase==8 && _s.lives==3,"lives message reached after sword descends");
    var _surface=surface_create(240,144);surface_set_target(_surface);ln3_transition_draw(_g);surface_reset_target();
    surface_save(_surface,"ln3-lives-transition.png");surface_free(_surface);
    var _loaded=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));
    repeat(400) if (_loaded.special_sequence==5) ln3_play_tick(_loaded,0);
    ln_check(_loaded.state.lives==3 && _loaded.special_sequence==0,"saved sword transition resumes without charging another life");
    _g=new LN3Play();_s=_g.state;_s.inventory[21]=1;_s.selected_item=21;
    _loaded=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));
    ln_check(_loaded.state.inventory[21]==1 && _loaded.state.selected_item==21,"saved potion remains held");
    // Real crouch animation must reach its source collection cursor, not award on press.
    _g=new LN3Play();_s=_g.state;_s.enabled&=159;_g.bounds=[];
    _s.player_x=100;_s.player_y=100;_s.parts[1].x=100;_s.parts[1].y=79;_s.parts[2].x=100;_s.parts[2].y=100;
    _s.player_action=0;_s.player_action_flags=0;_s.stun=0;_s.input_block=0;_s.climb_flags=0;
    _s.inventory[21]=0;_g.item_records=[[21,103,108,100,104]];
    ln3_item_assist_input(_g,0);ln3_item_assist_input(_g,16);
    ln_check(is_struct(_g.pickup_assist) && _s.player_x==103 && _s.inventory[21]==0,"nearby fire starts crouch with at most 3.6px movement");
    repeat(80) if (_s.inventory[21]==0) ln3_play_tick(_g,0);
    ln_check(_s.inventory[21]==1 && !is_struct(_g.pickup_assist),"assisted crouch actually picks up potion");
    _s.inventory[21]=0;_s.player_x=99;_s.parts[2].x=99;_s.player_action=0;_s.player_action_flags=0;
    ln3_item_assist_input(_g,0);ln3_item_assist_input(_g,16);
    ln_check(!is_struct(_g.pickup_assist),"four pixels away exceeds reduced pickup reach");
    _s.player_x=100;_s.parts[1].x=100;_s.parts[2].x=100;
    _s.enabled|=96;_s.enemy_dead=0;_s.enemy_x=105;_s.enemy_y=100;
    ln3_item_assist_input(_g,0);ln3_item_assist_input(_g,16);
    ln_check(!is_struct(_g.pickup_assist),"nearby enemy keeps fire as combat");
    _s.enabled&=159;_g.bounds=[[101,95,102,105,4]];
    ln3_item_assist_input(_g,0);ln3_item_assist_input(_g,16);
    ln_check(!is_struct(_g.pickup_assist) && _s.player_x==100,"pickup cannot cross wall");
    show_debug_message("LN3_CONSUMABLE_PASS");
}
