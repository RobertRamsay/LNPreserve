function ln3_item_checks() {
    var _o=ln3_data_read("verification/ln3_item_vectors.json"),_level=0,_data=undefined;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];
        if (_level!=_v.level) {_level=_v.level;_data=ln3_data_read("play/ln3/level"+string(_level)+"/items.json");}
        var _s=_v.before,_r=ln3_room_record(_data.rooms,_v.room_id);
        var _found=ln3_items_update(_s,_data,_r.items);
        ln_check(_found==_v.found,"LN3 item notice "+string(_i));
        ln3_state_check(_s,_v.expected,"LN3 item "+string(_i));
    }
    show_debug_message("LN3_ITEMS_PASS: "+string(array_length(_o.vectors))+" original pickup/mechanism and proximity states.");
}
