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
    var _world=ln3_data_read("play/ln3/level1/world.json");
    var _g={world:_world},_d={enemy_costume:0,draw_frames:[-1,-1,-1,-1,206,70,-1,-1],draw_mirror:array_create(8,false)};
    for(var _costume=0;_costume<3;_costume++) {
        _d.enemy_costume=_costume;
        for(var _mirror=0;_mirror<2;_mirror++) {
            _d.draw_mirror[4]=_mirror!=0;
            var _offset=ln3_part_registration(_g,_d,4);
            ln_check(_offset[0]==(_mirror?-2:2) && _offset[1]==-1,"Earth outline registration mirrors with actor");
        }
    }
    _d.enemy_costume=3;
    ln_check(ln3_part_registration(_g,_d,4)[0]==0,"special encounter registration unchanged");
    _d.enemy_costume=0;_d.draw_frames[5]=71;
    ln_check(ln3_part_registration(_g,_d,4)[0]==0,"unrelated body frames unchanged");
    show_debug_message("LN3_ANIMATION_PASS: "+string(_total)+" original animation updates and part placements across five banks.");
}
