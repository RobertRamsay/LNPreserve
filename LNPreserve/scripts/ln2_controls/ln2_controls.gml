/// Original $9292-$9357 selection effects, supplied with remapped keyboard rows.
function ln2_controls_update(_g,_row0,_row7) {
    var _masks=[16,32,64,8,16],_pressed=array_create(5,false);
    for (var _i=0;_i<5;_i++) {
        var _value=(_i==4?_row7:_row0)&_masks[_i];
        _pressed[_i]=_value!=_g.control_previous[_i] && _value==0;_g.control_previous[_i]=_value;
    }
    if (_pressed[0]) {
        _g.music=!_g.music;
        if (variable_global_exists("ln_music_voice") && global.ln_music_voice>=0) {
            if (_g.music) audio_resume_sound(global.ln_music_voice);else audio_pause_sound(global.ln_music_voice);
        }
    }
    for (var _direction=0;_direction<2;_direction++) {
        if (!_pressed[1+_direction]) continue;
        repeat(13) {
            if (_direction==0) { if (_g.selected_item==0) _g.selected_item=4;_g.selected_item++;if (_g.selected_item==17) _g.selected_item=0; }
            else { if (_g.selected_item==0) _g.selected_item=17;_g.selected_item--;if (_g.selected_item==4) _g.selected_item=0; }
            if (_g.inventory[_g.selected_item]&127) break;
        }
        if (_direction==1) _g.notice_item=-1;
    }
    if (_pressed[3]) _g.paused=!_g.paused;
    if (_pressed[4] && !_g.player_projectile_active) {
        repeat(5) {
            _g.player.selected_weapon=(_g.player.selected_weapon+1) mod 5;
            if (_g.inventory[_g.player.selected_weapon]&127) break;
        }
    }
}

function ln_game_select(_g,_game,_level) {
    if (_game==_g.game_number) return _game==1?ln1_level_load(_g,_level):(_game==2?ln2_level_load(_g,_level):ln3_level_load(_g,_level));
    if (_g.game_number==3) ln3_ending_free(_g);
    if (_g.game_number==2) ln2_ending_free(_g);
    if (variable_struct_exists(_g,"part_surface") && surface_exists(_g.part_surface)) {surface_free(_g.part_surface);_g.part_surface=-1;}
    var _fresh=_game==1?new LN1Play(_level):(_game==2?new LN2Play(_level):new LN3Play(_level));
    var _transport=_g.timer,_surface=_g.stage_surface,_controls=_g.controls;
    var _names=variable_struct_get_names(_fresh);
    for (var _i=0;_i<array_length(_names);_i++) variable_struct_set(_g,_names[_i],variable_struct_get(_fresh,_names[_i]));
    _g.timer=_transport;_g.timer.cycles_per_frame=_g.data.timer_period_cycles;_g.stage_surface=_surface;_g.controls=_controls;
    if (_game==1) { _g.player.world_game=_g;ln1_level_sync_controls(_g); }
    ln_music_play(_game,string_replace_all(string_lower(_g.title)," ","_"),false);
    return true;
}
