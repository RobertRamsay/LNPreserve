/// One original keypad poll, using the same joystick bit positions as gameplay.
function ln2_keypad_poll(_s,_joy) {
    var _pressed=_joy&(~_s.previous)&31;_s.previous=_joy;
    if (_pressed&16) {
        _s.cursor++;
        if (_s.cursor<4) return 0;
        for (var _i=3;_i>=0;_i--) if (_s.digits[_i]!=_s.code[_i]) return 2;
        return 1;
    }
    if (_pressed&4) {_s.cursor=(_s.cursor-1)&3;return 0;}
    if (_pressed&8) {_s.cursor=(_s.cursor+1)&3;return 0;}
    if (_pressed&1) {_s.digits[_s.cursor]++;if (_s.digits[_s.cursor]>=37) _s.digits[_s.cursor]=27;return 0;}
    if (_pressed&2) {_s.digits[_s.cursor]--;if (_s.digits[_s.cursor]<27) _s.digits[_s.cursor]=36;}
    return 0;
}

function ln2_keypad_checks() {
    var _b=buffer_load("verification/ln2_keypad_vectors.json"),_o=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i],_s=_v.before,_event=ln2_keypad_poll(_s,_v.joy);
        ln_check(_event==_v.event && _s.cursor==_v.expected.cursor && _s.previous==_v.expected.previous,"LN2 keypad original edge/submit state "+string(_i));
        for (var _j=0;_j<4;_j++) ln_check(_s.digits[_j]==_v.expected.digits[_j],"LN2 keypad original digit "+string(_i));
    }
    show_debug_message("LN2_KEYPAD_PASS: "+string(array_length(_o.vectors))+" original keypad input/acceptance states; display and pre-poll delay excluded.");
    ln2_candle_checks();
    ln2_boss_release_checks();
    ln2_object_integration_checks();
    ln2_item_flow_checks();
    ln2_ending_checks();
}

function ln2_candles_ready(_s) {
    if (_s.enemy_y<98 || _s.enemy_y>=131 || _s.enemy_x<90 || _s.enemy_x>=163) return false;
    for (var _i=4;_i>=0;_i--) if (_s.candles[_i]==0) return false;
    return true;
}

function ln2_candle_interact(_s,_d) {
    var _result={accepted:false,item:21,requests:[]};
    if (_s.boss_defeated!=0) return _result;
    for (var _i=(_s.facing&6)>>1;_i<20;_i+=4) {
        var _r=_d.rectangles[_i];
        if (_s.x<_r[0] || _s.x>=_r[2] || _s.y<_r[1] || _s.y>=_r[3]) continue;
        var _candle=_i div 4;
        if (_s.candles[_candle]<128) {
            _s.candles[_candle]=128;
            if (ln2_candles_ready(_s) && _s.enemy_knockouts>=128) {
                _s.enemy_mirror=(_s.enemy_facing&4)^4;
                array_push(_result.requests,{kind:"enemy",address:$c1c0});
                _s.enemy_active=0;_s.final_palette_phase=0;_s.enemy_knockouts=255;_s.exit_locked=255;_s.boss_defeated=255;
            }
        } else {
            _s.candles[_candle]=0;array_push(_result.requests,{kind:"fragment",bytes:[34,_d.x[_candle],_d.y[_candle]]});
        }
        _s.countdown=_s.countdown>>1;_result.accepted=true;return _result;
    }
    return _result;
}

function ln2_candle_animation(_s,_d) {
    var _result={requests:[]};if (((_s.tick-_s.candle_tick)&255)<6) return _result;
    _s.candle_tick=_s.tick;if (_s.room_id!=1) return _result;
    for (var _i=4;_i>=0;_i--) {
        if (_s.candles[_i]<128) continue;
        _s.candles[_i]^=1;array_push(_result.requests,{kind:"fragment",bytes:[32+(_s.candles[_i]&1),_d.x[_i],_d.y[_i]]});
    }
    return _result;
}

function ln2_candle_checks() {
    var _b=buffer_load("verification/ln2_candle_vectors.json"),_o=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
    _b=buffer_load("play/ln2/final_mechanisms.json");var _d=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i],_s=_v.before,_result={requests:[]};
        switch (_v.operation) {
            case 0:
                _result=ln2_candle_interact(_s,_d);
                ln_check(_result.accepted==_v.result.accepted && _result.item==_v.result.item,"LN2 original candle interaction result "+string(_i));break;
            case 1:_result=ln2_candle_animation(_s,_d);break;
            case 2:ln_check(ln2_candles_ready(_s)==!_v.result.carry,"LN2 original final enemy/candle predicate "+string(_i));break;
            case 3:ln_check((_s.selected_item==16 && _s.boss_defeated!=0)==_v.result.accepted,"LN2 original final reward prerequisite "+string(_i));break;
            case 4:_result=ln2_final_death_rule(_s);break;
        }
        ln3_state_check(_s,_v.expected,"LN2 original candle state "+string(_i));
        ln_check(array_length(_result.requests)==array_length(_v.result.requests),"LN2 candle drawing/animation request count");
        for (var _j=0;_j<array_length(_result.requests);_j++) ln3_state_check(_result.requests[_j],_v.result.requests[_j],"LN2 original candle request "+string(_i));
    }
    show_debug_message("LN2_CANDLES_PASS: "+string(array_length(_o.vectors))+" original candle/victory states and drawing/animation requests; presentation excluded.");
}

function ln2_keypad_tick(_g,_joy) {
    var _result=ln2_keypad_poll(_g.keypad,_joy);if (_result==0) return;
    ln2_item_complete(_g,_g.pending_item,_result==1?18:255);_g.pending_item=undefined;_g.keypad=undefined;
}

function ln2_keypad_draw(_g) {
    if (_g.world_state.code_visible) {
        var _code="";for (var _i=0;_i<4;_i++) _code+=string(_g.keycode[_i]-27);
        draw_text(800,630,"CODE  "+_code);
    }
    if (!is_struct(_g.keypad)) return;
    draw_set_colour(c_black);draw_rectangle(420,270,860,485,false);draw_set_colour(c_white);
    draw_text(460,300,"ENTER CODE");
    for (var _i=0;_i<4;_i++) {
        draw_set_colour(_i==_g.keypad.cursor?c_yellow:c_white);
        draw_text(510+_i*72,360,string(_g.keypad.digits[_i]-27));
    }
    draw_set_colour(c_white);draw_text(460,420,"W/S Change digit    A/D Select");draw_text(460,450,"J Next / confirm");
}

function ln2_final_state(_g,_tick) {
    var _p=_g.player,_e=_g.enemy;
    return {x:_p.x,y:_p.y,facing:_p.facing,countdown:_p.countdown,enemy_x:_e.x,enemy_y:_e.y,
        enemy_facing:_e.facing,enemy_mirror:_e.action_mirror,enemy_active:_e.active,enemy_knockouts:_e.knockouts,
        final_palette_phase:_g.world_state.final_palette_phase,boss_defeated:_g.world_state.boss_defeated?255:0,
        exit_locked:_g.exit_locked?255:0,tick:_tick,candle_tick:_g.inventory[20],room_id:_g.room_id,
        selected_item:_g.selected_item,candles:_g.world_state.candles,
        enemy_costume:_e.costume,enemy_mode:_e.mode,separation_y:_e.separation_y};
}

function ln2_final_death_rule(_s) {
    var _address=(_s.enemy_facing&4)?$b67b:$b687;
    if (_s.enemy_costume==2 && ln2_candles_ready(_s)) {
        _s.enemy_active=0;_s.final_palette_phase=0;_s.enemy_knockouts=255;_s.exit_locked=255;_s.boss_defeated=255;
        _s.enemy_mirror=(_s.enemy_facing&4)^4;_address=$c1b9;
    }
    _s.enemy_mode=7;_s.separation_y=0;return {requests:[{kind:"enemy",address:_address}]};
}

function ln2_final_enemy_hurt(_g) {
    var _s=ln2_final_state(_g,_g.player.tick),_result=ln2_final_death_rule(_s);
    _g.enemy.active=_s.enemy_active;_g.enemy.knockouts=_s.enemy_knockouts;_g.enemy.action_mirror=_s.enemy_mirror;
    _g.world_state.final_palette_phase=_s.final_palette_phase;_g.world_state.boss_defeated=_s.boss_defeated!=0;_g.exit_locked=_s.exit_locked!=0;
    _g.enemy.mode=_s.enemy_mode;_g.enemy.separation_y=_s.separation_y;ln2_enemy_special(_g,_result.requests[0].address);
}

function ln2_item_animation_finish(_p,_data) {
    for (var _i=0;_i<array_length(_data.pairs);_i++) {
        var _pair=_data.pairs[_i];if (_p.action!=_pair.before) continue;
        _p.action=_pair.after;_p.countdown=(_p.countdown<<1)&255;return;
    }
}

function ln2_item_flow_checks() {
    var _o=ln3_data_read("verification/ln2_item_flow_vectors.json"),_level=0,_data=undefined;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];
        if (_level!=_v.level) {_level=_v.level;_data=ln3_data_read("play/ln2/level"+string(_level)+"/item_flow.json");}
        var _p={action:_v.action,countdown:_v.countdown};ln2_item_animation_finish(_p,_data);
        ln_check(_p.action==_v.expected_action && _p.countdown==_v.expected_countdown,"LN2 original item animation continuation "+string(_i));
    }
    show_debug_message("LN2_ITEM_FLOW_PASS: "+string(array_length(_o.vectors))+" original post-interaction animation/countdown states across all seven levels.");
}

function ln2_final_candle_use(_g) {
    var _s=ln2_final_state(_g,_g.player.tick),_result=ln2_candle_interact(_s,_g.final_rules);
    _g.world_state.candles=_s.candles;
    if (!_result.accepted) return -1;
    _g.player.countdown=_s.countdown;_g.enemy.action_mirror=_s.enemy_mirror;
    _g.enemy.active=_s.enemy_active;_g.enemy.knockouts=_s.enemy_knockouts;
    _g.world_state.boss_defeated=_s.boss_defeated!=0;_g.world_state.final_palette_phase=_s.final_palette_phase;_g.exit_locked=_s.exit_locked!=0;
    for (var _i=0;_i<array_length(_result.requests);_i++) {
        var _r=_result.requests[_i];if (_r.kind=="enemy") ln2_enemy_special(_g,_r.address);
    }
    return _result.item;
}

function ln2_final_candles_tick(_g,_tick) {
    var _s=ln2_final_state(_g,_tick);ln2_candle_animation(_s,_g.final_rules);
    _g.world_state.candles=_s.candles;_g.inventory[20]=_s.candle_tick;
}

function ln2_final_candles_draw(_g) {
    if (_g.level!=7 || _g.room_id!=1) return;
    for (var _i=0;_i<5;_i++) {
        var _value=_g.world_state.candles[_i],_phase=_value>=128?(_value&1):2;
        draw_sprite(asset_get_index(_g.final_art.sprite),_g.final_art.candles[_i][_phase],0,0);
    }
}

function ln2_boss_release(_g) {
    if (_g.inventory[18]==0) return false;
    var _e=_g.enemy,_d=_g.boss_release;
    _e.x=30;_e.y=187;_e.depth_y=187;_e.facing=1;_e.heading=1;
    _e.retreat_trait=_d.retreat_trait;_e.frame=_d.frame;_e.display_frame=_d.frame;
    _e.action_mirror=_d.mirror;_e.mirror=_d.mirror!=0;_e.traits=_d.traits;_e.speed=_d.traits&3;
    _e.active=130;_e.mode=5;ln2_enemy_select(_e,_g.data,8);ln2_enemy_combat(_e,8);
    _g.world_state.candles=array_create(5,0);return true;
}

function ln2_boss_release_checks() {
    var _o=ln3_data_read("verification/ln2_boss_release_vectors.json"),_g=new LN2Play(7);
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];_g.enemy=_v.before.enemy;_g.enemy.costume=_v.before.costume;_g.enemy.retreat_trait=_v.before.retreat_trait;
        _g.world_state.candles=_v.before.candles;_g.inventory[18]=_v.before.gate;
        ln_check(ln2_boss_release(_g)==_v.accepted,"LN2 original final enemy release prerequisite");
        ln3_state_check(_g.enemy,_v.expected.enemy,"LN2 original final enemy release "+string(_i));
        ln_check(_g.enemy.costume==_v.expected.costume && _g.enemy.retreat_trait==_v.expected.retreat_trait,"LN2 original boss costume/retreat");
        for (var _j=0;_j<5;_j++) ln_check(_g.world_state.candles[_j]==_v.expected.candles[_j],"LN2 final room resets candles");
    }
    show_debug_message("LN2_BOSS_RELEASE_PASS: "+string(array_length(_o.vectors))+" original final enemy release states; compositor excluded.");
}

function ln2_object_integration_checks() {
    var _g=new LN2Play(7),_room=_g.world.rooms[1];ln2_test_enter(_g,_room.spawn_entry);
    var _records={};for (var _i=0;_i<array_length(_g.world.items);_i++) variable_struct_set(_records,string(_g.world.items[_i].id),_g.world.items[_i]);
    var _pad=variable_struct_get(_records,"18");
    ln_check(ln2_item_handler(_g,_pad)==-1,"LN2 keypad needs its original prerequisite");
    _g.inventory[17]=255;_g.last_joy=16;
    ln_check(ln2_item_handler(_g,_pad)==-2,"LN2 original interaction opens keypad");_g.pending_item=_pad;
    for (var _i=0;_i<4;_i++) {
        ln2_keypad_tick(_g,0);
        repeat(_g.keycode[_i]-27) {ln2_keypad_tick(_g,1);ln2_keypad_tick(_g,0);}
        ln2_keypad_tick(_g,16);
    }
    ln_check(!is_struct(_g.keypad) && _g.inventory[18]==255,"LN2 original code opens the final gate");
    var _release=variable_struct_get(_records,"16"),_result=ln2_item_handler(_g,_release);
    ln_check(_result==16 && _g.enemy.active==130,"LN2 solved gate releases final enemy");ln2_item_complete(_g,_release,_result);
    ln_check(variable_struct_exists(_g.world.enemy_banks,string(_g.enemy.weapon)+"_"+string(_g.enemy.costume)),"LN2 latent final enemy has original sprite bank");
    _g.enemy.x=118;_g.enemy.y=114;_g.enemy.knockouts=128;_g.player.facing=1;
    for (var _i=0;_i<5;_i++) {
        var _r=_g.final_rules.rectangles[_i*4];_g.player.x=(_r[0]+_r[2]) div 2;_g.player.y=(_r[1]+_r[3]) div 2;
        ln_check(ln2_item_handler(_g,variable_struct_get(_records,"22"))==21,"LN2 original candle can be lit");
    }
    ln_check(_g.world_state.boss_defeated && _g.enemy.action==$c1c0,"LN2 five candles and defeated enemy trigger final animation");
    _g.selected_item=16;ln_check(ln2_item_handler(_g,variable_struct_get(_records,"23"))==23,"LN2 original final reward is available");
    _g=new LN2Play(7);ln2_test_enter(_g,_g.world.rooms[1].spawn_entry);_g.inventory[18]=255;ln2_boss_release(_g);
    _g.enemy.x=118;_g.enemy.y=114;_g.world_state.candles=array_create(5,128);
    ln2_damage(_g,44,true);ln2_combat_hurt(_g,true);
    ln_check(_g.world_state.boss_defeated && _g.enemy.action==$c1b9 && _g.enemy.active==0,
        "LN2 candles lit before final blow use the original alternate victory animation");
    _g=new LN2Play(5);_g.inventory[1]=255;_g.inventory[18]=255;ln2_level_load(_g,6,true);
    ln_check(_g.inventory[1]==255 && _g.inventory[18]==0,"LN2 ordinary level travel preserves carried objects and clears local puzzle flags");
    ln2_level_load(_g,5);ln_check(_g.inventory[18]==255,"LN2 scene testing restores visited level puzzle state");
    show_debug_message("LN2_OBJECT_INTEGRATION_PASS: keypad, final enemy release, five-candle condition and per-level puzzle flags; original full-playthrough parity remains pending.");
}

function ln2_final_gpu_checks() {
    var _g=new LN2Play(7);ln2_test_enter(_g,_g.world.rooms[1].spawn_entry);
    _g.player.display_frame=255;_g.enemy.display_frame=255;
    var _o=ln3_data_read("verification/ln2_candle_gpu.json"),_b=buffer_create(240*144*4,buffer_fixed,1),_count=0;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];_g.world_state.candles=array_create(5,0);_g.world_state.candles[_v.candle]=_v.phase<2?128+_v.phase:0;
        ln2_play_draw(_g);buffer_get_surface(_b,_g.stage_surface,0);
        for (var _j=0;_j<array_length(_v.samples);_j++) {
            var _p=_v.samples[_j],_actual=buffer_peek(_b,(_p[1]*240+_p[0])*4,buffer_u32)&$ffffff;
            ln_check(_actual==make_colour_rgb(_p[2],_p[3],_p[4]),"LN2 original candle bitmap pixel "+string(_i)+":"+string(_j));_count++;
        }
    }
    buffer_delete(_b);surface_free(_g.stage_surface);
    _o=ln3_data_read("verification/ln2_final_enemy_gpu.json");_b=buffer_create(96*96*4,buffer_fixed,1);
    var _surface=surface_create(96,96),_pixels=0;_g.mask=-1;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i],_e=_g.enemy;_e.display_frame=_v.frame;_e.mirror=_v.mirror;_e.weapon=_v.weapon;_e.costume=_v.costume;
        _e.x=48;_e.y=64;_e.depth_y=255;_e.active=130;_e.custom=false;
        surface_set_target(_surface);draw_clear_alpha(c_black,0);ln2_play_actor(_g,_e,true);surface_reset_target();buffer_get_surface(_b,_surface,0);
        for (var _y=0;_y<96;_y++) for (var _x=0;_x<96;_x++) {
            var _code=string_char_at(_v.rows[_y],_x+1),_actual=buffer_peek(_b,(_y*96+_x)*4,buffer_u32),_visible=_code!=".";
            ln_check(((_actual>>24)&255)==(_visible?255:0),"LN2 original final enemy alpha "+string(_i));
            if (_visible) {
                var _rgb=_o.palette[string_pos(_code,"0123456789abcdef")-1];
                ln_check((_actual&$ffffff)==make_colour_rgb(_rgb[0],_rgb[1],_rgb[2]),"LN2 original final enemy colour "+string(_i));
            }
            _pixels++;
        }
    }
    buffer_delete(_b);surface_free(_surface);
    show_debug_message("LN2_FINAL_GPU_PASS: "+string(_count)+" original candle pixels and "+string(_pixels)+" original final-enemy pixels; unmasked compositor scope.");
    ln2_ending_gpu_checks();
}
