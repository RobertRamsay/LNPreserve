function ln3_input_checks() {
    var _b=buffer_load("verification/ln3_input_vectors.json"),_o=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
    var _level=0,_data=undefined,_actions=undefined;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];
        if (_level!=_v.level) {
            _level=_v.level;var _path="play/ln3/level"+string(_level)+"/";
            _b=buffer_load(_path+"input.json");_data=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
            _b=buffer_load(_path+"actions.json");_actions=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
        }
        var _s=_v.before;ln3_input_update(_s,_actions,_data,_v.joy,_v.weapon_switch);
        ln3_state_check(_s,_v.expected,"LN3 input "+string(_i));
    }
    show_debug_message("LN3_INPUT_PASS: "+string(array_length(_o.vectors))+" original input-selection states across five banks.");
}
