/// Source item records retain their action, facing, and approach rectangles.
function ln2_item_interact(_g,_kind) {
    var _p=_g.player;
    if (_kind==0 && _g.level==7 && _g.room_id==1 && _g.world_state.boss_defeated &&
        _g.selected_item==16 && (_g.inventory[16]&127)!=0 && _g.inventory[23]==0 &&
        abs(_p.x-_g.enemy.x)<=18 && abs(_p.y-_g.enemy.y)<=14) {
        for(var _i=0;_i<array_length(_g.world.items);_i++) {
            var _reward=_g.world.items[_i];
            if(_reward.id==23) {ln2_item_complete(_g,_reward,23);return;}
        }
    }
    for (var _i=0;_i<array_length(_g.world.items);_i++) {
        var _item=_g.world.items[_i];
        if (_item.room!=_g.room_id || _item.action!=_kind || _g.inventory[_item.id]!=0) continue;
        if (_item.facing!=0 && _item.facing!=_p.facing) continue;
        if (_p.x<_item.x_min || _p.x>=_item.x_max || _p.y<_item.y_min || _p.y>=_item.y_max) continue;
        var _id=ln2_item_handler(_g,_item);
        if (_id==-2) {_g.pending_item=_item;return;}
        if (_id<0) continue;
        ln2_item_complete(_g,_item,_id);
        return;
    }
}

function ln2_item_complete(_g,_item,_id) {
    if (_g.level==7 && _g.room_id==1 && _id!=255) {
        switch (_item.id) {
            case 17:_g.safe_scene_phase=1;break;
            case 18:_g.safe_scene_phase=2;break;
            case 16:_g.safe_scene_phase=3;_g.inventory[16]=255;break;
            case 23:_g.safe_scene_phase=4;_g.inventory[16]=128;_g.selected_item=0;break;
        }
    }
    if (_id!=255) {
        if (_g.inventory[_id]==0) _g.inventory[_id]=_id==4?137:255;
        if (_id<17) {_g.notice_item=_id;_g.notice_tick=_g.player.tick;_g.notice_duration=100;}
        if (_id!=8) ln2_score_add(_g,5);
    }
    ln2_refresh_scene(_g);
    ln2_item_animation_finish(_g.player,_g.item_flow);
}

function ln2_item_open_line(_g) {
    if (array_length(_g.data.boundaries)>0) _g.data.boundaries[0][2]=_g.data.boundaries[0][0];
    variable_struct_set(_g.opened_passages,string(_g.room_id),true);
}

/// A returned item number is the original handler's Y result; -1 rejects it.
function ln2_item_handler(_g,_item) {
    var _p=_g.player,_id=_item.id,_selected=_g.selected_item;
    if (_item.handler==0) return _id;
    switch (_g.level) {
        case 1:
            switch (_id) {
                case 17:
                    if (_selected!=7) return -1;
                    ln2_item_open_line(_g);return _id;
                case 5:case 6:
                    if (_g.inventory[_id==5?6:5]!=0) {
                        _g.inventory[3]=255;_g.inventory[5]=128;_g.inventory[6]=128;
                    }
                    return _id;
                case 19:
                    if (_p.weapon!=2) return -1;
                    ln2_enemy_special(_g,$cd7e);_g.special_mode=2;return _id;
            }
            break;
        case 2:
            if (_id==17) { ln2_item_open_line(_g);return _id; }
            if (_id==19) return _selected==11?_id:-1;
            break;
        case 3:
            if (_id==20) return _selected==12?_id:-1;
            if (_id==19) {
                if (_selected!=10) return -1;
                _g.inventory[19]=255;_g.inventory[10]=0;return 10;
            }
            break;
        case 4:
            if (_id==19) {
                if (_selected!=14) return -1;
                _g.inventory[19]=255;return 14;
            }
            if (_id==17) {
                if (_selected!=13) return -1;
                ln2_item_open_line(_g);return _id;
            }
            if (_id==18) {
                if (_selected!=14 || _g.inventory[19]==0) return -1;
                ln2_enemy_special(_g,$c777);return _id;
            }
            break;
        case 5:
            if (_id==17 || _id==20) { ln2_item_open_line(_g);return _id; }
            if (_item.room==14) {
                if (abs(_g.enemy.x-_p.x)>=8) return -1;
                _p.countdown=255;_g.world_state.sequence_lock=255;_g.special_flag=255;return 18;
            }
            if (_item.room==3) {
                // Original code reveals the generated keypad number here.
                var _known=_g.office_code_known || _g.world_state.code_visible;
                _g.office_code_known=true;_g.world_state.code_visible=true;
                return _known?255:18;
            }
            break;
        case 6:
            if (_id==19) { _g.inventory[20]=0;return _id; }
            if (_id==20) { _g.inventory[19]=0;return _id; }
            if (_id==21) { ln2_enemy_special(_g,$cb33);ln2_item_open_line(_g);return _id; }
            if (_id==24) { _g.inventory[18]&=128;return _id; }
            break;
        case 7:
            if (_id==18) {
                if (_g.inventory[17]==0) return -1;
                _g.keypad={cursor:0,previous:_g.last_joy,digits:[27,27,27,27],code:_g.keycode};return -2;
            }
            if (_id==22) return ln2_final_candle_use(_g);
            if (_id==16) return ln2_boss_release(_g)?16:-1;
            if (_id==23) return _selected==16 && _g.world_state.boss_defeated?_id:-1;
            break;
    }
    var _key="item:"+string(_item.handler);
    if (!array_contains(_g.pending_events,_key)) array_push(_g.pending_events,_key);
    return -1;
}

function ln2_refresh_scene(_g) {
    _g.scene_frame=0;
    // Scene variants are source-rendered and selected by their inventory flags.
    var _room=_g.scene_record;
    _g.scene=asset_get_index(_room.sprite);
    if (variable_struct_exists(_room,"variants")) {
        var _bits=0;
        for (var _i=0;_i<array_length(_room.variant_flags);_i++)
            if (_g.inventory[_room.variant_flags[_i]]!=0) _bits|=1<<_i;
        _g.scene=asset_get_index(_room.variants[_bits]);
    }
    // These removed panels are drawn on interaction, not by scene entry.
    if (_g.level==2 && (_g.room_id==8 || _g.room_id==14)) {
        var _bottle=_g.room_id==8,_flag=_bottle?10:19;
        _g.scene=asset_get_index(_bottle?"spr_ln2_street_bottle_states":"spr_ln2_street_manhole_states");
        _g.scene_frame=real(_g.inventory[_flag]!=0);
    }
    if (_g.level==3 && _g.room_id==5) {
        _g.scene=spr_ln2_sewer_grate_states;_g.scene_frame=real(_g.inventory[20]!=0);
    }
    // Source item completion draws these panels immediately, not on room entry.
    if (_g.level==7 && _g.room_id==1) {
        _g.safe_scene_phase=_g.inventory[23]!=0?4:(_g.inventory[18]!=0?(_g.inventory[16]==255?3:2):(_g.inventory[17]!=0?1:0));
        _g.scene=asset_get_index("spr_ln2_safe_states");_g.scene_frame=_g.safe_scene_phase;
    }
}

function ln2_park_switch_checks() {
    var _g=new LN2Play(1);ln2_test_enter(_g,3);
    var _p=_g.player,_surface=surface_create(240,144);
    surface_set_target(_surface);draw_sprite(_g.scene,0,0,0);surface_reset_target();
    ln_check(surface_getpixel(_surface,172,44)!=c_black,"unpunched switch is yellow");
    _p.x=160;_p.y=86;_p.depth_y=86;_p.facing=1;_p.heading=1;_p.stopped=255;_p.vehicle=0;
    _p.weapon=0;_p.selected_weapon=0;_p.fire_previous=0;_p.input_lock=0;_p.action=0;_g.enemy.active=0;
    repeat(80) {if (_g.inventory[18]!=0) break;ln2_play_tick(_g,17);}
    ln_check(_g.inventory[18]!=0,"actual unarmed punch activates the original switch flag");
    surface_set_target(_surface);draw_sprite(_g.scene,0,0,0);surface_reset_target();
    ln_check(surface_getpixel(_surface,172,44)==c_black,"punch displays original black switch panel immediately");
    ln2_test_enter(_g,4);ln2_test_enter(_g,3);
    ln_check(_g.scene==spr_ln2_park_switch_pressed,"activated switch remains black on revisit");
    _g.inventory[18]=0;ln2_refresh_scene(_g);
    ln_check(_g.scene!=spr_ln2_park_switch_pressed,"consumed switch flag restores yellow state");
    surface_free(_surface);show_debug_message("LN2_SWITCH_PASS: actual punch, yellow-to-black pixels, revisit and reset");
}

/// Two distinct fire presses within 18 game ticks consume the selected burger.
function ln2_burger_input(_g,_joy) {
    if (!variable_struct_exists(_g,"burger_taps")) _g.burger_taps={remaining:0,previous:0};
    var _tap=_g.burger_taps,_fire=_joy&16,_edge=_fire!=0 && _tap.previous==0;
    _tap.previous=_fire;
    if (_tap.remaining>0) _tap.remaining--;
    if (_g.selected_item!=8 || !(_g.inventory[8]&127) || _g.player.input_lock!=0 ||
        _g.respawn_wait>0 || _g.victory!=0 || is_struct(_g.keypad) || _g.hole_steps>0 ||
        _g.fall_remaining>=0 || is_struct(_g.route_descent)) {_tap.remaining=0;return _joy;}
    if (!_edge) return _joy;
    if (_tap.remaining==0) {_tap.remaining=18;return _joy;}
    _tap.remaining=0;
    // 128 keeps the world pickup removed while excluding it from item cycling.
    _g.inventory[8]=128;_g.selected_item=0;
    if (_g.notice_item==8) _g.notice_item=-1;
    _g.lives_left++;_g.player_health=44;
    ln2_refresh_scene(_g);
    return _joy&15;
}

function ln2_burger_checks() {
    var _g=new LN2Play(1);ln2_play_enter(_g,8);
    var _p=_g.player;_p.x=200;_p.y=67;_p.facing=1;
    _g.inventory[8]=0;_g.lives_left=2;_g.player_health=7;_g.status.health[0]=7;
    ln2_item_interact(_g,0);
    ln_check(_g.lives_left==2 && _g.player_health==7 && _g.inventory[8]==255,"pickup banks burger without reward");
    _g.selected_item=0;ln2_burger_input(_g,16);ln2_burger_input(_g,0);ln2_burger_input(_g,16);
    ln_check(_g.lives_left==2,"unselected double fire cannot consume burger");
    _g.selected_item=7;ln2_controls_update(_g,223,255);
    ln_check(_g.selected_item==8 && _g.notice_item==-1,"item cycle selects burger and shows holding");
    ln2_burger_input(_g,0);ln2_burger_input(_g,16);
    repeat(25) ln2_burger_input(_g,16);
    ln_check(_g.lives_left==2,"held fire is not double fire");
    ln2_burger_input(_g,0);ln2_burger_input(_g,16);
    ln_check(_g.lives_left==2,"expired first tap does not consume");
    ln2_burger_input(_g,0);ln2_burger_input(_g,16);
    ln_check(_g.lives_left==3 && _g.player_health==44 && _g.inventory[8]==128 && _g.selected_item==0,"selected double fire consumes once");
    ln_check(_g.status.health[0]==7,"consume preserves initial spiral frame");
    for(var _tick=1;_tick<=74;_tick++) {
        ln2_status_tick(_g,_tick);
        ln_check(_g.status.health[0]==7+(_tick div 2),"spiral refills progressively");
    }
    _g.player_health=20;_g.selected_item=8;
    ln2_burger_input(_g,0);ln2_burger_input(_g,16);ln2_burger_input(_g,0);ln2_burger_input(_g,16);
    ln_check(_g.lives_left==3 && _g.player_health==20,"consumed burger cannot repeat reward");
    ln2_play_enter(_g,1);ln2_play_enter(_g,8);ln2_item_interact(_g,0);
    ln_check(_g.inventory[8]==128,"consumed burger cannot be picked up again on revisit");
    _g.selected_item=7;ln2_controls_update(_g,255,255);ln2_controls_update(_g,223,255);
    ln_check(_g.selected_item!=8,"consumed burger skipped by selection");
    show_debug_message("LN2_BURGER_PASS: banked pickup, selection, double tap, held/expired fire, spiral refill and single consumption");
}

function ln2_final_room_checks() {
    var _g=new LN2Play(7);ln2_play_enter(_g,1);
    ln_check(_g.scene==spr_ln2_safe_states && _g.scene_frame==0 && _g.inventory[16]==0,"curtain covers safe and orb stays inside on arrival");
    _g.player.x=175;_g.player.y=83;_g.player.facing=1;ln2_item_interact(_g,1);
    ln_check(_g.scene_frame==1 && _g.inventory[17]!=0,"pulling curtain reveals safe");
    _g.player.x=175;_g.player.y=83;_g.player.facing=1;ln2_item_interact(_g,0);
    ln_check(is_struct(_g.keypad),"safe interaction opens keypad");
    // A standalone final-level test needs no office visit or god mode.
    ln_check(!_g.god_mode,"standalone safe test has god mode off");
    _g.keypad.digits=[27,27,27,27];
    repeat(4) {ln2_keypad_tick(_g,0);ln2_keypad_tick(_g,16);}
    ln_check(_g.scene_frame==2,"safe opens with orb inside");
    ln2_item_interact(_g,0);
    ln_check(_g.inventory[16]==255 && _g.enemy.active==130 && _g.scene_frame==3,"taking orb releases Shogun and empties safe");
    _g.enemy.x=118;_g.enemy.y=114;_g.enemy.knockouts=128;
    for(var _i=0;_i<5;_i++) {
        var _r=_g.final_rules.rectangles[_i*4];_g.player.x=(_r[0]+_r[2]) div 2;_g.player.y=(_r[1]+_r[3]) div 2;_g.player.facing=1;
        ln2_item_interact(_g,2);
    }
    ln_check(_g.world_state.boss_defeated,"defeated Shogun and five candles trigger spirits");
    _g.player.x=175;_g.player.y=83;_g.player.facing=1;_g.selected_item=16;
    ln2_item_interact(_g,0);
    ln_check(_g.inventory[23]!=0 && _g.inventory[16]==128 && _g.scene_frame==4,"returning orb completes safe sequence");
    ln2_play_enter(_g,0);ln2_play_enter(_g,1);
    ln_check(_g.scene_frame==4 && _g.inventory[16]==128,"revisit preserves returned orb and safe");
    var _loaded=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));
    ln_check(_loaded.scene==spr_ln2_safe_states && _loaded.scene_frame==4 && _loaded.inventory[16]==128,"save reload preserves final safe");
    ln2_final_ritual_checks();ln2_keypad_checks();
    show_debug_message("LN2_FINAL_ROOM_PASS: curtain reveal, original keypad, removal/release, five candles, orb return and save/revisit");
}

function ln2_final_ritual_checks() {
    var _g=new LN2Play(7);ln2_play_enter(_g,1);var _e=_g.enemy;
    _g.inventory[18]=255;ln2_boss_release(_g);
    _e.mode=11;_e.knockouts=128;_e.x=118;_e.y=114;_e.recovery_time=0;
    _e.actor_blocked=0;_e.edge_blocked=0;_e.boundary_hit=255;_e.decision_tick=0;
    _g.player.x=40;_g.player.y=160;_g.player.tick=200;_g.tick_epoch=100;
    _g.world_state.candles=[128,128,0,128,0];ln2_enemy_decide(_g);
    ln_check(_e.knockouts<128 && _e.mode==7,"Shogun revives after recovery");
    for(var _i=0;_i<5;_i++) ln_check(_g.world_state.candles[_i]==0,"revival extinguishes every candle");
    for(var _side=0;_side<2;_side++) {
        _g=new LN2Play(7);ln2_play_enter(_g,1);_e=_g.enemy;
        _e.x=110+_side*24;_e.y=120;_e.depth_y=120;_e.facing=_side?5:1;_e.knockouts=128;
        _g.world_state.candles=[128,128,128,128,0];
        var _r=_g.final_rules.rectangles[16];_g.player.x=(_r[0]+_r[2]) div 2;_g.player.y=(_r[1]+_r[3]) div 2;_g.player.facing=1;
        ln2_final_candle_use(_g);
        ln_check(_g.world_state.boss_defeated && _e.action_mirror==((_e.facing&4)^4),"spirit entrance follows fallen facing");
        repeat(20) ln2_combat_event(_g,23,true);
        ln_check(_e.x==110+_side*24 && _e.y==120,"spirit remains aligned with fallen body");
    }
    var _state={enemy_x:89,enemy_y:114,candles:[128,128,128,128,128]};
    ln_check(!ln2_candles_ready(_state),"outside star cannot complete ritual");
    show_debug_message("LN2_SEQUENCE_PASS: revival candle reset, star location gate, left/right spirit alignment");
}

function ln2_keypad_visual_checks() {
    var _g=new LN2Play(7);ln2_play_enter(_g,1);
    ln2_play_draw(_g);surface_save(application_surface,"ln2-curtain-start.png");
    _g.player.x=175;_g.player.y=83;_g.player.facing=1;ln2_item_interact(_g,1);ln2_item_interact(_g,0);
    ln2_play_draw(_g);surface_save(application_surface,"ln2-original-keypad.png");
    ln_check(is_struct(_g.keypad) && sprite_get_number(spr_ln2_keypad_digits)==20,"original keypad glyphs rendered");
    show_debug_message("LN2_KEYPAD_VISUAL_PASS");
}

/// Testing aid: two fire-only edges near the same unlit candle align and light it.
function ln2_candle_assist_input(_g,_joy) {
    if (!variable_struct_exists(_g,"candle_taps")) _g.candle_taps={previous:0,remaining:0,target:-1};
    var _t=_g.candle_taps,_fire=_joy&16,_edge=_fire!=0 && _t.previous==0,_p=_g.player;
    _t.previous=_fire;if(_t.remaining>0) _t.remaining--;
    if (_g.level!=7 || _g.room_id!=1 || _g.world_state.boss_defeated ||
        _p.input_lock!=0 || _g.respawn_wait>0 || is_struct(_g.keypad) || (_joy&15)!=0) {
        _t.remaining=0;_t.target=-1;return _joy;
    }
    var _best=32*32+1,_index=-1,_x=0,_y=0,_facing=1;
    for(var _i=0;_i<20;_i++) {
        var _c=_i div 4;if(_g.world_state.candles[_c]>=128) continue;
        var _r=_g.final_rules.rectangles[_i],_cx=(_r[0]+_r[2]) div 2,_cy=(_r[1]+_r[3]) div 2;
        var _dist=sqr(_p.x-_cx)+sqr(_p.y-_cy);
        if(_dist<_best) {_best=_dist;_index=_c;_x=_cx;_y=_cy;_facing=(_i mod 4)*2+1;}
    }
    if(_index<0) {_t.remaining=0;_t.target=-1;return _joy;}
    if (_p.action>=256 && variable_struct_exists(_g,"candle_assist_active") && _g.candle_assist_active) return 0;
    if(!_edge) return _joy;
    if(_t.remaining==0 || _t.target!=_index) {_t.remaining=30;_t.target=_index;return 0;}
    _t.remaining=0;_t.target=-1;
    _p.x=_x;_p.y=_y;_p.depth_y=_y;_p.fraction_x=0;_p.fraction_y=0;
    _p.facing=_facing;_p.heading=_facing;_p.turn_lock=0;_p.stopped=255;
    _p.action=0;_p.action_state=0;_p.flags=0;_p.countdown=0;
    _p.frame=16+(((_facing+2)&4)>>2);_p.display_frame=_p.frame;
    // Play the original crouch/pickup chain; its state 11 lights the candle.
    _g.candle_assist_active=true;
    ln2_player_begin(_p,_g.data,20);
    return 0;
}

function ln2_testing_aid_checks() {
    var _g=new LN2Play(7);ln2_play_enter(_g,1);_g.inventory[18]=255;ln2_boss_release(_g);
    ln2_damage(_g,1,true);ln_check(_g.enemy.health==43,"one-hit mode defaults off");
    _g.one_hit_kills=true;ln2_damage(_g,1,true);
    ln_check(_g.enemy.health==0 && _g.enemy.knockouts>=128,"one-hit mode uses normal knockout handling");
    var _health=_g.player_health;ln2_damage(_g,1,false);ln_check(_g.player_health==_health-1,"one-hit mode does not amplify enemy damage");
    ln2_level_load(_g,6);ln_check(_g.one_hit_kills,"one-hit preference survives level changes");
    var _loaded=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));ln_check(_loaded.one_hit_kills,"one-hit preference survives saves");
    for(var _c=0;_c<5;_c++) {
        _g=new LN2Play(7);ln2_play_enter(_g,1);_g.inventory[16]=255;
        var _r=_g.final_rules.rectangles[_c*4];_g.player.x=(_r[0]+_r[2]) div 2+3;_g.player.y=(_r[1]+_r[3]) div 2+2;
        ln2_candle_assist_input(_g,16);repeat(3) ln2_candle_assist_input(_g,16);
        ln_check(_g.world_state.candles[_c]==0,"holding fire cannot light candle");
        ln2_candle_assist_input(_g,0);ln2_candle_assist_input(_g,16);
        repeat(35) ln2_play_tick(_g,0);
        ln_check(_g.world_state.candles[_c]>=128,"double fire aligns and lights candle "+string(_c));
        ln2_candle_assist_input(_g,0);ln2_candle_assist_input(_g,16);ln2_candle_assist_input(_g,0);ln2_candle_assist_input(_g,16);
        ln_check(_g.world_state.candles[_c]>=128,"assistance never toggles a lit candle off");
    }
    _g=new LN2Play(7);ln2_play_enter(_g,1);_g.inventory[16]=255;_g.player.x=0;_g.player.y=0;
    ln2_candle_assist_input(_g,16);ln2_candle_assist_input(_g,0);ln2_candle_assist_input(_g,16);
    ln_check(_g.player.x==0 && _g.player.y==0,"distant double fire does not teleport ninja");
    show_debug_message("LN2_TESTING_AIDS_PASS: one-hit mode, damage isolation, persistence, all five candle approaches and tap guards");
}

function ln2_candle_body_checks() {
    for(var _c=0;_c<5;_c++) {
        var _g=new LN2Play(7);ln2_play_enter(_g,1);_g.enemy.active=0;
        var _r=_g.final_rules.rectangles[_c*4];_g.player.x=(_r[0]+_r[2]) div 2+10;_g.player.y=(_r[1]+_r[3]) div 2+5;
        ln2_play_tick(_g,16);repeat(5) ln2_play_tick(_g,0);ln2_play_tick(_g,16);
        ln_check(_g.player.action>=256 && (_g.player.display_frame==69 || _g.player.display_frame==71),"double hash starts visible crouch");
        repeat(35) ln2_play_tick(_g,0);
        ln_check(_g.world_state.candles[_c]>=128,"native double-fire lights candle "+string(_c));
    }
    var _g=new LN2Play(7);ln2_play_enter(_g,1);_g.enemy.x=118;_g.enemy.y=114;
    _g.player.x=118;_g.player.y=114;_g.selected_item=16;_g.inventory[16]=255;
    ln2_item_interact(_g,0);ln_check(_g.inventory[23]==0,"body interaction requires completed ritual");
    _g.world_state.boss_defeated=true;_g.world_state.candles=array_create(5,128);
    _g.selected_item=0;ln2_item_interact(_g,0);ln_check(_g.inventory[23]==0,"body interaction requires held orb");
    _g.selected_item=16;ln2_item_interact(_g,0);
    ln_check(_g.inventory[23]!=0 && _g.inventory[16]==128 && _g.scene_frame==4,"orb at body produces same completion as safe");
    var _score=json_stringify(_g.status.score);ln2_item_interact(_g,0);
    ln_check(json_stringify(_g.status.score)==_score,"orb completion awards once");
    show_debug_message("LN2_CANDLE_BODY_PASS: native double-fire crouch for five candles; held orb at defeated body and completion guards");
}

/// Read-only eligibility for supported held-item mechanisms. The original
/// handler still performs the action and checks its prerequisites on contact.
function ln2_item_use_ready(_g,_item) {
    var _required=-1;
    switch (_g.level) {
        case 1:if (_item.id==17) _required=7;break;
        case 2:if (_item.id==19) _required=11;break;
        case 3:
            if (_item.id==20) _required=12;
            if (_item.id==19) _required=10;
            break;
        case 4:
            if (_item.id==17) _required=13;
            if (_item.id==19 || (_item.id==18 && _g.inventory[19]!=0)) _required=14;
            break;
        case 7:if (_item.id==23 && _g.world_state.boss_defeated) _required=16;break;
    }
    return _required>=0 && _g.selected_item==_required && (_g.inventory[_required]&127)!=0;
}

function ln2_item_use_checks() {
    var _cases=[[1,17,7],[2,19,11],[3,20,12],[3,19,10],[4,17,13],[4,19,14],[4,18,14],[7,23,16]];
    var _g=undefined,_p=undefined,_level=0,_i=0,_pixel=0;
    for(_i=0;_i<array_length(_cases);_i++) {
        var _c=_cases[_i];if (_level!=_c[0]) {_level=_c[0];_g=new LN2Play(_level);}
        var _item={id:_c[1]};_g.inventory[19]=255;_g.world_state.boss_defeated=true;
        _g.inventory[_c[2]]=255;_g.selected_item=0;
        ln_check(!ln2_item_use_ready(_g,_item),"item use requires selected tool");
        _g.selected_item=_c[2];ln_check(ln2_item_use_ready(_g,_item),"supported held-item mechanism");
        _g.inventory[_c[2]]=128;ln_check(!ln2_item_use_ready(_g,_item),"consumed tool cannot assist");
    }
    _g=new LN2Play(4);_g.inventory[14]=255;_g.inventory[19]=0;_g.selected_item=14;
    ln_check(!ln2_item_use_ready(_g,{id:18}),"loaded-tool prerequisite retained");
    _g=new LN2Play(7);_g.inventory[16]=255;_g.selected_item=16;
    ln_check(!ln2_item_use_ready(_g,{id:23}),"orb return still requires defeated Shogun");
    _g=new LN2Play(3);ln2_play_enter(_g,5);_p=_g.player;
    var _target=undefined;
    for(_i=0;_i<array_length(_g.world.items);_i++) if (_g.world.items[_i].id==20) {_target=_g.world.items[_i];break;}
    _g.inventory[20]=0;_g.inventory[12]=255;_g.selected_item=12;_g.enemy.active=0;
    _p.x=_target.x_min-5;_p.y=_target.y_min;_p.action=0;_p.input_lock=0;_p.vehicle=0;
    ln2_refresh_scene(_g);ln_check(_g.scene_frame==0,"grate closed before use");
    var _surface=surface_create(240,144);
    surface_set_target(_surface);draw_sprite(_g.scene,0,0,0);surface_reset_target();
    var _closed=[];for(_pixel=0;_pixel<240*144;_pixel++) array_push(_closed,surface_getpixel(_surface,_pixel mod 240,_pixel div 240));
    // Directional fire and nearby combat retain their usual controls.
    ln2_pickup_assist_input(_g,0);ln2_pickup_assist_input(_g,17);
    ln_check(_p.action==0,"direction and fire retain manual action");
    _g.enemy.active=128;_g.enemy.health=44;_g.enemy.x=_p.x+10;_g.enemy.y=_p.y;
    ln2_pickup_assist_input(_g,0);ln2_pickup_assist_input(_g,16);
    ln_check(_p.action==0,"nearby enemy retains combat priority");_g.enemy.active=0;
    ln2_pickup_assist_input(_g,0);ln2_pickup_assist_input(_g,16);
    ln_check(_p.action>=256,"nearby fire starts tool-use pose");
    var _saved=ln_save_capture(_g);_g=ln_save_restore(json_parse(json_stringify(_saved)));_p=_g.player;
    repeat(100) {if (_g.inventory[20]!=0) break;ln2_play_tick(_g,0);}
    ln_check(_g.inventory[20]!=0 && _g.scene_frame==1,"fire-only grate action opens original panel");
    surface_set_target(_surface);draw_sprite(_g.scene,_g.scene_frame,0,0);surface_reset_target();
    var _changed=0;for(_pixel=0;_pixel<240*144;_pixel++) if(surface_getpixel(_surface,_pixel mod 240,_pixel div 240)!=_closed[_pixel]) _changed++;
    ln_check(_changed==132,"grate displays all 132 recovered changed pixels");surface_free(_surface);
    ln2_play_draw(_g);surface_save(_g.stage_surface,"ln2-sewer-grate-open.png");
    _g=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));_p=_g.player;
    ln_check(_g.scene==spr_ln2_sewer_grate_states && _g.scene_frame==1,"open grate survives save restore");
    ln2_play_enter(_g,4);ln2_play_enter(_g,5);ln_check(_g.scene_frame==1,"open grate survives revisit");
    _p.action=0;_p.boundary_mode=41;_p.boundary_crossings=129;
    ln_check(ln2_boundary_exit(_g) && is_struct(_g.route_descent),"open grate allows existing descent");
    show_debug_message("LN2_ITEM_USE_PASS: eight item mechanisms, tool/prerequisite guards, combat/manual controls, original grate pixels, saves and descent");
}
