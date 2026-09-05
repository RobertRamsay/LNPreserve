function ln2_enemy_checks() {
    var _buffer=buffer_load("verification/ln2_enemy_vectors.json");
    var _oracle=json_parse(buffer_read(_buffer,buffer_text));buffer_delete(_buffer);
    var _count=0,_level=0,_data=undefined;
    for (var _i=0;_i<array_length(_oracle.vectors);_i++) {
        var _v=_oracle.vectors[_i];
        if (_level!=_v.level) {
            _level=_v.level;_buffer=buffer_load("play/ln2/level"+string(_level)+"/gameplay.json");
            _data=json_parse(buffer_read(_buffer,buffer_text));buffer_delete(_buffer);
        }
        _data.boundaries=_v.boundaries;
        var _g={data:_data,player:json_parse(json_stringify(_v.player)),enemy:json_parse(json_stringify(_v.initial)),
                random_queue:[],random_head:0,tick_epoch:_v.tick_epoch};
        var _e=_g.enemy;_e.display_frame=_e.frame;_e.mirror=false;
        var _fields=variable_struct_get_names(_v.initial);
        for (var _j=0;_j<array_length(_v.frames);_j++) {
            var _f=_v.frames[_j];_g.player.tick=_f.tick;_g.random_queue=_f.randoms;_g.random_head=0;
            ln2_enemy_decide(_g);ln2_enemy_action(_g);
            for (var _k=0;_k<array_length(_fields);_k++) {
                var _name=_fields[_k],_actual=variable_struct_get(_e,_name),_expected=variable_struct_get(_f.expected,_name);
                ln_check(_actual==_expected,"LN2 enemy level "+string(_level)+" "+_v.name+" step "+string(_j)+" "+_name+
                         " got "+string(_actual)+" expected "+string(_expected));
            }
            ln_check(_g.random_head==array_length(_f.randoms),"LN2 enemy random consumption "+_v.name);
            ln_check(_e.display_frame==_f.display.frame && _e.mirror==_f.display.mirror,
                     "LN2 enemy requested pose "+string(_level)+" "+_v.name+" step "+string(_j));
            _count++;
        }
    }
    show_debug_message("LN2_ENEMY_PASS: "+string(_count)+" original enemy updates across seven level banks; world dispatch and hardware random timing excluded.");
}
