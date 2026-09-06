function ln3_movement_checks() {
    var _b=buffer_load("verification/ln3_movement_vectors.json"),_o=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
    var _level=0,_data=undefined;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];
        if (_level!=_v.level) {
            _level=_v.level;_b=buffer_load("play/ln3/level"+string(_level)+"/movement.json");
            _data=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
        }
        var _s=_v.before;
        if (_v.setup) ln3_movement_setup(_s,_data);
        ln3_movement(_s,_data);
        for (var _part=0;_part<8;_part++)
            ln2_compare_fields(_s.parts[_part],_v.expected.parts[_part],"LN3 move "+string(_i)+" part "+string(_part));
        var _keys=variable_struct_get_names(_v.expected);
        for (var _j=0;_j<array_length(_keys);_j++) {
            var _key=_keys[_j];if (_key=="parts") continue;
            var _a=variable_struct_get(_s,_key),_e=variable_struct_get(_v.expected,_key);
            ln_check(_a==_e,"LN3 move "+string(_i)+" "+_key+" got "+string(_a)+" expected "+string(_e));
        }
    }
    show_debug_message("LN3_MOVEMENT_PASS: "+string(array_length(_o.vectors))+" original sprite-part movement states across five banks. Full gameplay remains unconnected.");
}
