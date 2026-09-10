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
        // The original oracle explicitly excludes combat/world dispatch.
        // Use no encounter room and an ordinary costume; contextual revival
        // effects are checked separately below. Do not alter oracle fields.
        var _g={level:_level,room_id:-1,world_state:{boss_defeated:false,candles:array_create(5,0)},data:_data,player:json_parse(json_stringify(_v.player)),enemy:json_parse(json_stringify(_v.initial)),
                random_queue:[],random_head:0,tick_epoch:_v.tick_epoch};
        var _e=_g.enemy;_e.costume=0;_e.display_frame=_e.frame;_e.mirror=false;
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

function ln2_revival_context_checks() {
    for(var _level=6;_level<=7;_level++) for(var _room=1;_room<=2;_room++)
    for(var _costume=0;_costume<=2;_costume+=2) for(var _defeated=0;_defeated<2;_defeated++) {
        var _g=new LN2Play(_level),_e=_g.enemy;
        _g.room_id=_room;_g.player.tick=64;_g.tick_epoch=255;
        _g.player.x=20;_g.player.y=20;
        _e.active=128;_e.costume=_costume;_e.mode=11;_e.knockouts=128;
        _e.recovery_time=0;_e.decision_tick=0;_e.x=150;_e.y=100;_e.facing=1;
        _g.world_state.boss_defeated=bool(_defeated);_g.world_state.candles=array_create(5,1);
        ln2_enemy_decide(_g);
        ln_check(_e.mode==7 && _e.health==44,"enemy recovery remains enabled");
        var _clears=_level==7 && _room==1 && _costume==2 && !_defeated;
        for(var _i=0;_i<5;_i++) ln_check(_g.world_state.candles[_i]==(_clears?0:1),
            "only undefeated final-room Shogun revival extinguishes candles");
    }
    show_debug_message("LN2_REVIVAL_CONTEXT_PASS: 16 guard/boss, room, level and defeat contexts.");
}
