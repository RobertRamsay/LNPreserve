function ln3_state_check(_s,_expected,_label) {
    var _keys=variable_struct_get_names(_expected);
    for (var _j=0;_j<array_length(_keys);_j++) {
        var _key=_keys[_j],_a=variable_struct_get(_s,_key),_e=variable_struct_get(_expected,_key);
        if (_key=="parts") {
            for (var _i=0;_i<8;_i++) ln2_compare_fields(_a[_i],_e[_i],_label+" part "+string(_i));
        } else if (is_array(_e)) {
            for (var _i=0;_i<array_length(_e);_i++) ln_check(_a[_i]==_e[_i],_label+" "+_key+" "+string(_i)+" got "+string(_a[_i])+" expected "+string(_e[_i]));
        } else ln_check(_a==_e,_label+" "+_key+" got "+string(_a)+" expected "+string(_e));
    }
}

function ln3_action_checks() {
    var _b=buffer_load("verification/ln3_action_vectors.json"),_o=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
    var _level=0,_data=undefined;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];
        if (_level!=_v.level) {
            _level=_v.level;_b=buffer_load("play/ln3/level"+string(_level)+"/actions.json");
            _data=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
        }
        var _s=_v.before;ln3_action_set(_s,_data,_v.action,_v.action>=39);
        ln3_state_check(_s,_v.expected,"LN3 action "+string(_i));
    }
    show_debug_message("LN3_ACTION_PASS: "+string(array_length(_o.vectors))+" original player/enemy action states across five banks.");
}
