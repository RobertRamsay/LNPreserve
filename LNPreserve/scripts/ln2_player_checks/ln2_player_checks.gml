function ln2_player_checks() {
    var _buffer=buffer_load("verification/ln2_player_vectors.json");
    var _oracle=json_parse(buffer_read(_buffer,buffer_text));buffer_delete(_buffer);
    var _count=0,_level=0,_data=undefined;
    for (var _i=0;_i<array_length(_oracle.vectors);_i++) {
        var _v=_oracle.vectors[_i];
        if (_level!=_v.level) {
            _level=_v.level;_buffer=buffer_load("play/ln2/level"+string(_level)+"/gameplay.json");
            _data=json_parse(buffer_read(_buffer,buffer_text));buffer_delete(_buffer);
        }
        _data.boundaries=_v.boundaries;
        var _s=json_parse(json_stringify(_v.initial));_s.display_frame=_s.frame;_s.mirror=false;
        var _fields=variable_struct_get_names(_v.initial);
        for (var _j=0;_j<array_length(_v.frames);_j++) {
            var _f=_v.frames[_j];ln2_player_update(_s,_data,_f.joy,_f.tick);
            for (var _k=0;_k<array_length(_fields);_k++) {
                var _name=_fields[_k],_actual=variable_struct_get(_s,_name),_expected=variable_struct_get(_f.expected,_name);
                ln_check(_actual==_expected,"LN2 level "+string(_level)+" "+_v.name+" step "+string(_j)+" "+_name+
                         " got "+string(_actual)+" expected "+string(_expected));
            }
            ln_check(_s.display_frame==_f.display.frame && _s.mirror==_f.display.mirror,
                     "LN2 original requested pose "+string(_level)+" "+_v.name+" step "+string(_j));
            _count++;
        }
    }
    show_debug_message("LN2_PLAYER_PASS: "+string(_count)+" original player updates across seven level banks; vehicles/world dispatch/system timing excluded.");
}
