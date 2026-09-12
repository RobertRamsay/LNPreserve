/// In-memory same-scene rewind. Full mutable state, no disk-save migrations.
function LNRewind() constructor {
    frames=[];bytes=0;owner=undefined;identity="";epoch=-1;
    active=false;credit=0;last_cycle=-1;
}
function ln_rewind_boundary() {
    if (!variable_global_exists("ln_rewind_epoch")) global.ln_rewind_epoch=0;
    global.ln_rewind_epoch++;
}
function ln_rewind_clear(_r) {
    for (var _i=0;_i<array_length(_r.frames);_i++) buffer_delete(_r.frames[_i].buffer);
    _r.frames=[];_r.bytes=0;_r.last_cycle=-1;_r.credit=0;
}
function ln_rewind_supported(_g) {
    if (ln2_loader_active(_g)) return false;
    if (_g.game_number==2 && _g.victory==2) return false;
    if (_g.game_number==3 && (is_struct(_g.intro) || is_struct(_g.ending))) return false;
    return true;
}
function ln_rewind_pack(_g) {
    // Let the native JSON encoder traverse the data once; GML deep-copying the
    // large source tables first caused visible recording stalls.
    var _state={},_names=variable_struct_get_names(_g);
    for(var _i=0;_i<array_length(_names);_i++) {
        var _key=_names[_i],_value=variable_struct_get(_g,_key);
        if (_key=="timer" || ln_rewind_fixed_field(_key) || is_method(_value)) continue;
        if (_key=="data") {
            var _data={};
            if (_g.game_number!=3) {
                _data.initial=_g.player;_data.boundaries=_g.data.boundaries;
                if (variable_struct_exists(_g.data,"sewer_recessed")) _data.sewer_recessed=_g.data.sewer_recessed;
            }
            variable_struct_set(_state,_key,_data);continue;
        }
        variable_struct_set(_state,_key,string_pos("surface",_key)>0?-1:_value);
    }
    if (_g.game_number==1) variable_struct_remove(_g.player,"world_game");
    var _text;
    try {_text=json_stringify({state:_state,cycle:_g.timer.cycle,frame:_g.timer.frame});}
    catch(_error) {if (_g.game_number==1) _g.player.world_game=_g;throw _error;}
    if (_g.game_number==1) _g.player.world_game=_g;
    var _b=buffer_create(string_byte_length(_text)+1,buffer_fixed,1);buffer_write(_b,buffer_text,_text);
    var _packed=buffer_compress(_b,0,buffer_tell(_b));buffer_delete(_b);
    return {buffer:_packed,cycle:_g.timer.cycle,size:buffer_get_size(_packed)};
}
function ln_rewind_free_surfaces(_g) {
    // Gameplay owns these three render targets. Intro/outro are excluded.
    var _keys=["stage_surface","part_surface","ending_surface"];
    for(var _i=0;_i<array_length(_keys);_i++) if (variable_struct_exists(_g,_keys[_i])) {
        var _surface=variable_struct_get(_g,_keys[_i]);if (surface_exists(_surface)) surface_free(_surface);
    }
}
function ln_rewind_restore(_g,_snapshot) {
    var _b=buffer_decompress(_snapshot.buffer),_saved=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
    var _s=_saved.state,_names=variable_struct_get_names(_g);
    ln_rewind_free_surfaces(_g);
    for(var _i=0;_i<array_length(_names);_i++) {
        var _key=_names[_i];if (_key=="timer" || ln_rewind_fixed_field(_key)) continue;
        if (!variable_struct_exists(_s,_key)) variable_struct_remove(_g,_key);
    }
    _names=variable_struct_get_names(_s);
    for(var _i=0;_i<array_length(_names);_i++) {
        var _key=_names[_i],_value=variable_struct_get(_s,_key);
        if (_key=="data") {
            var _fields=variable_struct_get_names(_value);
            for(var _j=0;_j<array_length(_fields);_j++) variable_struct_set(_g.data,_fields[_j],variable_struct_get(_value,_fields[_j]));
        } else variable_struct_set(_g,_key,_value);
    }
    if (_g.game_number==1) {
        _g.player.world_game=_g;_g.data.initial=_g.player;
        _g.world.rooms[_g.room_id-1].boundaries=_g.data.boundaries;
    } else {
        for(var _i=0;_i<array_length(_g.world.rooms);_i++)
            if (_g.world.rooms[_i].id==_g.room_id) {_g.world.rooms[_i]=_g.scene_record;break;}
        if (_g.game_number==2) _g.data.initial=_g.player;
    }
    _g.timer.cycle=int64(_saved.cycle);_g.timer.frame=_saved.frame;_g.timer.credit=int64(0);
}
function ln_rewind_music(_host,_pause) {
    if (!variable_global_exists("ln_music_voice") || global.ln_music_voice<0) return;
    var _g=_host.play,_enabled=_g.game_number==1?(!is_struct(_g.controls) || _g.controls.music!=0):_g.music;
    if (_pause || !_enabled) audio_pause_sound(global.ln_music_voice);else audio_resume_sound(global.ln_music_voice);
}
function ln_rewind_release(_host) {
    var _r=_host.rewind;
    if (!_r.active) return;
    _r.active=false;_r.credit=0;_r.last_cycle=_host.play.timer.cycle;
    // Discard input edges observed in the abandoned future; sample current keys afresh.
    _host.input_state=new LNInput();_host.elapsed_us=(_host.play.timer.cycle*1000000) div _host.play.timer.hz;
    if (is_struct(_host.play.controls)) _host.control_state_ln1=_host.play.controls;
    ln_rewind_music(_host,false);
}
function ln_rewind_sync(_host) {
    if (!variable_global_exists("ln_rewind_epoch")) global.ln_rewind_epoch=0;
    var _r=_host.rewind,_g=_host.play,_id=string(_g.game_number)+":"+string(_g.level)+":"+string(_g.room_id);
    if (_r.owner!=_g || _r.identity!=_id || _r.epoch!=global.ln_rewind_epoch) {
        ln_rewind_release(_host);ln_rewind_clear(_r);
        _r.owner=_g;_r.identity=_id;_r.epoch=global.ln_rewind_epoch;
    }
    if (!ln_rewind_supported(_g)) {ln_rewind_release(_host);ln_rewind_clear(_r);return false;}
    return true;
}
function ln_rewind_step(_host,_held=undefined) {
    if (is_undefined(_held)) _held=keyboard_check(vk_left);
    if (!ln_rewind_sync(_host)) return false;
    var _r=_host.rewind;
    if (_host.workbench || _host.scene_test.menu || _host.scene_test.preview || !_held) {
        ln_rewind_release(_host);return false;
    }
    if (!_r.active) {
        if (array_length(_r.frames)==0) return false;
        _r.active=true;_r.credit=50000;ln_rewind_music(_host,true);
    } else _r.credit+=min(delta_time,100000);
    while (_r.credit>=50000 && array_length(_r.frames)>0) {
        _r.credit-=50000;
        var _snapshot=array_pop(_r.frames);_r.bytes-=_snapshot.size;
        ln_rewind_restore(_host.play,_snapshot);buffer_delete(_snapshot.buffer);
        if (is_struct(_host.play.controls)) _host.control_state_ln1=_host.play.controls;
    }
    // At the start of history stay still until Left Arrow is released.
    return true;
}
function ln_rewind_record(_host) {
    if (!ln_rewind_sync(_host) || _host.workbench || _host.scene_test.menu || _host.scene_test.preview) return;
    var _r=_host.rewind,_g=_host.play;
    if (_r.active || (_r.last_cycle>=0 && _g.timer.cycle-_r.last_cycle<_g.timer.hz/10)) return;
    if (_g.game_number==1?(is_struct(_g.controls) && _g.controls.pause!=0):_g.paused) return;
    var _frame=ln_rewind_pack(_g);array_push(_r.frames,_frame);_r.bytes+=_frame.size;_r.last_cycle=_g.timer.cycle;
    while (array_length(_r.frames)>100 || _r.bytes>32*1024*1024) {
        var _old=_r.frames[0];_r.bytes-=_old.size;buffer_delete(_old.buffer);array_delete(_r.frames,0,1);
        if (array_length(_r.frames)==0) break;
    }
}

function ln_rewind_checks() {
    for(var _game=1;_game<=3;_game++) for(var _level=1;_level<=(_game==1?6:(_game==2?7:5));_level++) {
        var _g=_game==1?new LN1Play(_level):(_game==2?new LN2Play(_level):new LN3Play(_level));
        if (_game==1) _g.controls=ln3_data_read("actors/ln1/initial_control_state.json");
        var _before=json_stringify(ln_save_copy(_g)),_start=get_timer(),_snapshot=ln_rewind_pack(_g);
        var _cost=get_timer()-_start;
        if (_game==3) {_g.state.player_health=0;_g.state.inventory[5]=99;_g.state.player_x+=30;}
        else {_g.player_health=0;_g.inventory[5]=99;_g.player.x+=30;}
        _g.rewind_future_only=123;
        ln_rewind_restore(_g,_snapshot);
        ln_check(!variable_struct_exists(_g,"rewind_future_only"),"rewind removes future-only state");
        ln_check(ln_rewind_equal(ln_save_copy(_g),json_parse(_before)),"whole-scene rewind equality game "+string(_game));
        buffer_delete(_snapshot.buffer);
        // Identical native input must produce the same subsequent complete state.
        _snapshot=ln_rewind_pack(_g);
        repeat(12) {if (_game==1) ln1_play_tick(_g,0);else if (_game==2) ln2_play_tick(_g,0);else ln3_play_tick(_g,0);}
        var _after=json_stringify(ln_save_copy(_g));ln_rewind_restore(_g,_snapshot);
        repeat(12) {if (_game==1) ln1_play_tick(_g,0);else if (_game==2) ln2_play_tick(_g,0);else ln3_play_tick(_g,0);}
        ln_check(ln_rewind_equal(ln_save_copy(_g),json_parse(_after)),"rewind replay determinism game "+string(_game));
        buffer_delete(_snapshot.buffer);
        show_debug_message("LN_REWIND_SAMPLE: game "+string(_game)+" level "+string(_level)+" capture_us "+string(_cost)+" compressed_bytes "+string(_snapshot.size));
        ln_rewind_free_surfaces(_g);
    }
    ln_rewind_history_checks();
    show_debug_message("LN_REWIND_PASS: whole-state restore and forward replay for all three games");
}

function ln_rewind_equal(_a,_b) {
    if (is_array(_a)) {
        if (!is_array(_b) || array_length(_a)!=array_length(_b)) return false;
        for(var _i=0;_i<array_length(_a);_i++) if (!ln_rewind_equal(_a[_i],_b[_i])) return false;
        return true;
    }
    if (is_struct(_a)) {
        if (!is_struct(_b)) return false;
        var _keys=variable_struct_get_names(_a);
        if (array_length(_keys)!=array_length(variable_struct_get_names(_b))) return false;
        for(var _i=0;_i<array_length(_keys);_i++) {
            var _k=_keys[_i];if (!variable_struct_exists(_b,_k) || !ln_rewind_equal(variable_struct_get(_a,_k),variable_struct_get(_b,_k))) return false;
        }
        return true;
    }
    return _a==_b;
}

/// Source tables are prepared at entry, which clears history. Current collision
/// boundaries and data.initial are captured separately; world/scene records stay
/// in every snapshot because interactions can change them during play.
function ln_rewind_fixed_field(_key) {
    return array_contains(["animation","actions","input","collision","movement","combat","masks","items","enemies",
        "scenery","special","status_data","transition","mechanisms","projectile_data","navigation","water_data",
        "final_rules","final_art","boss_release","item_flow","boat_support","ending_data","projectile_art","projectile_bodies"],_key);
}

function ln_rewind_history_checks() {
    var _g=new LN1Play();_g.controls=ln3_data_read("actors/ln1/initial_control_state.json");
    var _h={play:_g,rewind:new LNRewind(),workbench:false,scene_test:{menu:false,preview:false},
        input_state:new LNInput(),elapsed_us:0,control_state_ln1:_g.controls};
    for(var _i=0;_i<105;_i++) {
        _g.timer.cycle+=ceil(_g.timer.hz/10);_g.player.x=_i;ln_rewind_record(_h);
    }
    ln_check(array_length(_h.rewind.frames)==100 && _h.rewind.bytes<32*1024*1024,"history is bounded");
    _g.player.x=200;ln_check(ln_rewind_step(_h,true) && _g.player.x==104,"Left Arrow restores most recent point");
    _h.rewind.credit=50000;ln_rewind_step(_h,true);
    ln_check(_g.player.x==103,"holding Left Arrow rewinds further");
    ln_check(!ln_rewind_step(_h,false) && !_h.rewind.active,"release resumes play");
    _g.player.x=77;_g.timer.cycle+=ceil(_g.timer.hz/10);ln_rewind_record(_h);
    ln_rewind_step(_h,true);ln_check(_g.player.x==77,"new history follows resumed branch");
    _h.scene_test.menu=true;ln_rewind_step(_h,true);
    ln_check(!_h.rewind.active,"F11 suspends rewind");_h.scene_test.menu=false;
    ln_rewind_boundary();ln_rewind_sync(_h);
    ln_check(array_length(_h.rewind.frames)==0,"scene boundaries clear history");
    ln_rewind_record(_h);_h.play=new LN1Play();ln_rewind_sync(_h);
    ln_check(array_length(_h.rewind.frames)==0,"new or loaded game clears history");
    ln_frontend_begin(_h.play);ln_check(!ln_rewind_sync(_h),"loader has no rewind history");
    ln_rewind_clear(_h.rewind);ln_rewind_free_surfaces(_g);ln_rewind_free_surfaces(_h.play);
    show_debug_message("LN_REWIND_HISTORY_PASS: bounded history, hold/release, branch, menu, scene and load resets");
}
