/// Source item records retain their action, facing, and approach rectangles.
function ln2_item_interact(_g,_kind) {
    var _p=_g.player;
    for (var _i=0;_i<array_length(_g.world.items);_i++) {
        var _item=_g.world.items[_i];
        if (_item.room!=_g.room_id || _item.action!=_kind || _g.inventory[_item.id]!=0) continue;
        if (_item.facing!=0 && _item.facing!=_p.facing) continue;
        if (_p.x<_item.x_min || _p.x>=_item.x_max || _p.y<_item.y_min || _p.y>=_item.y_max) continue;
        var _id=ln2_item_handler(_g,_item);
        if (_id<0) continue;
        if (_id!=255) {
            if (_g.inventory[_id]==0) _g.inventory[_id]=_id==4?137:255;
            if (_id<17) { _g.notice_item=_id;_g.notice_tick=_p.tick;_g.notice_duration=100; }
        }
        ln2_refresh_scene(_g);
        return;
    }
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
            if (_id==23) return _selected==16 && _g.world_state.boss_defeated?_id:-1;
            break;
    }
    var _key="item:"+string(_item.handler);
    if (!array_contains(_g.pending_events,_key)) array_push(_g.pending_events,_key);
    return -1;
}

function ln2_refresh_scene(_g) {
    // Scene variants are source-rendered and selected by their inventory flags.
    var _room=_g.scene_record;
    _g.scene=asset_get_index(_room.sprite);
    if (variable_struct_exists(_room,"variants")) {
        var _bits=0;
        for (var _i=0;_i<array_length(_room.variant_flags);_i++)
            if (_g.inventory[_room.variant_flags[_i]]!=0) _bits|=1<<_i;
        _g.scene=asset_get_index(_room.variants[_bits]);
    }
}
