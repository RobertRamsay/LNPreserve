/// Sprite pixel artwork stored inside the user's scene project. While Modified is ON the
/// edited frames replace the game's own sprite assets; the original assets stay intact.
function LNSpriteArt() constructor {
    open=false;view=0;items=[];seconds=[];rect=[0,0,8,8];index=0;part=0;context="";
    entry=undefined;clip_index=0;sheet="";sheet_scroll=0;allowed=undefined;uses={};palette={};strict={};
    tool=0;colour=c_white;mode=1;mc=false;drafts={};undo=[];redo=[];surfaces={};
    stroke=false;stroke_button=mb_left;stroke_key="";last_x=-1;last_y=-1;
    canvas_surface=-1;playing=false;elapsed=0;dim=true;onion=false;crop=true;figure=undefined;full_rect=[0,0,8,8];clipboard=undefined;discard_armed=false;message="";
}
function ln_sprite_art_key(_name,_frame) {return _name+":"+string(_frame);}
function ln_sprite_art_get(_name,_frame) {
    var _art=global.ln_editor.sprite_art,_key=ln_sprite_art_key(_name,_frame);
    return variable_struct_exists(_art,_key)?variable_struct_get(_art,_key):undefined;
}
/// The untouched sprite, even while Modified ON has replaced the asset's frames.
function ln_sprite_art_source(_name) {
    var _backups=global.ln_editor.sprite_backups;
    return variable_struct_exists(_backups,_name)?variable_struct_get(_backups,_name):asset_get_index(_name);
}
function ln_sprite_art_catalog() {
    var _sv=global.ln_sprites,_v=_sv.art;
    if(is_struct(_v.allowed)) return _v.allowed;
    if(!is_struct(_sv.catalog)) _sv.catalog=ln3_data_read("sprite_viewer.json");
    var _allowed={},_uses={},_entries=_sv.catalog.entries;
    for(var _e=0;_e<array_length(_entries);_e++) {
        var _clips=_entries[_e].clips;
        for(var _c=0;_c<array_length(_clips);_c++) for(var _f=0;_f<array_length(_clips[_c].frames);_f++) {
            var _parts=_clips[_c].frames[_f].parts;
            for(var _i=0;_i<array_length(_parts);_i++) {
                var _p=_parts[_i],_info=variable_struct_exists(_allowed,_p[0])?variable_struct_get(_allowed,_p[0]):undefined;
                if(!is_struct(_info)) {_info={tinted:false,tint:c_white};variable_struct_set(_allowed,_p[0],_info);}
                if(_p[4]!=c_white) _info.tinted=true;
                var _k=ln_sprite_art_key(_p[0],_p[1]);
                variable_struct_set(_uses,_k,(variable_struct_exists(_uses,_k)?variable_struct_get(_uses,_k):0)+1);
            }
        }
    }
    for(var _i=0;_i<16;_i++) variable_struct_set(_v.palette,string(global.ln_paint_palette[_i]),true);
    _v.strict=ln3_data_read("sprite_palettes.json").palettes;
    _v.allowed=_allowed;_v.uses=_uses;return _allowed;
}
function ln_sprite_art_tinted(_name) {
    var _allowed=ln_sprite_art_catalog();
    return variable_struct_exists(_allowed,_name) && variable_struct_get(_allowed,_name).tinted;
}
/// Exact surface read of one original frame: -1 is transparent, otherwise a GameMaker colour.
function ln_sprite_art_read_index(_sprite,_frame) {
    var _w=sprite_get_width(_sprite),_h=sprite_get_height(_sprite);
    var _surface=surface_create(_w,_h),_b=buffer_create(_w*_h*4,buffer_fixed,1);
    var _view=matrix_get(matrix_view),_projection=matrix_get(matrix_projection),_world=matrix_get(matrix_world);
    ln_sprite_art_target(_surface,_w,_h);
    draw_clear_alpha(c_black,0);gpu_set_blendenable(false);
    draw_sprite_ext(_sprite,_frame,sprite_get_xoffset(_sprite),sprite_get_yoffset(_sprite),1,1,0,c_white,1);
    gpu_set_blendenable(true);surface_reset_target();
    matrix_set(matrix_view,_view);matrix_set(matrix_projection,_projection);matrix_set(matrix_world,_world);
    buffer_get_surface(_b,_surface,0);surface_free(_surface);
    var _pixels=array_create(_w*_h,-1);
    for(var _i=0;_i<_w*_h;_i++) {var _c=buffer_peek(_b,_i*4,buffer_u32);if(((_c>>24)&255)>=128) _pixels[_i]=_c&$ffffff;}
    buffer_delete(_b);return _pixels;
}
/// Targets a surface with the same camera setup the sprite viewer uses for its preview.
function ln_sprite_art_target(_surface,_w,_h) {
    surface_set_target(_surface);matrix_set(matrix_world,matrix_build_identity());
    var _camera=camera_create_view(0,0,_w,_h);camera_apply(_camera);camera_destroy(_camera);
}
function ln_sprite_art_read(_name,_frame) {return ln_sprite_art_read_index(ln_sprite_art_source(_name),_frame);}
function ln_sprite_art_encode(_pixels) {
    var _n=array_length(_pixels),_b=buffer_create(_n*4,buffer_fixed,1);
    for(var _i=0;_i<_n;_i++) buffer_poke(_b,_i*4,buffer_u32,_pixels[_i]<0?0:(_pixels[_i]|$ff000000));
    var _z=buffer_compress(_b,0,_n*4);buffer_delete(_b);
    var _text=buffer_base64_encode(_z,0,buffer_get_size(_z));buffer_delete(_z);return _text;
}
/// Raw RGBA buffer of a stored frame, or -1 when the data is malformed.
function ln_sprite_art_buffer(_a) {
    if(!is_string(_a.data) || string_length(_a.data)<4 || string_length(_a.data)>1000000) return -1;
    var _z=-1,_b=-1;
    try {_z=buffer_base64_decode(_a.data);_b=buffer_decompress(_z);} catch(_error) {_b=-1;}
    if(_z!=-1 && buffer_exists(_z)) buffer_delete(_z);
    if(_b==-1 || !buffer_exists(_b)) return -1;
    if(buffer_get_size(_b)!=_a.width*_a.height*4) {buffer_delete(_b);return -1;}
    return _b;
}
function ln_sprite_art_decode(_a) {
    var _b=ln_sprite_art_buffer(_a);if(_b==-1) return undefined;
    var _n=_a.width*_a.height,_pixels=array_create(_n,-1);
    for(var _i=0;_i<_n;_i++) {var _c=buffer_peek(_b,_i*4,buffer_u32);if(((_c>>24)&255)!=0) _pixels[_i]=_c&$ffffff;}
    buffer_delete(_b);return _pixels;
}
/// C64 Strict sprites may only use the colours the original sprite asset already uses,
/// i.e. the colours of its layered hardware sprites (LN1 ninja: black and pink).
function ln_sprite_art_strict(_name) {
    var _v=global.ln_sprites.art;ln_sprite_art_catalog();
    return variable_struct_exists(_v.strict,_name)?variable_struct_get(_v.strict,_name):global.ln_paint_palette;
}
function ln_sprite_art_allowed_colour(_c,_a) {
    if(_c==-1) return true;
    if(!ln_enemy_number(_c) || _c<0 || _c>16777215) return false;
    if(_a.tinted) return _c==c_white;
    if(_a.mode==0) return array_contains(ln_sprite_art_strict(_a.sprite),_c);
    if(_a.mode==1) return variable_struct_exists(global.ln_sprites.art.palette,string(_c));
    if(_a.mode==3) return colour_get_red(_c) mod 17==0 && colour_get_green(_c) mod 17==0 && colour_get_blue(_c) mod 17==0;
    return true;
}
function ln_sprite_art_quantize(_a,_colour) {
    if(_colour<0) return -1;
    if(_a.tinted) return c_white;
    if(_a.mode!=0) return ln_art_quantize(_colour,_a.mode);
    var _list=ln_sprite_art_strict(_a.sprite),_best=_list[0],_distance=infinity;
    for(var _i=0;_i<array_length(_list);_i++) {
        var _c=_list[_i],_d=sqr(colour_get_red(_c)-colour_get_red(_colour))+sqr(colour_get_green(_c)-colour_get_green(_colour))+sqr(colour_get_blue(_c)-colour_get_blue(_colour));
        if(_d<_distance) {_distance=_d;_best=_c;}
    }
    return _best;
}
function ln_sprite_art_put(_a,_x,_y,_colour) {
    if(_x<0 || _y<0 || _x>=_a.width || _y>=_a.height) return;
    var _step=_a.mc?2:1;_x=(_x div _step)*_step;
    _colour=ln_sprite_art_quantize(_a,_colour);
    for(var _j=0;_j<_step;_j++) _a.pixels[_y*_a.width+_x+_j]=_colour;
}
function ln_sprite_art_conform(_a) {
    if(_a.mode>=2 && !_a.tinted) _a.mc=false;
    var _n=array_length(_a.pixels);
    for(var _i=0;_i<_n;_i++) _a.pixels[_i]=ln_sprite_art_quantize(_a,_a.pixels[_i]);
    if(_a.mc) for(var _i=0;_i<_n;_i+=2) {if(_a.pixels[_i]<0) _a.pixels[_i]=_a.pixels[_i+1];else _a.pixels[_i+1]=_a.pixels[_i];}
}
function ln_sprite_art_pixels_valid(_a,_pixels) {
    if(_a.mc && (_a.width mod 2!=0 || (_a.mode>=2 && !_a.tinted))) return false;
    for(var _i=0;_i<array_length(_pixels);_i++) {
        var _c=_pixels[_i];
        if(!ln_sprite_art_allowed_colour(_c,_a)) return false;
        if(_a.mc && (_i mod 2)==1 && _pixels[_i-1]!=_c) return false;
    }
    return true;
}/// Structural checks always; pixel checks decode every frame and run when loading a file.
function ln_sprite_art_valid(_art,_deep=true) {
    if(!is_struct(_art)) return false;
    var _keys=variable_struct_get_names(_art),_total=0;
    if(array_length(_keys)==0) return true;
    if(array_length(_keys)>12000) return false;
    var _allowed=ln_sprite_art_catalog();
    for(var _i=0;_i<array_length(_keys);_i++) {
        var _a=variable_struct_get(_art,_keys[_i]);if(!is_struct(_a)) return false;
        var _fields=["sprite","frame","width","height","mode","mc","data"];
        for(var _j=0;_j<array_length(_fields);_j++) if(!variable_struct_exists(_a,_fields[_j])) return false;
        if(!is_string(_a.sprite) || !variable_struct_exists(_allowed,_a.sprite) || !is_bool(_a.mc) || !is_string(_a.data)) return false;
        if(!ln_enemy_number(_a.frame) || !ln_enemy_number(_a.width) || !ln_enemy_number(_a.height) || !ln_enemy_number(_a.mode)) return false;
        var _s=ln_sprite_art_source(_a.sprite);if(_s<0) return false;
        if(_a.frame<0 || _a.frame>=sprite_get_number(_s) || _a.width!=sprite_get_width(_s) || _a.height!=sprite_get_height(_s) || _a.mode<0 || _a.mode>4) return false;
        if(_keys[_i]!=ln_sprite_art_key(_a.sprite,_a.frame)) return false;
        _total+=_a.width*_a.height;if(_total>40000000) return false;
        if(!_deep) continue;
        var _pixels=ln_sprite_art_decode(_a);if(!is_array(_pixels)) return false;
        var _check={sprite:_a.sprite,width:_a.width,mode:_a.mode,mc:_a.mc,tinted:variable_struct_get(_allowed,_a.sprite).tinted};
        if(!ln_sprite_art_pixels_valid(_check,_pixels)) return false;
    }
    return true;
}
/// Working copies. A draft is created from the applied artwork or the original frame.
function ln_sprite_art_draft(_name,_frame,_create) {
    var _v=global.ln_sprites.art,_key=ln_sprite_art_key(_name,_frame);
    if(variable_struct_exists(_v.drafts,_key)) return variable_struct_get(_v.drafts,_key);
    if(!_create) return undefined;
    var _stored=ln_sprite_art_get(_name,_frame),_a;
    if(is_struct(_stored)) _a={sprite:_name,frame:_frame,width:_stored.width,height:_stored.height,mode:_stored.mode,mc:_stored.mc,pixels:ln_sprite_art_decode(_stored)};
    else {var _s=ln_sprite_art_source(_name);_a={sprite:_name,frame:_frame,width:sprite_get_width(_s),height:sprite_get_height(_s),mode:1,mc:false,pixels:ln_sprite_art_read(_name,_frame)};}
    _a.tinted=ln_sprite_art_tinted(_name);_a.rev=0;_a.changed=false;
    variable_struct_set(_v.drafts,_key,_a);return _a;
}
function ln_sprite_art_settings(_name,_frame) {
    var _v=global.ln_sprites.art,_a=ln_sprite_art_draft(_name,_frame,false);
    if(!is_struct(_a)) _a=ln_sprite_art_get(_name,_frame);
    return is_struct(_a)?[_a.mode,_a.mc]:[_v.mode,_v.mc];
}
function ln_sprite_art_touch(_a) {_a.rev++;_a.changed=true;global.ln_sprites.art.discard_armed=false;}
function ln_sprite_art_checkpoint(_a) {
    var _v=global.ln_sprites.art;
    array_push(_v.undo,{key:ln_sprite_art_key(_a.sprite,_a.frame),text:json_stringify(_a)});
    if(array_length(_v.undo)>60) array_delete(_v.undo,0,1);_v.redo=[];
}
/// Starts one undoable action on a frame. New drafts adopt the selected colour rules.
function ln_sprite_art_begin(_name,_frame) {
    var _v=global.ln_sprites.art,_fresh=!variable_struct_exists(_v.drafts,ln_sprite_art_key(_name,_frame)) && !is_struct(ln_sprite_art_get(_name,_frame));
    var _a=ln_sprite_art_draft(_name,_frame,true);ln_sprite_art_checkpoint(_a);
    if(_fresh && !_a.tinted && (_v.mode!=1 || _v.mc)) {_a.mode=_v.mode;_a.mc=_v.mc && _v.mode<2;ln_sprite_art_conform(_a);ln_sprite_art_touch(_a);}
    return _a;
}
function ln_sprite_art_history(_redo) {
    var _v=global.ln_sprites.art,_from=_redo?_v.redo:_v.undo;if(array_length(_from)==0) return false;
    var _entry=array_pop(_from),_current=variable_struct_get(_v.drafts,_entry.key);
    array_push(_redo?_v.undo:_v.redo,{key:_entry.key,text:json_stringify(_current)});
    var _a=json_parse(_entry.text);_a.rev=_current.rev+1;_a.changed=true;
    variable_struct_set(_v.drafts,_entry.key,_a);_v.stroke=false;_v.discard_armed=false;return true;
}
function ln_sprite_art_line(_a,_x0,_y0,_x1,_y1,_colour) {
    var _steps=max(1,max(abs(_x1-_x0),abs(_y1-_y0)));
    for(var _i=0;_i<=_steps;_i++) ln_sprite_art_put(_a,round(lerp(_x0,_x1,_i/_steps)),round(lerp(_y0,_y1,_i/_steps)),_colour);
    ln_sprite_art_touch(_a);
}
function ln_sprite_art_fill(_a,_x,_y,_colour) {
    var _step=_a.mc?2:1;_x=(_x div _step)*_step;
    var _old=_a.pixels[_y*_a.width+_x];_colour=ln_sprite_art_quantize(_a,_colour);if(_old==_colour) return;
    var _stack=[_y*_a.width+_x],_seen=array_create(array_length(_a.pixels),false);
    while(array_length(_stack)>0) {
        var _at=array_pop(_stack);if(_seen[_at]) continue;_seen[_at]=true;
        if(_a.pixels[_at]!=_old) continue;
        var _px=_at mod _a.width,_py=_at div _a.width;
        ln_sprite_art_put(_a,_px,_py,_colour);
        if(_px>=_step) array_push(_stack,_at-_step);if(_px+_step<_a.width) array_push(_stack,_at+_step);
        if(_py>0) array_push(_stack,_at-_a.width);if(_py+1<_a.height) array_push(_stack,_at+_a.width);
    }
    ln_sprite_art_touch(_a);
}
function ln_sprite_art_pending() {
    var _v=global.ln_sprites.art,_keys=variable_struct_get_names(_v.drafts),_n=0;
    for(var _i=0;_i<array_length(_keys);_i++) if(variable_struct_get(_v.drafts,_keys[_i]).changed) _n++;
    return _n;
}
/// Writes the project pack without capturing an untouched room as a room edit.
function ln_sprite_art_write(_file) {
    var _b=-1;
    try {
        _b=buffer_create(1024,buffer_grow,1);buffer_write(_b,buffer_text,json_stringify(ln_edit_pack()));buffer_save(_b,_file);buffer_delete(_b);
        return file_exists(_file);
    } catch(_error) {if(_b!=-1 && buffer_exists(_b)) buffer_delete(_b);return false;}
}
function ln_sprite_art_apply() {
    var _v=global.ln_sprites.art,_e=global.ln_editor,_keys=variable_struct_get_names(_v.drafts),_count=0;
    var _trial=ln_enemy_copy(_e.sprite_art);
    for(var _i=0;_i<array_length(_keys);_i++) {
        var _a=variable_struct_get(_v.drafts,_keys[_i]);if(!_a.changed) continue;
        if(!ln_sprite_art_pixels_valid(_a,_a.pixels)) {_v.message="Frame "+_keys[_i]+" breaks its colour rules; nothing applied.";return false;}
        if(array_equals(_a.pixels,ln_sprite_art_read(_a.sprite,_a.frame)) && !_a.mc && _a.mode==1) variable_struct_remove(_trial,_keys[_i]);
        else variable_struct_set(_trial,_keys[_i],{sprite:_a.sprite,frame:_a.frame,width:_a.width,height:_a.height,mode:_a.mode,mc:_a.mc,data:ln_sprite_art_encode(_a.pixels)});
        _count++;
    }
    if(_count==0) {_v.message="No unapplied frame edits.";return false;}
    if(!ln_sprite_art_valid(_trial,false)) {_v.message="Project sprite artwork limit reached; nothing applied.";return false;}
    _e.sprite_art=_trial;_e.sprite_rev++;_e.enabled=true;_e.dirty=true;
    for(var _i=0;_i<array_length(_keys);_i++) variable_struct_get(_v.drafts,_keys[_i]).changed=false;
    ln_sprite_art_write("modified-scenes.autosave.json");
    _v.message="Applied "+string(_count)+" frame"+(_count==1?"":"s")+" to the project. Modified ON. Save file stores them with your room edits.";
    return true;
}
function ln_sprite_art_discard() {
    var _v=global.ln_sprites.art,_n=ln_sprite_art_pending();
    if(_n==0) {_v.message="No unapplied frame edits.";return;}
    if(!_v.discard_armed) {_v.discard_armed=true;_v.message="Click Discard again to drop "+string(_n)+" unapplied frame"+(_n==1?"":"s")+".";return;}
    var _keys=variable_struct_get_names(_v.drafts);
    for(var _i=0;_i<array_length(_keys);_i++) if(variable_struct_get(_v.drafts,_keys[_i]).changed) variable_struct_remove(_v.drafts,_keys[_i]);
    _v.undo=[];_v.redo=[];_v.discard_armed=false;_v.message="Unapplied frame edits discarded.";
}
/// Called when a project file replaces the artwork, so stale drafts cannot be applied onto it.
function ln_sprite_art_reset_session() {
    var _v=global.ln_sprites.art;_v.drafts={};_v.undo=[];_v.redo=[];_v.stroke=false;ln_sprite_art_free();
}
function ln_sprite_art_free() {
    var _v=global.ln_sprites.art,_keys=variable_struct_get_names(_v.surfaces);
    for(var _i=0;_i<array_length(_keys);_i++) {var _c=variable_struct_get(_v.surfaces,_keys[_i]);if(surface_exists(_c.surface)) surface_free(_c.surface);}
    _v.surfaces={};if(surface_exists(_v.canvas_surface)) surface_free(_v.canvas_surface);_v.canvas_surface=-1;
}

// ---------------------------------------------------------------- game runtime
/// Keeps the game's sprite assets in step with the project and the Modified switch.
function ln_sprite_art_sync() {
    var _e=global.ln_editor;
    if(_e.sprite_synced_rev==_e.sprite_rev && _e.sprite_synced_enabled==_e.enabled) return;
    _e.sprite_synced_rev=_e.sprite_rev;_e.sprite_synced_enabled=_e.enabled;
    var _want={},_keys=variable_struct_get_names(_e.sprite_art);
    if(_e.enabled) for(var _i=0;_i<array_length(_keys);_i++) {
        var _a=variable_struct_get(_e.sprite_art,_keys[_i]);
        if(!variable_struct_exists(_want,_a.sprite)) variable_struct_set(_want,_a.sprite,[]);
        array_push(variable_struct_get(_want,_a.sprite),_keys[_i]);
    }
    var _names=variable_struct_get_names(_want);
    for(var _i=0;_i<array_length(_names);_i++) {
        var _list=variable_struct_get(_want,_names[_i]),_signature="";array_sort(_list,true);
        for(var _j=0;_j<array_length(_list);_j++) _signature+=_list[_j]+"="+md5_string_utf8(variable_struct_get(_e.sprite_art,_list[_j]).data)+";";
        if(variable_struct_exists(_e.sprite_assigned,_names[_i]) && variable_struct_get(_e.sprite_assigned,_names[_i])==_signature) continue;
        ln_sprite_art_build(_names[_i],_list);variable_struct_set(_e.sprite_assigned,_names[_i],_signature);
    }
    var _assigned=variable_struct_get_names(_e.sprite_assigned);
    for(var _i=0;_i<array_length(_assigned);_i++) if(!variable_struct_exists(_want,_assigned[_i])) {
        sprite_assign(asset_get_index(_assigned[_i]),variable_struct_get(_e.sprite_backups,_assigned[_i]));ln_sprite_art_release(_assigned[_i]);
        variable_struct_remove(_e.sprite_assigned,_assigned[_i]);
    }
}
/// The rebuilt sprite stays alive while assigned, in case its textures are shared.
function ln_sprite_art_release(_name) {
    var _live=global.ln_editor.sprite_live;
    if(variable_struct_exists(_live,_name)) {var _s=variable_struct_get(_live,_name);if(sprite_exists(_s)) sprite_delete(_s);variable_struct_remove(_live,_name);}
}
function ln_sprite_art_build(_name,_keys) {
    var _e=global.ln_editor,_asset=asset_get_index(_name);
    if(!variable_struct_exists(_e.sprite_backups,_name)) variable_struct_set(_e.sprite_backups,_name,sprite_duplicate(_asset));
    var _src=variable_struct_get(_e.sprite_backups,_name),_w=sprite_get_width(_src),_h=sprite_get_height(_src),_n=sprite_get_number(_src);
    var _xo=sprite_get_xoffset(_src),_yo=sprite_get_yoffset(_src),_by=array_create(_n,undefined);
    for(var _i=0;_i<array_length(_keys);_i++) {var _a=variable_struct_get(_e.sprite_art,_keys[_i]);_by[_a.frame]=_a;}
    var _surface=surface_create(_w,_h),_new=-1;
    var _view=matrix_get(matrix_view),_projection=matrix_get(matrix_projection),_world=matrix_get(matrix_world);
    for(var _i=0;_i<_n;_i++) {
        var _b=is_struct(_by[_i])?ln_sprite_art_buffer(_by[_i]):-1;
        if(_b!=-1) {buffer_set_surface(_b,_surface,0);buffer_delete(_b);}
        else {
            ln_sprite_art_target(_surface,_w,_h);
            draw_clear_alpha(c_black,0);gpu_set_blendenable(false);
            draw_sprite_ext(_src,_i,_xo,_yo,1,1,0,c_white,1);
            gpu_set_blendenable(true);surface_reset_target();
        }
        if(_new==-1) _new=sprite_create_from_surface(_surface,0,0,_w,_h,false,false,_xo,_yo);
        else sprite_add_from_surface(_new,_surface,0,0,_w,_h,false,false);
    }
    matrix_set(matrix_view,_view);matrix_set(matrix_projection,_projection);matrix_set(matrix_world,_world);
    surface_free(_surface);sprite_assign(_asset,_new);ln_sprite_art_release(_name);variable_struct_set(_e.sprite_live,_name,_new);
}

// ---------------------------------------------------------------- editor screen
function ln_sprite_art_bounds() {
    var _v=global.ln_sprites.art,_l=100000,_t=100000,_r=-100000,_b=-100000;
    for(var _i=0;_i<array_length(_v.items);_i++) for(var _j=0;_j<array_length(_v.items[_i]);_j++) {
        var _p=_v.items[_i][_j],_s=ln_sprite_art_source(_p[0]);if(_s<0) continue;
        var _sx=array_length(_p)>5?_p[5]:1,_sy=array_length(_p)>6?_p[6]:1;
        var _x=_p[2]-sprite_get_xoffset(_s)*_sx,_y=_p[3]-sprite_get_yoffset(_s)*_sy;
        _l=min(_l,_x);_t=min(_t,_y);_r=max(_r,_x+sprite_get_width(_s)*_sx);_b=max(_b,_y+sprite_get_height(_s)*_sy);
    }
    _v.full_rect=_r>_l?[floor(_l),floor(_t),ceil(_r)-floor(_l),ceil(_b)-floor(_t)]:[0,0,8,8];_v.rect=_v.full_rect;
    // Crop to the figure plus a margin, so characters get larger pixels; Full frame shows everything.
    if(_v.crop && is_array(_v.figure)) {
        var _f=_v.full_rect,_x0=max(_f[0],floor(_v.figure[0])-8),_y0=max(_f[1],floor(_v.figure[1])-8);
        var _x1=min(_f[0]+_f[2],ceil(_v.figure[2])+8),_y1=min(_f[1]+_f[3],ceil(_v.figure[3])+8);
        if(_x1-_x0>=8 && _y1-_y0>=8) _v.rect=[_x0,_y0,_x1-_x0,_y1-_y0];
    }
}
function ln_sprite_art_use_clip(_clip) {
    var _v=global.ln_sprites.art,_frames=_v.entry.clips[_clip].frames;
    _v.clip_index=_clip;_v.items=[];_v.seconds=[];
    for(var _i=0;_i<array_length(_frames);_i++) {array_push(_v.items,_frames[_i].parts);array_push(_v.seconds,_frames[_i].seconds);}
    _v.figure=variable_struct_exists(_v.entry.clips[_clip],"visible_bounds")?_v.entry.clips[_clip].visible_bounds:undefined;
    _v.context=_v.entry.name+" / "+_v.entry.clips[_clip].name;_v.index=0;_v.part=0;_v.view=0;_v.elapsed=0;ln_sprite_art_bounds();
}
function ln_sprite_art_use_sheet(_name,_frame) {
    var _v=global.ln_sprites.art,_s=ln_sprite_art_source(_name),_n=sprite_get_number(_s);
    _v.items=[];_v.seconds=[];
    for(var _i=0;_i<_n;_i++) {array_push(_v.items,[[_name,_i,sprite_get_xoffset(_s),sprite_get_yoffset(_s),c_white]]);array_push(_v.seconds,.1);}
    var _xo=sprite_get_xoffset(_s),_yo=sprite_get_yoffset(_s);
    _v.figure=[sprite_get_bbox_left(_s)-_xo,sprite_get_bbox_top(_s)-_yo,sprite_get_bbox_right(_s)+1-_xo,sprite_get_bbox_bottom(_s)+1-_yo];
    _v.sheet=_name;_v.context=_name+" sprite sheet ("+string(_n)+" frames)";_v.index=clamp(_frame,0,_n-1);_v.part=0;_v.elapsed=0;
    _v.sheet_scroll=max(0,(_v.index div 10)-3);ln_sprite_art_bounds();
}
/// Opens the editor on the viewer's current character, animation and frame.
function ln_sprite_art_open() {
    var _sv=global.ln_sprites,_v=_sv.art;ln_sprite_art_catalog();
    _v.entry=_sv.list[_sv.selected];ln_sprite_art_use_clip(_sv.animation);
    _v.index=clamp(_sv.frame,0,array_length(_v.items)-1);_v.open=true;_v.playing=false;_v.stroke=false;_v.discard_armed=false;
    _v.message="Shared frames update every animation that uses them. Apply stores edits in the project.";
}
function ln_sprite_art_close() {
    var _sv=global.ln_sprites,_v=_sv.art;
    if(_v.view==0 && is_struct(_v.entry) && _v.entry==_sv.list[_sv.selected]) {_sv.animation=_v.clip_index;_sv.frame=_v.index;_sv.elapsed=0;}
    _v.open=false;_v.stroke=false;_v.playing=false;ln_sprite_art_free();
}
function ln_sprite_art_active() {
    var _v=global.ln_sprites.art;if(array_length(_v.items)==0) return undefined;
    var _parts=_v.items[_v.index];if(array_length(_parts)==0) return undefined;
    _v.part=clamp(_v.part,0,array_length(_parts)-1);return _parts[_v.part];
}
function ln_sprite_art_layout() {
    var _r=global.ln_sprites.art.rect,_z=max(1,floor(min(704/_r[2],480/_r[3])));
    var _x=24+floor((704-_r[2]*_z)/2),_y=116+floor((480-_r[3]*_z)/2);
    return [_x,_y,_z,_x-_r[0]*_z,_y-_r[1]*_z];
}
/// Part-local pixel under a frame-space point.
function ln_sprite_art_local(_p,_fx,_fy) {
    var _s=ln_sprite_art_source(_p[0]),_sx=array_length(_p)>5?_p[5]:1,_sy=array_length(_p)>6?_p[6]:1;
    return [floor((_fx-(_p[2]-sprite_get_xoffset(_s)*_sx))/_sx),floor((_fy-(_p[3]-sprite_get_yoffset(_s)*_sy))/_sy),sprite_get_width(_s),sprite_get_height(_s)];
}
function ln_sprite_art_pixels(_name,_frame) {
    var _a=ln_sprite_art_draft(_name,_frame,false);if(is_struct(_a)) return _a.pixels;
    var _s=ln_sprite_art_get(_name,_frame);if(is_struct(_s)) return ln_sprite_art_decode(_s);
    return ln_sprite_art_read(_name,_frame);
}
/// Picks the topmost visible layer under the cursor and its displayed colour.
function ln_sprite_art_pick(_fx,_fy) {
    var _v=global.ln_sprites.art,_parts=_v.items[_v.index];
    for(var _j=array_length(_parts)-1;_j>=0;_j--) {
        var _p=_parts[_j],_l=ln_sprite_art_local(_p,_fx,_fy);
        if(_l[0]<0 || _l[1]<0 || _l[0]>=_l[2] || _l[1]>=_l[3]) continue;
        var _c=ln_sprite_art_pixels(_p[0],_p[1])[_l[1]*_l[2]+_l[0]];if(_c<0) continue;
        _v.part=_j;_v.colour=ln_sprite_art_tinted(_p[0])?_p[4]:_c;return true;
    }
    return false;
}
/// Surface for an edited or applied frame; -1 means draw the original sprite.
function ln_sprite_art_image(_name,_frame) {
    var _v=global.ln_sprites.art,_key=ln_sprite_art_key(_name,_frame),_d=ln_sprite_art_draft(_name,_frame,false),_s=undefined,_tag;
    if(is_struct(_d)) _tag="d"+string(_d.rev);
    else {_s=ln_sprite_art_get(_name,_frame);if(!is_struct(_s)) return -1;_tag="a"+string(global.ln_editor.sprite_rev);}
    var _c=variable_struct_exists(_v.surfaces,_key)?variable_struct_get(_v.surfaces,_key):undefined;
    if(is_struct(_c) && _c.tag==_tag && surface_exists(_c.surface)) return _c.surface;
    if(is_struct(_c) && surface_exists(_c.surface)) surface_free(_c.surface);
    var _surface;
    if(is_struct(_d)) _surface=ln_art_surface(_d);
    else {var _b=ln_sprite_art_buffer(_s);if(_b==-1) return -1;_surface=surface_create(_s.width,_s.height);buffer_set_surface(_b,_surface,0);buffer_delete(_b);}
    variable_struct_set(_v.surfaces,_key,{tag:_tag,surface:_surface});return _surface;
}
function ln_sprite_art_draw_part(_p,_ox,_oy,_z,_alpha) {
    var _s=ln_sprite_art_source(_p[0]);if(_s<0) return;
    var _sx=(array_length(_p)>5?_p[5]:1)*_z,_sy=(array_length(_p)>6?_p[6]:1)*_z,_surface=ln_sprite_art_image(_p[0],_p[1]);
    if(surface_exists(_surface)) draw_surface_ext(_surface,_ox+_p[2]*_z-sprite_get_xoffset(_s)*_sx,_oy+_p[3]*_z-sprite_get_yoffset(_s)*_sy,_sx,_sy,0,_p[4],_alpha);
    else draw_sprite_ext(_s,_p[1],_ox+_p[2]*_z,_oy+_p[3]*_z,_sx,_sy,0,_p[4],_alpha);
}
function ln_sprite_art_marker(_parts) {
    var _v=global.ln_sprites.art,_state=0;
    for(var _j=0;_j<array_length(_parts);_j++) {
        var _d=ln_sprite_art_draft(_parts[_j][0],_parts[_j][1],false);
        if(is_struct(_d) && _d.changed) return 2;
        if(is_struct(ln_sprite_art_get(_parts[_j][0],_parts[_j][1]))) _state=1;
    }
    return _state;
}
function ln_sprite_art_thumb(_i,_x,_y,_size,_selected) {
    var _v=global.ln_sprites.art,_r=_v.rect,_z=min(_size/_r[2],_size/_r[3]);
    draw_set_colour(make_colour_rgb(96,100,106));draw_rectangle(_x,_y,_x+_size-1,_y+_size-1,false);
    var _ox=_x+(_size-_r[2]*_z)/2-_r[0]*_z,_oy=_y+(_size-_r[3]*_z)/2-_r[1]*_z,_parts=_v.items[_i];
    for(var _j=0;_j<array_length(_parts);_j++) ln_sprite_art_draw_part(_parts[_j],_ox,_oy,_z,1);
    var _m=ln_sprite_art_marker(_parts);
    if(_m>0) {draw_set_colour(_m==2?make_colour_rgb(255,170,40):make_colour_rgb(90,220,120));draw_rectangle(_x+_size-10,_y+2,_x+_size-3,_y+9,false);}
    if(_selected) {draw_set_colour(make_colour_rgb(255,230,90));draw_rectangle(_x-2,_y-2,_x+_size+1,_y+_size+1,true);draw_rectangle(_x-1,_y-1,_x+_size,_y+_size,true);}
    draw_set_colour(c_white);
}
function ln_sprite_art_strip_start() {var _v=global.ln_sprites.art;return clamp(_v.index-4,0,max(0,array_length(_v.items)-10));}
function ln_sprite_art_step(_host) {
    var _sv=global.ln_sprites,_v=_sv.art,_e=global.ln_editor,_n=array_length(_v.items);
    var _ctrl=keyboard_check(vk_control),_mx=ln_tool_mouse_x(),_my=ln_tool_mouse_y();
    if(keyboard_check_pressed(vk_f9)) ln_fullscreen_toggle(_host);
    if(ln_edit_hit(206,18,170,28) || keyboard_check_pressed(vk_escape)) {ln_sprite_art_close();return true;}
    if(ln_edit_hit(24,18,170,28)) ln_sprite_art_apply();
    if(ln_edit_hit(388,18,110,28) || (_ctrl && keyboard_check_pressed(ord("Z")))) ln_sprite_art_history(false);
    if(ln_edit_hit(510,18,110,28) || (_ctrl && keyboard_check_pressed(ord("Y")))) ln_sprite_art_history(true);
    if(ln_edit_hit(632,18,190,28)) ln_sprite_art_discard();
    if(ln_edit_hit(834,18,120,28)) {
        var _file=get_save_filename("JSON files|*.json","modified-scenes.json");
        if(_file!="") _v.message=ln_sprite_art_write(_file)?"Saved project file with applied sprite and room edits.":"Could not save; edits remain in memory.";
    }
    if(ln_edit_hit(966,18,170,28)) _e.enabled=!_e.enabled;
    if(ln_edit_hit(760,60,240,28) && is_struct(_v.entry) && _v.view!=0) ln_sprite_art_use_clip(_v.clip_index);
    if(ln_edit_hit(1010,60,240,28)) {
        if(_v.view==2) _v.view=1;
        else if(_v.view==0) {var _p=ln_sprite_art_active();if(is_array(_p)) {ln_sprite_art_use_sheet(_p[0],_p[1]);_v.view=1;}}
    }
    _n=array_length(_v.items);
    if(_v.view==1) {
        var _rows=ceil(_n/10);
        if(mouse_wheel_up()) _v.sheet_scroll=max(0,_v.sheet_scroll-1);
        if(mouse_wheel_down()) _v.sheet_scroll=min(max(0,_rows-7),_v.sheet_scroll+1);
        var _d=ln_edit_value_repeat(600,612,60,28)+keyboard_check_pressed(vk_up);if(_d) _v.sheet_scroll=max(0,_v.sheet_scroll-_d);
        _d=ln_edit_value_repeat(670,612,74,28)+keyboard_check_pressed(vk_down);if(_d) _v.sheet_scroll=min(max(0,_rows-7),_v.sheet_scroll+_d);
        for(var _i=0;_i<70;_i++) {
            var _at=(_v.sheet_scroll+(_i div 10))*10+(_i mod 10);
            if(_at<_n && ln_edit_hit(24+(_i mod 10)*70,116+(_i div 10)*70,64,64)) {_v.index=_at;_v.view=2;_v.message="Editing sheet frame "+string(_at)+".";}
        }
        return true;
    }
    // Frame and animation navigation.
    var _delta=ln_edit_value_repeat(24,680,40,28)+keyboard_check_pressed(vk_left);
    if(_delta) {_v.index=(_v.index-_delta mod _n+_n) mod _n;_v.playing=false;}
    _delta=ln_edit_value_repeat(200,680,40,28)+keyboard_check_pressed(vk_right);
    if(_delta) {_v.index=(_v.index+_delta) mod _n;_v.playing=false;}
    if(ln_edit_hit(264,680,110,28) || keyboard_check_pressed(vk_space)) {_v.playing=!_v.playing;_v.elapsed=0;_v.stroke=false;}
    if(_v.view==0 && is_struct(_v.entry)) {
        var _clips=array_length(_v.entry.clips);
        if(ln_edit_hit(400,680,40,28)) ln_sprite_art_use_clip((_v.clip_index+_clips-1) mod _clips);
        if(ln_edit_hit(704,680,40,28)) ln_sprite_art_use_clip((_v.clip_index+1) mod _clips);
    }
    var _start=ln_sprite_art_strip_start();
    for(var _i=0;_i<10;_i++) if(_start+_i<_n && ln_edit_hit(24+_i*70,606,64,64)) {_v.index=_start+_i;_v.playing=false;}
    var _parts=_v.items[_v.index],_layers=array_length(_parts);
    if(ln_edit_hit(1002,260,40,28) && _layers>0) _v.part=(_v.part+_layers-1) mod _layers;
    if(ln_edit_hit(1210,260,40,28) && _layers>0) _v.part=(_v.part+1) mod _layers;
    if(_v.playing) {
        _v.elapsed+=min(delta_time/1000000,.1);var _guard=0;
        while(_v.elapsed>=_v.seconds[_v.index] && _guard++<100) {_v.elapsed-=_v.seconds[_v.index];_v.index=(_v.index+1) mod _n;}
        return true;
    }
    var _p=ln_sprite_art_active();if(!is_array(_p)) return true;
    var _tinted=ln_sprite_art_tinted(_p[0]),_settings=ln_sprite_art_settings(_p[0],_p[1]),_a;
    // Colour rules, tools and palette.
    for(var _i=0;_i<5;_i++) if(ln_edit_hit(760,96+_i*32,490,28) && _settings[0]!=_i) {
        _v.mode=_i;if(_i>=2) _v.mc=false;
        _a=ln_sprite_art_begin(_p[0],_p[1]);_a.mode=_i;if(_i>=2 && !_a.tinted) _a.mc=false;ln_sprite_art_conform(_a);ln_sprite_art_touch(_a);
        _v.message="Colour conversion can be undone with Ctrl+Z.";
    }
    if((_settings[0]<2 || _tinted) && ln_edit_hit(760,260,230,28)) {
        _v.mc=!_settings[1];_a=ln_sprite_art_begin(_p[0],_p[1]);_a.mc=_v.mc;ln_sprite_art_conform(_a);ln_sprite_art_touch(_a);
    }
    for(var _i=0;_i<4;_i++) if(ln_edit_hit(760+_i*124,296,116,28)) _v.tool=_i;
    for(var _i=0;_i<16;_i++) if(ln_edit_hit(760+(_i mod 8)*58,332+(_i div 8)*38,52,32)) _v.colour=global.ln_paint_palette[_i];
    for(var _i=0;_i<3;_i++) if(mouse_check_button(mb_left) && ln_edit_inside(802,428+_i*34,430,20)) {
        var _rgb=[colour_get_red(_v.colour),colour_get_green(_v.colour),colour_get_blue(_v.colour)];_rgb[_i]=round(clamp((_mx-802)/430,0,1)*255);
        _v.colour=ln_art_quantize(make_colour_rgb(_rgb[0],_rgb[1],_rgb[2]),_settings[0]);
    }
    if(ln_edit_hit(760,524,230,28) || ln_edit_hit(1002,524,230,28)) {
        var _horizontal=_mx<1000,_old;_a=ln_sprite_art_begin(_p[0],_p[1]);_old=_a.pixels;_a.pixels=array_create(array_length(_old),-1);
        for(var _y=0;_y<_a.height;_y++) for(var _x=0;_x<_a.width;_x++) _a.pixels[_y*_a.width+_x]=_horizontal?_old[_y*_a.width+_a.width-1-_x]:_old[(_a.height-1-_y)*_a.width+_x];
        ln_sprite_art_touch(_a);
    }
    if(ln_edit_hit(760,560,230,28)) {
        var _src=ln_sprite_art_pixels(_p[0],_p[1]),_l=ln_sprite_art_local(_p,0,0);
        _v.clipboard={width:_l[2],height:_l[3],pixels:ln_enemy_copy(_src)};_v.message="Frame copied.";
    }
    if(ln_edit_hit(1002,560,230,28)) {
        var _l=ln_sprite_art_local(_p,0,0);
        if(!is_struct(_v.clipboard)) _v.message="Copy a frame first.";
        else if(_v.clipboard.width!=_l[2] || _v.clipboard.height!=_l[3]) _v.message="Copied frame has a different size.";
        else {_a=ln_sprite_art_begin(_p[0],_p[1]);_a.pixels=ln_enemy_copy(_v.clipboard.pixels);ln_sprite_art_conform(_a);ln_sprite_art_touch(_a);_v.message="Frame pasted with this frame's colour rules.";}
    }
    if(ln_edit_hit(760,596,230,28)) {
        _a=ln_sprite_art_begin(_p[0],_p[1]);_a.pixels=ln_sprite_art_read(_p[0],_p[1]);_a.mode=1;_a.mc=false;ln_sprite_art_touch(_a);
        _v.message="Original frame restored. Apply removes the edit from the project.";
    }
    if(ln_edit_hit(1002,596,230,28)) _v.dim=!_v.dim;
    if(ln_edit_hit(760,632,230,28)) _v.onion=!_v.onion;
    if(ln_edit_hit(1002,632,230,28)) {_v.crop=!_v.crop;ln_sprite_art_bounds();}
    // Painting on the selected layer.
    var _L=ln_sprite_art_layout(),_fx=(_mx-_L[3])/_L[2],_fy=(_my-_L[4])/_L[2],_loc=ln_sprite_art_local(_p,_fx,_fy);
    var _inside=_mx>=_L[0] && _my>=_L[1] && _mx<_L[0]+_v.rect[2]*_L[2] && _my<_L[1]+_v.rect[3]*_L[2];
    if(mouse_check_button_pressed(mb_left) && _inside) {
        if(_v.tool==3 || keyboard_check(vk_alt)) {ln_sprite_art_pick(_fx,_fy);return true;}
        if(_loc[0]<0 || _loc[1]<0 || _loc[0]>=_loc[2] || _loc[1]>=_loc[3]) {_v.message="Outside the selected layer. Alt-click selects a layer; Crop to figure OFF shows the whole frame.";return true;}
        _a=ln_sprite_art_begin(_p[0],_p[1]);
        if(_v.tool==2) ln_sprite_art_fill(_a,_loc[0],_loc[1],_v.colour);
        else {_v.stroke=true;_v.stroke_button=mb_left;_v.stroke_key=ln_sprite_art_key(_p[0],_p[1]);_v.last_x=_loc[0];_v.last_y=_loc[1];}
    }
    // Right mouse button erases with any tool.
    if(mouse_check_button_pressed(mb_right) && _inside && !_v.stroke) {
        if(_loc[0]<0 || _loc[1]<0 || _loc[0]>=_loc[2] || _loc[1]>=_loc[3]) {_v.message="Outside the selected layer. Alt-click selects a layer; Crop to figure OFF shows the whole frame.";return true;}
        ln_sprite_art_begin(_p[0],_p[1]);
        _v.stroke=true;_v.stroke_button=mb_right;_v.stroke_key=ln_sprite_art_key(_p[0],_p[1]);_v.last_x=_loc[0];_v.last_y=_loc[1];
    }
    if(mouse_check_button(_v.stroke_button) && _v.stroke && variable_struct_exists(_v.drafts,_v.stroke_key)) {
        var _erase=_v.stroke_button==mb_right || _v.tool==1;_a=variable_struct_get(_v.drafts,_v.stroke_key);
        ln_sprite_art_line(_a,_v.last_x,_v.last_y,_loc[0],_loc[1],_erase?-1:_v.colour);
        _v.last_x=_loc[0];_v.last_y=_loc[1];
    }
    if(!mouse_check_button(_v.stroke_button)) _v.stroke=false;
    return true;
}
function ln_sprite_art_draw() {
    var _sv=global.ln_sprites,_v=_sv.art,_e=global.ln_editor,_n=array_length(_v.items);
    shader_reset();gpu_set_blendmode(bm_normal);gpu_set_texfilter(false);draw_set_alpha(1);
    ln_tool_clear(false);draw_set_font(font_jansina);draw_set_halign(fa_left);draw_set_valign(fa_top);draw_set_colour(c_white);
    var _pending=ln_sprite_art_pending();
    ln_edit_button(24,18,170,"Apply to project",_pending>0);ln_edit_button(206,18,170,"Back to viewer");
    ln_edit_button(388,18,110,"Undo (^Z)",array_length(_v.undo)>0);ln_edit_button(510,18,110,"Redo (^Y)",array_length(_v.redo)>0);
    ln_edit_button(632,18,190,_v.discard_armed?"Confirm discard":"Discard unapplied",_pending>0);
    ln_edit_button(834,18,120,"Save file");ln_edit_button(966,18,170,"Modified "+(_e.enabled?"ON":"OFF"),_e.enabled);
    ln_edit_button(760,60,240,"Animation",_v.view==0);ln_edit_button(1010,60,240,"Sprite sheet",_v.view!=0);
    draw_text(24,64,"SPRITE ART / LN"+string(_sv.game)+" / "+_v.context);
    var _p=ln_sprite_art_active();
    if(_v.view==1) {
        draw_text(24,90,"Click a frame to edit it. Mouse wheel or arrows scroll.");
        for(var _i=0;_i<70;_i++) {
            var _at=(_v.sheet_scroll+(_i div 10))*10+(_i mod 10);if(_at>=_n) break;
            ln_sprite_art_thumb(_at,24+(_i mod 10)*70,116+(_i div 10)*70,64,_at==_v.index);
        }
        ln_edit_button(600,612,60,"Up");ln_edit_button(670,612,74,"Down");
        draw_text(24,612,"Rows "+string(_v.sheet_scroll+1)+"-"+string(min(ceil(_n/10),_v.sheet_scroll+7))+" of "+string(ceil(_n/10))+".  Green: applied edit.  Orange: unapplied edit.");
    } else if(is_array(_p)) {
        var _l=ln_sprite_art_local(_p,0,0),_uses=variable_struct_exists(_v.uses,ln_sprite_art_key(_p[0],_p[1]))?variable_struct_get(_v.uses,ln_sprite_art_key(_p[0],_p[1])):0;
        var _d=ln_sprite_art_draft(_p[0],_p[1],false),_state=is_struct(_d) && _d.changed?"unapplied edit":(is_struct(ln_sprite_art_get(_p[0],_p[1]))?"applied edit":"original");
        draw_text(24,90,_p[0]+" #"+string(_p[1])+"  "+string(_l[2])+"x"+string(_l[3])+"  in "+string(_uses)+" animation frames  ("+_state+")");
        // Canvas: checkerboard, onion skin, layers and the selected layer's pixel grid,
        // drawn into a canvas-sized surface so cropped layers cannot spill over the panels.
        var _L=ln_sprite_art_layout(),_w=_v.rect[2]*_L[2],_h=_v.rect[3]*_L[2];
        if(!surface_exists(_v.canvas_surface)) _v.canvas_surface=surface_create(704,480);
        var _view=matrix_get(matrix_view),_projection=matrix_get(matrix_projection),_world=matrix_get(matrix_world);
        ln_sprite_art_target(_v.canvas_surface,704,480);draw_clear_alpha(c_black,0);gpu_set_blendmode_ext_sepalpha(bm_src_alpha,bm_inv_src_alpha,bm_one,bm_inv_src_alpha);
        var _cx=_L[0]-24,_cy=_L[1]-116,_ox=_L[3]-24,_oy=_L[4]-116;
        for(var _y=0;_y<_h;_y+=16) for(var _x=0;_x<_w;_x+=16) {
            draw_set_colour(((_x div 16+_y div 16) mod 2)==0?make_colour_rgb(112,116,122):make_colour_rgb(138,142,148));
            draw_rectangle(_cx+_x,_cy+_y,_cx+min(_w,_x+16)-1,_cy+min(_h,_y+16)-1,false);
        }
        if(_v.onion && !_v.playing && _n>1) {var _prev=_v.items[(_v.index+_n-1) mod _n];for(var _j=0;_j<array_length(_prev);_j++) ln_sprite_art_draw_part(_prev[_j],_ox,_oy,_L[2],.3);}
        var _parts=_v.items[_v.index];
        for(var _j=0;_j<array_length(_parts);_j++) ln_sprite_art_draw_part(_parts[_j],_ox,_oy,_L[2],(_v.playing || !_v.dim || _j==_v.part)?1:.35);
        if(!_v.playing) {
            var _s=ln_sprite_art_source(_p[0]),_sx=(array_length(_p)>5?_p[5]:1)*_L[2],_sy=(array_length(_p)>6?_p[6]:1)*_L[2];
            var _px=_ox+_p[2]*_L[2]-sprite_get_xoffset(_s)*_sx,_py=_oy+_p[3]*_L[2]-sprite_get_yoffset(_s)*_sy,_settings=ln_sprite_art_settings(_p[0],_p[1]);
            if(_sx>=6) {
                draw_set_alpha(.18);draw_set_colour(c_white);
                var _gx0=max(_px,_cx),_gx1=min(_px+_l[2]*_sx,_cx+_w),_gy0=max(_py,_cy),_gy1=min(_py+_l[3]*_sy,_cy+_h);
                for(var _x=0;_x<=_l[2];_x+=(_settings[1]?2:1)) if(_px+_x*_sx>=_gx0 && _px+_x*_sx<=_gx1) draw_line(_px+_x*_sx,_gy0,_px+_x*_sx,_gy1);
                for(var _y=0;_y<=_l[3];_y++) if(_py+_y*_sy>=_gy0 && _py+_y*_sy<=_gy1) draw_line(_gx0,_py+_y*_sy,_gx1,_py+_y*_sy);
                draw_set_alpha(1);
            }
            draw_set_colour(make_colour_rgb(255,230,90));draw_rectangle(max(_px,_cx)-1,max(_py,_cy)-1,min(_px+_l[2]*_sx,_cx+_w),min(_py+_l[3]*_sy,_cy+_h),true);
        }
        draw_set_alpha(1);draw_set_colour(c_white);gpu_set_blendmode(bm_normal);surface_reset_target();
        matrix_set(matrix_view,_view);matrix_set(matrix_projection,_projection);matrix_set(matrix_world,_world);
        draw_surface(_v.canvas_surface,24,116);
        // Frame strip and navigation.
        var _start=ln_sprite_art_strip_start();
        for(var _i=0;_i<10 && _start+_i<_n;_i++) ln_sprite_art_thumb(_start+_i,24+_i*70,606,64,_start+_i==_v.index);
        ln_edit_button(24,680,40,"<");ln_edit_button(200,680,40,">");ln_edit_button(264,680,110,_v.playing?"Pause":"Play");
        draw_set_colour(c_white);draw_text(74,685,"Frame "+string(_v.index+1)+"/"+string(_n));
        if(_v.view==0 && is_struct(_v.entry)) {
            ln_edit_button(400,680,40,"<");ln_edit_button(704,680,40,">");
            draw_text(450,685,string(_v.clip_index+1)+"/"+string(array_length(_v.entry.clips))+" "+_v.entry.clips[_v.clip_index].name);
        }
    }
    // Colour rules and tools for the selected layer.
    if(is_array(_p)) {
        var _tinted=ln_sprite_art_tinted(_p[0]),_settings=ln_sprite_art_settings(_p[0],_p[1]);
        var _names=["C64 Strict - sprite's own colours","C64 Loose","C64 HiRes - any colour","16bit AMIGA - 4096 colours","32bit AMIGA AGA - 24bit colour"];
        for(var _i=0;_i<5;_i++) ln_edit_button(760,96+_i*32,490,_names[_i],_settings[0]==_i);
        if(_settings[0]<2 || _tinted) ln_edit_button(760,260,230,_settings[1]?"Multicolour (2x1)":"Hi-res (1x1)");
        else {draw_set_colour(c_white);draw_text(760,265,"1x1 pixels");}
        var _layers=array_length(_v.items[_v.index]);
        ln_edit_button(1002,260,40,"<");ln_edit_button(1210,260,40,">");
        draw_set_colour(c_white);draw_text(1052,265,"Layer "+string(_v.part+1)+"/"+string(_layers));
        var _tools=["Pencil","Eraser","Fill","Pick colour"];
        for(var _i=0;_i<4;_i++) ln_edit_button(760+_i*124,296,116,_tools[_i],_v.tool==_i);
        var _own=_settings[0]==0 && !_tinted?ln_sprite_art_strict(_p[0]):global.ln_paint_palette;
        for(var _i=0;_i<16;_i++) {
            // C64 Strict dims the colours this sprite does not use.
            draw_set_alpha(array_contains(_own,global.ln_paint_palette[_i])?1:.18);draw_set_colour(global.ln_paint_palette[_i]);
            draw_rectangle(760+(_i mod 8)*58,332+(_i div 8)*38,812+(_i mod 8)*58,364+(_i div 8)*38,false);
        }
        draw_set_alpha(1);
        draw_set_colour(_tinted?_p[4]:ln_sprite_art_quantize({sprite:_p[0],mode:_settings[0],tinted:false},_v.colour));draw_rectangle(760,412,790,512,false);
        if(_tinted) {
            draw_set_colour(c_white);draw_text(802,414,"LN3 layer mask: its colour comes from");draw_text(802,440,"the game palette. Paint switches pixels on,");draw_text(802,466,"Eraser switches them off.");
        } else {
            var _rgb=[colour_get_red(_v.colour),colour_get_green(_v.colour),colour_get_blue(_v.colour)],_labels=["R","G","B"];
            for(var _i=0;_i<3;_i++) {
                draw_set_colour(c_white);draw_text(802,412+_i*34,_labels[_i]+" "+string(_rgb[_i]));
                draw_set_colour(make_colour_rgb(75,80,85));draw_rectangle(802,436+_i*34,1232,440+_i*34,false);
                draw_set_colour(c_white);draw_circle(802+430*_rgb[_i]/255,438+_i*34,5,false);
            }
        }
        ln_edit_button(760,524,230,"Flip horizontal");ln_edit_button(1002,524,230,"Flip vertical");
        ln_edit_button(760,560,230,"Copy frame");ln_edit_button(1002,560,230,"Paste frame",is_struct(_v.clipboard));
        ln_edit_button(760,596,230,"Revert frame");ln_edit_button(1002,596,230,"Dim other layers",_v.dim);
        ln_edit_button(760,632,230,"Onion skin",_v.onion);ln_edit_button(1002,632,230,"Crop to figure",_v.crop);
    }
    draw_set_colour(c_white);
    draw_text(760,672,"Project: "+string(array_length(variable_struct_get_names(_e.sprite_art)))+" edited frames.  Unapplied: "+string(_pending)+".");
    draw_text(24,716,"Right-drag: erase.  Alt-click: pick colour and layer.  Arrows: frame.  Space: play.  Esc: back to the viewer.");
    draw_set_colour(make_colour_rgb(150,210,220));draw_text(24,744,_v.message);draw_set_colour(c_white);
}

// ---------------------------------------------------------------- checks
function ln_sprite_art_checks() {
    var _e=global.ln_editor,_sv=global.ln_sprites,_v=_sv.art,_P=global.ln_paint_palette,_t=get_timer();
    _e.sprite_art={};_e.sprite_rev++;_e.enabled=true;ln_sprite_art_sync();ln_sprite_art_catalog();
    // Original pixels are read exactly, in the C64 palette.
    var _orig=ln_sprite_art_read("spr_char_ln2_enemy_type_2",0),_opaque=0,_inpal=true;
    for(var _i=0;_i<array_length(_orig);_i++) if(_orig[_i]>=0) {_opaque++;if(!array_contains(_P,_orig[_i])) _inpal=false;}
    ln_check(_opaque>0 && _inpal,"original sprite frame reads as exact C64 palette colours");
    // Restriction rules.
    var _ninja=ln_sprite_art_strict("spr_char_ln1_ninja");
    ln_check(array_length(_ninja)==2 && array_contains(_ninja,_P[0]) && array_contains(_ninja,_P[10]),"LN1 ninja strict colours are its own black and pink");
    var _a={sprite:"spr_char_ln1_ninja",frame:0,width:8,height:2,mode:0,mc:true,tinted:false,pixels:array_create(16,-1)};
    ln_sprite_art_put(_a,1,0,_P[7]);ln_check(_a.pixels[0]==_P[10] && _a.pixels[1]==_P[10],"strict snaps paint to the sprite's nearest own colour in 2x1 pairs");
    ln_sprite_art_put(_a,2,0,_P[2]);ln_check(array_contains(_ninja,_a.pixels[2]) && ln_sprite_art_pixels_valid(_a,_a.pixels),"strict frame uses only the sprite's colours");
    ln_check(!ln_sprite_art_pixels_valid({sprite:"spr_char_ln1_ninja",width:8,mode:0,mc:false,tinted:false},[_P[7],-1,-1,-1,-1,-1,-1,-1]),"colour outside the sprite's own set fails strict validation");
    ln_check(array_contains(ln_sprite_art_strict("spr_char_ln2_enemy_type_6"),make_colour_rgb(46,44,155)) && !array_contains(_ninja,make_colour_rgb(46,44,155)),"each sprite keeps its own strict colours");
    _a.mode=1;_a.mc=false;ln_sprite_art_put(_a,0,1,_P[7]);ln_check(_a.pixels[8]==_P[7],"loose allows the whole C64 palette");
    _a.mode=0;ln_sprite_art_conform(_a);ln_check(_a.pixels[8]==_P[10] && ln_sprite_art_pixels_valid(_a,_a.pixels),"converting to strict remaps to the sprite's colours");
    var _rgb=make_colour_rgb(23,71,193);
    _a.mode=2;ln_sprite_art_put(_a,1,1,_rgb);ln_check(_a.pixels[9]==_rgb,"C64 HiRes keeps any RGB at 1x1");
    _a.mode=3;ln_sprite_art_conform(_a);ln_check(colour_get_blue(_a.pixels[9]) mod 17==0 && ln_sprite_art_pixels_valid(_a,_a.pixels),"Amiga quantizes to 4096 colours");
    _a.mode=4;ln_sprite_art_put(_a,1,1,_rgb);ln_check(_a.pixels[9]==_rgb,"AGA keeps 24bit colour");
    var _m={sprite:"spr_ln3_actor_parts",frame:0,width:4,height:1,mode:4,mc:false,tinted:true,pixels:array_create(4,-1)};
    ln_sprite_art_put(_m,1,0,_rgb);ln_check(_m.pixels[1]==c_white && !ln_sprite_art_pixels_valid({sprite:"spr_ln3_actor_parts",width:4,mode:4,mc:false,tinted:true},[_rgb,-1,-1,-1]),"LN3 layers stay single-colour masks");    ln_check(ln_rewind_equal(ln_sprite_art_decode({width:8,height:2,data:ln_sprite_art_encode(_a.pixels)}),_a.pixels),"frame encoding roundtrips exactly");
    // Editor flow from the viewer: paint, undo, redo, apply.
    _sv.game=1;_sv.category=0;ln_sprite_filter();_sv.animation=0;_sv.frame=0;ln_sprite_art_open();
    ln_check(_v.open && array_length(_v.items)==array_length(_sv.list[0].clips[0].frames),"editor opens on the viewer animation");
    var _p=ln_sprite_art_active(),_name=_p[0],_frame=_p[1],_key=ln_sprite_art_key(_name,_frame),_w=ln_sprite_art_local(_p,0,0)[2];
    var _before=ln_sprite_art_read(_name,_frame),_spot=2*_w+2;ln_check(_before[_spot]==-1,"test pixel starts transparent");
    _v.mode=1;_v.mc=false;var _d=ln_sprite_art_begin(_name,_frame);ln_sprite_art_line(_d,2,2,2,2,_P[7]);
    ln_check(_d.pixels[_spot]==_P[7] && ln_sprite_art_pending()==1,"pencil paints the selected frame");
    ln_sprite_art_history(false);ln_check(variable_struct_get(_v.drafts,_key).pixels[_spot]==-1,"undo restores the frame");
    ln_sprite_art_history(true);ln_check(variable_struct_get(_v.drafts,_key).pixels[_spot]==_P[7],"redo repeats the stroke");
    ln_check(ln_sprite_art_apply() && is_struct(ln_sprite_art_get(_name,_frame)) && _e.enabled,"apply stores the frame in the project");
    var _sync=get_timer();ln_sprite_art_sync();_sync=get_timer()-_sync;
    var _asset=asset_get_index(_name),_backup=variable_struct_get(_e.sprite_backups,_name);
    ln_check(ln_sprite_art_read_index(_asset,_frame)[_spot]==_P[7],"Modified ON draws the edited frame in the game");
    ln_check(ln_sprite_art_read_index(_backup,_frame)[_spot]==-1,"original sprite is preserved");
    ln_check(ln_rewind_equal(ln_sprite_art_read_index(_asset,_frame+1),ln_sprite_art_read_index(_backup,_frame+1)),"unedited frames are unchanged");
    ln_check(sprite_get_number(_asset)==sprite_get_number(_backup) && sprite_get_xoffset(_asset)==sprite_get_xoffset(_backup) && sprite_get_yoffset(_asset)==sprite_get_yoffset(_backup),"edited sprite keeps frame count and origin");
    _e.enabled=false;ln_sprite_art_sync();ln_check(ln_sprite_art_read_index(_asset,_frame)[_spot]==-1,"Modified OFF restores the original sprite");
    _e.enabled=true;ln_sprite_art_sync();ln_check(ln_sprite_art_read_index(_asset,_frame)[_spot]==_P[7],"Modified ON reapplies the edit");
    // Project file.
    var _pack=ln_enemy_copy(ln_edit_pack());ln_check(ln_edit_validate(_pack),"sprite artwork validates in the project pack");
    ln_check(ln_sprite_art_write("sprite-art-test.json") && ln_edit_load("sprite-art-test.json"),"project file saves and loads");
    ln_check(ln_rewind_equal(_pack.sprites,_e.sprite_art) && array_length(variable_struct_get_names(_v.drafts))==0,"loaded project keeps exact sprite frames and clears drafts");
    ln_sprite_art_sync();ln_check(ln_sprite_art_read_index(_asset,_frame)[_spot]==_P[7],"loaded project applies to the game");
    var _bad=ln_enemy_copy(_pack);variable_struct_get(_bad.sprites,_key).data="AAAA";ln_check(!ln_edit_validate(_bad),"corrupt frame data is rejected");
    _bad=ln_enemy_copy(_pack);variable_struct_get(_bad.sprites,_key).frame=100000;ln_check(!ln_edit_validate(_bad),"out-of-range frame is rejected");
    _bad=ln_enemy_copy(_pack);variable_struct_get(_bad.sprites,_key).sprite="spr_not_a_sprite";ln_check(!ln_edit_validate(_bad),"unknown sprite is rejected");
    var _five=ln_sprite_art_read(_name,_frame);for(var _i=0;_i<5;_i++) _five[_i*2]=_P[_i+2];
    _bad=ln_enemy_copy(_pack);var _bf=variable_struct_get(_bad.sprites,_key);_bf.mode=0;_bf.data=ln_sprite_art_encode(_five);ln_check(!ln_edit_validate(_bad),"strict frame with colours outside the sprite's set is rejected");
    // Revert removes the project entry.
    _v.view=0;_d=ln_sprite_art_begin(_name,_frame);_d.pixels=ln_sprite_art_read(_name,_frame);_d.mode=1;_d.mc=false;ln_sprite_art_touch(_d);
    ln_check(ln_sprite_art_apply() && !is_struct(ln_sprite_art_get(_name,_frame)),"reverted frame leaves the project");
    ln_sprite_art_sync();ln_check(ln_sprite_art_read_index(_asset,_frame)[_spot]==-1 && !variable_struct_exists(_e.sprite_assigned,_name),"reverted sprite is restored in the game");
    // LN3 hardware-sprite layer.
    _sv.game=3;_sv.category=0;ln_sprite_filter();ln_sprite_art_open();
    var _q=ln_sprite_art_active(),_ql=ln_sprite_art_local(_q,0,0),_qpix=ln_sprite_art_read(_q[0],_q[1]),_qspot=-1;
    for(var _i=0;_i<array_length(_qpix);_i++) if(_qpix[_i]==-1) {_qspot=_i;break;}
    _d=ln_sprite_art_begin(_q[0],_q[1]);ln_sprite_art_line(_d,_qspot mod _ql[2],_qspot div _ql[2],_qspot mod _ql[2],_qspot div _ql[2],_P[2]);
    ln_check(ln_sprite_art_apply(),"LN3 layer applies");ln_sprite_art_sync();
    ln_check(ln_sprite_art_read_index(asset_get_index(_q[0]),_q[1])[_qspot]==c_white,"LN3 layer mask is switched on in the game bank");
    ln_check(ln_sprite_art_pick((_qspot mod _ql[2])+_q[2]+.5-sprite_get_xoffset(ln_sprite_art_source(_q[0])),(_qspot div _ql[2])+_q[3]+.5-sprite_get_yoffset(ln_sprite_art_source(_q[0]))) && _v.colour==_v.items[_v.index][_v.part][4],"picking an LN3 layer pixel selects that layer and its game colour");
    // Largest sheet rebuild cost.
    _d=ln_sprite_art_begin("spr_ln1_dungeon_uniforms",0);ln_sprite_art_line(_d,1,1,3,1,_P[7]);ln_sprite_art_apply();
    var _big=get_timer();ln_sprite_art_sync();_big=get_timer()-_big;
    ln_check(ln_sprite_art_read_index(asset_get_index("spr_ln1_dungeon_uniforms"),0)[1*96+1]==_P[7],"3121-frame sheet edit reaches the game");
    // Screens.
    _sv.game=1;_sv.category=0;ln_sprite_filter();ln_sprite_art_open();_d=ln_sprite_art_begin(ln_sprite_art_active()[0],ln_sprite_art_active()[1]);
    ln_sprite_art_line(_d,30,20,60,20,_P[7]);_v.onion=true;ln_sprite_art_draw();surface_save(application_surface,"sprite-art-animation.png");
    ln_sprite_art_use_sheet("spr_char_ln1_ninja",12);_v.view=1;ln_sprite_art_draw();surface_save(application_surface,"sprite-art-sheet.png");
    _sv.game=3;ln_sprite_filter();ln_sprite_art_open();ln_sprite_art_draw();surface_save(application_surface,"sprite-art-ln3.png");
    ln_sprite_art_close();
    _e.sprite_art={};_e.sprite_rev++;ln_sprite_art_reset_session();ln_sprite_art_sync();
    ln_check(variable_struct_names_count(_e.sprite_assigned)==0,"clearing the project restores every sprite");
    show_debug_message("LN_SPRITE_ART_PASS: sync "+string(_sync div 1000)+"ms, 3121-frame sheet "+string(_big div 1000)+"ms, total "+string((get_timer()-_t) div 1000)+"ms");
}
