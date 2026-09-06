function ln3_mask_checks() {
    var _b=buffer_load("verification/ln3_mask_vectors.json"),_o=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
    var _level=0,_room=-1,_data=undefined,_shapes=undefined;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];
        if (_level!=_v.level) {
            _level=_v.level;_room=-1;_b=buffer_load("play/ln3/level"+string(_level)+"/masks.json");
            _data=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
        }
        if (_room!=_v.room_id) {
            _room=_v.room_id;
            for (var _j=0;_j<array_length(_data.rooms);_j++) if (_data.rooms[_j].id==_room) {_shapes=_data.rooms[_j].shapes;break;}
        }
        var _s={mask_spill:_v.spill},_bytes=ln3_mask_bytes(_s,_shapes,_v.x,_v.y,_v.foot);
        for (var _j=0;_j<63;_j++) ln_check(_bytes[_j]==_v.expected[_j],"LN3 mask "+string(_i)+" byte "+string(_j)+" got "+string(_bytes[_j])+" expected "+string(_v.expected[_j]));
        ln_check(_s.mask_spill==_v.expected_spill,"LN3 mask "+string(_i)+" retained fragment");
    }
    show_debug_message("LN3_MASK_PASS: "+string(array_length(_o.vectors))+" original sprite masks across 66 scenes.");
}
