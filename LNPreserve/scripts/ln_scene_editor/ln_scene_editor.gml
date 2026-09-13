/// Versioned, opt-in scene overrides. No original assets or room logic are edited.
function LNSceneEditor() constructor {
    open=false;enabled=false;scenes={};datasets={};scene=undefined;preview=undefined;
    game=1;level=1;room_id=1;part=-1;asset=0;scroll=0;asset_scroll=0;
    dirty=false;message="F6 closes the editor";undo=[];revision=0;cache=undefined;context=false;
    probe_x=120;probe_y=100;show_ninja=true;show_depth=false;reference=false;build=-1;
    depth_edit=false;depth_hold_dir=0;depth_hold_age=0;depth_hold_next=350000;paused_voices=[];
    pending_pick=undefined;source_scene=undefined;decoded={};drag_before=undefined;dirty_rect=undefined;
    preview_surface=-1;preview_camera=-1;crt_enabled=false;native_preview=false;
    playback=undefined;build_presented=false;selected_panel="parts";drag=false;last_mouse_x=0;last_mouse_y=0;autosave_us=0;
}
function ln_edit_key(_game,_level,_room) {return string(_game)+":"+string(_level)+":"+string(_room);}
function ln_edit_data(_game,_level) {
    var _e,_key,_b;
     _e=global.ln_editor; _key=string(_game)+":"+string(_level);
    if(!variable_struct_exists(_e.datasets,_key)) {
         _b=buffer_load("graphics/ln"+string(_game)+"_game_level"+string(_level)+"/scene_data.json");
        variable_struct_set(_e.datasets,_key,json_parse(buffer_read(_b,buffer_text)));buffer_delete(_b);
    }
    return variable_struct_get(_e.datasets,_key);
}
function ln_edit_flatten(_data,_id,_x,_y,_colour,_flip,_trail,_out) {
    var _key,_o,_entries,_i,_p;
    if(array_length(_trail)>32 || array_contains(_trail,_id)) return _out;
     _key=string(_id);
    if(variable_struct_exists(_data.objects,_key)) {
         _o=variable_struct_get(_data.objects,_key);
        array_push(_out,{source_index:array_length(_out),asset:_id,x:_x,y:_y,flip:_flip,recolour:_colour,mode:0,depth:clamp(_y+_o.height,0,144)});
        return _out;
    }
    if(!variable_struct_exists(_data.panels,_key)) return _out;
    array_push(_trail,_id); _entries=variable_struct_get(_data.panels,_key).entries;
    for( _i=0;_i<array_length(_entries);_i++) {
         _p=_entries[_i];
        _out=ln_edit_flatten(_data,_p.object,_x+_p.x,_y+_p.y,array_length(_p.recolour)>0?_p.recolour:_colour,
            variable_struct_exists(_p,"flip_x")?_p.flip_x:false,_trail,_out);
    }
    return _out;
}
function ln_edit_rooms(_game,_level) {
    var _cache,_path,_world,_ids,_i;
     _cache="rooms:"+string(_game)+":"+string(_level);
    if(variable_struct_exists(global.ln_editor.datasets,_cache)) return variable_struct_get(global.ln_editor.datasets,_cache);
     _path="play/ln"+string(_game)+"/"+((_game==1 && _level==1)?"":"level"+string(_level)+"/");
     _world=ln3_data_read(_path+"world.json"); _ids=[];
    for( _i=0;_i<array_length(_world.rooms);_i++) array_push(_ids,_world.rooms[_i].id);
    variable_struct_set(global.ln_editor.datasets,_cache,_ids);return _ids;
}
function ln_edit_source(_game,_level,_room) {
    var _d,_location,_i;
     _d=ln_edit_data(_game,_level); _location=undefined;
    for( _i=0;_i<array_length(_d.locations);_i++) if(_d.locations[_i].id==_room) {_location=_d.locations[_i];break;}
    if(!is_struct(_location)) return undefined;
    return {game:_game,level:_level,room:_room,background:_location.background,
        parts:ln_edit_flatten(_d,_location.panel,0,0,[],false,[],[])};
}
function ln_edit_free_cache() {
    var _e;
     _e=global.ln_editor;
    if(is_struct(_e.cache)) {
        if(surface_exists(_e.cache.surface)) surface_free(_e.cache.surface);
        if(sprite_exists(_e.cache.mask)) sprite_delete(_e.cache.mask);
        if(variable_struct_exists(_e.cache,"depth_surface") && surface_exists(_e.cache.depth_surface)) surface_free(_e.cache.depth_surface);
    }
    _e.cache=undefined;_e.context=false;
}
function ln_edit_free_preview() {
    var _p;
     if(surface_exists(global.ln_editor.preview_surface)) surface_free(global.ln_editor.preview_surface);global.ln_editor.preview_surface=-1;
    if(global.ln_editor.preview_camera>=0) camera_destroy(global.ln_editor.preview_camera);global.ln_editor.preview_camera=-1;
    _p=global.ln_editor.preview;if(!is_struct(_p)) return;
    if(surface_exists(_p.stage_surface)) surface_free(_p.stage_surface);
    if(_p.game_number==3) {if(surface_exists(_p.part_surface)) surface_free(_p.part_surface);ln3_ending_free(_p);}
    global.ln_editor.preview=undefined;
}
function ln_edit_select(_game,_level,_room) {
    var _e,_source,_key,_epoch,_entry;
     _e=global.ln_editor; _source=ln_edit_source(_game,_level,_room);
    if(!is_struct(_source)) {_e.message="No source part list for that room";return false;}
    _e.game=_game;_e.level=_level;_e.room_id=_room;_e.source_scene=_source;_e.pending_pick=undefined;
     _key=ln_edit_key(_game,_level,_room);
    _e.scene=variable_struct_exists(_e.scenes,_key)?json_parse(json_stringify(variable_struct_get(_e.scenes,_key))):_source;
    _e.part=-1;_e.scroll=0;_e.asset=0;_e.asset_scroll=0;_e.undo=[];_e.build=-1;_e.reference=!variable_struct_exists(_e.scenes,_key);_e.depth_edit=false;_e.depth_hold_dir=0;
    ln_edit_free_cache();ln_edit_free_preview();
    // Preview constructors must not reset the running game's rewind epoch.
     _epoch=global.ln_rewind_epoch;
    _e.preview=_game==1?new LN1Play(_level):(_game==2?new LN2Play(_level):new LN3Play(_level));
    if(_game==1) ln1_play_enter(_e.preview,_room);
    else if(_game==2) ln2_play_enter(_e.preview,_room);
    else {_entry=json_parse(json_stringify(_e.preview.last_entry));_entry.destination=_room;ln3_play_enter(_e.preview,_entry);}
    global.ln_rewind_epoch=_epoch;
    _e.message=string(array_length(_e.scene.parts))+" source parts. Assign depth to props; F6 returns to play.";
    return true;
}
function ln_edit_changed(_before) {
    var _e;
     _e=global.ln_editor;
    if(_e.drag) {
        if(!is_string(_e.drag_before)) _e.drag_before=_before;
        _e.revision++;_e.dirty=true;_e.build=-1;_e.reference=false;return;
    }
    array_push(_e.undo,_before);if(array_length(_e.undo)>30) array_delete(_e.undo,0,1);
    variable_struct_set(_e.scenes,ln_edit_key(_e.game,_e.level,_e.room_id),json_parse(json_stringify(_e.scene)));
    _e.revision++;_e.dirty=true;_e.autosave_us=1000000;_e.build=-1;_e.reference=false;ln_edit_free_cache();
}
function ln_edit_pack() {return {format:"LNPreserve-scenes",version:1,scenes:global.ln_editor.scenes};}
function ln_edit_validate(_pack) {
    var _keys,_i,_s,_required,_j,_d,_p,_fields,_k;
    if(!is_struct(_pack) || !variable_struct_exists(_pack,"format") || _pack.format!="LNPreserve-scenes" ||
        !variable_struct_exists(_pack,"version") || _pack.version!=1 || !variable_struct_exists(_pack,"scenes") || !is_struct(_pack.scenes)) return false;
     _keys=variable_struct_get_names(_pack.scenes);if(array_length(_keys)>400) return false;
    for( _i=0;_i<array_length(_keys);_i++) {
         _s=variable_struct_get(_pack.scenes,_keys[_i]);
        if(!is_struct(_s)) return false;
         _required=["game","level","room","background","parts"];
        for( _j=0;_j<array_length(_required);_j++) if(!variable_struct_exists(_s,_required[_j])) return false;
        if(!is_real(_s.game) || !array_contains([1,2,3],_s.game) || !is_real(_s.level) || is_nan(_s.level) || is_infinity(_s.level) || floor(_s.level)!=_s.level ||
            _s.level<1 || _s.level>(_s.game==1?6:(_s.game==2?7:5)) || !is_real(_s.room) || is_nan(_s.room) || is_infinity(_s.room) || floor(_s.room)!=_s.room ||
            _s.room<0 || _s.room>63 || !is_real(_s.background) || is_nan(_s.background) || is_infinity(_s.background) || floor(_s.background)!=_s.background || _s.background<0 || _s.background>15 ||
            !is_array(_s.parts) || array_length(_s.parts)>1024 || _keys[_i]!=ln_edit_key(_s.game,_s.level,_s.room)) return false;
         _d=ln_edit_data(_s.game,_s.level);
        for( _j=0;_j<array_length(_s.parts);_j++) {
             _p=_s.parts[_j];if(!is_struct(_p)) return false;
             _fields=["asset","x","y","flip","recolour","mode","depth"];
            for( _k=0;_k<array_length(_fields);_k++) if(!variable_struct_exists(_p,_fields[_k])) return false;
            if(!is_real(_p.asset) || !variable_struct_exists(_d.objects,string(_p.asset)) ||
                !is_real(_p.x) || !is_real(_p.y) || is_nan(_p.x) || is_nan(_p.y) || abs(_p.x)>512 || abs(_p.y)>512 ||
                !is_real(_p.depth) || is_nan(_p.depth) || _p.depth<0 || _p.depth>144 ||
                !array_contains([0,1,2],_p.mode) || (!is_bool(_p.flip) && !array_contains([0,1],_p.flip)) ||
                !is_array(_p.recolour) || array_length(_p.recolour)>3) return false;
            for( _k=0;_k<array_length(_p.recolour);_k++) if(!is_real(_p.recolour[_k]) || _p.recolour[_k]<0 || _p.recolour[_k]>255 || is_nan(_p.recolour[_k]) || floor(_p.recolour[_k])!=_p.recolour[_k]) return false;
        }
    }
    return true;
}
function ln_edit_save(_file) {
    var _e,_b;
    if(_file=="") return false;
     _e=global.ln_editor;
    if(is_struct(_e.scene)) variable_struct_set(_e.scenes,ln_edit_key(_e.game,_e.level,_e.room_id),json_parse(json_stringify(_e.scene)));
     _b=-1;
    try {
        _b=buffer_create(1024,buffer_grow,1);buffer_write(_b,buffer_text,json_stringify(ln_edit_pack()));buffer_save(_b,_file);buffer_delete(_b);_b=-1;
        if(!file_exists(_file)) {_e.message="Could not save custom file; edits remain in memory";return false;}
        _e.message="Saved custom scene file";return true;
    } catch(_error) {if(_b>=0) buffer_delete(_b);_e.message="Could not save custom file; edits remain in memory";return false;}
}
function ln_edit_load(_file) {
    var _b,_pack;
    if(_file=="") return false;
    if(!file_exists(_file)) {global.ln_editor.message="Custom file not found; existing edits kept";return false;}
     _b=-1;
    try {
        _b=buffer_load(_file);if(buffer_get_size(_b)>8388608) {buffer_delete(_b);return false;}
         _pack=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);_b=-1;
        if(!ln_edit_validate(_pack)) {global.ln_editor.message="Invalid custom file; existing edits kept";return false;}
        global.ln_editor.scenes=_pack.scenes;global.ln_editor.revision++;ln_edit_free_cache();
        global.ln_editor.message="Custom file loaded. Modified switch controls gameplay.";return true;
    } catch(_error) {if(_b>=0) buffer_delete(_b);global.ln_editor.message="Could not load custom file; existing edits kept";return false;}
}
function ln_edit_build(_scene,_limit=-1,_variant="edit") {
    var _e,_key,_d,_colours,_depth,_attributes,_n,_i,_p,_o,_cw,_y,_x,_dx,_dy,_sx,_cell,_code,_attr,_dest,_old,_blend,_palette,_c,_j,_pixel,_surface,_mask_surface,_b,_mask,_owners,_overlay,_decoded,_at,_incremental,_left,_top,_right,_bottom,_start_x,_end_x,_start_y,_end_y,_reuse,_depth_surface;
     _e=global.ln_editor; _key=ln_edit_key(_scene.game,_scene.level,_scene.room)+":"+string(_e.revision)+":"+string(_limit)+":"+_variant;
    if(is_struct(_e.cache) && _e.cache.key==_key && surface_exists(_e.cache.surface)) return _e.cache;
    _incremental=_variant=="preview" && is_array(_e.dirty_rect) && is_struct(_e.cache) && _e.cache.variant==_variant && surface_exists(_e.cache.surface);
    _left=_incremental?_e.dirty_rect[0]:0;_top=_incremental?_e.dirty_rect[1]:0;
    _right=_incremental?_e.dirty_rect[2]:240;_bottom=_incremental?_e.dirty_rect[3]:144;
    _reuse=_incremental?_e.cache.surface:-1;_depth_surface=_incremental?_e.cache.depth_surface:-1;
    if(!_incremental) ln_edit_free_cache();
     _d=ln_edit_data(_scene.game,_scene.level); _colours=_incremental?_e.cache.colours:array_create(240*144,global.ln_paint_palette[_scene.background]);
     _owners=_incremental?_e.cache.owners:array_create(240*144,-1);_depth=_incremental?_e.cache.depth:array_create(240*144,0); _attributes=array_create(30*18,0); _n=array_length(_scene.parts);
    if(_incremental) for(_y=_top;_y<_bottom;_y++) for(_x=_left;_x<_right;_x++) {
        _pixel=_y*240+_x;_colours[_pixel]=global.ln_paint_palette[_scene.background];_owners[_pixel]=-1;_depth[_pixel]=0;
    }
    if(_limit>=0) _n=min(_n,_limit);
    for( _i=0;_i<_n;_i++) {
         _p=_scene.parts[_i]; _o=variable_struct_get(_d.objects,string(_p.asset)); _cw=_o.width div 8;
        _decoded=ln_edit_decode(_scene,_p,_o);_overlay=variable_struct_exists(_p,"overlay") && _p.overlay;
        _start_x=max(0,_left-round(_p.x));_end_x=min(_o.width,_right-round(_p.x));
        _start_y=max(0,_top-round(_p.y));_end_y=min(_o.height,_bottom-round(_p.y));
        for(_y=_start_y;_y<_end_y;_y++) for(_x=_start_x;_x<_end_x;_x++) {
             _dx=round(_p.x)+_x; _dy=round(_p.y)+_y;if(_dx<0 || _dx>=240 || _dy<0 || _dy>=144) continue;
             _sx=_p.flip?_o.width-1-_x:_x; _cell=(_y div 8)*_cw+(_sx div 8);
             _at=_y*_o.width+_sx;_code=_decoded.codes[_at];
             _attr=_o.colour[_cell]; _dest=(_dy div 8)*30+(_dx div 8); _old=_attributes[_dest];
            if(!_overlay && _old>31 && _attr<=31) continue;
             _blend=_overlay || (_old>31 && _attr>31 && (_attr&16)!=0);
            if(!_blend || _code!=0) {
                 _pixel=_dy*240+_dx;_owners[_pixel]=_code==0?-1:_i;_colours[_pixel]=_decoded.colours[_at];
                _depth[_pixel]=(_code==0 || _p.mode==0)?0:(_p.mode==2?255:clamp(round(_p.depth)+29,1,254));
            }
            if(!_overlay && (_x mod 8)==7 && (_y mod 8)==7) _attributes[_dest]=_blend?(_attr|_old):_attr;
        }
    }
     _surface=surface_exists(_reuse)?_reuse:surface_create(240,144); _mask_surface=-1; _b=buffer_create(240*144*4,buffer_fixed,1);
    for( _i=0;_i<240*144;_i++) buffer_poke(_b,_i*4,buffer_u32,_colours[_i]|$ff000000);
    buffer_set_surface(_b,_surface,0);
    _mask=-1;
    if(_variant=="preview") {
        if(!surface_exists(_depth_surface)) _depth_surface=surface_create(240,144);
        for(_i=0;_i<240*144;_i++) buffer_poke(_b,_i*4,buffer_u32,$ffffff|(_depth[_i]<<24));
        buffer_set_surface(_b,_depth_surface,0);
    }
    if(_variant=="edit") {
    _mask_surface=surface_create(240,144);
    for( _i=0;_i<240*144;_i++) buffer_poke(_b,_i*4,buffer_u32,$ffffff|(_depth[_i]<<24));
    buffer_set_surface(_b,_mask_surface,0);
     _mask=sprite_create_from_surface(_mask_surface,0,0,240,144,false,false,0,0);surface_free(_mask_surface);
    }
    buffer_delete(_b);_e.dirty_rect=undefined;
    _e.cache={key:_key,variant:_variant,surface:_surface,mask:_mask,depth_surface:_depth_surface,depth:_depth,owners:_owners,colours:_colours};return _e.cache;
}
function ln_modified_room(_g) {
    var _e,_key;
    if(!variable_global_exists("ln_editor")) return undefined;
     _e=global.ln_editor; if(!_e.enabled || !is_struct(_g)) return undefined;
    if(!variable_struct_exists(_g,"game_number") || !variable_struct_exists(_g,"level") || !variable_struct_exists(_g,"room_id")) return undefined;
     _key=ln_edit_key(_g.game_number,_g.level,_g.room_id);
    return _e.enabled && variable_struct_exists(_e.scenes,_key)?variable_struct_get(_e.scenes,_key):undefined;
}
function ln_modified_begin(_g) {
    var _e,_s,_b;
     _e=global.ln_editor;_e.context=false; _s=ln_modified_room(_g);
    if(!is_struct(_s)) return false;
     _b=ln_modified_paint_sync(_g);
    ln_edit_build(_s,is_struct(_b) && _b.active?floor(_b.part):-1);_e.context=true;return true;
}
function ln_modified_hidden(_x,_y,_foot) {
    var _e;
     _e=global.ln_editor;
    if((!_e.context && !_e.native_preview) || !is_struct(_e.cache)) return false;
    _x=floor(_x);_y=floor(_y);if(_x<0 || _x>=240 || _y<0 || _y>=144) return false;
    return _e.cache.depth[_y*240+_x]>_foot;
}
function ln_edit_hit(_x,_y,_w,_h) {return mouse_check_button_pressed(mb_left) && mouse_x>=_x && mouse_x<_x+_w && mouse_y>=_y && mouse_y<_y+_h;}
function ln_edit_button(_x,_y,_w,_label,_on=false) {
    draw_set_colour(_on?make_colour_rgb(45,95,110):make_colour_rgb(43,48,57));draw_rectangle(_x,_y,_x+_w,_y+28,false);
    draw_set_colour(c_white);draw_text(_x+6,_y+5,_label);
}
function ln_edit_step(_host) {
    var _e,_s,_file,_i,_g,_max,_level,_d,_ids,_index,_assets,_before,_changed,_id,_o,_p,_swap,_step,_dx,_dy,_held,_delta,_next_depth;
     _e=global.ln_editor;
    if(keyboard_check_pressed(vk_f6)) {
        ln_edit_finish_drag();_e.open=!_e.open;ln_paint_free();_e.depth_edit=false;_e.depth_hold_dir=0;ln_edit_music(_host,_e.open);
        if(_e.open) window_set_cursor(cr_default);
        if(_e.open && !is_struct(_e.scene)) ln_edit_select(_host.play.game_number,_host.play.level,_host.play.room_id);
        if(!_e.open) {_host.input_state=new LNInput();_e.context=false;if(_e.dirty) ln_edit_save("modified-scenes.autosave.json");return true;}
    }
    if(!_e.open) return false;
    if(!mouse_check_button(mb_left)) ln_edit_finish_drag();
    ln_crt_preferences_flush();
    if(keyboard_check_pressed(vk_f10) || ln_edit_hit(1110,18,160,28)) ln_edit_crt_toggle();
    if(keyboard_check_pressed(vk_f9) || ln_edit_hit(1110,62,160,28)) ln_fullscreen_toggle(_host);
     _s=_e.scene;if(!is_struct(_s)) return true;
    if(_e.depth_edit) {
        if(keyboard_check_pressed(vk_escape)) {_e.depth_edit=false;return true;}
        if(keyboard_check_pressed(vk_enter) || (mouse_check_button_pressed(mb_left) && !ln_edit_inside(1162,630,84,28))) {
            ln_edit_depth_accept(keyboard_string);_e.depth_edit=false;return true;
        }
        return true;
    }
    if(!_e.drag && _e.autosave_us>0) {_e.autosave_us-=delta_time;if(_e.autosave_us<=0) ln_edit_save("modified-scenes.autosave.json");}
    if(ln_edit_hit(24,18,180,28)) {_e.enabled=!_e.enabled;_e.playback=undefined;}
    if(ln_edit_hit(216,18,112,28)) { _file=get_save_filename("JSON files|*.json","modified-scenes.json");if(ln_edit_save(_file)) _e.dirty=false;}
    if(ln_edit_hit(340,18,112,28)) { _file=get_open_filename("JSON files|*.json","");if(ln_edit_load(_file)) ln_edit_select(_e.game,_e.level,_e.room_id);}
    if(ln_edit_hit(752,18,132,28)) {if(ln_edit_load("modified-scenes.autosave.json")) ln_edit_select(_e.game,_e.level,_e.room_id);}
    if(ln_edit_hit(464,18,112,28) && array_length(_e.undo)>0) {
        _e.scene=json_parse(array_pop(_e.undo));variable_struct_set(_e.scenes,ln_edit_key(_e.game,_e.level,_e.room_id),json_parse(json_stringify(_e.scene)));_e.revision++;_e.dirty=true;ln_edit_free_cache();_e.autosave_us=1000000;return true;
    }
    if(ln_edit_hit(588,18,152,28)) {_e.reference=false;_e.build=0;_e.build_presented=false;ln_edit_free_cache();}
    if(_e.build>=0 && _e.build_presented) {_e.build+=delta_time/80000*global.ln_paint_speed;if(_e.build>=array_length(_s.parts)) _e.build=-1;}
    for( _i=0;_i<3;_i++) if(ln_edit_hit(24+_i*110,62,102,28)) { _g=_i+1;ln_edit_select(_g,1,ln_edit_rooms(_g,1)[0]);return true;}
    if(ln_edit_hit(900,18,30,28)) global.ln_paint_speed=max(0.1,round((global.ln_paint_speed-0.1)*10)/10);
    if(ln_edit_hit(1060,18,30,28)) global.ln_paint_speed=min(4,round((global.ln_paint_speed+0.1)*10)/10);
     _max=_e.game==1?6:(_e.game==2?7:5);
    if(ln_edit_hit(370,62,30,28) || ln_edit_hit(570,62,30,28)) { _level=clamp(_e.level+(mouse_x<400?-1:1),1,_max); _d=ln_edit_data(_e.game,_level);ln_edit_select(_e.game,_level,ln_edit_rooms(_e.game,_level)[0]);return true;}
     _d=ln_edit_data(_e.game,_e.level); _ids=ln_edit_rooms(_e.game,_e.level);
    if(ln_edit_hit(620,62,30,28) || ln_edit_hit(810,62,30,28)) { _index=0;while(_index<array_length(_ids)-1 && _ids[_index]!=_e.room_id) _index++;_index=clamp(_index+(mouse_x<650?-1:1),0,array_length(_ids)-1);ln_edit_select(_e.game,_e.level,_ids[_index]);return true;}
    if(ln_edit_hit(24,594,140,28)) _e.show_ninja=!_e.show_ninja;
    if(ln_edit_hit(176,594,140,28)) _e.show_depth=!_e.show_depth;
    if(ln_edit_hit(490,594,140,28)) {
        variable_struct_set(_e.scenes,ln_edit_key(_e.game,_e.level,_e.room_id),json_parse(json_stringify(_s)));_e.enabled=true;_e.dirty=true;_e.revision++;ln_edit_free_cache();_e.autosave_us=1000000;_e.message="Room enabled in Modified mode. F6 returns to play.";
    }
     _assets=variable_struct_get_names(_d.objects);array_sort(_assets,function(a,b){return real(a)-real(b);});
    if(mouse_wheel_up()) {if(mouse_x<990) _e.scroll=max(0,_e.scroll-3);else _e.asset_scroll=max(0,_e.asset_scroll-3);}
    if(mouse_wheel_down()) {if(mouse_x<990) _e.scroll=min(max(0,array_length(_s.parts)-18),_e.scroll+3);else _e.asset_scroll=min(max(0,array_length(_assets)-18),_e.asset_scroll+3);}
    for( _i=0;_i<18;_i++) {
        if(ln_edit_hit(760,140+_i*22,225,22) && _e.scroll+_i<array_length(_s.parts)) _e.part=_e.scroll+_i;
        if(ln_edit_hit(1000,140+_i*22,250,22) && _e.asset_scroll+_i<array_length(_assets)) _e.asset=_e.asset_scroll+_i;
    }
     _before=is_string(_e.drag_before)?_e.drag_before:json_stringify(_s); _changed=false;
    if(ln_edit_hit(1000,548,245,28) && array_length(_s.parts)<1024) {
         _id=real(_assets[_e.asset]); _o=variable_struct_get(_d.objects,string(_id));
        ln_edit_add_asset(_id);_changed=true;
    }
    if(_e.part>=0 && _e.part<array_length(_s.parts)) {
         _p=_s.parts[_e.part];
        if(ln_edit_hit(760,548,65,28) && _e.part>0) { _swap=_s.parts[_e.part-1];_s.parts[_e.part-1]=_p;_s.parts[_e.part]=_swap;_e.part--;_changed=true;}
        if(ln_edit_hit(832,548,65,28) && _e.part<array_length(_s.parts)-1) { _swap=_s.parts[_e.part+1];_s.parts[_e.part+1]=_p;_s.parts[_e.part]=_swap;_e.part++;_changed=true;}
        if(ln_edit_hit(904,548,80,28) || keyboard_check_pressed(vk_delete)) {array_delete(_s.parts,_e.part,1);_e.part=min(_e.part,array_length(_s.parts)-1);_changed=true;}
        else {
             _step=keyboard_check(vk_shift)?8:1;
            if(keyboard_check_pressed(vk_left)) {_p.x-=2*_step;_changed=true;}
            if(keyboard_check_pressed(vk_right)) {_p.x+=2*_step;_changed=true;}
            if(keyboard_check_pressed(vk_up)) {_p.y-=_step;_changed=true;}
            if(keyboard_check_pressed(vk_down)) {_p.y+=_step;_changed=true;}
            if(ln_edit_hit(760,630,115,28)) {_p.flip=!_p.flip;_changed=true;}
            if(ln_edit_hit(888,630,180,28)) {_p.mode=(_p.mode+1) mod 3;_changed=true;}
            _held=mouse_check_button(mb_left)?(ln_edit_inside(1080,630,35,28)?-1:(ln_edit_inside(1122,630,35,28)?1:0)):0;
            _delta=ln_edit_depth_repeat(_held,mouse_check_button_pressed(mb_left),delta_time);
            if(_delta!=0) {_next_depth=clamp(_p.depth+_delta,0,144);if(_next_depth!=_p.depth) {_p.depth=_next_depth;_e.show_depth=true;_changed=true;}}
            if(ln_edit_hit(1162,630,84,28)) {_e.depth_edit=true;_e.depth_hold_dir=0;keyboard_string="";_e.drag=false;return true;}
            _p.x=clamp(_p.x,-512,512);_p.y=clamp(_p.y,-512,512);
        }
    }
    // Right-drag moves the ninja; left-drag moves the selected scenery part.
    if(mouse_x>=24 && mouse_x<744 && mouse_y>=140 && mouse_y<572) {
        if(mouse_check_button(mb_right)) {_e.probe_x=clamp((mouse_x-24)/3,0,239);_e.probe_y=clamp((mouse_y-140)/3,0,143);}
        if(mouse_check_button_pressed(mb_left) && keyboard_check(vk_alt)) {
            _e.pending_pick=[floor((mouse_x-24)/3),floor((mouse_y-140)/3)];_e.drag=false;return true;
        }
        if(mouse_check_button_pressed(mb_left)) {_e.drag=true;_e.last_mouse_x=mouse_x;_e.last_mouse_y=mouse_y;}
    }
    if(!mouse_check_button(mb_left)) _e.drag=false;
    if(_e.drag && _e.part>=0 && _e.part<array_length(_s.parts)) {
         _dx=round((mouse_x-_e.last_mouse_x)/6)*2; _dy=round((mouse_y-_e.last_mouse_y)/3);
        if(_dx!=0 || _dy!=0) {ln_edit_move_bounds(_s.parts[_e.part],_dx,_dy);_s.parts[_e.part].x=clamp(_s.parts[_e.part].x+_dx,-512,512);_s.parts[_e.part].y=clamp(_s.parts[_e.part].y+_dy,-512,512);_e.last_mouse_x+=_dx*3;_e.last_mouse_y+=_dy*3;_changed=true;}
    }
    if(_changed) ln_edit_changed(_before);
    return true;
}
function ln_edit_draw() {
    var _e,_s,_view,_projection,_cache,_surface,_camera,_g,_d,_dx,_dy,_i,_sprite,_r,_record,_p,_o,_assets,_j,_a;
     _e=global.ln_editor; _s=_e.scene;if(!is_struct(_s)) return;
    draw_set_font(font_jansina);draw_set_halign(fa_left);draw_set_valign(fa_top);
    draw_clear(make_colour_rgb(20,23,28));draw_set_colour(c_white);
    if(_e.build>=0) _e.build_presented=true;
     _view=matrix_get(matrix_view); _projection=matrix_get(matrix_projection);
     _cache=ln_edit_build(_e.reference?_e.source_scene:_s,_e.build<0?-1:floor(_e.build),_e.reference?"source":"preview");
    if(is_array(_e.pending_pick)) {ln_edit_pick_part(_cache,_e.pending_pick[0],_e.pending_pick[1]);_e.pending_pick=undefined;}
    if(!surface_exists(_e.preview_surface)) _e.preview_surface=surface_create(240,144);
    if(_e.preview_camera<0) _e.preview_camera=camera_create_view(0,0,240,144);
    _surface=_e.preview_surface;
    surface_set_target(_surface); _camera=_e.preview_camera;camera_apply(_camera);draw_clear(c_black);
    if(_e.reference) {
        _sprite=-1;
        for(_r=0;_r<array_length(_e.preview.world.rooms);_r++) {
            _record=_e.preview.world.rooms[_r];if(_record.id==_e.room_id) {_sprite=asset_get_index(_record.sprite);break;}
        }
        if(_sprite>=0) draw_sprite(_sprite,0,0,0);
    } else draw_surface(_cache.surface,0,0);
    _e.context=false; // Native room depth stays active for every editor preview.
    _e.native_preview=true;
    if(_e.show_ninja && _e.build<0 && is_struct(_e.preview)) ln_edit_preview_actor();
    _e.native_preview=false;
    _e.context=false;surface_reset_target();matrix_set(matrix_view,_view);matrix_set(matrix_projection,_projection);
    draw_set_colour(c_white);ln_crt_surface(_surface,24,140,3,1,undefined,_e.crt_enabled);
    if(_e.part>=0 && _e.part<array_length(_s.parts)) {
         _p=_s.parts[_e.part]; _o=variable_struct_get(ln_edit_data(_e.game,_e.level).objects,string(_p.asset));
        draw_set_colour(c_yellow);draw_rectangle(clamp(24+_p.x*3,24,744),clamp(140+_p.y*3,140,572),clamp(24+(_p.x+_o.width)*3,24,744),clamp(140+(_p.y+_o.height)*3,140,572),true);
        if(_e.show_depth) {draw_set_colour(c_aqua);draw_line(24,140+_p.depth*3,744,140+_p.depth*3);}
        draw_set_colour(c_white);draw_text(760,594,"Part "+string(_e.part+1)+"  x "+string(_p.x)+" y "+string(_p.y));
        ln_edit_button(760,630,115,"Flip X",_p.flip);ln_edit_button(888,630,180,["Ground","Depth","Always front"][_p.mode]);
        ln_edit_button(1080,630,35,"-");ln_edit_button(1122,630,35,"+");ln_edit_button(1162,630,84,_e.depth_edit?(keyboard_string+"|"):string(_p.depth),_e.depth_edit);
    }
    ln_edit_button(24,18,180,"Modified: "+(_e.enabled?"ON":"OFF"),_e.enabled);ln_edit_button(216,18,112,"Save file");ln_edit_button(340,18,112,"Load file");ln_edit_button(464,18,112,"Undo");ln_edit_button(588,18,152,"Build preview");
    ln_edit_button(752,18,132,"Recover");
    ln_edit_button(1110,18,160,"Editor CRT "+(_e.crt_enabled?"ON":"OFF")+" F10",_e.crt_enabled);
    ln_edit_button(1110,62,160,"Fullscreen F9",window_get_fullscreen());
    ln_edit_button(900,18,30,"-");draw_set_colour(c_white);draw_text(938,24,string_format(global.ln_paint_speed,1,1)+"x build");ln_edit_button(1060,18,30,"+");
    for( _i=0;_i<3;_i++) ln_edit_button(24+_i*110,62,102,"Ninja "+string(_i+1),_e.game==_i+1);
    ln_edit_button(370,62,30,"<");draw_set_colour(c_white);draw_text(412,68,"Level "+string(_e.level));ln_edit_button(570,62,30,">");
    ln_edit_button(620,62,30,"<");draw_set_colour(c_white);draw_text(662,68,"Room "+string(_e.room_id)+" (ID)");ln_edit_button(810,62,30,">");
    ln_edit_button(24,594,140,"Ninja",_e.show_ninja);ln_edit_button(176,594,140,"Depth line",_e.show_depth);draw_set_colour(make_colour_rgb(150,210,220));draw_text(328,600,"Original depth: ON");ln_edit_button(490,594,140,"Use room");
    draw_set_colour(c_white);draw_text(760,110,"PARTS (draw order)");draw_text(1000,110,"ASSETS (this level)");
     _d=ln_edit_data(_e.game,_e.level); _assets=variable_struct_get_names(_d.objects);array_sort(_assets,function(a,b){return real(a)-real(b);});
    for( _i=0;_i<18;_i++) {
         _j=_e.scroll+_i;if(_j<array_length(_s.parts)) {draw_set_colour(_e.part==_j?c_yellow:c_white);draw_text(760,140+_i*22,string(_j+1)+"  Asset "+string(_s.parts[_j].asset));}
         _a=_e.asset_scroll+_i;if(_a<array_length(_assets)) { _o=variable_struct_get(_d.objects,_assets[_a]);draw_set_colour(_e.asset==_a?c_yellow:c_white);draw_text(1038,140+_i*22,_assets[_a]+"  "+string(_o.width)+"x"+string(_o.height));ln_edit_thumbnail(real(_assets[_a]),1000,140+_i*22,32,20);}
    }
    if(array_length(_assets)>0) ln_edit_thumbnail(real(_assets[_e.asset]),1030,675,190,75);
    ln_edit_button(760,548,65,"Up");ln_edit_button(832,548,65,"Down");ln_edit_button(904,548,80,"Remove");ln_edit_button(1000,548,245,"Add selected asset");
    draw_set_colour(c_white);draw_text(24,646,"Alt-click: select part. Drag/arrows: move. Right-drag: ninja. Shift: larger steps.");
    draw_text(24,670,"Depth line = ground contact. Imported parts start as Ground; assign depth to props.");
    draw_text(24,702,"Visual editing only: original collision paths, pickups and exits stay in place.");
    draw_text(24,726,"Original depth is always active. Edited props retain their own depth settings.");
    draw_set_colour(make_colour_rgb(150,210,220));draw_text(24,760,(_e.dirty?"Unsaved changes | ":"")+_e.message+" | F6 return");
}

function ln_modified_delta_start(_original) {
    var _uv;
    shader_set(sh_ln_modified_delta);
     _uv=sprite_get_uvs(_original,0);
    texture_set_stage(shader_get_sampler_index(sh_ln_modified_delta,"u_original"),sprite_get_texture(_original,0));
    shader_set_uniform_f(shader_get_uniform(sh_ln_modified_delta,"u_original_uv"),_uv[0],_uv[1],_uv[2],_uv[3]);
}
function ln_edit_checks() {
    var _e,_rooms,_parts,_game,_level,_data,_before,_valid,_i,_s,_pack,_original,_c,_saved,_file,_bad,_b,_g;
     _e=global.ln_editor; _rooms=0; _parts=0;
    for( _game=1;_game<=3;_game++) for( _level=1;_level<=(_game==1?6:(_game==2?7:5));_level++) {
         _data=ln_edit_data(_game,_level); _before=json_stringify(_data);
         _valid=ln_edit_rooms(_game,_level);
        for( _i=0;_i<array_length(_valid);_i++) {
             _s=ln_edit_source(_game,_level,_valid[_i]);
            ln_check(is_struct(_s) && is_array(_s.parts),"source room part list "+ln_edit_key(_game,_level,_valid[_i]));
             _pack={format:"LNPreserve-scenes",version:1,scenes:{}};
            variable_struct_set(_pack.scenes,ln_edit_key(_game,_level,_valid[_i]),_s);
            ln_check(ln_edit_validate(_pack),"import validates");_rooms++;_parts+=array_length(_s.parts);
        }
        ln_check(_before==json_stringify(_data),"source data remains unchanged");
    }
    // Synthetic assets give an independent, exact expected image and depth.
     _data=ln_edit_data(1,1); _original=json_stringify(_data);
    variable_struct_set(_data.objects,"999",{width:8,height:8,bitmap:array_create(8,85),screen:[16],colour:[0]});
    variable_struct_set(_data.objects,"998",{width:8,height:8,bitmap:array_create(8,85),screen:[32],colour:[0]});
     _s={game:1,level:1,room:1,background:5,parts:[
        {asset:999,x:2,y:3,flip:false,recolour:[],mode:1,depth:70},
        {asset:998,x:4,y:4,flip:false,recolour:[],mode:2,depth:80}]};
     _c=ln_edit_build(_s);
    ln_check(surface_getpixel(_c.surface,0,0)==global.ln_paint_palette[5],"plain background");
    ln_check(surface_getpixel(_c.surface,2,3)==c_white && surface_getpixel(_c.surface,3,3)==c_white,"double-width pixels");
    ln_check(surface_getpixel(_c.surface,4,4)==global.ln_paint_palette[2],"later part paints above earlier part");
    _e.context=true;
    ln_check(ln_modified_hidden(2,3,98) && !ln_modified_hidden(2,3,100),"depth line separates front and behind");
    ln_check(ln_modified_hidden(4,4,200) && !ln_modified_hidden(0,0,20),"always-front and ground mask");
    _s.parts=[_s.parts[1],_s.parts[0]];_e.revision++;_c=ln_edit_build(_s);
    ln_check(surface_getpixel(_c.surface,4,4)==c_white,"reorder changes visible pixels");
    array_delete(_s.parts,1,1);_e.revision++;_c=ln_edit_build(_s);
    ln_check(surface_getpixel(_c.surface,2,3)==global.ln_paint_palette[5],"remove reveals background");
    _e.scenes={};variable_struct_set(_e.scenes,"1:1:1",_s);
     _saved=json_stringify(_e.scenes); _file="scene-editor-check.tmp.json";
    ln_check(ln_edit_save(_file),"write pack");_e.scenes={};
    ln_check(ln_edit_load(_file),"load custom file: "+_e.message);
    ln_check(ln_rewind_equal(_e.scenes,json_parse(_saved)),"custom file roundtrip");file_delete(_file);
     _bad=json_parse(json_stringify(ln_edit_pack()));variable_struct_get(_bad.scenes,"1:1:1").parts[0].asset=997;
    ln_check(!ln_edit_validate(_bad),"reject unknown asset");
     _b=buffer_create(64,buffer_grow,1);buffer_write(_b,buffer_text,"{broken");buffer_save(_b,_file);buffer_delete(_b);
    ln_check(!ln_edit_load(_file) && ln_rewind_equal(_e.scenes,json_parse(_saved)),"invalid load preserves edits");file_delete(_file);
    _e.enabled=false;ln_check(!is_struct(ln_modified_room({game_number:1,level:1,room_id:1})),"master off preserves original");
    _e.enabled=true;ln_check(is_struct(ln_modified_room({game_number:1,level:1,room_id:1})),"master on selects saved room");
    ln_check(!is_struct(ln_modified_room({game_number:2,level:1,room_id:0})),"unmodified room untouched");
    variable_struct_set(_e.datasets,"1:1",json_parse(_original));_e.scenes={};_e.enabled=false;ln_edit_free_cache();
    ln_edit_gpu_checks();
    // Draw actual in-situ actors, then exercise all three modified game renderers.
    for( _game=1;_game<=3;_game++) {
        ln_check(ln_edit_select(_game,1,ln_edit_rooms(_game,1)[0]),"preview opens");
        _e.show_ninja=true;ln_edit_draw();
        surface_save(application_surface,"scene-editor-preview-"+string(_game)+".png");
         _g=_e.preview;variable_struct_set(_e.scenes,ln_edit_key(_game,1,_g.room_id),_e.scene);_e.enabled=true;
        if(_game==1) ln1_play_draw(_g,false);else if(_game==2) ln2_play_draw(_g);else ln3_play_draw(_g);
        ln_check(!global.ln_editor.context,"mask context does not leak into HUD");
        surface_save(application_surface,"scene-editor-runtime-"+string(_game)+".png");
        _e.enabled=false;
    }
    ln_edit_free_preview();ln_edit_free_cache();_e.scenes={};
    ln_edit_interaction_checks();
    ln_edit_control_checks(self);
    ln_edit_optimization_checks(self);
    show_debug_message("LN_EDITOR_PASS: "+string(_rooms)+" room imports, "+string(_parts)+" parts; composition/depth, save/load validation, mode isolation and three game previews");
}


function ln_edit_thumbnail(_id,_x,_y,_w,_h) {
    var _e,_m,_i,_d,_map,_j,_o,_sprite,_scale;
     _e=global.ln_editor;
    if(!variable_struct_exists(_e,"asset_map")) {
        _e.asset_map={}; _m=ln3_data_read("graphics/manifest.json");
        for( _i=0;_i<array_length(_m.datasets);_i++) {
             _d=_m.datasets[_i]; _map={};
            for( _j=0;_j<array_length(_d.objects);_j++) {
                 _o=_d.objects[_j];variable_struct_set(_map,string(_o.source_id),asset_get_index("spr_"+_o.canonical_name));
            }
            variable_struct_set(_e.asset_map,_d.id,_map);
        }
    }
     _map=variable_struct_get(_e.asset_map,"ln"+string(_e.game)+"_game_level"+string(_e.level));
    if(!variable_struct_exists(_map,string(_id))) return;
     _sprite=variable_struct_get(_map,string(_id));if(_sprite<0) return;
     _scale=min(_w/sprite_get_width(_sprite),_h/sprite_get_height(_sprite));
    draw_sprite_ext(_sprite,0,_x,_y,_scale,_scale,0,c_white,1);
}

// Cosmetic part playback. Source-native timing remains reserved for Original mode.
function ln_modified_paint_sync(_g) {
    var _e,_s,_key;
     _e=global.ln_editor; _s=ln_modified_room(_g);
    if(!is_struct(_s) || !global.ln_preferences_enabled) return undefined;
     _key=ln_edit_key(_g.game_number,_g.level,_g.room_id)+":"+string(_e.revision)+":"+string(global.ln_rewind_epoch);
    if(!is_struct(_e.playback) || _e.playback.key!=_key)
        _e.playback={key:_key,part:0,presented:false,active:array_length(_s.parts)>0,total:array_length(_s.parts)};
    return _e.playback;
}
function ln_modified_paint_tick(_g) {
    var _b;
     _b=ln_modified_paint_sync(_g);if(!is_struct(_b) || !_b.active) return false;
    if(!_b.presented) return true;
    _b.part+=global.ln_paint_speed*_g.timer.cycles_per_frame/_g.timer.hz/0.08;
    if(_b.part>=_b.total) {_b.active=false;return false;}
    return true;
}
function ln_modified_paint_cover() {
    var _e;
     _e=global.ln_editor;
    if(_e.context && is_struct(_e.playback) && _e.playback.active) {
        draw_set_colour(c_white);draw_surface(_e.cache.surface,0,0);_e.playback.presented=true;
    }
}

function ln_edit_gpu_checks() {
    var _v,_p,_camera,_base,_current,_out,_bs,_cs,_e,_g,_s,_before,_limit;
    ln_check(shader_is_compiled(sh_ln_modified_delta),"mechanism delta shader compiled");
     _v=matrix_get(matrix_view); _p=matrix_get(matrix_projection); _camera=camera_create_view(0,0,240,144);
     _base=surface_create(240,144); _current=surface_create(240,144); _out=surface_create(240,144);
    surface_set_target(_base);camera_apply(_camera);draw_clear(c_white);surface_reset_target();
    surface_set_target(_current);camera_apply(_camera);draw_clear(c_white);draw_set_colour(c_red);draw_rectangle(8,8,16,16,false);surface_reset_target();
     _bs=sprite_create_from_surface(_base,0,0,240,144,false,false,0,0); _cs=sprite_create_from_surface(_current,0,0,240,144,false,false,0,0);
    surface_set_target(_out);camera_apply(_camera);draw_clear(c_green);draw_set_colour(c_white);
    ln_modified_delta_start(_bs);draw_sprite(_cs,0,0,0);shader_reset();surface_reset_target();
    ln_check(surface_getpixel(_out,2,2)==c_green,"legacy full panel cannot overwrite unchanged edited background");
    ln_check(surface_getpixel(_out,10,10)==c_red,"changed mechanism pixels remain visible");
    sprite_delete(_bs);sprite_delete(_cs);surface_free(_base);surface_free(_current);surface_free(_out);
    matrix_set(matrix_view,_v);matrix_set(matrix_projection,_p);camera_destroy(_camera);
     _e=global.ln_editor; _g=new LN1Play();_e.scenes={};_e.enabled=true;_e.playback=undefined;
     _s=ln_edit_source(1,1,1);variable_struct_set(_e.scenes,"1:1:1",_s);
    global.ln_preferences_enabled=true;
    ln_check(ln_modified_paint_tick(_g) && _e.playback.part==0,"modified scene waits for first actual presentation");
     _before=_g.player.x;ln1_play_draw(_g,false);
    ln_check(surface_getpixel(_g.stage_surface,20,20)==global.ln_paint_palette[_s.background],"modified first draw is plain background");
    ln_check(_e.playback.presented && ln_modified_paint_tick(_g) && _e.playback.part>0,"modified construction advances only after draw");
     _limit=0;while(ln_modified_paint_tick(_g) && _limit++<1000) {}
    ln_check(!_e.playback.active && _g.player.x==_before,"construction completes without moving player");
    global.ln_preferences_enabled=false;_e.enabled=false;_e.scenes={};_e.playback=undefined;
    if(surface_exists(_g.stage_surface)) surface_free(_g.stage_surface);ln_edit_free_cache();
}

function ln_modified_build_active(_g) {
    return is_struct(ln_modified_room(_g)) && is_struct(global.ln_editor.playback) && global.ln_editor.playback.active;
}

// Hit-test the compositor's visible-pixel ownership, not an asset bounding box.
function ln_edit_pick_part(_cache,_x,_y) {
    var _e=global.ln_editor,_index=-1,_source,_p,_i,_assets;
    if(_x>=0 && _x<240 && _y>=0 && _y<144) _index=_cache.owners[floor(_y)*240+floor(_x)];
    if(_e.reference && _index>=0) {
        _source=_e.source_scene.parts[_index];_index=-1;
        for(_i=0;_i<array_length(_e.scene.parts);_i++) {
            _p=_e.scene.parts[_i];
            if(variable_struct_exists(_p,"source_index")) {
                if(_p.source_index==_source.source_index) {_index=_i;break;}
            } else if(_p.asset==_source.asset && _p.x==_source.x && _p.y==_source.y && _p.flip==_source.flip &&
                json_stringify(_p.recolour)==json_stringify(_source.recolour)) {_index=_i;break;}
        }
    }
    _e.part=_index;
    if(_index<0) {_e.message="No editable part at this pixel";return -1;}
    _e.scroll=clamp(_index-8,0,max(0,array_length(_e.scene.parts)-18));
    _assets=variable_struct_get_names(ln_edit_data(_e.game,_e.level).objects);array_sort(_assets,function(a,b){return real(a)-real(b);});
    for(_i=0;_i<array_length(_assets);_i++) if(real(_assets[_i])==_e.scene.parts[_index].asset) {_e.asset=_i;break;}
    _e.asset_scroll=clamp(_e.asset-8,0,max(0,array_length(_assets)-18));
    _e.message="Selected part "+string(_index+1)+", asset "+string(_e.scene.parts[_index].asset);
    return _index;
}
function ln_edit_preview_actor() {
    var _e=global.ln_editor,_g=_e.preview,_d,_dx,_dy,_i,_spill;
    if(_g.game_number<3) {
        _g.player.x=floor(_e.probe_x);_g.player.y=floor(_e.probe_y)+29;
        if(_g.game_number==2) _g.player.depth_y=_g.player.y;
        if(_g.game_number==1) ln1_play_actor(_g,_g.player,false);else ln2_play_actor(_g,_g.player,false);
    } else {
        _d=json_parse(json_stringify(_g.display));
        _dx=floor(_e.probe_x)-(_d.parts[2].x-24);_dy=floor(_e.probe_y)-(_d.parts[2].y-29);
        for(_i=0;_i<4;_i++) {_d.draw_x[_i]+=_dx;_d.draw_y[_i]+=_dy;_d.parts[_i].x+=_dx;_d.parts[_i].y+=_dy;}
        // Regenerate the native mask at the preview position, using gameplay's own routine.
        _spill=_g.state.mask_spill;ln3_play_prepare_draw(_g,_d);_g.state.mask_spill=_spill;
        for(_i=0;_i<8;_i++) if(_g.animation.order[_i]<4) ln3_play_actor_part(_g,_d,_g.animation.order[_i]);
    }
}

function ln_edit_interaction_checks() {
    var _e=global.ln_editor,_data,_saved,_s,_c,_game,_g,_room,_epoch,_mask,_shapes,_baseline,_visible,_hidden,_dx,_x,_y,_offset,_changes,_i,_original,_state;
    _data=ln_edit_data(1,1);_saved=json_stringify(_data);_e.scene=undefined;_e.reference=false;
    variable_struct_set(_data.objects,"999",{width:8,height:8,bitmap:array_create(8,85),screen:[16],colour:[0]});
    _s={game:1,level:1,room:1,background:5,parts:[
        {source_index:0,asset:999,x:4,y:4,flip:false,recolour:[],mode:0,depth:80},
        {source_index:1,asset:999,x:6,y:6,flip:false,recolour:[],mode:0,depth:80}]};
    _e.scene=_s;_e.source_scene=json_parse(json_stringify(_s));_e.game=1;_e.level=1;_e.room_id=1;ln_edit_free_cache();
    _c=ln_edit_build(_s);
    ln_check(ln_edit_pick_part(_c,7,7)==1,"Alt-click selects top visible part");
    ln_check(ln_edit_pick_part(_c,4,4)==0,"Alt-click selects lower exposed part");
    ln_check(ln_edit_pick_part(_c,0,0)==-1,"Alt-click background selects nothing");
    _s.parts=[_s.parts[1],_s.parts[0]];_s.parts[1].x=40;
    _e.reference=true;
    ln_check(ln_edit_pick_part(_c,4,4)==1,"Original view maps a source part after moving/reordering");
    variable_struct_set(_e.datasets,"1:1",json_parse(_saved));_e.scene=undefined;_e.scenes={};_e.enabled=false;ln_edit_free_cache();
    for(_game=1;_game<=3;_game++) {
        _epoch=global.ln_rewind_epoch;_room=ln_edit_rooms(_game,1)[1];ln_edit_select(_game,1,_room);_g=_e.preview;
        ln_check(_g.room_id==_room && global.ln_rewind_epoch==_epoch,"preview enters selected room without touching live rewind");
        _e.reference=false;_e.probe_x=120;_e.probe_y=100;_e.show_ninja=false;ln_edit_draw();
        _baseline=ln_edit_screen_buffer();
        // Make native masking unambiguously open, then unambiguously closed.
        if(_game<3) {_mask=_g.mask;_g.mask=-1;}
        else {_shapes=_g.mask_shapes;_g.mask_shapes=[];}
        _state=_game==3?json_stringify(_g.state):"";
        _e.show_ninja=true;ln_edit_draw();_visible=ln_edit_screen_buffer();
        ln_check(ln_edit_canvas_difference(_baseline,_visible)>0,"original background does not cover preview ninja");
        if(_game<3) {
            _original=surface_create(240,144);surface_set_target(_original);draw_clear_alpha(c_white,1);surface_reset_target();
            _g.mask=sprite_create_from_surface(_original,0,0,240,144,false,false,0,0);surface_free(_original);
            ln_edit_draw();_hidden=ln_edit_screen_buffer();
            ln_check(ln_edit_canvas_difference(_baseline,_hidden)==0,"original preview uses original actor depth mask");
            buffer_delete(_hidden);sprite_delete(_g.mask);_g.mask=_mask;
        } else {
            _original=json_stringify(_g.display.draw_x);ln_edit_draw();
            ln_check(json_stringify(_g.display.draw_x)==_original,"LN3 stationary preview does not drift");
            _x=_g.display.draw_x[2];_y=_g.display.draw_y[2];_e.probe_x+=8;_e.probe_y+=6;ln_edit_draw();
            ln_check(_g.display.draw_x[2]==_x+8 && _g.display.draw_y[2]==_y+6,"LN3 preview follows requested bitmap position");
            ln_check(json_stringify(_g.state)==_state,"LN3 preview masking does not mutate simulation state");
            _g.mask_shapes=_shapes;
        }
        buffer_delete(_baseline);buffer_delete(_visible);ln_edit_draw();
        surface_save(application_surface,"scene-editor-original-depth-"+string(_game)+".png");
    }
    _e.reference=false;_e.scene=undefined;_e.source_scene=undefined;ln_edit_free_preview();ln_edit_free_cache();
    show_debug_message("LN_EDITOR_INTERACTION_PASS: visible-pixel selection, source mapping, selected-room original masks and stable movable ninja previews");
}
function ln_edit_screen_buffer() {
    var _b=buffer_create(surface_get_width(application_surface)*surface_get_height(application_surface)*4,buffer_fixed,1);
    buffer_get_surface(_b,application_surface,0);return _b;
}
function ln_edit_canvas_difference(_a,_b) {
    var _width=surface_get_width(application_surface),_x,_y,_offset,_count=0;
    for(_y=140;_y<572;_y+=3) for(_x=24;_x<744;_x+=3) {
        _offset=(_y*_width+_x)*4;
        if(buffer_peek(_a,_offset,buffer_u32)!=buffer_peek(_b,_offset,buffer_u32)) _count++;
    }
    return _count;
}

function ln_edit_inside(_x,_y,_w,_h) {return mouse_x>=_x && mouse_x<_x+_w && mouse_y>=_y && mouse_y<_y+_h;}
function ln_edit_add_asset(_id) {
    var _e=global.ln_editor,_s=_e.scene,_o=variable_struct_get(ln_edit_data(_e.game,_e.level).objects,string(_id));
    array_push(_s.parts,{asset:_id,x:80,y:48,flip:false,recolour:[],mode:1,depth:clamp(48+_o.height,0,144),overlay:true});
    _e.part=array_length(_s.parts)-1;_e.scroll=max(0,_e.part-17);_e.reference=false;_e.build=-1;_e.show_depth=true;
}
function ln_edit_depth_repeat(_direction,_pressed,_elapsed) {
    var _e=global.ln_editor,_count=0;
    if(_direction==0) {_e.depth_hold_dir=0;return 0;}
    if(_pressed || _e.depth_hold_dir!=_direction) {
        _e.depth_hold_dir=_direction;_e.depth_hold_age=0;_e.depth_hold_next=350000;return _direction;
    }
    _e.depth_hold_age+=min(_elapsed,250000);
    while(_e.depth_hold_age>=_e.depth_hold_next && _count<16) {
        _count++;_e.depth_hold_next+=_e.depth_hold_next>=1200000?30000:90000;
    }
    return _count*_direction;
}
function ln_edit_depth_accept(_text) {
    var _e=global.ln_editor,_p,_value,_before;
    if(_text=="" || _e.part<0 || _e.part>=array_length(_e.scene.parts)) return false;
    if(string_digits(_text)!=_text || string_length(_text)>6) {_e.message="Depth must be a whole number, 0 to 144";return false;}
    _p=_e.scene.parts[_e.part];_value=clamp(real(_text),0,144);
    if(_value==_p.depth) return false;
    _before=json_stringify(_e.scene);_p.depth=_value;_e.show_depth=true;ln_edit_changed(_before);return true;
}
function ln_edit_music(_host,_pause) {
    var _e=global.ln_editor,_voices=[],_i,_voice;
    if(_pause) {
        _e.paused_voices=[];
        if(variable_global_exists("ln_music_voice")) array_push(_voices,global.ln_music_voice);
        if(_host.play.game_number==3 && is_struct(_host.play.intro)) array_push(_voices,_host.play.intro.voice);
        for(_i=0;_i<array_length(_voices);_i++) {
            _voice=_voices[_i];
            if(_voice>=0 && audio_is_playing(_voice) && !audio_is_paused(_voice) && !array_contains(_e.paused_voices,_voice)) {
                audio_pause_sound(_voice);array_push(_e.paused_voices,_voice);
            }
        }
    } else {
        for(_i=0;_i<array_length(_e.paused_voices);_i++) {
            _voice=_e.paused_voices[_i];if(audio_is_paused(_voice)) audio_resume_sound(_voice);
        }
        _e.paused_voices=[];
    }
}

function ln_edit_control_checks(_host) {
    var _e=global.ln_editor,_count,_slow=0,_fast=0,_i,_previous,_voice,_before;
    ln_edit_select(1,1,1);_count=array_length(_e.scene.parts);
    ln_edit_add_asset(_e.scene.parts[0].asset);
    ln_check(_e.part==_count && _e.scroll==max(0,_count-17) && !_e.reference && _e.scene.parts[_count].overlay,"new asset selected at visible list bottom in edited view");
    ln_check(ln_edit_depth_repeat(1,true,0)==1,"depth press takes one step");
    for(_i=0;_i<10;_i++) _slow+=ln_edit_depth_repeat(1,false,100000);
    for(_i=0;_i<10;_i++) _fast+=ln_edit_depth_repeat(1,false,100000);
    ln_check(_fast>_slow && ln_edit_depth_repeat(0,false,0)==0,"depth hold accelerates and stops on release");
    ln_edit_depth_accept("123");ln_check(_e.scene.parts[_count].depth==123,"direct depth entry");
    ln_edit_depth_accept("999");ln_check(_e.scene.parts[_count].depth==144,"depth entry clamps at scene height");
    ln_edit_depth_accept("oops");ln_check(_e.scene.parts[_count].depth==144,"invalid depth entry leaves value intact");
    _previous=global.ln_music_voice;_voice=audio_play_sound(snd_ln1_dungeons_game,0,true,0);global.ln_music_voice=_voice;
    ln_edit_music(_host,true);ln_check(audio_is_paused(_voice),"editor pauses playing music");
    ln_edit_music(_host,false);ln_check(!audio_is_paused(_voice),"editor resumes its paused music");
    audio_pause_sound(_voice);ln_edit_music(_host,true);ln_edit_music(_host,false);
    ln_check(audio_is_paused(_voice),"editor preserves previously paused music");
    audio_stop_sound(_voice);global.ln_music_voice=_previous;
    show_debug_message("LN_EDITOR_CONTROLS_PASS: add/select, depth repeat/entry, music pause/resume");
}

function ln_edit_decode(_scene,_part,_o) {
    var _e=global.ln_editor,_key=string(_scene.game)+":"+string(_scene.level)+":"+string(_part.asset)+":"+string(_scene.background)+":"+json_stringify(_part.recolour),_result,_cell,_palette,_c,_j,_x,_y,_code,_at;
    if(variable_struct_exists(_e.decoded,_key)) return variable_struct_get(_e.decoded,_key);
    _result={codes:array_create(_o.width*_o.height,0),colours:array_create(_o.width*_o.height,0)};
    for(_cell=0;_cell<array_length(_o.colour);_cell++) {
        _palette=[_scene.background,_o.screen[_cell]>>4,_o.screen[_cell]&15,_o.colour[_cell]&15];
        for(_c=0;_c<array_length(_part.recolour);_c++) for(_j=1;_j<4;_j++) if(_palette[_j]==(_part.recolour[_c]&15)) _palette[_j]=_part.recolour[_c]>>4;
        for(_y=0;_y<8;_y++) for(_x=0;_x<8;_x++) {
            _code=(_o.bitmap[_cell*8+_y]>>(6-2*(_x div 2)))&3;
            _at=((_cell div (_o.width div 8))*8+_y)*_o.width+(_cell mod (_o.width div 8))*8+_x;
            _result.codes[_at]=_code;_result.colours[_at]=global.ln_paint_palette[_palette[_code]];
        }
    }
    variable_struct_set(_e.decoded,_key,_result);return _result;
}
function ln_edit_move_bounds(_part,_dx,_dy) {
    var _e=global.ln_editor,_o=variable_struct_get(ln_edit_data(_e.game,_e.level).objects,string(_part.asset));
    _e.dirty_rect=[clamp(floor(min(_part.x,_part.x+_dx)/8)*8,0,240),clamp(floor(min(_part.y,_part.y+_dy)/8)*8,0,144),
        clamp(ceil((max(_part.x,_part.x+_dx)+_o.width)/8)*8,0,240),clamp(ceil((max(_part.y,_part.y+_dy)+_o.height)/8)*8,0,144)];
}
function ln_edit_finish_drag() {
    var _e=global.ln_editor,_before=_e.drag_before;
    _e.drag=false;_e.drag_before=undefined;
    if(is_string(_before)) ln_edit_changed(_before);
}
function ln_edit_crt_toggle() {
    global.ln_editor.crt_enabled=!global.ln_editor.crt_enabled;
    ln_crt_preferences_flush();
}

function ln_edit_optimization_checks(_host) {
    var _e=global.ln_editor,_game,_i,_p,_c,_expected,_owners,_depth,_stamp,_partial=0,_full=0,_undo,_before,_game_crt,_editor_crt,_off,_on,_file,_persist;
    for(_game=1;_game<=3;_game++) {
        ln_edit_select(_game,1,ln_edit_rooms(_game,1)[1]);_e.reference=false;_e.part=array_length(_e.scene.parts)-1;_p=_e.scene.parts[_e.part];
        ln_edit_build(_e.scene,-1,"preview");
        _undo=array_length(_e.undo);_before=json_stringify(_e.scene);_e.drag=true;
        for(_i=0;_i<6;_i++) {
            ln_edit_move_bounds(_p,2,1);_p.x+=2;_p.y+=1;ln_edit_changed(_before);
            _stamp=get_timer();_c=ln_edit_build(_e.scene,-1,"preview");_partial+=get_timer()-_stamp;
            _expected=json_stringify(_c.colours);_owners=json_stringify(_c.owners);_depth=json_stringify(_c.depth);
            ln_check(_c.mask==-1,"preview never creates a GPU-readback mask sprite");
            ln_edit_free_cache();_stamp=get_timer();_c=ln_edit_build(_e.scene,-1,"preview");_full+=get_timer()-_stamp;
            ln_check(json_stringify(_c.colours)==_expected && json_stringify(_c.owners)==_owners && json_stringify(_c.depth)==_depth,"partial drag redraw matches full colour, ownership and depth arrays");
        }
        ln_check(array_length(_e.undo)==_undo,"drag does not copy undo history each frame");ln_edit_finish_drag();
        ln_check(array_length(_e.undo)==_undo+1 && ln_rewind_equal(json_parse(_e.undo[_undo]),json_parse(_before)),"one complete undo snapshot per drag");
    }
    _game_crt=global.ln_crt_enabled;_editor_crt=_e.crt_enabled;_persist=global.ln_preferences_enabled;global.ln_preferences_enabled=false;
    global.ln_crt_enabled=false;_e.crt_enabled=false;ln_edit_draw();_off=ln_edit_screen_buffer();
    ln_edit_crt_toggle();ln_edit_draw();_on=ln_edit_screen_buffer();
    ln_check(!global.ln_crt_enabled && _e.crt_enabled && ln_edit_canvas_difference(_off,_on)>0,"editor CRT changes only preview without enabling gameplay CRT");
    ln_check(buffer_peek(_off,(115*surface_get_width(application_surface)+765)*4,buffer_u32)==buffer_peek(_on,(115*surface_get_width(application_surface)+765)*4,buffer_u32),"editor panel stays outside CRT");
    surface_save(application_surface,"scene-editor-crt-on.png");buffer_delete(_off);buffer_delete(_on);
    _file="editor-crt-test.ini";ln_crt_preferences_write(_file);_e.crt_enabled=false;global.ln_crt_enabled=true;ln_crt_preferences_read(_file);
    ln_check(_e.crt_enabled && !global.ln_crt_enabled,"editor and gameplay CRT preferences remain independent");file_delete(_file);
    global.ln_crt_enabled=_game_crt;_e.crt_enabled=_editor_crt;global.ln_preferences_enabled=_persist;
    show_debug_message("LN_EDITOR_OPTIMIZATION_PASS: 18 partial/full comparisons; partial us="+string(_partial)+" full us="+string(_full)+"; independent CRT and undo");
}
