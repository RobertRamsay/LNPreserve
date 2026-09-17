/// Versioned, opt-in scene overrides. No original assets or room logic are edited.
function LNSceneEditor() constructor {
    maps={};map_undo=[];map_redo=[];map_open=false;map_room=-1;map_edge=0;map_scroll=0;
    nav_job=undefined;nav_last_nodes=0;nav_last_us=0;enemy_edit=false;enemy_index=0;enemy_drag=false;enemy_waypoint=-1;enemy_catalogs={};enemy_catalog_building=false;
    test_music_restore=undefined;test_active=false;
    open=false;toggle_requested=false;enabled=false;scenes={};datasets={};bitmap_baselines={};scene=undefined;preview=undefined;
    game=1;level=1;room_id=1;part=-1;asset=0;scroll=0;asset_scroll=0;
    dirty=false;message="F6 closes the editor";undo=[];redo=[];revision=0;cache=undefined;context=false;
    probe_x=120;probe_y=100;show_ninja=true;show_depth=false;reference=false;build=-1;
    depth_edit=false;depth_hold_dir=0;depth_hold_age=0;depth_hold_next=350000;paused_voices=[];
    pending_pick=undefined;source_scene=undefined;decoded={};drag_before=undefined;dirty_rect=undefined;
    preview_surface=-1;preview_camera=-1;crt_enabled=false;native_preview=false;
    pulse_selected=true;pulse_time_us=0;show_collisions=false;collision_shapes=[];collision_edit=false;collision_index=-1;collision_scroll=0;collision_before=undefined;collision_drag_record=undefined;collision_handle=-1;collision_mouse=[0,0];
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
    return {game:_game,level:_level,room:_room,preserve_bitmap:true,background:_location.background,
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
    _e.collision_index=-1;_e.collision_scroll=0;_e.collision_before=undefined;
    _e.enemy_drag=false;_e.enemy_waypoint=-1;_e.enemy_index=0;
    _e.game=_game;_e.level=_level;_e.room_id=_room;_e.source_scene=_source;_e.pending_pick=undefined;
     _key=ln_edit_key(_game,_level,_room);
    _e.scene=variable_struct_exists(_e.scenes,_key)?json_parse(json_stringify(variable_struct_get(_e.scenes,_key))):_source;
    _e.scene.preserve_bitmap=true;
    _e.part=-1;_e.scroll=0;_e.asset=0;_e.asset_scroll=0;_e.undo=[];_e.redo=[];_e.build=-1;_e.reference=!variable_struct_exists(_e.scenes,_key);_e.depth_edit=false;_e.depth_hold_dir=0;
    ln_edit_free_cache();ln_edit_free_preview();
    // Preview constructors must not reset the running game's rewind epoch.
     _epoch=global.ln_rewind_epoch;
    _e.preview=_game==1?new LN1Play(_level):(_game==2?new LN2Play(_level):new LN3Play(_level));
    ln_edit_spawn_preview();
    ln_edit_collision_refresh();
    global.ln_rewind_epoch=_epoch;
    _e.message=string(array_length(_e.scene.parts))+" source parts. Assign depth to props; F6 returns to play.";
    return true;
}
function ln_edit_changed(_before) {
    var _e;
     _e=global.ln_editor;
    _e.enabled=true;
    if(_e.drag) {
        if(!is_string(_e.drag_before)) _e.drag_before=_before;
        _e.revision++;_e.dirty=true;_e.build=-1;_e.reference=false;return;
    }
    _e.redo=[];array_push(_e.undo,_before);if(array_length(_e.undo)>30) array_delete(_e.undo,0,1);
    variable_struct_set(_e.scenes,ln_edit_key(_e.game,_e.level,_e.room_id),json_parse(json_stringify(_e.scene)));
    _e.revision++;_e.dirty=true;_e.autosave_us=1000000;_e.build=-1;_e.reference=false;ln_edit_free_cache();
}
function ln_edit_pack() {return {format:"LNPreserve-scenes",version:1,scenes:global.ln_editor.scenes,maps:global.ln_editor.maps};}
function ln_edit_validate(_pack) {
    var _keys,_i,_s,_required,_j,_d,_p,_fields,_k;
    if(!is_struct(_pack) || !variable_struct_exists(_pack,"format") || _pack.format!="LNPreserve-scenes" ||
        !variable_struct_exists(_pack,"version") || _pack.version!=1 || !variable_struct_exists(_pack,"scenes") || !is_struct(_pack.scenes)) return false;
    if(variable_struct_exists(_pack,"maps") && !ln_map_validate(_pack.maps)) return false;
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
        if(!ln_collision_validate(_s) || !ln_enemy_validate(_s)) return false;
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
            if(variable_struct_exists(_p,"depth_override") && !is_bool(_p.depth_override)) return false;
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
        global.ln_editor.maps=variable_struct_exists(_pack,"maps")?_pack.maps:{};global.ln_editor.map_undo=[];global.ln_editor.map_redo=[];
        global.ln_editor.scenes=_pack.scenes;global.ln_editor.revision++;ln_edit_free_cache();
        global.ln_editor.enabled=true;
        global.ln_editor.message="Custom file loaded. Modified ON.";return true;
    } catch(_error) {if(_b>=0) buffer_delete(_b);global.ln_editor.message="Could not load custom file; existing edits kept";return false;}
}
function ln_edit_build(_scene,_limit=-1,_variant="edit") {
    var _e,_key,_d,_colours,_depth,_attributes,_n,_i,_p,_o,_cw,_y,_x,_dx,_dy,_sx,_cell,_code,_attr,_dest,_old,_blend,_palette,_c,_j,_pixel,_surface,_mask_surface,_b,_mask,_owners,_overlay,_decoded,_at,_incremental,_left,_top,_right,_bottom,_start_x,_end_x,_start_y,_end_y,_reuse,_depth_surface,_overrides,_baseline,_owner,_source_owner,_output,_display,_edited_underlay,_edits;
     _e=global.ln_editor; _key=ln_edit_key(_scene.game,_scene.level,_scene.room)+":"+string(_e.revision)+":"+string(_limit)+":"+_variant;
    if(is_struct(_e.cache) && _e.cache.key==_key && surface_exists(_e.cache.surface)) return _e.cache;
    _baseline=(_variant!="source" && _limit<0 && variable_struct_exists(_scene,"preserve_bitmap") && _scene.preserve_bitmap)?ln_edit_bitmap_baseline(_scene):undefined;
    _edits=is_struct(_baseline)?ln_edit_source_changes(_scene):undefined;
    _incremental=_variant=="preview" && is_array(_e.dirty_rect) && is_struct(_e.cache) && _e.cache.variant==_variant && surface_exists(_e.cache.surface);
    _left=_incremental?_e.dirty_rect[0]:0;_top=_incremental?_e.dirty_rect[1]:0;
    _right=_incremental?_e.dirty_rect[2]:240;_bottom=_incremental?_e.dirty_rect[3]:144;
    _reuse=_incremental?_e.cache.surface:-1;_depth_surface=_incremental?_e.cache.depth_surface:-1;
    if(!_incremental) ln_edit_free_cache();
     _d=ln_edit_data(_scene.game,_scene.level); _colours=_incremental?_e.cache.colours:array_create(240*144,global.ln_paint_palette[_scene.background]);
     _owners=_incremental?_e.cache.owners:array_create(240*144,-1);_depth=_incremental?_e.cache.depth:array_create(240*144,0); _attributes=array_create(30*18,0); _n=array_length(_scene.parts);
    _overrides=_incremental?_e.cache.overrides:array_create(240*144,false);
    if(_incremental) for(_y=_top;_y<_bottom;_y++) for(_x=_left;_x<_right;_x++) {
        _pixel=_y*240+_x;_colours[_pixel]=global.ln_paint_palette[_scene.background];_owners[_pixel]=-1;_depth[_pixel]=0;_overrides[_pixel]=false;
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
            _pixel=_dy*240+_dx;_owner=_owners[_pixel];
            // Original background pixels must not punch holes in an edited prop
            // underneath. Keep native attribute merging independent of this alpha rule.
            _edited_underlay=_code==0 && _owner>=0 && variable_struct_exists(_scene.parts[_owner],"overlay") && _scene.parts[_owner].overlay;
            if((!_blend || _code!=0) && !_edited_underlay) {
                 _owners[_pixel]=_code==0?-1:_i;_colours[_pixel]=_decoded.colours[_at];
                _overrides[_pixel]=_code!=0 && (_p.mode!=0 || (variable_struct_exists(_p,"depth_override") && _p.depth_override));
                _depth[_pixel]=(_code==0 || _p.mode==0)?0:(_p.mode==2?255:clamp(round(_p.depth)+29,1,254));
            }
            if(!_overlay && (_x mod 8)==7 && (_y mod 8)==7) _attributes[_dest]=_blend?(_attr|_old):_attr;
        }
    }
     _surface=surface_exists(_reuse)?_reuse:surface_create(240,144); _mask_surface=-1; _b=buffer_create(240*144*4,buffer_fixed,1);
    _display=_incremental?_e.cache.display_colours:array_create(240*144,0);
    for(_y=_top;_y<_bottom;_y++) for(_x=_left;_x<_right;_x++) {
        _i=_y*240+_x;_output=_colours[_i];
        if(is_struct(_baseline) && _scene.background==_baseline.background) {
            _owner=_owners[_i];_source_owner=-1;
            if(_owner>=0) _source_owner=variable_struct_exists(_scene.parts[_owner],"source_index")?_scene.parts[_owner].source_index:-2;
            if(!(_source_owner>=0 && _edits.changed[_source_owner]) && _source_owner==_baseline.owners[_i] && _output==_baseline.colours[_i]) _output=_baseline.original[_i];
            // The diagnostic source palette may differ from the native bitmap.
            // When revealing an unchanged layer, recover its local palette from
            // visible pixels of that same layer, never from the removed prop.
            else if(_scene.game==3 && _baseline.owners[_i]>=0 && _edits.changed[_baseline.owners[_i]] &&
                (_source_owner<0 || !_edits.changed[_source_owner]))
                _output=ln_edit_revealed_colour(_baseline,_source_owner,_output,_x,_y);
        }
        if(is_struct(_edits)) {
            _owner=_owners[_i];_source_owner=-1;
            if(_owner>=0 && variable_struct_exists(_scene.parts[_owner],"source_index")) _source_owner=_scene.parts[_owner].source_index;
            // Vacated native pixels must not keep hiding actors. An unchanged
            // visible prop still inherits its original mask where appropriate.
            if((_edits.original[_i] || (_source_owner>=0 && _edits.changed[_source_owner])) && !_overrides[_i] && (_source_owner<0 || _edits.changed[_source_owner] || _source_owner!=_baseline.owners[_i])) {
                _overrides[_i]=true;_depth[_i]=0;
                if(_owner>=0) {
                    _p=_scene.parts[_owner];
                    if(_p.mode==0 && (_source_owner<0 || _edits.changed[_source_owner]) && !(variable_struct_exists(_p,"depth_override") && _p.depth_override)) {
                        _o=variable_struct_get(_d.objects,string(_p.asset));
                        _depth[_i]=clamp(round(_p.y+_o.height)+29,1,254);
                    }
                }
            }
        }
        _display[_i]=_output;
    }
    for(_i=0;_i<240*144;_i++) buffer_poke(_b,_i*4,buffer_u32,_display[_i]|$ff000000);
    buffer_set_surface(_b,_surface,0);
    _mask=-1;
    if(_variant=="preview" || _variant=="edit") {
        if(!surface_exists(_depth_surface)) _depth_surface=surface_create(240,144);
        for(_i=0;_i<240*144;_i++) buffer_poke(_b,_i*4,buffer_u32,(_overrides[_i]?$ffffff:0)|(_depth[_i]<<24));
        buffer_set_surface(_b,_depth_surface,0);
    }
    if(_variant=="edit") {
    _mask_surface=surface_create(240,144);
    for( _i=0;_i<240*144;_i++) buffer_poke(_b,_i*4,buffer_u32,(_overrides[_i]?$ffffff:0)|(_depth[_i]<<24));
    buffer_set_surface(_b,_mask_surface,0);
     _mask=sprite_create_from_surface(_mask_surface,0,0,240,144,false,false,0,0);surface_free(_mask_surface);
    }
    buffer_delete(_b);_e.dirty_rect=undefined;
    _e.cache={key:_key,variant:_variant,surface:_surface,mask:_mask,depth_surface:_depth_surface,depth:_depth,overrides:_overrides,owners:_owners,colours:_colours,display_colours:_display};return _e.cache;
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
    // Cache the finished edit once; recorded painting covers it until complete.
    ln_edit_build(_s);_e.context=true;return true;
}
function ln_modified_hidden(_x,_y,_foot,_original=false) {
    var _e;
     _e=global.ln_editor;
    if((!_e.context && !_e.native_preview) || !is_struct(_e.cache)) return _original;
    _x=floor(_x);_y=floor(_y);if(_x<0 || _x>=240 || _y<0 || _y>=144) return _original;
    if(variable_struct_exists(_e.cache,"overrides") && !_e.cache.overrides[_y*240+_x]) return _original;
    return _e.cache.depth[_y*240+_x]>_foot;
}
function ln_edit_hit(_x,_y,_w,_h) {return mouse_check_button_pressed(mb_left) && ln_tool_mouse_x()>=_x && ln_tool_mouse_x()<_x+_w && ln_tool_mouse_y()>=_y && ln_tool_mouse_y()<_y+_h;}
function ln_edit_button(_x,_y,_w,_label,_on=undefined) {
    ln_ui_button_background(_x,_y,_w,28,_on);
    draw_set_colour(is_undefined(_on) || _on?c_white:make_colour_rgb(128,128,128));draw_text(_x+6,_y+5,_label);draw_set_colour(c_white);
}
function ln_edit_step(_host) {
    var _e,_s,_file,_i,_g,_max,_level,_d,_ids,_index,_assets,_before,_changed,_id,_o,_p,_swap,_step,_dx,_dy,_held,_delta,_next_depth;
     _e=global.ln_editor;
    var _test_key=(keyboard_check_pressed(ord("T")) || keyboard_check_pressed(vk_f5)) && !keyboard_check(vk_control) && !keyboard_check(vk_alt);
    var _test_return=!_e.open && !_host.workbench && !_host.scene_test.menu && _test_key;
    if(_test_return) _e.toggle_requested=true;
    if(keyboard_check_pressed(vk_f6) || _e.toggle_requested || (_e.open && !_e.map_open && ln_edit_hit(1110,62,160,28))) {
        _e.toggle_requested=false;
        ln_collision_finish_drag();ln_edit_finish_drag();_e.open=!_e.open;ln_paint_free();_e.depth_edit=false;_e.depth_hold_dir=0;ln_edit_music(_host,_e.open);
        if(_e.open) window_set_cursor(cr_default);
        if(_e.open) {ln_edit_finish_test(_host.play);ln_edit_follow_game(_host.play);}
        if(_test_return) return true;
        if(!_e.open) {ln_edit_restore_game_music(_host.play);_host.input_state=new LNInput();_e.context=false;if(_e.dirty) ln_edit_save("modified-scenes.autosave.json");return true;}
    }
    if(!_e.open) return false;
    if(ln_edit_hit(974,62,124,28) && !_e.map_open) {_e.map_open=true;_e.map_room=_e.room_id;return true;}
    if(ln_map_step(_host)) return true;
    _e.pulse_time_us=(_e.pulse_time_us+delta_time) mod 1600000;
    if(!mouse_check_button(mb_left)) {ln_collision_finish_drag();ln_edit_finish_drag();}
    ln_crt_preferences_flush();
    if(keyboard_check_pressed(vk_f10) || ln_edit_hit(1110,18,160,28)) ln_edit_crt_toggle();
    if(keyboard_check_pressed(vk_f9)) ln_fullscreen_toggle(_host);
     _s=_e.scene;if(!is_struct(_s)) return true;
    if(_e.depth_edit) {
        if(keyboard_check_pressed(vk_escape)) {_e.depth_edit=false;return true;}
        if(keyboard_check_pressed(vk_enter) || (mouse_check_button_pressed(mb_left) && !ln_edit_inside(846,666,178,28))) {
            ln_edit_depth_accept(keyboard_string);_e.depth_edit=false;return true;
        }
        return true;
    }
    if(!_e.drag && !is_string(_e.collision_before) && _e.autosave_us>0) {_e.autosave_us-=delta_time;if(_e.autosave_us<=0) ln_edit_save("modified-scenes.autosave.json");}
    if(ln_edit_hit(24,18,180,28)) {_e.enabled=!_e.enabled;_e.playback=undefined;}
    if(ln_edit_hit(216,18,112,28)) { _file=get_save_filename("JSON files|*.json","modified-scenes.json");if(ln_edit_save(_file)) _e.dirty=false;}
    if(ln_edit_hit(340,18,112,28)) { _file=get_open_filename("JSON files|*.json","");if(ln_edit_load(_file)) ln_edit_select(_e.game,_e.level,_e.room_id);}
    if(ln_edit_hit(752,18,132,28)) {ln_edit_restore_all();return true;}
    if(ln_edit_hit(464,18,112,28) || (keyboard_check(vk_control) && keyboard_check_pressed(ord("Z")))) {ln_edit_history(false);return true;}
    if(ln_edit_hit(850,62,112,28) || (keyboard_check(vk_control) && keyboard_check_pressed(ord("Y")))) {ln_edit_history(true);return true;}
    if(ln_edit_hit(588,18,152,28)) ln_edit_build_preview_start();
    if(_e.build>=0) ln_edit_build_preview_tick(delta_time);
    for( _i=0;_i<3;_i++) if(ln_edit_hit(24+_i*110,62,102,28)) { _g=_i+1;ln_edit_select(_g,1,ln_edit_rooms(_g,1)[0]);return true;}
    _delta=ln_edit_value_repeat(900,18,30,28);if(_delta) global.ln_paint_speed=max(0.1,round((global.ln_paint_speed-0.1*_delta)*10)/10);
    _delta=ln_edit_value_repeat(1060,18,30,28);if(_delta) global.ln_paint_speed=min(5,round((global.ln_paint_speed+0.1*_delta)*10)/10);
     _max=_e.game==1?6:(_e.game==2?7:5);
    if(ln_edit_value_repeat(370,62,30,28) || ln_edit_value_repeat(570,62,30,28)) { _level=clamp(_e.level+(ln_tool_mouse_x()<400?-1:1),1,_max); _d=ln_edit_data(_e.game,_level);ln_edit_select(_e.game,_level,ln_edit_rooms(_e.game,_level)[0]);return true;}
     _d=ln_edit_data(_e.game,_e.level); _ids=ln_edit_rooms(_e.game,_e.level);
    if(ln_edit_value_repeat(620,62,30,28) || ln_edit_value_repeat(810,62,30,28)) { _index=0;while(_index<array_length(_ids)-1 && _ids[_index]!=_e.room_id) _index++;_index=clamp(_index+(ln_tool_mouse_x()<650?-1:1),0,array_length(_ids)-1);ln_edit_select(_e.game,_e.level,_ids[_index]);return true;}
    if(ln_edit_hit(652,104,92,28)) {ln_edit_finish_drag();_e.enemy_edit=!_e.enemy_edit;_e.collision_edit=false;_e.part=-1;_e.enemy_index=0;_e.enemy_waypoint=-1;}
    if(ln_edit_hit(460,104,180,28)) {_e.enemy_edit=false;ln_collision_finish_drag();_e.collision_edit=!_e.collision_edit;_e.show_collisions=true;_e.part=-1;}
    if(ln_edit_hit(24,104,180,28) && !_e.collision_edit) _e.show_collisions=!_e.show_collisions;
    if(ln_edit_hit(24,594,140,28)) _e.show_ninja=!_e.show_ninja;
    if(ln_edit_hit(176,594,140,28)) _e.show_depth=!_e.show_depth;
    if(ln_edit_hit(328,594,150,28)) {_e.pulse_selected=!_e.pulse_selected;_e.pulse_time_us=0;}
    if(ln_edit_hit(490,594,175,28) || _test_key) {ln_edit_test_room(_host);return true;}

    if(_e.enemy_edit) return ln_enemy_editor_step();
    if(_e.collision_edit) return ln_collision_edit_step();
     _assets=variable_struct_get_names(_d.objects);array_sort(_assets,function(a,b){return real(a)-real(b);});
    if(mouse_wheel_up()) {if(ln_tool_mouse_x()<990) _e.scroll=max(0,_e.scroll-3);else _e.asset_scroll=max(0,_e.asset_scroll-3);}
    if(mouse_wheel_down()) {if(ln_tool_mouse_x()<990) _e.scroll=min(max(0,array_length(_s.parts)-18),_e.scroll+3);else _e.asset_scroll=min(max(0,array_length(_assets)-18),_e.asset_scroll+3);}
    for( _i=0;_i<18;_i++) {
        if(ln_edit_hit(760,140+_i*22,225,22) && _e.scroll+_i<array_length(_s.parts)) _e.part=_e.scroll+_i;
        if(ln_edit_hit(1000,140+_i*22,250,22) && _e.asset_scroll+_i<array_length(_assets)) _e.asset=_e.asset_scroll+_i;
    }
     _before=is_string(_e.drag_before)?_e.drag_before:json_stringify(_s); _changed=false;
    if(ln_edit_hit(1000,548,245,28) && array_length(_s.parts)<1024) {
         _id=real(_assets[_e.asset]); _o=variable_struct_get(_d.objects,string(_id));
        ln_edit_add_asset(_id);_changed=true;
    }
    if(!_e.enemy_edit && !_e.collision_edit && _e.part>=0 && _e.part<array_length(_s.parts)) {
         _p=_s.parts[_e.part];
        _delta=ln_edit_value_repeat(760,548,65,28);if(_delta) _changed=ln_edit_move_part(_e.part-1*_delta) || _changed;
        _delta=ln_edit_value_repeat(832,548,65,28);if(_delta) _changed=ln_edit_move_part(_e.part+1*_delta) || _changed;
        _delta=ln_edit_value_repeat(760,704,112,28);if(_delta) _changed=ln_edit_move_part(_e.part-10*_delta) || _changed;
        _delta=ln_edit_value_repeat(880,704,144,28);if(_delta) _changed=ln_edit_move_part(_e.part+10*_delta) || _changed;
        if(ln_edit_hit(760,740,112,28)) _changed=ln_edit_move_part(0) || _changed;
        if(ln_edit_hit(880,740,144,28)) _changed=ln_edit_move_part(array_length(_s.parts)-1) || _changed;
        if(ln_edit_hit(904,548,80,28) || keyboard_check_pressed(vk_delete)) {array_delete(_s.parts,_e.part,1);_e.part=min(_e.part,array_length(_s.parts)-1);_changed=true;}
        else {
             _step=keyboard_check(vk_shift)?8:1;
            if(keyboard_check_pressed(vk_left)) {_p.x-=2*_step;_p.overlay=true;_changed=true;}
            if(keyboard_check_pressed(vk_right)) {_p.x+=2*_step;_p.overlay=true;_changed=true;}
            if(keyboard_check_pressed(vk_up)) {_p.y-=_step;_p.overlay=true;_changed=true;}
            if(keyboard_check_pressed(vk_down)) {_p.y+=_step;_p.overlay=true;_changed=true;}
            if(ln_edit_hit(760,630,92,28)) {_p.flip=!_p.flip;_changed=true;}
            if(ln_edit_hit(860,630,164,28)) {if(_p.mode==0 && variable_struct_exists(_p,"depth_override") && _p.depth_override) {_p.depth_override=false;} else {_p.mode=(_p.mode+1) mod 3;_p.depth_override=true;}_changed=true;}
            _held=mouse_check_button(mb_left)?(ln_edit_inside(760,666,35,28)?-1:(ln_edit_inside(803,666,35,28)?1:0)):0;
            _delta=ln_edit_depth_repeat(_held,mouse_check_button_pressed(mb_left),delta_time);
            if(_delta!=0) {_next_depth=clamp(_p.depth+_delta,0,144);if(_next_depth!=_p.depth || _p.mode!=1) {_p.mode=1;_p.depth_override=true;_p.depth=_next_depth;_e.show_depth=true;_changed=true;}}
            if(ln_edit_hit(846,666,178,28)) {_e.depth_edit=true;_e.depth_hold_dir=0;keyboard_string="";_e.drag=false;return true;}
            _p.x=clamp(_p.x,-512,512);_p.y=clamp(_p.y,-512,512);
        }
    }
    // Right-drag moves the ninja; left-drag moves the selected scenery part.
    if(ln_tool_mouse_x()>=24 && ln_tool_mouse_x()<744 && ln_tool_mouse_y()>=140 && ln_tool_mouse_y()<572) {
        if(mouse_check_button(mb_right)) {_e.probe_x=clamp((ln_tool_mouse_x()-24)/3,0,239);_e.probe_y=clamp((ln_tool_mouse_y()-140)/3,0,143);}
        if(mouse_check_button_pressed(mb_left) && keyboard_check(vk_alt)) {
            _e.pending_pick=[floor((ln_tool_mouse_x()-24)/3),floor((ln_tool_mouse_y()-140)/3)];_e.drag=false;return true;
        }
        if(mouse_check_button_pressed(mb_left)) {_e.drag=true;_e.last_mouse_x=ln_tool_mouse_x();_e.last_mouse_y=ln_tool_mouse_y();}
    }
    if(!mouse_check_button(mb_left)) _e.drag=false;
    if(_e.drag && _e.part>=0 && _e.part<array_length(_s.parts)) {
         _dx=round((ln_tool_mouse_x()-_e.last_mouse_x)/6)*2; _dy=round((ln_tool_mouse_y()-_e.last_mouse_y)/3);
        if(_dx!=0 || _dy!=0) {ln_edit_move_bounds(_s.parts[_e.part],_dx,_dy);_s.parts[_e.part].x=clamp(_s.parts[_e.part].x+_dx,-512,512);_s.parts[_e.part].y=clamp(_s.parts[_e.part].y+_dy,-512,512);_e.last_mouse_x+=_dx*3;_e.last_mouse_y+=_dy*3;_changed=true;}
    }
    if(_changed) ln_edit_changed(_before);
    return true;
}
function ln_edit_draw() {
    var _e,_s,_view,_projection,_cache,_surface,_camera,_g,_d,_dx,_dy,_i,_sprite,_r,_record,_p,_o,_assets,_j,_a;
     _e=global.ln_editor; if(_e.map_open) {ln_map_draw();return;}
     _s=_e.scene;if(!is_struct(_s)) return;
    draw_set_font(font_jansina);draw_set_halign(fa_left);draw_set_valign(fa_top);
    ln_tool_clear(false);draw_set_colour(c_white);
    _view=matrix_get(matrix_view); _projection=matrix_get(matrix_projection);
    if(_e.build>=0 && global.ln_paint.active) ln_paint_prepare();
    matrix_set(matrix_view,_view);matrix_set(matrix_projection,_projection);
     _cache=ln_edit_build(_e.reference?_e.source_scene:_s,-1,_e.reference?"source":"preview");
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
    if(_e.build>=0 && global.ln_paint.active && surface_exists(global.ln_paint.surface)) draw_surface(global.ln_paint.surface,0,0);
    else ln_edit_selected_pulse(_cache);
    _e.context=false; // Native room depth stays active for every editor preview.
    _e.native_preview=true;
    if(_e.show_ninja && _e.build<0 && is_struct(_e.preview)) ln_edit_preview_actor();
    if(_e.enemy_edit && _e.build<0) ln_enemy_editor_overlay();
    _e.native_preview=false;
    if(_e.show_collisions) ln_edit_collision_draw();
    if(_e.collision_edit) ln_collision_edit_handles();
    _e.context=false;surface_reset_target();matrix_set(matrix_view,_view);matrix_set(matrix_projection,_projection);
    draw_set_colour(c_white);ln_crt_surface(_surface,24,140,3,1,undefined,_e.crt_enabled);
    if(!_e.collision_edit && _e.part>=0 && _e.part<array_length(_s.parts)) {
         _p=_s.parts[_e.part]; _o=variable_struct_get(ln_edit_data(_e.game,_e.level).objects,string(_p.asset));
        draw_set_colour(c_yellow);draw_rectangle(clamp(24+_p.x*3,24,744),clamp(140+_p.y*3,140,572),clamp(24+(_p.x+_o.width)*3,24,744),clamp(140+(_p.y+_o.height)*3,140,572),true);
        if(_e.show_depth) {draw_set_colour(c_aqua);draw_line(24,140+_p.depth*3,744,140+_p.depth*3);}
        draw_set_colour(c_white);draw_text(24,626,"Part "+string(_e.part+1)+"  x "+string(_p.x)+" y "+string(_p.y));
        ln_edit_button(760,704,112,"Up 10");ln_edit_button(880,704,144,"Down 10");
        ln_edit_button(760,740,112,"Top (back)");ln_edit_button(880,740,144,"Bottom (front)");
        ln_edit_button(760,630,92,"Flip X",_p.flip);ln_edit_button(860,630,164,(_p.mode==0 && (!variable_struct_exists(_p,"depth_override") || !_p.depth_override))?"Inherited":["Ground","Depth","Always front"][_p.mode]);
        ln_edit_button(760,666,35,"-");ln_edit_button(803,666,35,"+");ln_edit_button(846,666,178,_e.depth_edit?(keyboard_string+"|"):string(_p.depth),_e.depth_edit);
    }
    ln_edit_button(24,18,180,"Modified: "+(_e.enabled?"ON":"OFF"),_e.enabled);ln_edit_button(216,18,112,"Save file");ln_edit_button(340,18,112,"Load file");ln_edit_button(464,18,112,"Undo (^Z)");ln_edit_button(588,18,152,"Build preview");
    ln_edit_button(752,18,132,"Restore all");ln_edit_button(850,62,112,"Redo (^Y)");
    ln_edit_button(1110,18,160,"Editor CRT "+(_e.crt_enabled?"ON":"OFF")+" F10",_e.crt_enabled);
    ln_edit_button(974,62,124,"Level map");
    ln_edit_button(1110,62,160,"Back to game F6");
    ln_edit_button(900,18,30,"-");draw_set_colour(c_white);draw_text(938,24,string_format(global.ln_paint_speed,1,1)+"x build");ln_edit_button(1060,18,30,"+");
    for( _i=0;_i<3;_i++) ln_edit_button(24+_i*110,62,102,"Ninja "+string(_i+1),_e.game==_i+1);
    ln_edit_button(370,62,30,"<");draw_set_colour(c_white);draw_text(412,68,"Level "+string(_e.level));ln_edit_button(570,62,30,">");
    ln_edit_button(620,62,30,"<");draw_set_colour(c_white);draw_text(662,68,"Room "+string(_e.room_id)+" (ID)");ln_edit_button(810,62,30,">");
    ln_edit_button(24,594,140,"Ninja",_e.show_ninja);ln_edit_button(176,594,140,"Depth line",_e.show_depth);ln_edit_button(328,594,150,"pulseSelected?",_e.pulse_selected);ln_edit_button(490,594,175,"Test Room (T/F5)");
    ln_edit_button(24,104,180,"Collision overlay",_e.show_collisions);
    ln_edit_button(460,104,180,"Edit collisions",_e.collision_edit);
    ln_edit_button(652,104,92,"Enemies",_e.enemy_edit);
    if(_e.show_collisions) {draw_set_colour(c_white);draw_text(216,110,string(array_length(_e.collision_shapes))+(_e.collision_edit?" boundaries":" boundaries | read-only"));}
    if(_e.enemy_edit) {ln_enemy_editor_panel();return;}
    if(_e.collision_edit) {ln_collision_edit_panel();return;}
    draw_set_colour(c_white);draw_text(760,110,"PARTS (draw order)");draw_text(1000,110,"ASSETS (this level)");
     _d=ln_edit_data(_e.game,_e.level); _assets=variable_struct_get_names(_d.objects);array_sort(_assets,function(a,b){return real(a)-real(b);});
    for( _i=0;_i<18;_i++) {
         _j=_e.scroll+_i;if(_j<array_length(_s.parts)) {draw_set_colour(_e.part==_j?c_yellow:c_white);draw_text(760,140+_i*22,string(_j+1)+"  Asset "+string(_s.parts[_j].asset));}
         _a=_e.asset_scroll+_i;if(_a<array_length(_assets)) { _o=variable_struct_get(_d.objects,_assets[_a]);draw_set_colour(_e.asset==_a?c_yellow:c_white);draw_text(1038,140+_i*22,_assets[_a]+"  "+string(_o.width)+"x"+string(_o.height));ln_edit_thumbnail(real(_assets[_a]),1000,140+_i*22,32,20);}
    }
    if(array_length(_assets)>0) {
        var _panel_x=1058,_panel_y=630,_panel_size=156;
        draw_sprite_ext(spr_assetPanel,0,_panel_x+_panel_size/2,_panel_y+_panel_size/2,_panel_size/600,_panel_size/600,0,c_white,1);
        // Artwork opening is approximately source x/y 120..480. Leave padding.
        var _preview_id=real(_assets[_e.asset]);
        var _preview_o=variable_struct_get(_d.objects,string(_preview_id));
        var _inner=86,_fit=min(_inner/_preview_o.width,_inner/_preview_o.height);
        ln_edit_thumbnail(_preview_id,_panel_x+(_panel_size-_preview_o.width*_fit)/2,
            _panel_y+(_panel_size-_preview_o.height*_fit)/2,_inner,_inner);
    }
    ln_edit_button(760,548,65,"Up");ln_edit_button(832,548,65,"Down");ln_edit_button(904,548,80,"Remove");ln_edit_button(1000,548,245,"Add selected asset");
    if(_e.show_collisions) {
        draw_set_colour(make_colour_rgb(70,220,255));draw_text(24,646,"CYAN: solid boundary / area");
        draw_set_colour(make_colour_rgb(255,175,45));draw_text(24,670,"AMBER: hazard / conditional boundary or area");
        draw_set_colour(c_white);draw_text(24,702,"White cross: ninja collision position. Right-drag to move the ninja.");
        draw_text(24,726,"Room entry rules only; scripted obstacles and exits are not shown.");
    } else {
    draw_set_colour(c_white);draw_text(24,646,"Alt-click: select part. Drag/arrows: move. Right-drag: ninja. Shift: larger steps.");
    draw_text(24,670,"Depth line = ground contact. Enter a number to override inherited masking.");
    draw_text(24,702,"Visual editing only: original collision paths, pickups and exits stay in place.");
    draw_text(24,726,"Parts inherit original masking until overridden. Ground clears it; Inherited restores it.");
    }
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
    ln_check(!ln_modified_hidden(2,3,100,true) && ln_modified_hidden(0,0,100,true),"authored depth replaces native while untouched pixels inherit");
    _s.parts=[_s.parts[1],_s.parts[0]];_e.revision++;_c=ln_edit_build(_s);
    ln_check(surface_getpixel(_c.surface,4,4)==c_white,"reorder changes visible pixels");
    array_delete(_s.parts,1,1);_e.revision++;_c=ln_edit_build(_s);
    ln_check(surface_getpixel(_c.surface,2,3)==global.ln_paint_palette[5],"remove reveals background");
    _e.scenes={};variable_struct_set(_e.scenes,"1:1:1",_s);
     _saved=json_stringify(_e.scenes); _file="scene-editor-check.tmp.json";
    ln_check(ln_edit_save(_file),"write pack");_e.scenes={};_e.enabled=false;
    ln_check(ln_edit_load(_file),"load custom file: "+_e.message);
    ln_check(_e.enabled,"successful load enables Modified");
    ln_check(ln_rewind_equal(_e.scenes,json_parse(_saved)),"custom file roundtrip");file_delete(_file);
     _bad=json_parse(json_stringify(ln_edit_pack()));variable_struct_get(_bad.scenes,"1:1:1").parts[0].asset=997;
    ln_check(!ln_edit_validate(_bad),"reject unknown asset");
     _b=buffer_create(64,buffer_grow,1);buffer_write(_b,buffer_text,"{broken");buffer_save(_b,_file);buffer_delete(_b);
    _e.enabled=false;
    ln_check(!ln_edit_load(_file) && !_e.enabled && ln_rewind_equal(_e.scenes,json_parse(_saved)),"invalid load preserves edits and Modified state");file_delete(_file);
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
    ln_edit_paint_timing_checks();
    ln_edit_bitmap_checks();
    ln_edit_control_checks(self);
    ln_edit_optimization_checks(self);
    ln_edit_test_room_checks(self);
    ln_edit_collision_checks();
    ln_edit_follow_game_checks();
    ln_edit_overlap_transparency_checks();
    ln_edit_vacated_checks();
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

// Modified rooms share the recorded source sequence and timing. The finished
// edited bitmap replaces it on completion, rather than replaying every part.
function ln_modified_paint_sync(_g) {
    ln_paint_sync(_g);return global.ln_paint;
}
function ln_modified_paint_tick(_g) {return ln_paint_tick(_g);}
function ln_modified_paint_cover() {
    // The game draw already composites global.ln_paint.surface last.
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
    ln_check(ln_modified_paint_tick(_g) && global.ln_paint.time==0,"modified scene waits for first actual presentation");
     _before=_g.player.x;ln1_play_draw(_g,false);
    ln_check(surface_getpixel(_g.stage_surface,20,20)==global.ln_paint_palette[_s.background],"modified first draw is plain background");
    ln_check(global.ln_paint.presented && ln_modified_paint_tick(_g) && global.ln_paint.time>0,"modified construction advances only after draw");
     _limit=0;while(ln_modified_paint_tick(_g) && _limit++<1000) {}
    ln_check(!global.ln_paint.active && _g.player.x==_before,"construction completes without moving player");
    global.ln_preferences_enabled=false;_e.enabled=false;_e.scenes={};_e.playback=undefined;
    if(surface_exists(_g.stage_surface)) surface_free(_g.stage_surface);ln_edit_free_cache();
}

function ln_modified_build_active(_g) {
    return is_struct(ln_modified_room(_g)) && global.ln_paint.active;
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
    ln_edit_pulse_checks(_c);
    _s.parts=[_s.parts[1],_s.parts[0]];_s.parts[1].x=40;
    _e.reference=true;
    ln_check(ln_edit_pick_part(_c,4,4)==1,"Original view maps a source part after moving/reordering");
    variable_struct_set(_e.datasets,"1:1",json_parse(_saved));_e.scene=undefined;_e.scenes={};_e.enabled=false;ln_edit_free_cache();
    for(_game=1;_game<=3;_game++) {
        _epoch=global.ln_rewind_epoch;_room=ln_edit_rooms(_game,1)[1];ln_edit_select(_game,1,_room);_g=_e.preview;
        ln_check(_g.room_id==_room && global.ln_rewind_epoch==_epoch,"preview enters selected room without touching live rewind");
        _e.reference=false;_e.show_depth=false;_e.probe_x=120;_e.probe_y=100;_e.show_ninja=false;ln_edit_draw();
        _baseline=ln_edit_screen_buffer();
        // Make native masking unambiguously open, then unambiguously closed.
        if(_game<3) {_mask=_g.mask;_g.mask=-1;}
        else {_shapes=_g.mask_shapes;_g.mask_shapes=[];}
        _state=_game==3?json_stringify(_g.state):"";
        _e.show_ninja=true;ln_edit_draw();_visible=ln_edit_screen_buffer();
        ln_check(ln_edit_canvas_difference(_baseline,_visible)>0,"original background does not cover preview ninja");
        // Authored depth must also hide actors in rooms with no native mask.
        ln_edit_test_depth_fill(255);ln_edit_draw();_hidden=ln_edit_screen_buffer();
        ln_check(ln_edit_canvas_difference(_baseline,_hidden)==0,"authored foreground hides ninja in all three games");buffer_delete(_hidden);
        ln_edit_test_depth_fill(0);ln_edit_draw();_hidden=ln_edit_screen_buffer();
        ln_check(ln_edit_canvas_difference(_visible,_hidden)==0,"lowered authored depth reveals ninja in all three games");buffer_delete(_hidden);
        ln_edit_free_cache();ln_edit_draw();
        if(_game<3) {
            _original=surface_create(240,144);surface_set_target(_original);draw_clear_alpha(c_white,1);surface_reset_target();
            _g.mask=sprite_create_from_surface(_original,0,0,240,144,false,false,0,0);surface_free(_original);
            ln_edit_draw();_hidden=ln_edit_screen_buffer();
            ln_check(ln_edit_canvas_difference(_baseline,_hidden)==0,"original preview uses original actor depth mask");
            buffer_delete(_hidden);
            ln_edit_test_depth_fill(0);ln_edit_draw();_hidden=ln_edit_screen_buffer();
            ln_check(ln_edit_canvas_difference(_visible,_hidden)==0,"ground override replaces fully closed native GPU mask");buffer_delete(_hidden);
            ln_edit_free_cache();sprite_delete(_g.mask);_g.mask=_mask;
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

function ln_edit_inside(_x,_y,_w,_h) {return ln_tool_mouse_x()>=_x && ln_tool_mouse_x()<_x+_w && ln_tool_mouse_y()>=_y && ln_tool_mouse_y()<_y+_h;}
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
    if(_value==_p.depth && _p.mode==1) return false;
    _before=json_stringify(_e.scene);_p.mode=1;_p.depth_override=true;_p.depth=_value;_e.show_depth=true;ln_edit_changed(_before);return true;
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
    _e.scene.parts[_count].mode=0;_e.scene.parts[_count].depth_override=false;
    ln_edit_depth_accept(string(_e.scene.parts[_count].depth));
    ln_check(_e.scene.parts[_count].mode==1 && _e.scene.parts[_count].depth_override,"entering unchanged inherited number activates override");
    ln_edit_depth_accept("123");ln_check(_e.scene.parts[_count].depth==123,"direct depth entry");
    ln_edit_depth_accept("999");ln_check(_e.scene.parts[_count].depth==144,"depth entry clamps at scene height");
    ln_edit_depth_accept("oops");ln_check(_e.scene.parts[_count].depth==144,"invalid depth entry leaves value intact");
    _previous=global.ln_music_voice;_voice=audio_play_sound(snd_ln1_dungeons_game,0,true,0);global.ln_music_voice=_voice;
    ln_edit_music(_host,true);ln_check(audio_is_paused(_voice),"editor pauses playing music");
    ln_edit_music(_host,false);ln_check(!audio_is_paused(_voice),"editor resumes its paused music");
    audio_pause_sound(_voice);ln_edit_music(_host,true);ln_edit_music(_host,false);
    ln_check(audio_is_paused(_voice),"editor preserves previously paused music");
    audio_stop_sound(_voice);global.ln_music_voice=_previous;
    ln_edit_snag_checks();
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
    _part.overlay=true;
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
    var _e=global.ln_editor,_game,_i,_p,_c,_expected,_owners,_depth,_stamp,_partial=0,_full=0,_undo,_before,_game_crt,_editor_crt,_off,_on,_file,_persist,_display_expected;
    for(_game=1;_game<=3;_game++) {
        ln_edit_select(_game,1,ln_edit_rooms(_game,1)[1]);_e.reference=false;_e.part=array_length(_e.scene.parts)-1;_p=_e.scene.parts[_e.part];
        ln_edit_build(_e.scene,-1,"preview");
        _undo=array_length(_e.undo);_before=json_stringify(_e.scene);_e.drag=true;
        for(_i=0;_i<6;_i++) {
            ln_edit_move_bounds(_p,2,1);_p.x+=2;_p.y+=1;ln_edit_changed(_before);
            _stamp=get_timer();_c=ln_edit_build(_e.scene,-1,"preview");_partial+=get_timer()-_stamp;
            _expected=json_stringify(_c.colours);_owners=json_stringify(_c.owners);_depth=json_stringify(_c.depth);_display_expected=json_stringify(_c.display_colours);
            ln_check(_c.mask==-1,"preview never creates a GPU-readback mask sprite");
            ln_edit_free_cache();_stamp=get_timer();_c=ln_edit_build(_e.scene,-1,"preview");_full+=get_timer()-_stamp;
            ln_check(json_stringify(_c.colours)==_expected && json_stringify(_c.owners)==_owners && json_stringify(_c.depth)==_depth && json_stringify(_c.display_colours)==_display_expected,"partial drag redraw matches full colour, ownership and depth arrays");
        }
        ln_check(array_length(_e.undo)==_undo,"drag does not copy undo history each frame");ln_edit_finish_drag();
        ln_check(array_length(_e.undo)==_undo+1 && ln_rewind_equal(json_parse(_e.undo[_undo]),json_parse(_before)),"one complete undo snapshot per drag");
        _expected=json_stringify(_e.scene);
        ln_check(ln_edit_history(false) && ln_rewind_equal(_e.scene,json_parse(_before)),"undo restores entire drag");
        ln_check(ln_edit_history(true) && ln_rewind_equal(_e.scene,json_parse(_expected)),"redo restores entire drag");
        ln_edit_history(false);_before=json_stringify(_e.scene);_e.scene.parts[0].x+=2;ln_edit_changed(_before);
        ln_check(array_length(_e.redo)==0 && !ln_edit_history(true),"new edits invalidate redo branch");

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

function ln_edit_history(_redo) {
    var _e=global.ln_editor,_current,_next;
    ln_collision_finish_drag();ln_edit_finish_drag();
    if(_redo?array_length(_e.redo)==0:array_length(_e.undo)==0) return false;
    _current=json_stringify(_e.scene);
    if(_redo) {_next=array_pop(_e.redo);array_push(_e.undo,_current);}
    else {_next=array_pop(_e.undo);array_push(_e.redo,_current);}
    _e.scene=json_parse(_next);_e.part=min(_e.part,array_length(_e.scene.parts)-1);
    _e.scroll=clamp(_e.scroll,0,max(0,array_length(_e.scene.parts)-18));
    variable_struct_set(_e.scenes,ln_edit_key(_e.game,_e.level,_e.room_id),json_parse(_next));
    _e.revision++;_e.dirty=true;_e.reference=false;_e.build=-1;_e.autosave_us=1000000;ln_edit_free_cache();
    _e.enabled=true;
    ln_edit_collision_refresh();
    _e.message=_redo?"Redo applied":"Undo applied";return true;
}

// Test encounters are temporary; ordinary room travel retains defeated guards.
function ln_edit_reset_test_enemies(_g) {
    _g.edited_enemies=undefined;
    _g.edited_enemy_rooms={};
    ln_enemy_runtime(_g);
}
function ln_edit_finish_test(_g) {
    var _e=global.ln_editor;
    if(!_e.test_active) return;
    _e.test_active=false;
    ln_edit_reset_test_enemies(_g);
}

function ln_edit_test_room(_host) {
    var _e=global.ln_editor,_t=_host.scene_test,_level=-1,_scene=-1,_i,_j;
    ln_collision_finish_drag();ln_edit_finish_drag();
    for(_i=0;_i<array_length(_t.levels);_i++) {
        if(_t.levels[_i].game!=_e.game || _t.levels[_i].number!=_e.level) continue;
        _level=_i;
        for(_j=0;_j<array_length(_t.levels[_i].scenes);_j++) if(_t.levels[_i].scenes[_j].id==_e.room_id) {_scene=_j;break;}
        break;
    }
    if(_level<0 || _scene<0) {_e.message="This source room has no playable entry";return false;}
    variable_struct_set(_e.scenes,ln_edit_key(_e.game,_e.level,_e.room_id),json_parse(json_stringify(_e.scene)));
    _e.enabled=true;_e.dirty=true;_e.revision++;_e.autosave_us=1000000;_e.playback=undefined;ln_edit_free_cache();
    _t.level_index=_level;_t.game=_e.game;
    ln_edit_music(_host,false);
    if(is_undefined(_e.test_music_restore)) _e.test_music_restore=ln_tool_music_enabled(_host.play);
    if(!ln_scene_test_open(_t,_host.play,_scene)) {ln_edit_music(_host,true);_e.message="Room entry failed; edits kept";return false;}
    _e.test_active=true;ln_edit_reset_test_enemies(_host.play);
    _e.open=false;_e.context=false;_e.depth_edit=false;_host.workbench=false;_host.input_state=new LNInput();
    // Testing is silent without changing the user's normal gameplay preference.
    ln_tool_music_set(_host.play,false);
    ln_frontend_music(_host.play,false);
    if(global.ln_preferences_enabled) ln_edit_save("modified-scenes.autosave.json");
    ln_scene_test_message(_t,"Testing edited room - T/F5 returns to the editor");return true;
}

function ln_edit_test_room_checks(_host) {
    var _e=global.ln_editor,_game,_room,_scene;
    for(_game=1;_game<=3;_game++) {
        _room=ln_edit_rooms(_game,1)[1];ln_edit_select(_game,1,_room);_e.open=true;
        _e.scene.parts[0].x+=2;_scene=json_stringify(_e.scene);
        ln_check(ln_edit_test_room(_host),"Test room enters playable room");
        ln_check(!_e.open && !_host.workbench && !_host.scene_test.menu && !_host.scene_test.preview && _host.play.game_number==_game && _host.play.room_id==_room,"Test room uses selected game and room in play mode");
        ln_check(ln_rewind_equal(ln_modified_room(_host.play),json_parse(_scene)) && ln_rewind_equal(_e.scene,json_parse(_scene)),"Test room retains edited scene for gameplay and editor return");
        ln_check(variable_global_exists("ln_music_voice") && global.ln_music_voice>=0 && (audio_is_playing(global.ln_music_voice) || audio_is_paused(global.ln_music_voice)),"Test room loads level music respecting mute");
        ln_check(!ln_tool_music_enabled(_host.play) && audio_is_paused(global.ln_music_voice),"Test room starts silent in every game");
        var _restore=_e.test_music_restore;ln_edit_restore_game_music(_host.play);
        ln_check(ln_tool_music_enabled(_host.play)==_restore,"Back to game restores its own music preference");
    }
    show_debug_message("LN_EDITOR_TEST_ROOM_PASS: selected edited room and level music for all three games");
}

// Test-only uniform override isolates GPU precedence from source asset coverage.
function ln_edit_test_depth_fill(_depth) {
    var _c=global.ln_editor.cache,_b=buffer_create(240*144*4,buffer_fixed,1);
    for(var _i=0;_i<240*144;_i++) {
        _c.overrides[_i]=true;_c.depth[_i]=_depth;
        buffer_poke(_b,_i*4,buffer_u32,$ffffff|(_depth<<24));
    }
    buffer_set_surface(_b,_c.depth_surface,0);buffer_delete(_b);
}

// Editor-only highlight: use existing visible-pixel ownership, not a rectangle
// or a rebuilt texture. One 400 ms white pulse per 1.6 seconds (200 ms each way).
function ln_edit_selected_pulse(_cache) {
    var _e=global.ln_editor;
    if(!_e.pulse_selected || _e.pulse_time_us>=400000 || _e.part<0 || _e.part>=array_length(_e.scene.parts)) return;
    var _alpha=sin(pi*_e.pulse_time_us/400000);
    if(_alpha<=0) return;
    var _index=_e.part,_part=_e.scene.parts[_index];
    if(_e.reference) {
        _index=-1;
        for(var _i=0;_i<array_length(_e.source_scene.parts);_i++) {
            var _source=_e.source_scene.parts[_i];
            if(variable_struct_exists(_part,"source_index") && _source.source_index==_part.source_index) {_index=_i;_part=_source;break;}
        }
        if(_index<0) return;
    }
    var _o=variable_struct_get(ln_edit_data(_e.game,_e.level).objects,string(_part.asset));
    var _left=max(0,round(_part.x)),_right=min(240,round(_part.x)+_o.width);
    var _top=max(0,round(_part.y)),_bottom=min(144,round(_part.y)+_o.height);
    var _old_alpha=draw_get_alpha(),_old_colour=draw_get_colour();
    draw_set_colour(c_white);draw_set_alpha(_alpha);
    for(var _y=_top;_y<_bottom;_y++) {
        var _x=_left;
        while(_x<_right) {
            if(_cache.owners[_y*240+_x]!=_index) {_x++;continue;}
            var _start=_x;
            while(_x<_right && _cache.owners[_y*240+_x]==_index) _x++;
            // Explicit area: a filled rectangle with identical Y endpoints
            // can collapse to zero-area triangles on the GPU.
            draw_primitive_begin(pr_trianglelist);
            draw_vertex(_start,_y);draw_vertex(_x,_y);draw_vertex(_start,_y+1);
            draw_vertex(_x,_y);draw_vertex(_x,_y+1);draw_vertex(_start,_y+1);
            draw_primitive_end();
        }
    }
    draw_set_alpha(_old_alpha);draw_set_colour(_old_colour);
}

function ln_edit_pulse_checks(_cache) {
    var _e=global.ln_editor,_part=_e.part,_time=_e.pulse_time_us,_enabled=_e.pulse_selected;
    var _v=matrix_get(matrix_view),_p=matrix_get(matrix_projection);
    var _surface=surface_create(240,144),_camera=camera_create_view(0,0,240,144);
    _e.part=0;_e.pulse_selected=true;
    surface_set_target(_surface);camera_apply(_camera);
    _e.pulse_time_us=200000;draw_clear(c_black);ln_edit_selected_pulse(_cache);draw_flush();
    ln_check(surface_getpixel(_surface,4,4)==c_white,"selected pulse peak is visible white");
    ln_check(surface_getpixel(_surface,6,6)==c_black && surface_getpixel(_surface,0,0)==c_black,"pulse preserves overlapping parts and empty background");
    _e.pulse_time_us=100000;draw_clear(c_black);ln_edit_selected_pulse(_cache);draw_flush();
    var _rising=surface_getpixel(_surface,4,4);
    ln_check(_rising!=c_black && _rising!=c_white,"pulse fades towards white");
    _e.pulse_time_us=300000;draw_clear(c_black);ln_edit_selected_pulse(_cache);draw_flush();
    ln_check(abs(colour_get_red(surface_getpixel(_surface,4,4))-colour_get_red(_rising))<=1,"pulse fades back symmetrically");
    _e.pulse_time_us=400000;draw_clear(c_black);ln_edit_selected_pulse(_cache);draw_flush();
    ln_check(surface_getpixel(_surface,4,4)==c_black,"pulse ends after 0.4 seconds");
    _e.pulse_time_us=200000;_e.pulse_selected=false;ln_edit_selected_pulse(_cache);draw_flush();
    ln_check(surface_getpixel(_surface,4,4)==c_black,"pulse toggle disables highlight");
    surface_reset_target();matrix_set(matrix_view,_v);matrix_set(matrix_projection,_p);
    surface_free(_surface);camera_destroy(_camera);
    _e.part=_part;_e.pulse_time_us=_time;_e.pulse_selected=_enabled;
}

// Preserve native pixels wherever the reconstructed source is unchanged.
// Cache the comparison once per room; never rewrite the underlying assets.
function ln_edit_bitmap_baseline(_scene) {
    var _e=global.ln_editor,_key=ln_edit_key(_scene.game,_scene.level,_scene.room);
    if(variable_struct_exists(_e.bitmap_baselines,_key)) return variable_struct_get(_e.bitmap_baselines,_key);
    var _source=ln_edit_source(_scene.game,_scene.level,_scene.room);
    var _raw=ln_edit_build(_source,-1,"source");
    var _baseline={colours:_raw.colours,owners:_raw.owners,background:_source.background,original:array_create(240*144,0)};
    var _path="play/ln"+string(_scene.game)+"/"+((_scene.game==1 && _scene.level==1)?"":"level"+string(_scene.level)+"/");
    var _world=ln3_data_read(_path+"world.json"),_sprite=-1;
    for(var _i=0;_i<array_length(_world.rooms);_i++) if(_world.rooms[_i].id==_scene.room) {_sprite=asset_get_index(_world.rooms[_i].sprite);break;}
    if(_sprite<0) return undefined;
    var _view=matrix_get(matrix_view),_projection=matrix_get(matrix_projection);
    var _surface=surface_create(240,144),_camera=camera_create_view(0,0,240,144);
    var _alpha=draw_get_alpha(),_colour=draw_get_colour();
    surface_set_target(_surface);camera_apply(_camera);draw_clear(c_black);
    draw_set_alpha(1);draw_set_colour(c_white);draw_sprite(_sprite,0,0,0);draw_flush();
    var _buffer=buffer_create(240*144*4,buffer_fixed,1);buffer_get_surface(_buffer,_surface,0);
    for(var _pixel=0;_pixel<240*144;_pixel++) _baseline.original[_pixel]=buffer_peek(_buffer,_pixel*4,buffer_u32)&$ffffff;
    surface_reset_target();matrix_set(matrix_view,_view);matrix_set(matrix_projection,_projection);
    draw_set_alpha(_alpha);draw_set_colour(_colour);buffer_delete(_buffer);surface_free(_surface);camera_destroy(_camera);
    variable_struct_set(_e.bitmap_baselines,_key,_baseline);return _baseline;
}

function ln_edit_bitmap_checks() {
    var _e=global.ln_editor,_saved=json_stringify(_e.scenes);
    _e.scenes={};
    for(var _game=1;_game<=3;_game++) {
        ln_edit_select(_game,_game==2?2:1,1);_e.reference=false;
        var _baseline=ln_edit_bitmap_baseline(_e.scene),_cache=ln_edit_build(_e.scene,-1,"preview");
        var _buffer=buffer_create(240*144*4,buffer_fixed,1),_same=true;
        buffer_get_surface(_buffer,_cache.surface,0);
        for(var _i=0;_i<240*144;_i++) if((buffer_peek(_buffer,_i*4,buffer_u32)&$ffffff)!=_baseline.original[_i]) {_same=false;break;}
        ln_check(_same,"unedited reconstructed view preserves every original bitmap pixel, game "+string(_game));
        var _asset=_game==2?51:_e.scene.parts[array_length(_e.scene.parts)-1].asset;
        ln_edit_add_asset(_asset);var _part=_e.scene.parts[_e.part];_part.x=138;_part.y=105;_e.revision++;
        _cache=ln_edit_build(_e.scene,-1,"preview");buffer_get_surface(_buffer,_cache.surface,0);
        var _outside=true,_changed=0,_depth_same=true;
        for(var _pixel=0;_pixel<240*144;_pixel++) {
            var _actual=buffer_peek(_buffer,_pixel*4,buffer_u32)&$ffffff;
            if(_cache.owners[_pixel]!=_e.part) {
                if(_actual!=_baseline.original[_pixel]) _outside=false;
                if(_cache.overrides[_pixel]) _depth_same=false;
            } else if(_actual!=_baseline.original[_pixel]) _changed++;
        }
        ln_check(_outside && _changed>0,"adding asset changes only its visible pixels, game "+string(_game));
        ln_check(_depth_same,"added asset leaves all other depth inherited");
        surface_save(_cache.surface,"scene-editor-added-asset-"+string(_game)+".png");
        var _preview=buffer_get_size(_buffer),_copy=buffer_create(_preview,buffer_fixed,1);buffer_copy(_buffer,0,_preview,_copy,0);
        _part.depth=20;_e.revision++;_cache=ln_edit_build(_e.scene,-1,"edit");buffer_get_surface(_buffer,_cache.surface,0);
        _same=true;
        for(var _byte=0;_byte<_preview;_byte+=4) if(buffer_peek(_buffer,_byte,buffer_u32)!=buffer_peek(_copy,_byte,buffer_u32)) {_same=false;break;}
        ln_check(_same,"depth-only edit and runtime rendering preserve preview bitmap");
        buffer_delete(_copy);buffer_delete(_buffer);
    }
    _e.scenes=json_parse(_saved);ln_edit_free_cache();
    show_debug_message("LN_EDITOR_BITMAP_PASS: native pixels preserved; added asset isolated; depth and runtime parity in three games");
}

function ln_edit_paint_timing_checks() {
    var _e=global.ln_editor,_saved=json_stringify(_e.scenes),_enabled=_e.enabled,_prefs=global.ln_preferences_enabled;
    global.ln_preferences_enabled=true;
    for(var _game=1;_game<=3;_game++) {
        var _level=_game==2?2:1,_g={game_number:_game,level:_level,room_id:1,timer:new LNClock()};
        _e.enabled=false;global.ln_rewind_epoch++;ln_check(ln_paint_sync(_g),"native painting available");
        var _duration=global.ln_paint.duration,_size=buffer_get_size(global.ln_paint.buffer);
        var _record=buffer_create(_size,buffer_fixed,1);buffer_copy(global.ln_paint.buffer,0,_size,_record,0);
        ln_edit_select(_game,_level,1);ln_edit_add_asset(_game==2?51:_e.scene.parts[0].asset);
        variable_struct_set(_e.scenes,ln_edit_key(_game,_level,1),json_parse(json_stringify(_e.scene)));_e.enabled=true;global.ln_rewind_epoch++;ln_check(ln_paint_sync(_g),"edited room uses recorded painting");
        ln_check(global.ln_paint.duration==_duration && buffer_get_size(global.ln_paint.buffer)==_size,"one added asset does not extend build duration");
        var _same=true;
        for(var _i=0;_i<_size;_i++) if(buffer_peek(_record,_i,buffer_u8)!=buffer_peek(global.ln_paint.buffer,_i,buffer_u8)) {_same=false;break;}
        ln_check(_same,"edited room preserves exact recorded drawing order");buffer_delete(_record);
        ln_modified_begin(_g);var _surface=_e.cache.surface,_key=_e.cache.key;
        global.ln_paint.presented=true;repeat(5) {ln_paint_tick(_g);ln_modified_begin(_g);}
        ln_check(_e.cache.surface==_surface && _e.cache.key==_key,"painting does not rebuild edited bitmap each tick");
        var _speed=global.ln_paint_speed;global.ln_paint_speed=1;
        ln_edit_build_preview_start();ln_edit_build_preview_tick(100000);
        ln_check(global.ln_paint.duration==_duration && global.ln_paint.time==0,"editor preview uses game duration and waits for background draw");
        var _pv=matrix_get(matrix_view),_pp=matrix_get(matrix_projection);
        ln_paint_prepare();ln_check(ln_rewind_equal(_pv,matrix_get(matrix_view)) && ln_rewind_equal(_pp,matrix_get(matrix_projection)),"first painting frame preserves editor camera");
        ln_edit_build_preview_tick(10000);var _first=global.ln_paint.time;
        ln_paint_prepare();ln_check(ln_rewind_equal(_pv,matrix_get(matrix_view)) && ln_rewind_equal(_pp,matrix_get(matrix_projection)),"painting updates preserve editor camera");
        global.ln_paint_speed=2;ln_edit_build_preview_tick(10000);
        ln_check(abs(global.ln_paint.time-_first*3)<=0.00001,"editor preview uses shared build speed immediately: "+string(_first)+" to "+string(global.ln_paint.time)+"");
        global.ln_paint.time=_duration;ln_edit_build_preview_tick(0);
        ln_check(_e.build<0 && !global.ln_paint.active,"editor preview hands over to edited room");global.ln_paint_speed=_speed;
        ln_paint_free();
    }
    _e.scenes=json_parse(_saved);_e.enabled=_enabled;global.ln_preferences_enabled=_prefs;ln_edit_free_cache();
    show_debug_message("LN_EDIT_PAINT_TIMING_PASS: three games retain native duration/order and one cached edit");
}

// Relocate the selected entry without changing its depth or other properties.
// The caller records this as a single undoable scene edit.
function ln_edit_move_part(_target) {
    var _e=global.ln_editor,_parts=_e.scene.parts,_count=array_length(_parts);
    if(_e.part<0 || _e.part>=_count) return false;
    _target=clamp(_target,0,_count-1);if(_target==_e.part) return false;
    var _part=_parts[_e.part];array_delete(_parts,_e.part,1);array_insert(_parts,_target,_part);
    _e.scene.parts=_parts;_e.part=_target;
    _e.scroll=clamp(_target-8,0,max(0,_count-18));
    return true;
}

// Use the same room entrance as F11, without touching the running game or edits.
function ln_edit_spawn_preview() {
    var _e=global.ln_editor,_g=_e.preview;if(!is_struct(_g)) return;
    var _epoch=global.ln_rewind_epoch,_entered=false;
    if(_e.game==1) {
        _entered=ln1_test_enter(_g,_g.navigation.rooms[_e.room_id-1].spawn_entry);
        if(!_entered) ln1_play_enter(_g,_e.room_id);
    } else if(_e.game==2) {
        for(var _i=0;_i<array_length(_g.world.rooms);_i++) if(_g.world.rooms[_i].id==_e.room_id) {
            if(_g.world.rooms[_i].spawn_entry>=0) _entered=ln2_test_enter(_g,_g.world.rooms[_i].spawn_entry);
            break;
        }
        if(!_entered) ln2_play_enter(_g,_e.room_id);
    } else {
        _entered=ln3_test_enter(_g,_e.room_id);
        if(!_entered) {var _entry=json_parse(json_stringify(_g.last_entry));_entry.destination=_e.room_id;ln3_play_enter(_g,_entry);}
    }
    _e.probe_x=_e.game==3?_g.display.parts[2].x-24:_g.player.x;
    _e.probe_y=_e.game==3?_g.display.parts[2].y-29:_g.player.y-29;
    _e.show_ninja=true;global.ln_rewind_epoch=_epoch;
}

function ln_edit_build_preview_start() {
    var _e=global.ln_editor;
    ln_paint_free();global.ln_paint.key="";
    _e.reference=false;_e.build=ln_paint_sync(_e.preview)?0:-1;
}
function ln_edit_build_preview_tick(_elapsed_us) {
    var _e=global.ln_editor,_p=global.ln_paint;
    if(_e.build<0 || !_p.active || !_p.presented) return;
    _p.time+=_elapsed_us/1000000*global.ln_paint_speed;
    if(_p.time>=_p.duration) {ln_paint_free();_e.build=-1;}
}

// Nine-slice the supplied artwork at the existing logical button dimensions.
// Scale the decorative corners down to four UI pixels rather than stretching them.
function ln_ui_button_background(_x,_y,_w,_h,_selected=undefined) {
    var _sw=sprite_get_width(spr_UI_button),_sh=sprite_get_height(spr_UI_button);
    // Inner tool controls use legacy coordinates; the top bar/start screen use the full canvas.
    var _inside=variable_global_exists("ln_tool") && global.ln_tool.active && global.ln_tool.drawing;
    var _mx=_inside?ln_tool_mouse_x():mouse_x,_my=_inside?ln_tool_mouse_y():mouse_y;
    var _hover=_mx>=_x && _mx<_x+_w && _my>=_y && _my<_y+_h;
    var _shade=_hover?255:204;
    if(!is_undefined(_selected) && !_selected) _shade*=0.5;
    var _border=min(4,_w/2,_h/2),_tint=make_colour_rgb(_shade,_shade,_shade);
    var _sx=[0,12,_sw-12],_sy=[0,12,_sh-12];
    var _widths=[12,_sw-24,12],_heights=[12,_sh-24,12];
    var _dx=[_x,_x+_border,_x+_w-_border],_dy=[_y,_y+_border,_y+_h-_border];
    var _dw=[_border,_w-2*_border,_border],_dh=[_border,_h-2*_border,_border];
    for(var _row=0;_row<3;_row++) for(var _col=0;_col<3;_col++) {
        draw_sprite_part_ext(spr_UI_button,0,_sx[_col],_sy[_row],_widths[_col],_heights[_row],
            _dx[_col],_dy[_row],_dw[_col]/_widths[_col],_dh[_row]/_heights[_row],_tint,1);
    }
}

function ln_edit_restore_all() {
    var _e=global.ln_editor;ln_edit_finish_drag();
    var _before=json_stringify(_e.scene);
    _e.scene=ln_edit_source(_e.game,_e.level,_e.room_id);
    ln_edit_changed(_before);_e.reference=true;_e.part=-1;_e.scroll=0;
    _e.depth_edit=false;_e.pending_pick=undefined;_e.dirty_rect=undefined;
    ln_paint_free();ln_edit_spawn_preview();ln_edit_collision_refresh();
    _e.message="Room restored to original. Ctrl+Z to undo.";
}
function ln_edit_value_repeat(_x,_y,_w,_h) {
    if(!variable_global_exists("ln_ui_repeats")) global.ln_ui_repeats={};
    var _key=string(_x)+":"+string(_y);
    if(!variable_struct_exists(global.ln_ui_repeats,_key)) variable_struct_set(global.ln_ui_repeats,_key,{held:false,age:0,next:350000});
    var _state=variable_struct_get(global.ln_ui_repeats,_key);
    return ln_ui_repeat_count(_state,mouse_check_button(mb_left) && ln_edit_inside(_x,_y,_w,_h),mouse_check_button_pressed(mb_left),delta_time);
}
function ln_ui_repeat_count(_state,_held,_pressed,_elapsed) {
    if(!_held) {_state.held=false;return 0;}
    if(_pressed || !_state.held) {_state.held=true;_state.age=0;_state.next=350000;return 1;}
    _state.age+=min(_elapsed,250000);var _count=0;
    while(_state.age>=_state.next && _count<16) {_count++;_state.next+=_state.next>=1200000?30000:90000;}
    return _count;
}

function ln_edit_snag_checks() {
    var _e=global.ln_editor,_scenes=json_stringify(_e.scenes);
    ln_edit_select(1,2,1);var _before=ln_edit_build(_e.scene,-1,"preview").display_colours;
    ln_edit_add_asset(73);var _part=_e.scene.parts[_e.part];_part.x=68;_part.y=101;
    ln_edit_changed(json_stringify(_e.source_scene));
    var _cache=ln_edit_build(_e.scene,-1,"preview"),_o=variable_struct_get(ln_edit_data(1,2).objects,"73"),_decoded=ln_edit_decode(_e.scene,_part,_o);
    for(var _y=0;_y<144;_y++) for(var _x=0;_x<240;_x++) {
        var _px=_x-68,_py=_y-101;
        if(_px>=0 && _px<_o.width && _py>=0 && _py<_o.height && _decoded.codes[_py*_o.width+_px]!=0) continue;
        ln_check(_cache.display_colours[_y*240+_x]==_before[_y*240+_x],"added tree preserves transparent pixels and surrounding room");
    }
    ln_edit_move_bounds(_part,-6,-3);_part.x-=6;_part.y-=3;_e.revision++;
    var _partial=ln_edit_build(_e.scene,-1,"preview").display_colours;
    ln_edit_free_cache();var _full=ln_edit_build(_e.scene,-1,"preview").display_colours;
    ln_check(ln_rewind_equal(_partial,_full),"moved tree partial rebuild matches complete rebuild");
    ln_edit_draw();draw_flush();surface_save(application_surface,"editor-tree-transparency.png");
    var _edited=json_stringify(_e.scene);
    ln_edit_restore_all();ln_check(ln_rewind_equal(_e.scene,ln_edit_source(1,2,1)),"Restore all resets current room");
    ln_check(ln_edit_history(false) && json_stringify(_e.scene)==_edited,"Restore all can be undone");
    var _state={held:false,age:0,next:350000};
    ln_check(ln_ui_repeat_count(_state,true,true,0)==1 && ln_ui_repeat_count(_state,true,false,200000)==0 && ln_ui_repeat_count(_state,true,false,150000)==1,"value button uses depth's 350ms hold delay");
    ln_check(ln_ui_repeat_count(_state,false,false,100000)==0,"value repeat stops on release");
    _e.scenes=json_parse(_scenes);ln_edit_free_cache();
    show_debug_message("LN_EDITOR_SNAGS_PASS");
}

// Read-only geometry derived from the same records used by movement collision.
// LN1/2 actor Y anchors a 42px composite: ground is Y + 42 - 50 = Y - 8.
// LN3 anchors its 21px lower sprite instead: Y + 21 - 50 = Y - 29; X - 24.
function ln_edit_collision_geometry(_game,_bounds) {
    var _out=[];
    for(var _i=0;_i<array_length(_bounds);_i++) {
        var _b=_bounds[_i],_points=[],_rect=undefined,_kind=0;
        if(_game<3) {
            _kind=(_b[4]&1)?1:0;
            for(var _x=_b[0];_x<=_b[2];_x++) {
                var _y=(_b[1]+(_b[4]>=64?-1:1)*(((_x-_b[0])*(_b[4]&62)) div 16))&255;
                array_push(_points,[_x,_y-8]);
            }
        } else {
            _kind=(_b[4]&32)?1:0;
            var _x0=(_b[0]-2)&255,_x1=(_b[2]+2)&255,_y0=_b[1],_y1=_b[3];
            if(_y0<_y1) {_y0=(_y0+1)&255;_y1=(_y1-1)&255;}
            // Match the inclusive/exclusive rectangle test in ln3_collision_update.
            var _lo=_y0>=_y1?_y1:_y0+1,_hi=_y0>=_y1?_y0:_y1;
            if(_x0<=_x1 && _lo<=_hi) _rect=[_x0-24,_lo-29,_x1-24,_hi-29];
            var _type=(_b[4]>>6)&3;
            if(_type!=0 && (_b[4]&3)) for(var _x=_x0;_x<=_x1;_x++) {
                var _y=(_y0+ceil((_x-_x0)/4)*(_type==1?1:-1))&255;
                if(_y>=_lo && _y<=_hi) array_push(_points,[_x-24,_y-29]);
            }
        }
        array_push(_out,{kind:_kind,points:_points,rect:_rect});
    }
    return _out;
}
function ln_edit_collision_refresh() {
    var _e=global.ln_editor,_g=_e.preview;
    var _base=ln_collision_source(_e.scene);
    _e.collision_shapes=ln_edit_collision_geometry(_e.game,ln_collision_merge(_e.game,_base,_e.scene));
}
function ln_edit_collision_draw() {
    var _e=global.ln_editor,_alpha=draw_get_alpha(),_colour=draw_get_colour();
    for(var _i=0;_i<array_length(_e.collision_shapes);_i++) {
        var _shape=_e.collision_shapes[_i];
        draw_set_colour(_shape.kind==0?make_colour_rgb(70,220,255):make_colour_rgb(255,175,45));
        var _r=_shape.rect;
        if(is_array(_r) && _r[2]>=0 && _r[0]<240 && _r[3]>=0 && _r[1]<144) {
            draw_set_alpha(.16);draw_rectangle(_r[0],_r[1],_r[2]+1,_r[3]+1,false);
            draw_set_alpha(.85);draw_rectangle(_r[0],_r[1],_r[2],_r[3],true);
        }
        draw_set_alpha(1);
        for(var _j=0;_j<array_length(_shape.points);_j++) {
            var _p=_shape.points[_j];
            // Pixel samples preserve C64 stepped slopes and avoid joining wrapped Y values.
            draw_rectangle(_p[0],_p[1],_p[0]+1,_p[1]+1,false);
        }
    }
    // The editor's probe corresponds to the player position used by collision.
    if(_e.show_ninja) {
        draw_set_colour(c_white);draw_set_alpha(1);
        var _ground_y=_e.probe_y+(_e.game<3?21:0);
        draw_line(_e.probe_x-3,_ground_y,_e.probe_x+3,_ground_y);
        draw_line(_e.probe_x,_ground_y-3,_e.probe_x,_ground_y+3);
    }
    draw_set_colour(_colour);draw_set_alpha(_alpha);
}
function ln_edit_collision_checks() {
    var _e=global.ln_editor,_rooms=0,_records=0;
    for(var _game=1;_game<=3;_game++) for(var _level=1;_level<=(_game==1?6:(_game==2?7:5));_level++) {
        var _path="play/ln"+string(_game)+"/"+((_game==1 && _level==1)?"":"level"+string(_level)+"/");
        var _data=ln3_data_read(_path+(_game==3?"collision.json":"world.json"));
        for(var _ri=0;_ri<array_length(_data.rooms);_ri++) {
            var _bounds=_data.rooms[_ri].boundaries,_before=json_stringify(_bounds);
            var _shapes=ln_edit_collision_geometry(_game,_bounds);
            ln_check(array_length(_shapes)==array_length(_bounds) && json_stringify(_bounds)==_before,"overlay retains all records without modifying collision data");
            _rooms++;_records+=array_length(_shapes);
        }
    }
    var _test=ln_edit_collision_geometry(1,[[10,60,12,60,16],[10,60,12,60,80]]);
    ln_check(_test[0].points[2][1]==54 && _test[1].points[2][1]==50,"overlay follows signed fixed-point slopes and screen Y offset");
    _test=ln_edit_collision_geometry(3,[[40,80,60,60,33,130]]);
    ln_check(_test[0].rect[0]==14 && _test[0].rect[1]==31 && _test[0].rect[2]==38 && _test[0].rect[3]==51 && _test[0].kind==1,"LN3 effective area includes collision margins and bitmap offset");
    for(var _game=1;_game<=3;_game++) {
        var _preview_level=_game==1?1:2;
        ln_edit_select(_game,_preview_level,ln_edit_rooms(_game,_preview_level)[0]);
        var _scene=json_stringify(_e.scene),_dirty=_e.dirty,_revision=_e.revision;
        _e.show_collisions=false;ln_edit_draw();var _off=ln_edit_screen_buffer();
        _e.show_collisions=true;ln_edit_draw();var _on=ln_edit_screen_buffer();
        ln_check(ln_edit_canvas_difference(_off,_on)>0,"collision overlay renders within each game's room canvas");
        ln_check(json_stringify(_e.scene)==_scene && _e.dirty==_dirty && _e.revision==_revision,"overlay does not create room edits");
        buffer_delete(_off);buffer_delete(_on);surface_save(application_surface,"collision-overlay-"+string(_game)+".png");
    }
    _e.show_collisions=false;
    show_debug_message("LN_COLLISION_OVERLAY_PASS: "+string(_rooms)+" rooms / "+string(_records)+" boundary records across 18 levels");
}

function ln_collision_solid(_game,_record) {return (_record[4]&(_game==3?32:1))==0;}
function ln_collision_source(_scene) {
    var _e=global.ln_editor,_key="collision:"+string(_scene.game)+":"+string(_scene.level);
    if(!variable_struct_exists(_e.datasets,_key)) {
        var _path="play/ln"+string(_scene.game)+"/"+((_scene.game==1 && _scene.level==1)?"":"level"+string(_scene.level)+"/");
        var _data=ln3_data_read(_path+(_scene.game==3?"collision.json":"world.json"));
        if(_scene.game==3) ln3_exposed_wind_edges(_data);
        variable_struct_set(_e.datasets,_key,_data);
    }
    return ln3_room_record(variable_struct_get(_e.datasets,_key).rooms,_scene.room).boundaries;
}
function ln_collision_pack(_scene) {
    if(!variable_struct_exists(_scene,"collisions")) _scene.collisions={edits:[],added:[]};
    return _scene.collisions;
}
function ln_collision_merge(_game,_bounds,_scene) {
    var _out=json_parse(json_stringify(_bounds));
    if(!is_struct(_scene) || !variable_struct_exists(_scene,"collisions")) return _out;
    var _pack=_scene.collisions;
    for(var _i=0;_i<array_length(_pack.edits);_i++) {
        var _edit=_pack.edits[_i],_idx=_edit.index;
        if(_idx>=array_length(_out) || !ln_collision_solid(_game,_out[_idx])) continue;
        if(_edit.removed) {
            // Preserve slots and byte lengths for original scripted references.
            var _off=array_create(array_length(_out[_idx]),0);_off[0]=255;_off[2]=0;_out[_idx]=_off;
        } else _out[_idx]=json_parse(json_stringify(_edit.record));
    }
    for(var _i=0;_i<array_length(_pack.added);_i++) array_push(_out,json_parse(json_stringify(_pack.added[_i])));
    return _out;
}
function ln_collision_runtime(_g,_bounds) {return ln_collision_merge(_g.game_number,_bounds,ln_modified_room(_g));}
function ln_collision_record_valid(_game,_record,_original=undefined) {
    if(!is_array(_record) || array_length(_record)!=(_game==2?6:(_game==3 && is_array(_original)?array_length(_original):5))) return false;
    for(var _i=0;_i<array_length(_record);_i++) if(!(is_real(_record[_i]) || is_int32(_record[_i]) || is_int64(_record[_i])) || is_nan(_record[_i]) || is_infinity(_record[_i]) || _record[_i]!=floor(_record[_i]) || _record[_i]<0 || _record[_i]>255) return false;
    if(!ln_collision_solid(_game,_record) || _record[0]>=_record[2]) return false;
    if(_game<3 && (_record[4]>126 || (_record[4]&1))) return false;
    if(_game==3 && !is_array(_original) && (_record[4]&48)!=0) return false;
    if(is_array(_original)) {
        if(!ln_collision_solid(_game,_original)) return false;
        if(_game==3 && _record[4]!=_original[4]) return false;
        for(var _i=5;_i<array_length(_record);_i++) if(_record[_i]!=_original[_i]) return false;
    } else if(_game==2 && _record[5]!=0) return false;
    return true;
}
function ln_collision_validate(_scene) {
    if(!variable_struct_exists(_scene,"collisions")) return true;
    var _pack=_scene.collisions;
    if(!is_struct(_pack) || !variable_struct_exists(_pack,"edits") || !variable_struct_exists(_pack,"added") || !is_array(_pack.edits) || !is_array(_pack.added) || array_length(_pack.added)>64) return false;
    var _base=ln_collision_source(_scene),_seen=[];
    if(array_length(_pack.edits)>array_length(_base)) return false;
    for(var _i=0;_i<array_length(_pack.edits);_i++) {
        var _v=_pack.edits[_i];
        if(!is_struct(_v) || !variable_struct_exists(_v,"index") || !variable_struct_exists(_v,"removed") || !variable_struct_exists(_v,"record")) return false;
        if(!(is_real(_v.index) || is_int32(_v.index) || is_int64(_v.index)) || is_nan(_v.index) || _v.index!=floor(_v.index) || _v.index<0 || _v.index>=array_length(_base) || array_contains(_seen,_v.index) || !is_bool(_v.removed)) return false;
        if(!ln_collision_record_valid(_scene.game,_v.record,_base[_v.index])) return false;
        array_push(_seen,_v.index);
    }
    for(var _i=0;_i<array_length(_pack.added);_i++) if(!ln_collision_record_valid(_scene.game,_pack.added[_i])) return false;
    return true;
}
function ln_collision_entries() {
    var _e=global.ln_editor,_base=ln_collision_source(_e.scene),_records=ln_collision_merge(_e.game,_base,_e.scene),_out=[];
    for(var _i=0;_i<array_length(_records);_i++) {
        var _r=_records[_i];if(_r[0]>_r[2]) continue;
        array_push(_out,{index:_i,record:_r,locked:!ln_collision_solid(_e.game,_r)});
    }
    return _out;
}
function ln_collision_store(_idx,_record,_remove=false) {
    var _e=global.ln_editor,_base=ln_collision_source(_e.scene),_pack=ln_collision_pack(_e.scene);
    if(_idx<array_length(_base)) {
        if(!ln_collision_solid(_e.game,_base[_idx])) return false;
        var _v={index:_idx,record:_record,removed:_remove};
        for(var _i=0;_i<array_length(_pack.edits);_i++) if(_pack.edits[_i].index==_idx) {_pack.edits[_i]=_v;return true;}
        array_push(_pack.edits,_v);
    } else {
        var _at=_idx-array_length(_base);
        if(_remove) array_delete(_pack.added,_at,1);else _pack.added[_at]=_record;
    }
    return true;
}
function ln_collision_selected() {
    var _e=global.ln_editor,_entries=ln_collision_entries();
    for(var _i=0;_i<array_length(_entries);_i++) if(_entries[_i].index==_e.collision_index) return _entries[_i];
    return undefined;
}
function ln_collision_handles(_game,_r) {
    var _ox=_game==3?24:0,_oy=_game==3?29:8;
    var _y=_game==3?_r[3]:(_r[1]+(_r[4]>=64?-1:1)*(((_r[2]-_r[0])*(_r[4]&62)) div 16))&255;
    return [[_r[0]-_ox,_r[1]-_oy],[_r[2]-_ox,_y-_oy]];
}
function ln_collision_reshape(_game,_r,_handle,_dx,_dy) {
    var _n=json_parse(json_stringify(_r)),_ox=_game==3?24:0,_oy=_game==3?29:8;
    if(_dx==0 && _dy==0) return _n;
    if(_handle<0) {
        _dx=clamp(_dx,min(0,_ox-_r[0]),max(0,min(255,239+_ox)-_r[2]));
        _dy=clamp(_dy,min(0,_oy-min(_r[1],_r[3])),max(0,143+_oy-max(_r[1],_r[3])));
        _n[0]+=_dx;_n[2]+=_dx;_n[1]+=_dy;_n[3]+=_dy;
    } else {
        var _at=_handle*2;
        _n[_at]=clamp(_r[_at]+_dx,_handle==0?min(_ox,_r[0]):_r[0]+1,_handle==0?_r[2]-1:max(_r[2],min(255,239+_ox)));
        _n[_at+1]=clamp(_r[_at+1]+_dy,min(_oy,_r[_at+1]),max(143+_oy,_r[_at+1]));
        if(_game<3) {
            var _slope=clamp(round(abs(_n[3]-_n[1])*8/(_n[2]-_n[0]))*2,0,62);
            var _sign=_n[3]<_n[1]?-1:1;_n[4]=_slope+(_sign<0?64:0);
            _n[3]=(_n[1]+_sign*(((_n[2]-_n[0])*_slope) div 16))&255;
        }
    }
    return _n;
}
function ln_collision_add(_copy=undefined) {
    var _e=global.ln_editor,_before=json_stringify(_e.scene),_pack=ln_collision_pack(_e.scene);
    if(array_length(_pack.added)>=64) return;
    var _r=is_struct(_copy)?json_parse(json_stringify(_copy.record)):(_e.game==1?[80,80,144,80,0]:(_e.game==2?[80,80,144,80,0,0]:[104,80,168,110,15]));
    if(is_struct(_copy)) {
        if(_copy.locked) return;
        // Copy shape/directions, omitting unused trigger descriptor bytes.
        if(_e.game==3) _r=[_r[0],_r[1],_r[2],_r[3],_r[4]&207];
        _r=ln_collision_reshape(_e.game,_r,-1,4,4);
    }
    array_push(_pack.added,_r);_e.collision_index=array_length(ln_collision_source(_e.scene))+array_length(_pack.added)-1;
    _e.collision_scroll=max(0,array_length(ln_collision_entries())-18);
    ln_edit_changed(_before);ln_edit_collision_refresh();
}
function ln_collision_finish_drag() {
    var _e=global.ln_editor;
    if(!is_string(_e.collision_before)) return;
    var _before=_e.collision_before;_e.collision_before=undefined;
    if(json_stringify(_e.scene)!=_before) ln_edit_changed(_before);
    ln_edit_collision_refresh();
}
function ln_collision_edit_step() {
    var _e=global.ln_editor,_entries=ln_collision_entries(),_selected=ln_collision_selected();
    if(mouse_wheel_up()) _e.collision_scroll=max(0,_e.collision_scroll-3);
    if(mouse_wheel_down()) _e.collision_scroll=min(max(0,array_length(_entries)-18),_e.collision_scroll+3);
    for(var _i=0;_i<18;_i++) if(_i+_e.collision_scroll<array_length(_entries) && ln_edit_hit(760,140+22*_i,480,22)) {_e.collision_index=_entries[_i+_e.collision_scroll].index;return true;}
    if(ln_edit_hit(760,548,144,28)) {ln_collision_add();return true;}
    if(ln_edit_hit(916,548,144,28) && is_struct(_selected) && !_selected.locked) {ln_collision_add(_selected);return true;}
    if(is_struct(_selected) && !_selected.locked && (ln_edit_hit(1072,548,144,28) || keyboard_check_pressed(vk_delete))) {
        var _before=json_stringify(_e.scene);ln_collision_store(_selected.index,_selected.record,true);_e.collision_index=-1;ln_edit_changed(_before);ln_edit_collision_refresh();return true;
    }
    var _mx=(ln_tool_mouse_x()-24)/3,_my=(ln_tool_mouse_y()-140)/3;
    if(_mx>=0 && _mx<240 && _my>=0 && _my<144) {
        if(mouse_check_button(mb_right)) {_e.probe_x=_mx;_e.probe_y=_my-(_e.game<3?21:0);}
        if(mouse_check_button_pressed(mb_left)) {
            var _best=6,_hit=undefined,_handle=-1;
            for(var _i=0;_i<array_length(_entries);_i++) {
                var _entry=_entries[_i],_h=ln_collision_handles(_e.game,_entry.record);
                for(var _j=0;_j<2;_j++) {
                    var _dist=point_distance(_mx,_my,_h[_j][0],_h[_j][1]);
                    if(_dist<_best) {_best=_dist;_hit=_entry;_handle=_j;}
                }
                var _shape=ln_edit_collision_geometry(_e.game,[_entry.record])[0];
                for(var _j=0;_j<array_length(_shape.points);_j++) {
                    var _p=_shape.points[_j],_dist=point_distance(_mx,_my,_p[0],_p[1]);
                    if(_dist<_best && _best>2) {_best=_dist;_hit=_entry;_handle=-1;}
                }
                if(_e.game==3 && _mx>=min(_h[0][0],_h[1][0]) && _mx<=max(_h[0][0],_h[1][0]) && _my>=min(_h[0][1],_h[1][1]) && _my<=max(_h[0][1],_h[1][1]) && _best==6) {_hit=_entry;_handle=-1;}
            }
            if(is_struct(_hit)) {
                _e.collision_index=_hit.index;
                if(!_hit.locked) {_e.collision_before=json_stringify(_e.scene);_e.collision_drag_record=_hit.record;_e.collision_handle=_handle;_e.collision_mouse=[_mx,_my];}
            }
        }
    }
    if(is_string(_e.collision_before) && mouse_check_button(mb_left)) {
        var _r=ln_collision_reshape(_e.game,_e.collision_drag_record,_e.collision_handle,round(_mx-_e.collision_mouse[0]),round(_my-_e.collision_mouse[1]));
        ln_collision_store(_e.collision_index,_r);ln_edit_collision_refresh();
    }
    if(is_struct(_selected) && !_selected.locked && !is_string(_e.collision_before)) {
        var _dx=real(keyboard_check_pressed(vk_right))-real(keyboard_check_pressed(vk_left));
        var _dy=real(keyboard_check_pressed(vk_down))-real(keyboard_check_pressed(vk_up));
        if(_dx || _dy) {
            var _step=keyboard_check(vk_shift)?8:1,_before=json_stringify(_e.scene);
            ln_collision_store(_selected.index,ln_collision_reshape(_e.game,_selected.record,-1,_dx*_step,_dy*_step));ln_edit_changed(_before);ln_edit_collision_refresh();
        }
    }
    return true;
}
function ln_collision_edit_handles() {
    var _e=global.ln_editor,_v=ln_collision_selected();if(!is_struct(_v)) return;
    var _h=ln_collision_handles(_e.game,_v.record);draw_set_colour(_v.locked?c_orange:c_yellow);
    for(var _i=0;_i<2;_i++) draw_rectangle(_h[_i][0]-2,_h[_i][1]-2,_h[_i][0]+2,_h[_i][1]+2,true);
    draw_set_colour(c_white);
}
function ln_collision_edit_panel() {
    var _e=global.ln_editor,_entries=ln_collision_entries(),_selected=ln_collision_selected();
    draw_set_colour(c_white);draw_text(760,110,"COLLISIONS (amber rules are locked)");
    for(var _i=0;_i<18 && _i+_e.collision_scroll<array_length(_entries);_i++) {
        var _v=_entries[_i+_e.collision_scroll];
        draw_set_colour(_v.index==_e.collision_index?c_yellow:(_v.locked?c_orange:c_white));
        draw_text(760,140+22*_i,string(_v.index+1)+"  "+(_v.locked?"Hazard / conditional - LOCKED":(_e.game==3?"Solid area":"Solid line")));
    }
    ln_edit_button(760,548,144,_e.game==3?"Add solid area":"Add solid line");ln_edit_button(916,548,144,"Duplicate");ln_edit_button(1072,548,144,"Delete");
    draw_set_colour(c_white);
    if(is_struct(_selected)) {
        var _h=ln_collision_handles(_e.game,_selected.record);
        draw_text(760,602,"Start: "+string(_h[0][0])+", "+string(_h[0][1])+"   End: "+string(_h[1][0])+", "+string(_h[1][1]));
        draw_text(760,632,_selected.locked?"Trigger / hazard record: read-only":"Drag handles to reshape; drag line/area to move.");
        draw_text(760,660,"Original slope and direction rules apply.");
    }
    draw_text(24,646,"Select a line/area or choose it in the list. Yellow boxes are handles.");
    draw_text(24,670,"Arrows: move selection. Shift: larger steps. Ctrl+Z / Ctrl+Y: undo / redo.");
    draw_text(24,702,"Solid collisions only. Amber hazards and trigger rules stay locked.");
    draw_text(24,726,"Save file includes collisions. Test room uses edits with Modified ON.");
    draw_set_colour(make_colour_rgb(150,210,220));draw_text(24,760,(_e.dirty?"Unsaved changes | ":"")+_e.message);
}
function ln_collision_edit_checks() {
    var _e=global.ln_editor;
    for(var _game=1;_game<=3;_game++) {
        var _level=_game==3?2:1;ln_edit_select(_game,_level,ln_edit_rooms(_game,_level)[0]);
        var _base=ln_collision_source(_e.scene),_source=json_stringify(_base),_original=json_stringify(_e.scene);
        _e.collision_edit=true;_e.show_collisions=true;ln_collision_add();
        var _v=ln_collision_selected();ln_check(is_struct(_v) && !_v.locked,"new collision selected");
        var _saved=json_stringify(_e.scene);
        ln_check(ln_edit_validate({format:"LNPreserve-scenes",version:1,scenes:_e.scenes}),"collision file validates in all three games");
        ln_check(ln_edit_history(false) && json_stringify(_e.scene)==_original,"collision add undo");
        ln_check(ln_edit_history(true) && json_stringify(_e.scene)==_saved,"collision add redo");
        var _r=ln_collision_reshape(_game,_v.record,1,8,4),_before=json_stringify(_e.scene);
        ln_collision_store(_v.index,_r);ln_edit_changed(_before);ln_edit_collision_refresh();
        ln_check(ln_collision_record_valid(_game,_r) && _r[2]>_v.record[2],"endpoint reshaping retains valid solid record: "+json_stringify(_r)+" before "+json_stringify(_v.record)+" valid "+string(ln_collision_record_valid(_game,_r)));
        var _runtime=ln_collision_runtime(_e.preview,_base);
        ln_check(array_length(_runtime)==array_length(_base)+1 && ln_rewind_equal(_runtime[array_length(_base)],_r),"Modified runtime receives edited solid");
        _e.enabled=false;ln_check(ln_rewind_equal(ln_collision_runtime(_e.preview,_base),_base),"Modified OFF uses original boundaries");_e.enabled=true;
        var _file="collision-edit-test.json";ln_edit_save(_file);_saved=json_stringify(_e.scene);
        ln_check(ln_edit_load(_file),"collision save/load round trip");file_delete(_file);
        ln_edit_select(_game,_level,_e.room_id);ln_check(ln_rewind_equal(_e.scene,json_parse(_saved)),"saved collisions survive room selection");
        ln_check(ln_rewind_equal(_game==3?_e.preview.bounds:_e.preview.data.boundaries,ln_collision_merge(_game,_base,_e.scene)),"room entry applies saved collisions");
        var _entries=ln_collision_entries(),_solid=undefined;
        for(var _i=0;_i<array_length(_entries);_i++) if(!_entries[_i].locked && _entries[_i].index<array_length(_base) && _entries[_i].record[0]<_entries[_i].record[2]) {_solid=_entries[_i];break;}
        ln_check(is_struct(_solid),"original solid available");
        _before=json_stringify(_e.scene);ln_collision_store(_solid.index,_solid.record,true);ln_edit_changed(_before);
        _runtime=ln_collision_runtime(_e.preview,_base);
        ln_check(array_length(_runtime)==array_length(_base)+1 && _runtime[_solid.index][0]>_runtime[_solid.index][2],"deleted solid retains an inactive slot");
        for(var _i=0;_i<array_length(_base);_i++) if(!ln_collision_solid(_game,_base[_i])) {
            ln_check(ln_rewind_equal(_runtime[_i],_base[_i]),"trigger index and bytes preserved");
            var _bad=json_parse(json_stringify(_e.scene));array_push(ln_collision_pack(_bad).edits,{index:_i,removed:true,record:_base[_i]});
            ln_check(!ln_collision_validate(_bad),"loading trigger edits rejected");
            ln_check(!ln_collision_store(_i,_base[_i],true),"UI cannot delete trigger");
        }
        ln_check(json_stringify(_base)==_source,"original source collision records immutable");
        ln_edit_collision_refresh();_e.collision_index=array_length(_base);ln_edit_draw();surface_save(application_surface,"collision-editor-"+string(_game)+".png");
        ln_edit_restore_all();ln_check(!variable_struct_exists(_e.scene,"collisions"),"Restore all clears collision edits");
        ln_check(ln_edit_history(false) && variable_struct_exists(_e.scene,"collisions"),"restore collisions can be undone");
        _e.scenes={};_e.enabled=false;
    }
    // Native line crossing responds to edited geometry, not only its overlay.
    var _actor={x:100,y:79,boundary_mode:0,boundary_crossings:0};
    ln_check(ln1_player_boundary(_actor,{boundaries:[[80,80,144,80,0]]},100,81)==255,"LN1 added solid blocks movement");
    _actor={x:100,y:79,boundary_mode:0,boundary_crossings:0};
    ln_check(ln1_player_boundary(_actor,{boundaries:[[80,90,144,90,0]]},100,81)==0,"LN1 moved solid clears old position");
    _e.collision_edit=false;_e.show_collisions=false;
    show_debug_message("LN_COLLISION_EDIT_PASS: solid edits, protected triggers, save/load, undo/redo, runtime entry and restore across three games");
}

// Opening via either the toolbar or F6 follows the live room, not the last browse.
function ln_edit_follow_game(_game) {
    var _e=global.ln_editor;
    if(ln_map_active(_game)) {ln_edit_select(_game.game_number,_game.level,_game.room_id);_e.map_open=true;_e.map_room=_game.map_transit.route.rooms[_game.map_transit.index];return true;}
    if(!is_struct(_e.scene) || _e.game!=_game.game_number || _e.level!=_game.level || _e.room_id!=_game.room_id)
        return ln_edit_select(_game.game_number,_game.level,_game.room_id);
    // Preserve selection and undo history when already editing this exact room.
    ln_edit_spawn_preview();ln_edit_collision_refresh();return true;
}
function ln_edit_follow_game_checks() {
    var _e=global.ln_editor;
    for(var _game=1;_game<=3;_game++) {
        var _room=ln_edit_rooms(_game,1)[0];ln_edit_select(_game,1,_room);
        var _before=json_stringify(_e.scene);_e.scene.parts[0].x+=2;ln_edit_changed(_before);
        var _saved=json_stringify(_e.scene),_undo=array_length(_e.undo);
        ln_edit_follow_game({game_number:_game,level:1,room_id:_room});
        ln_check(array_length(_e.undo)==_undo,"same-room editor opening preserves undo");
        var _other=ln_edit_rooms(_game,2)[1];
        ln_edit_follow_game({game_number:_game,level:2,room_id:_other});
        ln_check(_e.game==_game && _e.level==2 && _e.room_id==_other && _e.preview.room_id==_other,"editor follows live level and room");
        ln_edit_follow_game({game_number:_game,level:1,room_id:_room});
        ln_check(ln_rewind_equal(_e.scene,json_parse(_saved)),"switching away retains in-memory edits");
    }
    _e.scenes={};_e.enabled=false;
    show_debug_message("LN_EDITOR_FOLLOW_GAME_PASS");
}
function ln_edit_overlap_transparency_checks() {
    var _e=global.ln_editor,_saved=json_stringify(_e.scenes);
    _e.scenes={};ln_edit_select(1,1,3);_e.reference=false;_e.show_ninja=false;
    // Reported room: move the large boulder behind the original foreground shrub.
    _e.scene.parts[13].x=88;_e.scene.parts[13].y=-2;_e.scene.parts[13].overlay=true;
    var _full=json_parse(json_stringify(_e.scene)),_front=_full.parts[33];
    var _o=variable_struct_get(ln_edit_data(1,1).objects,string(_front.asset)),_decoded=ln_edit_decode(_full,_front,_o);
    var _prefix=json_parse(json_stringify(_full));array_resize(_prefix.parts,33);
    ln_edit_free_cache();var _under=ln_edit_build(_prefix,-1,"preview"),_under_colours=_under.display_colours,_under_owners=_under.owners;
    ln_edit_free_cache();var _drawn=ln_edit_build(_full,-1,"preview"),_checked=0;
    for(var _y=0;_y<_o.height;_y++) for(var _x=0;_x<_o.width;_x++) {
        var _px=_front.x+_x,_py=_front.y+_y,_at=_py*240+_px;
        if(_px<0 || _px>=240 || _py<0 || _py>=144 || _decoded.codes[_y*_o.width+_x]!=0 || _under_owners[_at]!=13) continue;
        _checked++;ln_check(_drawn.display_colours[_at]==_under_colours[_at],"foreground transparent pixels retain edited boulder before any jiggle at "+string(_px)+","+string(_py));
    }
    ln_check(_checked>0,"reported overlap exercises actual transparent foreground pixels");
    var _first=json_stringify(_drawn.display_colours);
    ln_edit_free_cache();ln_check(json_stringify(ln_edit_build(_full,-1,"preview").display_colours)==_first,"cold and cached overlap draws agree");
    _e.scene=_full;ln_edit_draw();surface_save(application_surface,"editor-overlap-transparency.png");
    _e.scenes=json_parse(_saved);ln_edit_free_cache();
    show_debug_message("LN_EDITOR_OVERLAP_TRANSPARENCY_PASS: "+string(_checked)+" foreground holes preserve edited underlay");
}
function ln_edit_restore_game_music(_g) {
    var _e=global.ln_editor;
    if(!is_undefined(_e.test_music_restore)) {
        ln_tool_music_set(_g,_e.test_music_restore);_e.test_music_restore=undefined;
    } else ln_tool_music_set(_g,ln_tool_music_enabled(_g));
}

// Locate source and destination footprints independently of the current drag.
// This also covers deletion and edits restored from a saved file.
function ln_edit_source_changes(_scene) {
    var _source=ln_edit_source(_scene.game,_scene.level,_scene.room),_data=ln_edit_data(_scene.game,_scene.level);
    var _changed=array_create(array_length(_source.parts),true),_original=array_create(240*144,false),_boxes=[];
    for(var _i=0;_i<array_length(_scene.parts);_i++) {
        var _p=_scene.parts[_i],_id=variable_struct_exists(_p,"source_index")?_p.source_index:-1,_same=false;
        if(_id>=0 && _id<array_length(_source.parts)) {
            var _old=_source.parts[_id];
            _same=_p.asset==_old.asset && _p.x==_old.x && _p.y==_old.y && _p.flip==_old.flip && json_stringify(_p.recolour)==json_stringify(_old.recolour);
            _changed[_id]=!_same;
        }
    }
    for(var _j=0;_j<array_length(_changed);_j++) if(_changed[_j]) array_push(_boxes,_source.parts[_j]);
    for(var _b=0;_b<array_length(_boxes);_b++) {
        var _part=_boxes[_b],_o=variable_struct_get(_data.objects,string(_part.asset));
        for(var _y=max(0,floor(_part.y/8)*8);_y<min(144,ceil((_part.y+_o.height)/8)*8);_y++)
            for(var _x=max(0,floor(_part.x/8)*8);_x<min(240,ceil((_part.x+_o.width)/8)*8);_x++) _original[_y*240+_x]=true;
    }
    return {original:_original,changed:_changed};
}

function ln_edit_vacated_checks() {
    var _e=global.ln_editor,_saved=json_stringify(_e.scenes);_e.scenes={};
    for(var _game=2;_game<=3;_game++) {
        ln_edit_select(_game,1,_game==2?1:0);_e.reference=false;_e.show_ninja=false;
        var _indices=_game==2?[59]:[52,55],_source=json_parse(json_stringify(_e.scene));
        for(var _j=0;_j<array_length(_indices);_j++) {
            var _p=_e.scene.parts[_indices[_j]];_p.overlay=true;
            _p.x=_game==2?72:156;_p.y=_game==2?55:(_j==0?75:67);
        }
        ln_edit_free_cache();var _c=ln_edit_build(_e.scene,-1,"preview"),_baseline=ln_edit_bitmap_baseline(_e.scene),_changes=ln_edit_source_changes(_e.scene),_cleared=0;
        for(var _i=0;_i<240*144;_i++) {
            var _old=_baseline.owners[_i];
            if(_old>=0 && _changes.changed[_old] && _c.owners[_i]<0) {
                ln_check(_c.overrides[_i] && _c.depth[_i]==0,"vacated object silhouette clears native depth");
                _e.native_preview=true;ln_check(!ln_modified_hidden(_i mod 240,_i div 240,120,true),"native mask cannot hide ninja in vacated silhouette");_e.native_preview=false;_cleared++;
            }
            var _owner=_c.owners[_i],_source_owner=_owner<0?-1:_e.scene.parts[_owner].source_index;
            if(_source_owner==_old && (_old<0 || !_changes.changed[_old]) && _c.colours[_i]==_baseline.colours[_i])
                ln_check(_c.display_colours[_i]==_baseline.original[_i],"unchanged ground keeps native colours even inside moved prop bounds");

        }
        ln_check(_cleared>0,"reported move exercises exposed original mask pixels");
        if(_game==3) {
            ln_check(_c.display_colours[58*240+148]==make_colour_rgb(123,123,123) && _c.display_colours[60*240+150]==make_colour_rgb(123,123,123),"LN3 vacated trunk reveals grey path, not green background");
        }
        var _expected=json_stringify(_c.display_colours);ln_edit_free_cache();_e.scene=json_parse(json_stringify(_e.scene));
        ln_check(json_stringify(ln_edit_build(_e.scene,-1,"preview").display_colours)==_expected,"saved/reloaded moved props reconstruct identically");
        ln_edit_draw();surface_save(application_surface,"editor-vacated-ln"+string(_game)+".png");
        _e.scene=_source;array_delete(_e.scene.parts,_indices[0],1);ln_edit_free_cache();
        _c=ln_edit_build(_e.scene,-1,"preview");_cleared=0;
        for(var _k=0;_k<240*144;_k++) if(_baseline.owners[_k]==_indices[0] && _c.owners[_k]<0) {
            ln_check(_c.overrides[_k] && _c.depth[_k]==0,"removed props clear native depth");_cleared++;
        }
        ln_check(_cleared>0,"removed prop exposes mask pixels");
    }
    _e.scenes=json_parse(_saved);ln_edit_free_cache();show_debug_message("LN_EDITOR_VACATED_PASS: LN2/LN3 moved and removed props clear native pixels and depth");
}

function ln_edit_revealed_colour(_baseline,_owner,_colour,_x,_y) {
    var _best=100000,_result=_colour;
    for(var _dy=-16;_dy<=16;_dy++) for(var _dx=-16;_dx<=16;_dx+=2) {
        var _distance=_dx*_dx+_dy*_dy;
        if(_distance==0 || _distance>=_best) continue;
        var _px=_x+_dx,_py=_y+_dy;
        if(_px<0 || _px>=240 || _py<0 || _py>=144) continue;
        var _at=_py*240+_px;
        if(_baseline.owners[_at]==_owner && _baseline.colours[_at]==_colour) {
            _best=_distance;_result=_baseline.original[_at];
        }
    }
    return _result;
}


// Modified-mode ordinary enemies. Native scripted encounters are never replaced.
function ln_enemy_copy(_v) {return json_parse(json_stringify(_v));}
function ln_enemy_capture(_g) {
    if(_g.game_number<3) return ln_enemy_copy(_g.enemy);
    var _s=_g.state,_out={},_names=variable_struct_get_names(_s);
    for(var _i=0;_i<array_length(_names);_i++) {
        var _key=_names[_i];
        if(string_pos("enemy_",_key)==1 || string_pos("patrol_",_key)==1) variable_struct_set(_out,_key,ln_enemy_copy(variable_struct_get(_s,_key)));
    }
    _out.parts=[ln_enemy_copy(_s.parts[4]),ln_enemy_copy(_s.parts[5]),ln_enemy_copy(_s.parts[6])];
    _out.draw={};
    var _drawkeys=["draw_frames","draw_x","draw_y","draw_colours","draw_mirror"];
    for(var _k=0;_k<array_length(_drawkeys);_k++) {var _v=variable_struct_get(_s,_drawkeys[_k]);variable_struct_set(_out.draw,_drawkeys[_k],is_array(_v)?[_v[4],_v[5],_v[6]]:[-1,-1,-1]);}
    _out.enabled=_s.enabled&112;_out.mirror=_s.mirror&112;
    _out.multicolour=_s.multicolour&112;_out.expand_x=_s.expand_x&112;_out.expand_y=_s.expand_y&112;
    return _out;
}
function ln_enemy_apply(_g,_actor) {
    if(_g.game_number<3) {_g.enemy=ln_enemy_copy(_actor);return;}
    var _s=_g.state,_names=variable_struct_get_names(_actor);
    for(var _i=0;_i<array_length(_names);_i++) {
        var _key=_names[_i];
        if(string_pos("enemy_",_key)==1 || string_pos("patrol_",_key)==1) variable_struct_set(_s,_key,ln_enemy_copy(variable_struct_get(_actor,_key)));
    }
    for(var _j=0;_j<3;_j++) _s.parts[4+_j]=ln_enemy_copy(_actor.parts[_j]);
    if(variable_struct_exists(_actor,"draw")) {var _keys=variable_struct_get_names(_actor.draw);for(var _k=0;_k<array_length(_keys);_k++) {var _v=variable_struct_get(_s,_keys[_k]);if(!is_array(_v)) _v=array_create(8,-1);var _a=variable_struct_get(_actor.draw,_keys[_k]);for(var _j=0;_j<3;_j++) _v[4+_j]=_a[_j];variable_struct_set(_s,_keys[_k],_v);}}
    _s.enabled=(_s.enabled&143)|_actor.enabled;_s.mirror=(_s.mirror&143)|_actor.mirror;
    _s.multicolour=(_s.multicolour&143)|_actor.multicolour;_s.expand_x=(_s.expand_x&143)|_actor.expand_x;_s.expand_y=(_s.expand_y&143)|_actor.expand_y;
}
function ln_enemy_position(_game,_a) {return _game<3?[_a.x,_a.y-8]:[_a.enemy_x-24,_a.enemy_y-29];}
function ln_enemy_place(_game,_a,_x,_y,_facing) {
    if(_game<3) {
        _a.x=round(_x);_a.y=round(_y)+8;_a.facing=_facing;_a.heading=_facing;_a.action_mirror=_facing&2;
        _a.fraction_x=0;_a.fraction_y=0;_a.depth_y=_a.y;_a.patrol_x=_a.x;
    } else {
        var _dx=round(_x)+24-_a.enemy_x,_dy=round(_y)+29-_a.enemy_y;
        _a.enemy_x+=_dx;_a.enemy_y+=_dy;
        for(var _i=0;_i<3;_i++) {_a.parts[_i].x+=_dx;_a.parts[_i].y+=_dy;}
        _a.mirror=(_facing&4)?112:0;
        if(variable_struct_exists(_a,"draw")) for(var _j=0;_j<3;_j++) {_a.draw.draw_x[_j]+=_dx;_a.draw.draw_y[_j]+=_dy;_a.draw.draw_mirror[_j]=(_facing&4)!=0;}
    }
}
function ln_enemy_catalog(_game,_level) {
    var _e=global.ln_editor,_key=string(_game)+":"+string(_level);
    if(variable_struct_exists(_e.enemy_catalogs,_key)) return variable_struct_get(_e.enemy_catalogs,_key);
    _e.enemy_catalog_building=true;var _epoch=global.ln_rewind_epoch;
    var _g=_game==1?new LN1Play(_level):(_game==2?new LN2Play(_level):new LN3Play(_level));
    var _out={types:[],rooms:{}},_rooms=_g.world.rooms;
    for(var _i=0;_i<array_length(_rooms);_i++) {
        var _room=_rooms[_i],_id=_room.id,_ordinary=false,_special=false,_actor=undefined;
        if(_game<3) {
            if(_game==1) ln1_play_enter(_g,_id);else ln2_play_enter(_g,_id);
            var _steps=0;
            while((_g.enemy.active<128 || _g.enemy.display_frame>=64) && _g.enemy.action>=256 && _steps++<240) {
                _g.player.tick=(_g.player.tick+1)&255;
                if(_game==1) {ln1_enemy_action(_g);ln1_combat_event(_g,_g.enemy.action_state,true);}
                else {ln2_enemy_action(_g);ln2_combat_event(_g,_g.enemy.action_state,true);}
                _g.enemy.action_state=0;
            }
            _ordinary=_g.enemy.active>=128 && _g.enemy.active<132 && _g.enemy.display_frame<64 && !(_game==2 && _level==7);
            _special=!_ordinary && (_g.enemy.active>=128 || _g.enemy.action>=256 || (_game==1?_room.enemy_script!=0:_g.enemy.custom));
            if(_ordinary) {
                _actor=ln_enemy_capture(_g);
                // The editor replaces the entrance animation with an idle pose.
                // LN1 event 9 normally equips this weapon later in that sequence.
                if(_game==1) _actor.weapon=_actor.active&3;
            }
        } else {
            var _record=ln3_room_record(_g.data.rooms,_id);
            if(is_struct(_record) && array_length(_record.enemy)>=6) {
                _g.state.enemy_dead=0;_g.state.enemy_health=44;
                ln3_enemy_enter(_g.state,_g.actions,_g.data,_record);
                _special=(_g.state.parts[4].animation==138 || _id>=13 || _level==5);
                _ordinary=!_special;
                if(_ordinary) {ln3_animation_update(_g.state,_g.animation);_actor=ln_enemy_capture(_g);}
            }
        }
        var _entry={locked:_special,type:-1,defaults:[]};
        if(_ordinary) {
            var _type=array_length(_out.types),_pos=ln_enemy_position(_game,_actor);
            var _facing=_game<3?_actor.facing:((_actor.mirror&96)?7:3);
            if(!array_contains([1,3,5,7],_facing)) _facing=3;
            array_push(_out.types,{label:"Guard / room "+string(_id),actor:_actor,room:_id,trace:ln_enemy_native_trace(_g,_actor)});
            _entry.type=_type;
            array_push(_entry.defaults,{type:_type,x:clamp(_pos[0],0,239),y:clamp(_pos[1],0,143),facing:_facing,patrol:0,route:[]});
        }
        variable_struct_set(_out.rooms,string(_id),_entry);
    }
    variable_struct_set(_e.enemy_catalogs,_key,_out);_e.enemy_catalog_building=false;global.ln_rewind_epoch=_epoch;
    return _out;
}
function ln_enemy_configs(_scene) {
    if(variable_struct_exists(_scene,"enemies")) return _scene.enemies;
    var _cat=ln_enemy_catalog(_scene.game,_scene.level);
    return variable_struct_exists(_cat.rooms,string(_scene.room))?variable_struct_get(_cat.rooms,string(_scene.room)).defaults:[];
}
function ln_enemy_validate(_scene) {
    if(!variable_struct_exists(_scene,"enemies")) return true;
    if(!is_array(_scene.enemies) || array_length(_scene.enemies)>8) return false;
    var _catalog=ln_enemy_catalog(_scene.game,_scene.level);
    if(!variable_struct_exists(_catalog.rooms,string(_scene.room)) || variable_struct_get(_catalog.rooms,string(_scene.room)).locked) return false;
    for(var _i=0;_i<array_length(_scene.enemies);_i++) {
        var _a=_scene.enemies[_i];if(!is_struct(_a)) return false;
        var _keys=["type","x","y","facing","patrol","route"];
        for(var _j=0;_j<array_length(_keys);_j++) if(!variable_struct_exists(_a,_keys[_j])) return false;
        if(!ln_enemy_number(_a.type) || _a.type<0 || _a.type>=array_length(_catalog.types) || !ln_enemy_number(_a.x) || _a.x<0 || _a.x>239 || !ln_enemy_number(_a.y) || _a.y<0 || _a.y>143 || !array_contains([1,3,5,7],_a.facing) || !array_contains([0,1,2],_a.patrol) || !is_array(_a.route) || array_length(_a.route)>16) return false;
        for(var _k=0;_k<array_length(_a.route);_k++) {
            var _point=_a.route[_k];if(!is_array(_point) || array_length(_point)!=2 || !ln_enemy_number(_point[0]) || !ln_enemy_number(_point[1]) || _point[0]<0 || _point[0]>239 || _point[1]<0 || _point[1]>143) return false;
        }
    }
    return true;
}
function ln_enemy_editor_commit(_before,_list) {
    var _e=global.ln_editor;_e.scene.enemies=_list;ln_edit_changed(_before);
}
function ln_enemy_editor_step() {
    var _e=global.ln_editor,_cat=ln_enemy_catalog(_e.game,_e.level),_info=variable_struct_get(_cat.rooms,string(_e.room_id));
    var _list=ln_enemy_copy(ln_enemy_configs(_e.scene)),_before=json_stringify(_e.scene),_changed=false;
    if(_info.locked) return true;
    _e.enemy_index=clamp(_e.enemy_index,0,max(0,array_length(_list)-1));
    for(var _i=0;_i<array_length(_list);_i++) if(ln_edit_hit(760,140+_i*30,480,28)) {_e.enemy_index=_i;_e.enemy_waypoint=-1;}
    if(ln_edit_hit(760,400,120,28) && array_length(_list)<8 && array_length(_cat.types)>0) {
        var _a=array_length(_list)>0?ln_enemy_copy(_list[_e.enemy_index]):{type:0,x:120,y:90,facing:3,patrol:1,route:[]};
        _a.x=clamp(_a.x+16,0,239);array_push(_list,_a);_e.enemy_index=array_length(_list)-1;_changed=true;
    }
    if(ln_edit_hit(892,400,120,28) && array_length(_list)>0) {array_delete(_list,_e.enemy_index,1);_e.enemy_index=max(0,_e.enemy_index-1);_changed=true;}
    if(ln_edit_hit(1024,400,220,28)) {
        if(variable_struct_exists(_e.scene,"enemies")) {variable_struct_remove(_e.scene,"enemies");ln_edit_changed(_before);}return true;
    }
    if(array_length(_list)>0) {
        var _p=_list[_e.enemy_index];
        if(array_length(_cat.types)>0 && ln_edit_hit(760,446,44,28)) {_p.type=(_p.type+array_length(_cat.types)-1) mod array_length(_cat.types);_changed=true;}
        if(array_length(_cat.types)>0 && ln_edit_hit(1200,446,44,28)) {_p.type=(_p.type+1) mod array_length(_cat.types);_changed=true;}
        if(ln_edit_hit(760,486,145,28)) {_p.facing=(_p.facing+2)&7;_changed=true;}
        if(ln_edit_hit(916,486,160,28)) {_p.patrol=(_p.patrol+1) mod 3;_changed=true;}
        if(ln_edit_hit(1088,486,156,28)) {_p.route=[];_p.patrol=1;_changed=true;}
        var _mx=round((ln_tool_mouse_x()-24)/3),_my=round((ln_tool_mouse_y()-140)/3),_inside=_mx>=0 && _mx<240 && _my>=0 && _my<144;
        if(_inside && mouse_check_button_pressed(mb_left)) {
            if(keyboard_check(vk_shift) && array_length(_p.route)<16) {array_push(_p.route,[_mx,_my]);_p.patrol=2;_changed=true;}
            else {
                _e.enemy_waypoint=-1;_e.enemy_drag=false;
                for(var _k=0;_k<array_length(_p.route);_k++) if(point_distance(_mx,_my,_p.route[_k][0],_p.route[_k][1])<5) {_e.enemy_waypoint=_k;_e.enemy_drag=true;break;}
                if(!_e.enemy_drag) for(var _j=array_length(_list)-1;_j>=0;_j--) if(point_distance(_mx,_my,_list[_j].x,_list[_j].y)<12) {_e.enemy_index=_j;_e.enemy_drag=true;_p=_list[_j];break;}
                if(_e.enemy_drag) {_e.drag=true;_e.drag_before=_before;}
            }
        }
        if(_e.enemy_drag && _inside && mouse_check_button(mb_left)) {
            if(_e.enemy_waypoint>=0) {if(_p.route[_e.enemy_waypoint][0]!=_mx || _p.route[_e.enemy_waypoint][1]!=_my) {_p.route[_e.enemy_waypoint]=[_mx,_my];_changed=true;}}
            else if(_p.x!=_mx || _p.y!=_my) {_p.x=_mx;_p.y=_my;_changed=true;}
        }
        if(!mouse_check_button(mb_left)) _e.enemy_drag=false;
        var _step=keyboard_check(vk_shift)?8:1;
        var _dx=(keyboard_check_pressed(vk_right)-keyboard_check_pressed(vk_left))*_step,_dy=(keyboard_check_pressed(vk_down)-keyboard_check_pressed(vk_up))*_step;
        if(_dx || _dy) {_p.x=clamp(_p.x+_dx,0,239);_p.y=clamp(_p.y+_dy,0,143);_changed=true;}
    }
    if(_changed) ln_enemy_editor_commit(_before,_list);
    return true;
}
function ln_enemy_editor_panel() {
    var _e=global.ln_editor,_cat=ln_enemy_catalog(_e.game,_e.level),_list=ln_enemy_configs(_e.scene),_info=variable_struct_get(_cat.rooms,string(_e.room_id));
    draw_set_colour(c_white);draw_text(760,110,"ENEMIES / one opponent engages");
    if(_info.locked) {draw_text(760,150,"Scripted encounter / original behaviour");draw_text(24,646,"This animal or boss encounter is protected.");return;}
    for(var _i=0;_i<array_length(_list);_i++) {
        var _a=_list[_i];ln_edit_button(760,140+_i*30,480,string(_i+1)+"  "+(_a.type<array_length(_cat.types)?_cat.types[_a.type].label:"Unavailable type"),_i==_e.enemy_index);
    }
    ln_edit_button(760,400,120,"Add / copy");ln_edit_button(892,400,120,"Remove");ln_edit_button(1024,400,220,"Original enemies");
    if(array_length(_list)>0) {
        var _p=_list[clamp(_e.enemy_index,0,array_length(_list)-1)];
        ln_edit_button(760,446,44,"<");ln_edit_button(1200,446,44,">");draw_text(820,451,_p.type<array_length(_cat.types)?_cat.types[_p.type].label:"Unavailable");
        ln_edit_button(760,486,145,"Facing "+string(_p.facing));ln_edit_button(916,486,160,["Native patrol","Idle","Route"][_p.patrol]);ln_edit_button(1088,486,156,"Clear route");
        draw_text(760,530,"Spawn: "+string(_p.x)+", "+string(_p.y)+" / "+string(array_length(_p.route))+" waypoints");
    }
    draw_text(24,646,"Drag a numbered spawn marker. Arrows move it; Shift makes larger steps.");
    draw_text(24,670,"Shift-click: add patrol point. Drag points to adjust. Routes loop to spawn.");
    draw_text(24,702,"Yellow: spawn. Cyan: route. Blue: native patrol sample (reactive).");
    draw_text(24,726,"Ordinary guards only, from this level. Modified ON applies edits in Test room.");
    draw_set_colour(make_colour_rgb(150,210,220));draw_text(24,760,_e.message);draw_set_colour(c_white);
}
function ln_enemy_editor_overlay() {
    var _e=global.ln_editor,_cat=ln_enemy_catalog(_e.game,_e.level),_list=ln_enemy_configs(_e.scene);
    for(var _i=0;_i<array_length(_list);_i++) {
        var _c=_list[_i];if(_c.type>=array_length(_cat.types)) continue;
        var _a=ln_enemy_copy(_cat.types[_c.type].actor);ln_enemy_place(_e.game,_a,_c.x,_c.y,_c.facing);
        _a=ln_enemy_pose(_e.preview,_a,_c.facing,false);
        ln_enemy_draw_actor(_e.preview,_a);
        draw_set_colour(_i==_e.enemy_index?c_yellow:c_white);draw_circle(_c.x,_c.y,4,true);
        draw_line(_c.x,_c.y,_c.x+((_c.facing&4)?-8:8),_c.y+((_c.facing==1 || _c.facing==7)?-4:4));
        draw_set_font(-1);draw_text(_c.x+5,_c.y-9,string(_i+1));draw_set_font(font_jansina);
        if(_c.patrol==0) {
            var _trace=_cat.types[_c.type].trace;draw_set_colour(make_colour_rgb(100,150,200));
            for(var _t=1;_t<array_length(_trace);_t++) draw_line(_c.x+_trace[_t-1][0],_c.y+_trace[_t-1][1],_c.x+_trace[_t][0],_c.y+_trace[_t][1]);
        }
        if(_c.patrol==2) {
            var _last=[_c.x,_c.y];draw_set_colour(c_aqua);
            for(var _j=0;_j<array_length(_c.route);_j++) {var _point=_c.route[_j];draw_line(_last[0],_last[1],_point[0],_point[1]);draw_rectangle(_point[0]-2,_point[1]-2,_point[0]+2,_point[1]+2,true);_last=_point;}
            if(array_length(_c.route)>0) draw_line(_last[0],_last[1],_c.x,_c.y);
        }
    }
    draw_set_colour(c_white);
}
function ln_enemy_draw_actor(_g,_actor) {
    if(_g.game_number==1) {ln1_play_actor(_g,_actor,true);return;}
    if(_g.game_number==2) {var _kind=_g.projectiles[1].kind;_g.projectiles[1].kind=0;ln2_play_actor(_g,_actor,true);_g.projectiles[1].kind=_kind;return;}
    var _saved=ln_enemy_capture(_g),_display=_g.display,_masks=_g.draw_masks,_version=_g.render_version,_spill=_g.state.mask_spill,_colours=_g.special_colours;
    ln_enemy_apply(_g,_actor);var _d=ln_enemy_copy(_g.state);ln3_play_prepare_draw(_g,_d);
    for(var _i=0;_i<8;_i++) {var _part=_g.animation.order[_i];if(_part>=4 && _part<=6) ln3_play_actor_part(_g,_d,_part);}
    ln_enemy_apply(_g,_saved);_g.display=_display;_g.draw_masks=_masks;_g.render_version=_version;_g.state.mask_spill=_spill;_g.special_colours=_colours;
}

function ln_enemy_number(_v) {return (is_real(_v) || is_int32(_v) || is_int64(_v)) && !is_nan(_v) && !is_infinity(_v) && floor(_v)==_v;}
function ln_enemy_custom(_g) {return variable_struct_exists(_g,"edited_enemies") && is_struct(_g.edited_enemies);}
function ln_enemy_flush(_g) {
    if(!ln_enemy_custom(_g)) return;
    var _m=_g.edited_enemies;
    if(_m.active>=0) _m.slots[_m.active].actor=ln_enemy_capture(_g);
}
function ln_enemy_room_leave(_g) {
    if(!ln_enemy_custom(_g)) return;
    ln_enemy_flush(_g);
    var _m=_g.edited_enemies,_dead={};
    for(var _i=0;_i<array_length(_m.slots);_i++) {
        var _slot=_m.slots[_i];
        if(_slot.finished || ln_enemy_dead(_g,_slot.actor))
            variable_struct_set(_dead,string(_i),ln_enemy_copy(_slot));
    }
    if(!variable_struct_exists(_g,"edited_enemy_rooms")) _g.edited_enemy_rooms={};
    variable_struct_set(_g.edited_enemy_rooms,_m.key,{signature:_m.signature,dead:_dead});
    _g.edited_enemies=undefined;
}
function ln_enemy_dead(_g,_a) {
    if(_g.game_number==1) return _a.wounds>=32;
    if(_g.game_number==2) return _a.health<=0 || _a.knockouts>=128;
    return _a.enemy_dead!=0 || _a.enemy_health<=0;
}
function ln_enemy_runtime(_g) {
    var _e=global.ln_editor;if(_e.enemy_catalog_building) return;
    var _scene=ln_modified_room(_g),_key=ln_edit_key(_g.game_number,_g.level,_g.room_id);
    if(!is_struct(_scene) || !variable_struct_exists(_scene,"enemies")) {
        if(ln_enemy_custom(_g)) {ln_enemy_apply(_g,_g.edited_enemies.original);_g.edited_enemies=undefined;}return;
    }
    var _cat=ln_enemy_catalog(_g.game_number,_g.level),_info=variable_struct_get(_cat.rooms,string(_g.room_id));
    if(_info.locked) return;
    var _signature=json_stringify(_scene.enemies);
    if(!ln_enemy_custom(_g) || _g.edited_enemies.key!=_key || _g.edited_enemies.signature!=_signature) {
        var _m={key:_key,signature:_signature,slots:[],active:-1,engaged:false,original:ln_enemy_capture(_g),ticks:0,shapes:ln_edit_collision_geometry(_g.game_number,_g.game_number==3?_g.bounds:_g.data.boundaries)};
        for(var _i=0;_i<array_length(_scene.enemies);_i++) {
            var _cfg=_scene.enemies[_i];if(_cfg.type>=array_length(_cat.types)) continue;
            var _a=ln_enemy_copy(_cat.types[_cfg.type].actor);ln_enemy_place(_g.game_number,_a,_cfg.x,_cfg.y,_cfg.facing);
            _a=ln_enemy_pose(_g,_a,_cfg.facing,false);
            if(_g.game_number<3) {_a.action_tick=_g.player.tick;_a.decision_tick=_g.player.tick;_a.mode=1;}
            array_push(_m.slots,{config:ln_enemy_copy(_cfg),actor:_a,finished:false,down_ticks:0,route_index:0,x:_cfg.x,y:_cfg.y,walking:false});
        }
        // Living guards restart their patrol; defeated guards retain their pose and position.
        if(variable_struct_exists(_g,"edited_enemy_rooms") && variable_struct_exists(_g.edited_enemy_rooms,_key)) {
            var _visit=variable_struct_get(_g.edited_enemy_rooms,_key);
            if(_visit.signature==_signature) for(var _i=0;_i<array_length(_m.slots);_i++) {
                if(variable_struct_exists(_visit.dead,string(_i))) {
                    _m.slots[_i]=ln_enemy_copy(variable_struct_get(_visit.dead,string(_i)));
                    _m.slots[_i].walking=false;
                    if(!_m.slots[_i].finished) _m.active=_i;
                }
            }
        }
        _g.edited_enemies=_m;
        if(_m.active>=0) ln_enemy_apply(_g,_m.slots[_m.active].actor);
    } else ln_enemy_flush(_g);
    var _m=_g.edited_enemies;_m.ticks++;
    var _player=_g.game_number<3?[_g.player.x,_g.player.y-8]:[_g.state.player_x-24,_g.state.player_y-29];
    if(_m.active>=0) {
        var _current=_m.slots[_m.active];
        if(ln_enemy_dead(_g,_current.actor)) {
            _current.down_ticks++;
            if(_current.down_ticks>=60) {_current.finished=true;_m.active=-1;}
        }
    }
    var _nearest=-1,_distance=100000,_best_score=infinity;
    for(var _j=0;_j<array_length(_m.slots);_j++) if(!_m.slots[_j].finished) {
        var _pos=ln_enemy_position(_g.game_number,_m.slots[_j].actor),_d=abs(_player[0]-_pos[0])+abs(_player[1]-_pos[1]);
        var _score=ln_enemy_engagement_score(_pos,_player,_m.shapes);
        if(_score<_best_score) {_nearest=_j;_distance=_d;_best_score=_score;}
    }
    var _hold=false;
    if(_m.active>=0) {var _pos=ln_enemy_position(_g.game_number,_m.slots[_m.active].actor);_hold=(_m.engaged && abs(_player[0]-_pos[0])+abs(_player[1]-_pos[1])<160 && (ln_enemy_route_clear(_pos,_player,_m.shapes) || point_distance(_pos[0],_pos[1],_player[0],_player[1])<24)) || _m.slots[_m.active].down_ticks>0 || (variable_struct_exists(_m.slots[_m.active].actor,"nav_return") && _m.slots[_m.active].actor.nav_return);}
    var _chosen=_hold?_m.active:_nearest;
    if(_chosen!=_m.active) {
        if(_g.game_number==1) _g.projectiles[1]=new LN1Projectile();
        else if(_g.game_number==2) {_g.projectiles[1].kind=0;_g.projectiles[1].enabled=0;}
        else {_g.state.enabled&=127;_g.state.parts[7].animation=0;_g.state.parts[7].move_mode=0;}
        _m.active=_chosen;
        if(_chosen>=0) {ln_enemy_apply(_g,_m.slots[_chosen].actor);if(_g.game_number<3) {_g.enemy.action_tick=_g.player.tick;_g.enemy.decision_tick=_g.player.tick;}}
    }
    if(_m.active>=0) {var _ap=ln_enemy_position(_g.game_number,_m.slots[_m.active].actor);_distance=abs(_player[0]-_ap[0])+abs(_player[1]-_ap[1]);}
    _m.engaged=_m.active>=0 && (_hold && _m.engaged || _distance<112 || _m.slots[_m.active].down_ticks>0);
    for(var _n=0;_n<array_length(_m.slots);_n++) {
        var _waiting=_m.slots[_n];
        if(_m.engaged && _n!=_m.active && !_waiting.finished && !ln_enemy_dead(_g,_waiting.actor)) {
            if(!variable_struct_exists(_waiting,"bystanding") || !_waiting.bystanding) {
                var _facing=_g.game_number<3?_waiting.actor.facing:_waiting.config.facing;
                _waiting.actor=ln_enemy_pose(_g,_waiting.actor,_facing,false);
                _waiting.walking=false;_waiting.bystanding=true;
            }
        } else _waiting.bystanding=false;
    }
    if(!_m.engaged) for(var _n=0;_n<array_length(_m.slots);_n++) if(!_m.slots[_n].finished) {
        if(_n!=_m.active && _m.slots[_n].config.patrol==0) _m.slots[_n].actor=ln_enemy_native_preview_tick(_g,_m.slots[_n].actor);
        else ln_enemy_route_tick(_g,_m.slots[_n],_m.shapes);
    }
    if(_m.active<0) {
        if(_g.game_number<3) {_g.enemy.active=0;_g.enemy.action=0;_g.enemy.display_frame=255;_g.enemy.separation_y=0;}
        else {_g.state.enabled&=143;_g.state.enemy_health=0;_g.state.enemy_dead=1;}
    } else if(!_m.engaged && _m.slots[_m.active].config.patrol!=0) ln_enemy_apply(_g,_m.slots[_m.active].actor);
}
// Cheap boundary visibility test, not a pathfinding search. A nearby guard
// with a clear approach gets first refusal over a guard across a road edge.
function ln_enemy_engagement_score(_pos,_player,_shapes) {
    var _distance=abs(_player[0]-_pos[0])+abs(_player[1]-_pos[1]);
    return _distance+(_distance<112 && ln_enemy_route_clear(_pos,_player,_shapes)?0:1024);
}
function ln_enemy_native_ai(_g) {
    if(!ln_enemy_custom(_g)) return true;
    var _m=_g.edited_enemies;return _m.active>=0 && (_m.engaged || _m.slots[_m.active].config.patrol==0);
}
function ln_enemy_segment_cross(_a,_b,_c,_d) {
    var _s1=(_b[0]-_a[0])*(_c[1]-_a[1])-(_b[1]-_a[1])*(_c[0]-_a[0]);
    var _s2=(_b[0]-_a[0])*(_d[1]-_a[1])-(_b[1]-_a[1])*(_d[0]-_a[0]);
    var _s3=(_d[0]-_c[0])*(_a[1]-_c[1])-(_d[1]-_c[1])*(_a[0]-_c[0]);
    var _s4=(_d[0]-_c[0])*(_b[1]-_c[1])-(_d[1]-_c[1])*(_b[0]-_c[0]);
    return _s1*_s2<=0 && _s3*_s4<=0 && (_s1!=0 || _s2!=0) && (_s3!=0 || _s4!=0);
}
function ln_enemy_route_clear(_a,_b,_shapes) {
    for(var _i=0;_i<array_length(_shapes);_i++) {
        var _s=_shapes[_i];
        if(array_length(_s.points)>1) {
            for(var _j=1;_j<array_length(_s.points);_j++) {
                var _c=_s.points[_j-1],_d=_s.points[_j];
                if(max(_a[0],_b[0])<min(_c[0],_d[0]) || min(_a[0],_b[0])>max(_c[0],_d[0]) ||
                   max(_a[1],_b[1])<min(_c[1],_d[1]) || min(_a[1],_b[1])>max(_c[1],_d[1])) continue;
                if(ln_enemy_segment_cross(_a,_b,_c,_d)) return false;
            }
        } else if(is_array(_s.rect)) {
            var _r=_s.rect;
            if(_b[0]>=_r[0] && _b[0]<=_r[2] && _b[1]>=_r[1] && _b[1]<=_r[3]) return false;
        }
    }
    return true;
}
function ln_enemy_route_tick(_g,_slot,_shapes) {
    var _cfg=_slot.config;if(_cfg.patrol!=2 || array_length(_cfg.route)==0 || _slot.down_ticks>0) return;
    var _pos=ln_enemy_position(_g.game_number,_slot.actor);
    if(abs(_pos[0]-_slot.x)>2 || abs(_pos[1]-_slot.y)>2) {_slot.x=_pos[0];_slot.y=_pos[1];}
    var _target=_slot.route_index<array_length(_cfg.route)?_cfg.route[_slot.route_index]:[_cfg.x,_cfg.y];
    var _distance=point_distance(_slot.x,_slot.y,_target[0],_target[1]);
    if(_distance<1) {_slot.route_index=(_slot.route_index+1) mod (array_length(_cfg.route)+1);return;}
    var _speed=_g.game_number==3?1.2:0.4,_dx=(_target[0]-_slot.x)/_distance*min(_speed,_distance),_dy=(_target[1]-_slot.y)/_distance*min(_speed,_distance);
    var _next=ln_enemy_slide([_slot.x,_slot.y],[_slot.x+_dx,_slot.y+_dy],_target,_shapes);
    if(point_distance(_slot.x,_slot.y,_next[0],_next[1])<0.001) return;
    var _previous=variable_struct_exists(_slot,"walk_facing")?_slot.walk_facing:_cfg.facing;
    var _facing=ln_enemy_stable_facing(_previous,_target[0]-_slot.x,_target[1]-_slot.y,1);
    _slot.x=_next[0];_slot.y=_next[1];
    ln_enemy_place(_g.game_number,_slot.actor,_slot.x,_slot.y,_facing);
    if(_g.game_number<3) {
        var _old=_g.enemy;_g.enemy=_slot.actor;
        if(!_slot.walking || !variable_struct_exists(_slot,"walk_facing") || _slot.walk_facing!=_facing) {_slot.walk_facing=_facing;if(_g.game_number==1) ln1_enemy_begin(_g.enemy,_g.data,24);else ln2_enemy_select(_g.enemy,_g.data,24);_slot.walking=true;}
        if(_g.game_number==1) ln1_enemy_action(_g);else ln2_enemy_action(_g);
        _slot.actor=_g.enemy;_slot.actor.action_state=0;ln_enemy_place(_g.game_number,_slot.actor,_slot.x,_slot.y,_facing);_g.enemy=_old;
    } else {_slot.actor=ln_enemy_pose(_g,_slot.actor,_facing,true);ln_enemy_place(3,_slot.actor,_slot.x,_slot.y,_facing);}
}
function ln_enemy_draw_group(_g) {
    if(!ln_enemy_custom(_g)) return false;
    var _m=_g.edited_enemies,_order=[],_player=_g.game_number<3?_g.player.y-8:_g.state.player_y-29;
    array_push(_order,{index:-1,y:_player});
    for(var _i=0;_i<array_length(_m.slots);_i++) {
        var _a=_i==_m.active?ln_enemy_capture(_g):_m.slots[_i].actor;
        array_push(_order,{index:_i,y:ln_enemy_position(_g.game_number,_a)[1],actor:_a});
    }
    array_sort(_order,function(a,b){return a.y-b.y;});
    for(var _j=0;_j<array_length(_order);_j++) {
        var _r=_order[_j];
        if(_r.index>=0) {if(_g.game_number==2 && _r.index==_m.active) ln2_play_actor(_g,_r.actor,true);else ln_enemy_draw_actor(_g,_r.actor);}
        else if(_g.game_number==1) ln1_play_actor(_g,_g.player,false);
        else if(_g.game_number==2) ln2_play_actor(_g,_g.player,false);
        else for(var _k=0;_k<8;_k++) {var _part=_g.animation.order[_k];if(_part<4) ln3_play_actor_part(_g,_g.display,_part);}
    }
    if(_g.game_number==3) ln3_play_actor_part(_g,_g.display,7);
    return true;
}

function ln_enemy_checks() {
    var _e=global.ln_editor;_e.scenes={};_e.enabled=true;
    for(var _game=1;_game<=3;_game++) for(var _level=1;_level<=(_game==1?6:(_game==2?7:5));_level++) {var _catalog=ln_enemy_catalog(_game,_level);ln_check(is_struct(_catalog.rooms),"all-level native enemy catalogs load");}
    for(var _game=1;_game<=3;_game++) {
        var _cat=ln_enemy_catalog(_game,1);show_debug_message("ENEMY_CATALOG "+string(_game)+" types="+string(array_length(_cat.types)));
        ln_check(array_length(_cat.types)>0,"ordinary guard templates available in each game");
        var _room=_cat.types[0].room;ln_edit_select(_game,1,_room);_e.enemy_edit=true;_e.enemy_index=0;_e.open=true;
        var _list=ln_enemy_copy(ln_enemy_configs(_e.scene));
        ln_check(array_length(_list)==1,"native room exposes its guard");
        _list[0].x=100;_list[0].y=85;_list[0].patrol=1;
        var _second=ln_enemy_copy(_list[0]);_second.x=145;array_push(_list,_second);
        _e.scene.enemies=_list;variable_struct_set(_e.scenes,ln_edit_key(_game,1,_room),ln_enemy_copy(_e.scene));
        ln_check(ln_enemy_validate(_e.scene),"valid multiple-enemy configuration accepted");
        var _file="enemy-editor-check.json";ln_edit_save(_file);ln_check(ln_edit_load(_file),"enemy edits save/load");file_delete(_file);
        ln_check(array_length(_e.scene.enemies)==2,"saved multiple guards retained");
        var _bad=ln_enemy_copy(_e.scene);_bad.enemies[0].x=999;ln_check(!ln_enemy_validate(_bad),"out-of-room spawn rejected");
        ln_edit_draw();surface_save(application_surface,"enemy-editor-ln"+string(_game)+".png");
        var _g=_e.preview;
        if(_game<3) {_g.player.x=100;_g.player.y=100;} else {_g.state.player_x=124;_g.state.player_y=114;}
        ln_enemy_runtime(_g);
        ln_check(ln_enemy_custom(_g) && array_length(_g.edited_enemies.slots)==2 && _g.edited_enemies.active==0 && _g.edited_enemies.engaged,"only closest guard receives combat slot");
        var _waiting=json_stringify(_g.edited_enemies.slots[1].actor);
        repeat(12) {if(_game==1) ln1_play_tick(_g,0);else if(_game==2) ln2_play_tick(_g,0);else ln3_play_tick(_g,0);}
        ln_check(json_stringify(_g.edited_enemies.slots[1].actor)==_waiting,"other guard stays idle during combat");
        ln_enemy_flush(_g);var _saved=ln_enemy_copy(_g.edited_enemies);
        var _restored=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));
        ln_check(ln_rewind_equal(_saved,_restored.edited_enemies),"multi-enemy state survives actual save restore");
        var _rewind=ln_rewind_pack(_g);_g.edited_enemies.active=-1;ln_rewind_restore(_g,_rewind);buffer_delete(_rewind.buffer);
        ln_check(ln_rewind_equal(_saved,_g.edited_enemies),"multi-enemy state survives actual rewind restore");
        if(_game==1) _g.enemy.wounds=32;else if(_game==2) _g.enemy.health=0;else _g.state.enemy_dead=1;
        repeat(60) ln_enemy_runtime(_g);
        ln_check(_g.edited_enemies.active==1 && _g.edited_enemies.slots[0].finished,"next guard engages after defeated guard cooldown");
        var _corpse=ln_enemy_copy(_g.edited_enemies.slots[0].actor);
        ln_enemy_room_leave(_g);
        var _return_save=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));
        ln_check(ln_rewind_equal(_g.edited_enemy_rooms,_return_save.edited_enemy_rooms),"defeated room history survives save restore");
        ln_enemy_runtime(_g);
        ln_check(_g.edited_enemies.slots[0].finished && ln_enemy_dead(_g,_g.edited_enemies.slots[0].actor),"room re-entry preserves defeated guards");
        ln_check(ln_rewind_equal(_corpse,_g.edited_enemies.slots[0].actor),"room re-entry preserves corpse position and pose");
        for(var _i=1;_i<2;_i++) {var _slot=_g.edited_enemies.slots[_i],_pos=ln_enemy_position(_game,_slot.actor);
            ln_check(abs(_pos[0]-_slot.config.x)<=1 && abs(_pos[1]-_slot.config.y)<=1 && !ln_enemy_dead(_g,_slot.actor),"room re-entry restores spawn and health");}
        _e.test_active=true;ln_edit_finish_test(_g);
        ln_check(!_e.test_active && !_g.edited_enemies.slots[0].finished && !ln_enemy_dead(_g,_g.edited_enemies.slots[0].actor),"leaving editor test resets defeated custom guard");
        for(var _reset_i=0;_reset_i<2;_reset_i++) {
            var _reset_slot=_g.edited_enemies.slots[_reset_i],_reset_pos=ln_enemy_position(_game,_reset_slot.actor);
            ln_check(abs(_reset_pos[0]-_reset_slot.config.x)<=1 && abs(_reset_pos[1]-_reset_slot.config.y)<=1,"test exit restores configured enemy positions");
        }
        if(_game==1) for(var _type_i=0;_type_i<array_length(_cat.types);_type_i++)
            ln_check(_cat.types[_type_i].actor.weapon==(_cat.types[_type_i].actor.active&3),"edited LN1 guards retain native weapon type");
        _e.enabled=false;ln_enemy_runtime(_g);ln_check(!ln_enemy_custom(_g),"Modified OFF leaves native engine in control");_e.enabled=true;
        var _route={config:{x:50,y:70,facing:3,patrol:2,route:[[55,70]]},actor:ln_enemy_copy(_cat.types[0].actor),x:50,y:70,route_index:0,down_ticks:0,walking:false};
        ln_enemy_place(_game,_route.actor,50,70,3);repeat(5) ln_enemy_route_tick(_g,_route,[]);
        ln_check(_route.x>50,"custom patrol advances without an engaged enemy");
    }
    ln_check(!ln_enemy_route_clear([10,10],[20,10],[{points:[[15,0],[15,20]],rect:undefined}]),"patrol cannot cross solid room boundary");
    var _wall=[{points:[[15,0],[15,30]],rect:undefined}];
    ln_check(ln_enemy_engagement_score([25,20],[20,10],_wall)<ln_enemy_engagement_score([10,10],[20,10],_wall),"visible guard takes priority over nearer blocked guard");
    ln_enemy_boundary_checks();ln_enemy_return_checks();ln_enemy_combat_spacing_checks();
    var _job=ln_enemy_search_start([10,10],[30,10],[{points:[[20,0],[20,24]],rect:undefined}]),_slices=0;
    while(!_job.done) {ln_check(ln_enemy_search_step(_job,16,1000)<=16,"navigation has a fixed per-frame expansion cap");_slices++;ln_check(_slices<10000,"incremental search finishes");}
    ln_check(_slices>1 && array_length(_job.path)>0,"detour search is spread across frames");
    ln_check(ln_enemy_frame_time({edited_enemies:{}},1000000)==40000,"edited play discards long stall debt");
    ln_check(ln_enemy_frame_time({},1000000)==1000000,"original timing remains unchanged");
    var _bend=[{points:[[20,0],[20,24]],rect:undefined}];
    var _path=ln_enemy_find_path([10,10],[30,10],_bend),_last=[10,10],_detour=false;
    ln_check(array_length(_path)>0,"chase finds route around blocking wall");
    for(var _i=0;_i<array_length(_path);_i++) {ln_check(ln_enemy_route_clear(_last,_path[_i],_bend),"every chase segment stays inside boundaries");if(_path[_i][1]>24) _detour=true;_last=_path[_i];}
    ln_check(_detour,"chase temporarily moves away from ninja to go around bend");
    var _a={x:10,y:20,facing:7,heading:7,action_mirror:0,mirror:false,fraction_x:0,fraction_y:0,depth_y:20,patrol_x:10};
    ln_enemy_place(1,_a,11,12,7);ln_check(!_a.mirror,"position update leaves animation mirror unchanged");
    var _wall=[{points:[[11,0],[11,30]],rect:undefined}];
    var _slide=ln_enemy_slide([10,10],[12,12],[20,20],_wall);
    ln_check(_slide[0]<11 && _slide[1]>10,"guard slides along blocked edge toward target");
    ln_check(ln_enemy_route_clear([10,10],_slide,_wall),"sliding never crosses the blocking edge");
    var _clear=ln_enemy_slide([10,10],[12,12],[20,20],[]);
    ln_check(_clear[0]==12 && _clear[1]==12,"clear movement keeps direct approach");
    ln_check(ln_enemy_stable_facing(7,0.2,-20,1)==7 && ln_enemy_stable_facing(7,-0.2,-20,1)==7,"axis rounding cannot flicker facing");
    show_debug_message("LN_ENEMY_EDITOR_PASS: three games / two guards / single engagement / patrols / persistence");
}

// Produce an idle/walk pose without advancing the live player's state.
function ln_enemy_pose(_g,_actor,_facing,_walk) {
    if(_g.game_number<3) {
        var _old=_g.enemy,_tick=_g.player.tick;_g.enemy=ln_enemy_copy(_actor);
        if(_g.game_number==1) ln1_enemy_begin(_g.enemy,_g.data,_walk?24:0);else ln2_enemy_select(_g.enemy,_g.data,_walk?24:0);
        _g.enemy.action_tick=(_tick-1)&255;
        if(_g.game_number==1) ln1_enemy_action(_g);else ln2_enemy_action(_g);
        var _out=ln_enemy_copy(_g.enemy);_g.enemy=_old;_out.action_state=0;return _out;
    }
    var _old=_g.state;_g.state=ln_enemy_copy(_old);ln_enemy_apply(_g,_actor);
    var _s=_g.state;_s.joy=(_facing&4?4:8)|((_facing==1 || _facing==7)?1:2);
    // Native actions: 39/40 are idle down/up; 41/43 walk down/up.
    ln3_action_set(_s,_g.actions,(_walk?41:39)+((_facing==1 || _facing==7)?(_walk?2:1):0),true);
    ln3_animation_update(_s,_g.animation);var _out=ln_enemy_capture(_g);_g.state=_old;return _out;
}

// Isolated native patrol samples; never run attacks or mutate player state.
function ln_enemy_native_preview_tick(_g,_actor) {
    if(_g.game_number<3) {
        var _enemy=_g.enemy,_player=_g.player,_group=ln_enemy_custom(_g)?_g.edited_enemies:undefined;
        _g.edited_enemies=undefined;_g.enemy=ln_enemy_copy(_actor);_g.player=ln_save_copy(_player);
        _g.player.x=10000;_g.player.y=10000;_g.player.tick=(_actor.action_tick+1)&255;
        if(_g.game_number==1) {ln1_enemy_decide(_g);ln1_enemy_action(_g);}else {ln2_enemy_decide(_g);ln2_enemy_action(_g);}
        var _out=ln_enemy_copy(_g.enemy);_out.action_state=0;
        if(is_struct(_group) && !ln_enemy_route_clear(ln_enemy_position(_g.game_number,_actor),ln_enemy_position(_g.game_number,_out),_group.shapes)) {
            _out.x=_actor.x;_out.y=_actor.y;_out.fraction_x=0;_out.fraction_y=0;_out.depth_y=_actor.depth_y;
        }
        _g.enemy=_enemy;_g.player=_player;_g.edited_enemies=_group;return _out;
    }
    var _old=_g.state;_g.state=ln_enemy_copy(_old);ln_enemy_apply(_g,_actor);
    var _s=_g.state;_s.player_x=10000;_s.player_y=10000;
    if(_s.enemy_behavior>=128) {
        ln3_enemy_patrol(_s,_g.actions,_g.input,_g.enemies);
        ln3_movement_setup(_s,_g.movement);ln3_movement(_s,_g.movement);ln3_animation_update(_s,_g.animation);
    }
    var _out=ln_enemy_capture(_g);_g.state=_old;return _out;
}
function ln_enemy_native_trace(_g,_actor) {
    var _a=ln_enemy_copy(_actor),_origin=ln_enemy_position(_g.game_number,_a),_trace=[[0,0]];
    repeat(_g.game_number==3?80:300) {
        _a=ln_enemy_native_preview_tick(_g,_a);var _pos=ln_enemy_position(_g.game_number,_a);
        var _point=[_pos[0]-_origin[0],_pos[1]-_origin[1]],_last=_trace[array_length(_trace)-1];
        if(point_distance(_last[0],_last[1],_point[0],_point[1])>=2 && abs(_point[0])<80 && abs(_point[1])<60) array_push(_trace,_point);
    }
    return _trace;
}

function ln_enemy_boundary_checks() {
    var _g=new LN1Play(1),_cat=ln_enemy_catalog(1,1);
    _g.enemy=ln_enemy_copy(_cat.types[0].actor);ln_enemy_place(1,_g.enemy,120,80,3);
    _g.enemy.speed=0;_g.player.x=220;_g.player.y=140;
    var _room_shapes=ln_edit_collision_geometry(1,_g.world.rooms[0].boundaries);
    var _path=ln_enemy_find_path([180,125],[220,65],_room_shapes),_last=[180,125],_around=false;
    ln_check(array_length(_path)>0,"LN1 room 1 V-shaped road has a chase route");
    for(var _i=0;_i<array_length(_path);_i++) {
        ln_check(ln_enemy_route_clear(_last,_path[_i],_room_shapes),"LN1 room 1 chase never cuts across grass boundary");
        if(_path[_i][0]<126) _around=true;_last=_path[_i];
    }
    ln_check(_around && _last[0]==220 && _last[1]==65,"LN1 room 1 chase goes around inner bend and reaches upper path");
    var _start=ln_enemy_copy(_g.enemy);ln1_enemy_move(_g,8);
    var _end=ln_enemy_copy(_g.enemy),_dx=_end.x-_start.x;
    ln_check(_end.x!=_start.x || _end.y!=_start.y,"native enemy movement test advances");
    var _mid=_dx!=0?(_start.x+_end.x)/2:(_start.y+_end.y)/2-8;
    var _points=_dx!=0?[[_mid,0],[_mid,144]]:[[0,_mid],[240,_mid]];
    _g.enemy=ln_enemy_copy(_start);_g.edited_enemies={engaged:false,shapes:[{points:_points,rect:undefined}]};ln1_enemy_move(_g,8);
    ln_check(_dx!=0?abs(_g.enemy.x-_start.x)<abs(_dx):abs(_g.enemy.y-_start.y)<abs(_end.y-_start.y),"edited LN1 chase stops at room boundary");
    _g.edited_enemies=undefined;_g.enemy=ln_enemy_copy(_start);ln1_enemy_move(_g,8);
    ln_check(_g.enemy.x==_end.x && _g.enemy.y==_end.y,"native unmodified enemy movement unchanged");
}

// Retain each facing component near its axis instead of alternating poses as
// fractional movement rounds to either side of the destination.
function ln_enemy_stable_facing(_old,_dx,_dy,_band=4) {
    var _left=abs(_dx)<=_band?(_old&4)!=0:_dx<0;
    var _up=abs(_dy)<=_band?(_old==1 || _old==7):_dy<0;
    return _left?(_up?7:5):(_up?1:3);
}
function ln_enemy_slide(_from,_wanted,_target,_shapes) {
    if(_wanted[0]>=0 && _wanted[0]<=239 && _wanted[1]>=0 && _wanted[1]<=143 && ln_enemy_route_clear(_from,_wanted,_shapes)) return _wanted;
    var _step=max(abs(_wanted[0]-_from[0]),abs(_wanted[1]-_from[1]));
    if(_step<0.0001) return _from;
    var _best=_from,_score=point_distance(_from[0],_from[1],_target[0],_target[1]);
    // Axis steps allow contact to slide around the C64's stepped/sloping edges.
    for(var _y=-1;_y<=1;_y++) for(var _x=-1;_x<=1;_x++) {
        if(_x==0 && _y==0) continue;
        var _p=[_from[0]+_x*_step,_from[1]+_y*_step];
        if(_p[0]<0 || _p[0]>239 || _p[1]<0 || _p[1]>143 || !ln_enemy_route_clear(_from,_p,_shapes)) continue;
        var _cost=point_distance(_p[0],_p[1],_target[0],_target[1]);
        if(_cost<_score-0.0001) {_best=_p;_score=_cost;}
    }
    return _best;
}

// A room-sized four-pixel navigation lattice. Edges use the same collision
// geometry as movement, so diagonal links cannot cut across a road boundary.
function ln_enemy_search_start(_start,_goal,_shapes) {
    var _job={goal:_goal,shapes:_shapes,parent:array_create(2160,-2),queue:[],head:0,done:false,path:[],expanded:0};
    if(ln_enemy_route_clear(_start,_goal,_shapes)) {_job.done=true;_job.path=[_goal];return _job;}
    var _sx=clamp(round(_start[0]/4),0,59),_sy=clamp(round(_start[1]/4),0,35);
    for(var _y=max(0,_sy-1);_y<=min(35,_sy+1);_y++) for(var _x=max(0,_sx-1);_x<=min(59,_sx+1);_x++) {
        var _p=[_x*4,_y*4],_id=_y*60+_x;
        if(ln_enemy_route_clear(_start,_p,_shapes)) {_job.parent[_id]=-1;array_push(_job.queue,_id);}
    }
    return _job;
}
function ln_enemy_search_step(_job,_limit=16,_budget_us=1000) {
    var _begin=get_timer(),_nodes=0;
    while(!_job.done && _job.head<array_length(_job.queue) && _nodes<_limit && get_timer()-_begin<_budget_us) {
        _nodes++;_job.expanded++;
        var _id=_job.queue[_job.head++],_x=_id mod 60,_y=_id div 60,_from=[_x*4,_y*4];
        if(point_distance(_from[0],_from[1],_job.goal[0],_job.goal[1])<=6 && ln_enemy_route_clear(_from,_job.goal,_job.shapes)) {
            var _reverse=[_job.goal],_found=_id;
            while(_found>=0) {array_push(_reverse,[(_found mod 60)*4,(_found div 60)*4]);_found=_job.parent[_found];}
            for(var _i=array_length(_reverse)-1;_i>=0;_i--) array_push(_job.path,_reverse[_i]);
            _job.done=true;break;
        }
        for(var _dy=-1;_dy<=1;_dy++) for(var _dx=-1;_dx<=1;_dx++) {
            var _nx=_x+_dx,_ny=_y+_dy;if(_nx<0 || _nx>=60 || _ny<0 || _ny>=36) continue;
            var _next=_ny*60+_nx;if(_job.parent[_next]!=-2) continue;
            if(!ln_enemy_route_clear(_from,[_nx*4,_ny*4],_job.shapes)) continue;
            _job.parent[_next]=_id;array_push(_job.queue,_next);
        }
    }
    if(_job.head>=array_length(_job.queue)) _job.done=true;
    return _nodes;
}
// Synchronous wrapper is for offline checks only. Gameplay advances a bounded
// job once per host frame, outside native ticks and save/rewind actor snapshots.
function ln_enemy_find_path(_start,_goal,_shapes) {
    var _job=ln_enemy_search_start(_start,_goal,_shapes);
    while(!_job.done) ln_enemy_search_step(_job,2160,1000000);
    return _job.path;
}
function ln_enemy_nav_step(_g) {
    var _editor=global.ln_editor,_job=_editor.nav_job;
    _editor.nav_last_nodes=0;_editor.nav_last_us=0;
    if(!is_struct(_job)) return;
    if(_job.owner!=_g || !ln_enemy_custom(_g) || _job.group!=_g.edited_enemies || _job.active!=_g.edited_enemies.active) {_editor.nav_job=undefined;return;}
    var _start=get_timer();_editor.nav_last_nodes=ln_enemy_search_step(_job,16,1000);_editor.nav_last_us=get_timer()-_start;
    if(_job.done) {
        _g.enemy.nav_path=_job.path;_g.enemy.nav_goal=_job.goal;_g.enemy.nav_until=_g.edited_enemies.ticks+30;
        _editor.nav_job=undefined;
    }
}
function ln_enemy_chase_point(_g,_goal) {
    var _e=_g.enemy,_m=_g.edited_enemies,_from=[_e.x,_e.y-8];
    if(ln_enemy_route_clear(_from,_goal,_m.shapes)) {global.ln_editor.nav_job=undefined;return _goal;}
    var _has=variable_struct_exists(_e,"nav_path"),_needs=!_has;
    if(_has) _needs=_m.ticks>=_e.nav_until && (array_length(_e.nav_path)==0 || point_distance(_goal[0],_goal[1],_e.nav_goal[0],_e.nav_goal[1])>8);
    var _job=global.ln_editor.nav_job;
    if(_needs && (!is_struct(_job) || _job.owner!=_g || _job.group!=_m || _job.active!=_m.active)) {
        _job=ln_enemy_search_start(_from,_goal,_m.shapes);_job.owner=_g;_job.group=_m;_job.active=_m.active;global.ln_editor.nav_job=_job;
    }
    if(_has) for(var _i=array_length(_e.nav_path)-1;_i>=0;_i--) if(ln_enemy_route_clear(_from,_e.nav_path[_i],_m.shapes)) return _e.nav_path[_i];
    return _from;
}
function ln_enemy_frame_time(_g,_us) {
    return ln_enemy_custom(_g)?min(_us,40000):_us;
}
function ln_enemy_ln1_chase(_g) {
    var _e=_g.enemy,_m=_g.edited_enemies;
    if(!_m.engaged || _e.wounds>=32 || _e.mode<1 || _e.mode>5) return false;
    var _from=[_e.x,_e.y-8],_goal=ln_enemy_return_goal(_g);
    if(!_e.nav_return && abs(_g.player.x-_e.x)<=ln_enemy_ln1_standoff(_e)+2 && abs(_g.player.y-_e.y)<4 && ln_enemy_route_clear(_from,_goal,_m.shapes)) {ln1_enemy_attack_stance(_g);return true;}
    if(!_e.nav_return) _goal=ln_enemy_ln1_combat_goal(_g,_goal);
    var _point=ln_enemy_chase_point(_g,_goal);_e.nav_point=_point;
    if(point_distance(_from[0],_from[1],_point[0],_point[1])<0.5) {
        if(_e.mode!=1) {ln1_enemy_begin(_e,_g.data,0);ln1_enemy_combat(_e,0);}_e.mode=1;return true;
    }
    var _facing=ln_enemy_stable_facing(_e.facing,_point[0]-_from[0],_point[1]-_from[1],1);
    if(_e.mode!=5 || _e.facing!=_facing) {
        _e.facing=_facing;_e.heading=_facing;_e.speed=_e.speed_traits>>2;
        ln1_enemy_begin(_e,_g.data,8);ln1_enemy_combat(_e,8);
    }
    _e.mode=5;return true;
}

// A blocked approach commits to returning home. Reconsider the player only
// at half distance, 20% remaining, and after reaching the configured spawn.
function ln_enemy_return_goal(_g) {
    var _e=_g.enemy,_m=_g.edited_enemies,_cfg=_m.slots[_m.active].config;
    var _from=[_e.x,_e.y-8],_home=[_cfg.x,_cfg.y],_player=[_g.player.x,_g.player.y-8];
    var _remaining=point_distance(_from[0],_from[1],_home[0],_home[1]);
    if(!variable_struct_exists(_e,"nav_return")) _e.nav_return=false;
    var _check=false,_change=false;
    if(_e.nav_return) {
        if(_remaining<=_e.nav_return_distance*0.5 && !(_e.nav_return_checks&1)) {_e.nav_return_checks|=1;_check=true;}
        if(_remaining<=_e.nav_return_distance*0.2 && !(_e.nav_return_checks&2)) {_e.nav_return_checks|=2;_check=true;}
        if(_remaining<=1) _check=true;
        if(_check && ln_enemy_route_clear(_from,_player,_m.shapes)) {_e.nav_return=false;_change=true;}
    } else if(!ln_enemy_route_clear(_from,_player,_m.shapes)) {
        _e.nav_return=true;_e.nav_return_distance=max(1,_remaining);_e.nav_return_checks=0;_change=true;
    }
    var _goal=_e.nav_return?_home:_player;
    if(_change) {
        global.ln_editor.nav_job=undefined;_e.nav_path=[];_e.nav_goal=_goal;_e.nav_until=0;
    }
    return _goal;
}
function ln_enemy_return_checks() {
    var _g={enemy:{x:100,y:88},player:{x:130,y:88},edited_enemies:{active:0,slots:[{config:{x:20,y:80}}],shapes:[{points:[[110,0],[110,140]],rect:undefined}]}};
    var _goal=ln_enemy_return_goal(_g);ln_check(_g.enemy.nav_return && _goal[0]==20,"blocked chase prioritises spawn");
    _g.edited_enemies.shapes=[];_g.enemy.x=80;_goal=ln_enemy_return_goal(_g);
    ln_check(_g.enemy.nav_return && _goal[0]==20,"clear route before halfway does not interrupt return");
    _g.enemy.x=60;_goal=ln_enemy_return_goal(_g);ln_check(!_g.enemy.nav_return && _goal[0]==130,"halfway check resumes clear chase");
    _g.enemy.x=100;_g.edited_enemies.shapes=[{points:[[110,0],[110,140]],rect:undefined}];ln_enemy_return_goal(_g);
    _g.enemy.x=60;ln_enemy_return_goal(_g);ln_check(_g.enemy.nav_return && _g.enemy.nav_return_checks==1,"blocked halfway check is consumed once");
    _g.edited_enemies.shapes=[];_g.enemy.x=50;ln_enemy_return_goal(_g);ln_check(_g.enemy.nav_return,"no repeated halfway checks");
    _g.enemy.x=36;_goal=ln_enemy_return_goal(_g);ln_check(!_g.enemy.nav_return && _goal[0]==130,"20 percent remaining check resumes clear chase");
}

function ln_enemy_ln1_standoff(_enemy) {
    return [18,22,28,24,18,18,20][clamp(_enemy.weapon,0,6)];
}
function ln_enemy_ln1_combat_goal(_g,_player) {
    var _e=_g.enemy,_from=[_e.x,_e.y-8],_range=ln_enemy_ln1_standoff(_e);
    var _side=abs(_player[0]-_e.x)<4?((_e.facing&4)?1:-1):(_e.x<_player[0]?-1:1);
    var _goal=[clamp(_player[0]+_side*_range,0,239),_player[1]];
    if(ln_enemy_route_clear(_from,_goal,_g.edited_enemies.shapes)) return _goal;
    // Do not replace a safe approach with a point beyond the road edge.
    return _player;
}
function ln_enemy_combat_spacing_checks() {
    var _g=new LN1Play(1),_cat=ln_enemy_catalog(1,1);
    _g.enemy=ln_enemy_copy(_cat.types[0].actor);_g.enemy.x=100;_g.enemy.y=88;_g.enemy.weapon=0;_g.enemy.mode=5;_g.enemy.wounds=0;
    _g.player.x=110;_g.player.y=96;
    _g.edited_enemies={active:0,engaged:true,ticks:0,slots:[{config:{x:100,y:80}}],shapes:[]};
    var _goal=ln_enemy_ln1_combat_goal(_g,[_g.player.x,_g.player.y-8]);
    ln_check(_goal[0]==92 && _goal[1]==88,"close diagonal approach backs out to fighting distance instead of body contact");
    _g.enemy.nav_point=_goal;_g.enemy.speed=0;_g.enemy.fraction_x=0;_g.enemy.fraction_y=0;_g.enemy.separation_y=10;
    ln1_enemy_move(_g,8);ln_check(_g.enemy.x<100,"guard can back out of existing body contact to align");
    _g.enemy.x=92;_g.enemy.y=96;ln_enemy_ln1_chase(_g);
    ln_check(_g.enemy.mode==6,"aligned guard immediately leaves chase for attack stance");
    _g.enemy.weapon=2;_g.enemy.mode=5;_g.enemy.x=82;ln_enemy_ln1_chase(_g);
    ln_check(_g.enemy.mode==6,"armed guard attacks at its weapon spacing");
}
