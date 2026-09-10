/// Local save slots. Native state only; surfaces and methods are rebuilt.
function ln_save_copy(_value) {
    if (is_array(_value)) {
        var _a=array_create(array_length(_value));
        for (var _i=0;_i<array_length(_a);_i++) _a[_i]=ln_save_copy(_value[_i]);
        return _a;
    }
    if (is_struct(_value)) {
        var _s={},_names=variable_struct_get_names(_value);
        for (var _i=0;_i<array_length(_names);_i++) {
            var _key=_names[_i],_v=variable_struct_get(_value,_key);
            if (is_method(_v) || (_key=="timer" || _key=="world_game")) continue;
            // Surface handles have no meaning after restarting the runner.
            variable_struct_set(_s,_key,string_pos("surface",_key)>0?-1:ln_save_copy(_v));
        }
        return _s;
    }
    return _value;
}

function ln_save_read(_path) {
    var _b=buffer_load(_path);
    if (_b<0) throw "Cannot read save file";
    var _text=buffer_read(_b,buffer_text);buffer_delete(_b);
    return json_parse(_text);
}

function ln_save_write(_path,_value) {
    var _temp=_path+".tmp",_backup=_path+".bak";
    var _text=json_stringify(_value),_b=buffer_create(string_byte_length(_text)+1,buffer_fixed,1);
    buffer_write(_b,buffer_text,_text);buffer_save(_b,_temp);buffer_delete(_b);
    // Verify the new file before rotating the last readable version.
    ln_save_read(_temp);
    if (file_exists(_backup)) file_delete(_backup);
    if (file_exists(_path)) file_rename(_path,_backup);
    file_rename(_temp,_path);
    if (!file_exists(_path)) {
        if (file_exists(_backup)) file_rename(_backup,_path);
        throw "Cannot write save file";
    }
}

function LNSaves() constructor {
    slots=[];message="";message_ticks=0;ready=true;
    directory_create("save_slots");
    if (file_exists("save_slots/index.json") || file_exists("save_slots/index.json.bak")) {
        try {
            var _index;
            try {_index=ln_save_read("save_slots/index.json");}
            catch (_read_error) {_index=ln_save_read("save_slots/index.json.bak");}
            if (_index.version!=1 || !is_array(_index.slots) || array_length(_index.slots)>10) throw "Invalid save list";
            slots=_index.slots;
        } catch (_error) {ready=false;message="Save list unreadable";message_ticks=300;}
    }
}

function ln_save_capture(_g) {
    var _state=ln_save_copy(_g);
    // Compiled asset IDs may change in a later build; persist their names.
    for (var _i=0;_i<2;_i++) {
        var _key=_i==0?"scene":"mask";
        if (variable_struct_exists(_g,_key)) {
            var _id=variable_struct_get(_g,_key);
            variable_struct_set(_state,_key,sprite_exists(_id)?sprite_get_name(_id):"");
        }
    }
    return {version:1,game:_g.game_number,level:_g.level,room:_g.room_id,cycle:_g.timer.cycle,frame:_g.timer.frame,state:_state};
}

function ln_save_restore(_save) {
    if (_save.version!=1 || _save.game<1 || _save.game>3 || _save.level<1 ||
        _save.level>(_save.game==1?6:(_save.game==2?7:5)) || !is_struct(_save.state)) throw "Incompatible save";
    var _g=_save.game==1?new LN1Play(_save.level):(_save.game==2?new LN2Play(_save.level):new LN3Play(_save.level));
    var _fresh_ln2_actions=_save.game==2?_g.data.actions:undefined;
    var _state=ln_save_copy(_save.state),_names=variable_struct_get_names(_state);
    for (var _i=0;_i<array_length(_names);_i++) {
        var _key=_names[_i];
        if (_key=="timer") continue;
        variable_struct_set(_g,_key,variable_struct_get(_state,_key));
    }
    for (var _i=0;_i<2;_i++) {
        var _key=_i==0?"scene":"mask";
        if (variable_struct_exists(_g,_key)) variable_struct_set(_g,_key,asset_get_index(variable_struct_get(_g,_key)));
    }
    if (_g.game_number!=_save.game || _g.level!=_save.level || _g.room_id!=_save.room) throw "Invalid save identity";
    if (_save.game==2) {
        // Saves contain their original action graph. Add newly recovered roots
        // without replacing saved animation records or player progression.
        var _action_names=variable_struct_get_names(_fresh_ln2_actions);
        for(var _j=0;_j<array_length(_action_names);_j++) {
            var _action_name=_action_names[_j];
            if (!variable_struct_exists(_g.data.actions,_action_name))
                variable_struct_set(_g.data.actions,_action_name,variable_struct_get(_fresh_ln2_actions,_action_name));
        }
        if (_g.level==1 && _g.room_id==17 && _g.inventory[19]!=0 && _g.special_mode==0 &&
            _g.enemy.custom && _g.enemy.display_frame==255 && _g.enemy.action==($cd79&255)) {
            ln2_environment_action(_g,$cd79);_g.special_mode=8;_g.enemy.action_tick=_g.player.tick;
        }
    }

    var _room_ok=false;
    for (var _i=0;_g.game_number!=1 && _i<array_length(_g.world.rooms);_i++) {
        if (_g.world.rooms[_i].id==_g.room_id) {_room_ok=true;break;}
    }
    // LN1 rooms are indexed rather than carrying an id field.
    if (_g.game_number==1) _room_ok=_g.room_id>=1 && _g.room_id<=array_length(_g.world.rooms);
    if (!_room_ok) throw "Invalid saved room";
    // Reconnect the mutable current-room records detached by JSON copying.
    if (_g.game_number==1) {
        ln1_reverse_roll_prepare(_g.data);
        if (_g.level==2) for(var _i=0;_i<array_length(_g.world.items);_i++) {
            var _item=_g.world.items[_i];
            if (_item.room==17 && _item.id==16) _item.flash_sprite="spr_ln1_level2_pickup_16_flash";
        }
        _g.player.world_game=_g;
        _g.data.initial=_g.player;
        _g.world.rooms[_g.room_id-1].boundaries=_g.data.boundaries;
    }
    else {
        for (var _i=0;_i<array_length(_g.world.rooms);_i++) {
            if (_g.world.rooms[_i].id==_g.room_id) {_g.world.rooms[_i]=_g.scene_record;break;}
        }
    }
    if (_g.game_number==2 && _g.level==7) {
        // Migrate the temporary loaned orb from the previous test build.
        if (_g.inventory[16]==1) {_g.inventory[16]=0;if (_g.selected_item==16) _g.selected_item=0;}
        if (_g.room_id==1) ln2_refresh_scene(_g);
    }
    if (_g.game_number==2 && _g.level==2) ln2_refresh_scene(_g);
    _g.timer.cycle=int64(_save.cycle);_g.timer.frame=_save.frame;_g.timer.credit=int64(0);
    return _g;
}

function ln_save_add(_ui,_g) {
    if (!_ui.ready) return;
    try {
        var _lives=_g.game_number==3?_g.state.lives:_g.lives_left;
        var _name="LN"+string(_g.game_number)+"_SAVE_"+string(_g.level)+string(_lives)+string(_g.room_id);
        var _id=0;
        while (file_exists("save_slots/state_"+string(_id)+".json")) _id++;
        var _path="save_slots/state_"+string(_id)+".json";
        ln_save_write(_path,ln_save_capture(_g));
        var _slots=[{name:_name,game:_g.game_number,path:_path}];
        for (var _i=0;_i<min(9,array_length(_ui.slots));_i++) array_push(_slots,_ui.slots[_i]);
        ln_save_write("save_slots/index.json",{version:1,slots:_slots});
        // Keep the old state's file for the backup index. At most 11 referenced
        // snapshots are retained: ten visible slots and one recovery slot.
        var _keep=[_path];
        for (var _i=0;_i<array_length(_ui.slots);_i++) array_push(_keep,_ui.slots[_i].path);
        var _file=file_find_first("save_slots/state_*.json",0);
        while (_file!="") {
            var _full="save_slots/"+_file;
            if (!array_contains(_keep,_full)) file_delete(_full);
            _file=file_find_next();
        }
        file_find_close();
        _ui.slots=_slots;_ui.message="Saved "+_name;_ui.message_ticks=180;
    } catch (_error) {_ui.message="Save failed";_ui.message_ticks=300;show_debug_message("LN_SAVE_ERROR: "+string(_error));}
}

function ln_saves_step(_host) {
    var _ui=_host.saves;
    if (_ui.message_ticks>0) _ui.message_ticks--;
    if (_host.workbench || _host.scene_test.menu || _host.scene_test.preview) return false;
    if (keyboard_check(vk_control) && keyboard_check_pressed(ord("S"))) {
        ln_save_add(_ui,_host.play);return true;
    }
    if (!mouse_check_button_pressed(mb_left) || mouse_x<1128 || mouse_x>=1272) return false;
    var _slot=floor((mouse_y-116)/46);
    if (mouse_y<116 || _slot<0 || _slot>=array_length(_ui.slots)) return false;
    try {
        var _fresh=ln_save_restore(ln_save_read(_ui.slots[_slot].path)),_old=_host.play;
        for (var _i=0;_i<3;_i++) {
            var _key=["stage_surface","part_surface","ending_surface"][_i];
            if (variable_struct_exists(_old,_key)) {
                var _s=variable_struct_get(_old,_key);if (surface_exists(_s)) surface_free(_s);
            }
        }
        if (_old.game_number==3 && is_struct(_old.ending) && surface_exists(_old.ending.scroll_surface)) surface_free(_old.ending.scroll_surface);
        _fresh.timer.cycles_per_frame=_fresh.data.timer_period_cycles;
        _host.play=_fresh;
        if (is_struct(_fresh.controls)) _host.control_state_ln1=_fresh.controls;
        else _fresh.controls=_host.control_state_ln1;
        _host.input_state=new LNInput();
        _host.elapsed_us=(_fresh.timer.cycle*1000000) div _fresh.timer.hz;
        if (variable_global_exists("ln_music_voice") && global.ln_music_voice>=0) audio_stop_sound(global.ln_music_voice);
        var _level=_host.scene_test.levels;
        for (var _i=0;_i<array_length(_level);_i++) {
            if (_level[_i].game==_fresh.game_number && _level[_i].number==_fresh.level) {
                ln_music_play(_fresh.game_number,string_replace_all(string_lower(_level[_i].title)," ","_"),false);break;
            }
        }
        _ui.message="Loaded "+_ui.slots[_slot].name;_ui.message_ticks=180;
    } catch (_error) {_ui.message="Load failed";_ui.message_ticks=300;show_debug_message("LN_LOAD_ERROR: "+string(_error));}
    return true;
}

function ln_saves_draw(_ui) {
    draw_set_colour(make_colour_rgb(24,28,34));draw_rectangle(1128,84,1272,620,false);
    draw_set_colour(c_white);draw_text(1136,92,"SAVES  Ctrl+S");
    for (var _i=0;_i<10;_i++) {
        var _y=116+46*_i,_filled=_i<array_length(_ui.slots);
        var _hover=mouse_x>=1128 && mouse_x<1272 && mouse_y>=_y && mouse_y<_y+46;
        draw_set_colour(_hover && _filled?make_colour_rgb(53,74,82):make_colour_rgb(32,37,44));
        draw_rectangle(1132,_y,1268,_y+42,false);
        draw_set_colour(_filled?c_white:make_colour_rgb(130,138,146));
        var _label=_filled?_ui.slots[_i].name:"Empty";
        var _scale=min(1,124/max(1,string_width(_label)));
        draw_text_transformed(1138,_y+4,_label,_scale,1,0);
        if (_filled) {
            draw_set_colour(make_colour_rgb(150,190,170));
            var _hint="Click to load",_hint_scale=min(1,124/max(1,string_width(_hint)));
            draw_text_transformed(1138,_y+22,_hint,_hint_scale,1,0);
        }
    }
    draw_set_colour(c_white);draw_text(1136,584,"Newest at top");
    if (_ui.message_ticks>0) draw_text_ext(24,84,_ui.message,18,120);
}

/// Serialization checks run with the existing native selftest, without touching saves.
function ln_save_checks(_ln1_only=false) {
    for (var _game=1;_game<=(_ln1_only?1:3);_game++) {
        var _g=_game==1?new LN1Play(2):(_game==2?new LN2Play():new LN3Play());
        if (_game==3) {_g.state.lives=4;_g.state.player_health=7;_g.state.inventory[0]=128;}
        else {_g.lives_left=4;_g.player_health=7;_g.inventory[_game==1?11:1]=1;}
        if (_game==1) {_g.player.action=$aa1e;_g.player.countdown=3;_g.world_state.mode=7;}
        _g.timer.cycle=int64(1234567);
        var _saved=json_parse(json_stringify(ln_save_capture(_g)));
        var _loaded=ln_save_restore(_saved);
        ln_check(_loaded.game_number==_game && _loaded.level==_g.level && _loaded.room_id==_g.room_id,
            "save restores game, level and room");
        ln_check(is_method(_loaded.timer.advance) && _loaded.timer.cycle==1234567 && _loaded.stage_surface==-1,
            "save rebuilds clock methods and excludes GPU handles");
        if (_game==3) ln_check(_loaded.state.lives==4 && _loaded.state.player_health==7 && _loaded.state.inventory[0]==128,"LN3 saved lives, health and weapon");
        else ln_check(_loaded.lives_left==4 && _loaded.player_health==7 && _loaded.inventory[_game==1?11:1]==1,"saved lives, health and weapon");
        if (_game==1) {
            ln_check(_loaded.player.action==$aa1e && _loaded.player.countdown==3 && _loaded.world_state.mode==7,
                "save preserves active animation and encounter state");
            ln_check(_loaded.player.world_game==_loaded,"save reconnects LN1 pickup callback to loaded world");
            _loaded.inventory[11]=0;
            ln_check(_g.inventory[11]==1,"loaded inventory does not mutate original snapshot");
        }
    }
}
