/// Source item records retain their action, facing, and approach rectangles.
function ln2_item_interact(_g,_kind) {
    var _p=_g.player;
    for (var _i=0;_i<array_length(_g.world.items);_i++) {
        var _item=_g.world.items[_i];
        var _test_orb=_g.level==7 && _item.id==16 && _g.inventory[16]==1;
        if (_item.room!=_g.room_id || _item.action!=_kind || (_g.inventory[_item.id]!=0 && !_test_orb)) continue;
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
    ln2_final_test_setup(_g);
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
    // Source item completion draws these panels immediately, not on room entry.
    if (_g.level==7 && _g.room_id==1) {
        _g.safe_scene_phase=_g.inventory[23]!=0?4:(_g.inventory[18]!=0?(_g.inventory[16]==255?3:2):1);
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

/// Temporary final-room testing aid: remove the orb grant after testing.
function ln2_final_test_setup(_g) {
    if (_g.level!=7 || _g.room_id!=1) return;
    _g.inventory[17]=255; // Reveal the wall safe on arrival.
    if (_g.inventory[16]==0 && _g.inventory[23]==0) {
        // 1 is a loaned orb; 255 means the safe-removal interaction occurred.
        _g.inventory[16]=1;_g.selected_item=16;_g.notice_item=-1;
    }
}

function ln2_final_room_checks() {
    var _g=new LN2Play(7);ln2_play_enter(_g,1);
    ln_check(_g.scene==spr_ln2_safe_states && _g.scene_frame==1,"wall safe visible on arrival");
    ln_check(_g.inventory[16]==1 && _g.selected_item==16,"temporary orb available without skipping removal");
    _g.player.x=175;_g.player.y=83;_g.player.facing=1;ln2_item_interact(_g,0);
    ln_check(is_struct(_g.keypad),"safe interaction opens keypad");
    _g.keypad.digits=array_create(4);array_copy(_g.keypad.digits,0,_g.keycode,0,4);
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
    ln2_keypad_checks();
    show_debug_message("LN2_FINAL_ROOM_PASS: visible safe, temporary orb, keypad, removal/release, five candles, orb return and save/revisit");
}
