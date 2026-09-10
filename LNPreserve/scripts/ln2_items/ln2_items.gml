/// Source item records retain their action, facing, and approach rectangles.
function ln2_item_interact(_g,_kind) {
    var _p=_g.player;
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
            case 16:_g.safe_scene_phase=3;break;
            case 23:_g.safe_scene_phase=4;break;
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
                _g.world_state.code_visible=true;return 18;
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
    // Source item completion draws these panels immediately, not on room entry.
    if (_g.level==7 && _g.room_id==1 && _g.safe_scene_phase>0) {
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
