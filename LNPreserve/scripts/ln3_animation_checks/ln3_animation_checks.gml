function ln3_animation_checks() {
    var _b=buffer_load("verification/ln3_animation_vectors.json"),_o=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
    var _level=0,_data=undefined,_total=0;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];
        if (_level!=_v.level) {
            _level=_v.level;_b=buffer_load("play/ln3/level"+string(_level)+"/animation.json");
            _data=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
        }
        var _s=_v.initial;
        for (var _f=0;_f<array_length(_v.frames);_f++) {
            ln3_animation_update(_s,_data);ln3_state_check(_s,_v.frames[_f],"LN3 animation "+string(_i)+" frame "+string(_f));_total++;
        }
    }
    show_debug_message("LN3_ANIMATION_PASS: "+string(_total)+" original animation updates and part placements across five banks.");
}
