function ln3_collision_checks() {
    var _b=buffer_load("verification/ln3_collision_vectors.json"),_o=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
    var _level=0,_room=-1,_data=undefined,_actions=undefined,_bounds=undefined;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];
        if (_level!=_v.level) {
            _level=_v.level;_room=-1;var _path="play/ln3/level"+string(_level)+"/";
            _b=buffer_load(_path+"collision.json");_data=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
            _b=buffer_load(_path+"actions.json");_actions=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
        }
        if (_room!=_v.room_id) {
            _room=_v.room_id;
            for (var _j=0;_j<array_length(_data.rooms);_j++) if (_data.rooms[_j].id==_room) {_bounds=_data.rooms[_j].boundaries;break;}
        }
        var _s=_v.before;ln3_collision_update(_s,_actions,_data,_bounds);
        ln3_state_check(_s,_v.expected,"LN3 collision "+string(_i));
    }
    show_debug_message("LN3_COLLISION_PASS: "+string(array_length(_o.vectors))+" original boundary responses across five banks.");
}
