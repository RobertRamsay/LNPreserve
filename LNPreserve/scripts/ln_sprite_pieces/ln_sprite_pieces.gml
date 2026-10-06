/// LN1 characters are built like the original: each pose is three hi-res 24x21 body pieces
/// plus a weapon piece, mirrored in code. The editor edits those pieces ("ln1_pieces", a
/// dynamic sprite of white masks) and rebuilds every frame that uses them. Frames the
/// recipes do not rebuild exactly stay whole-frame editable.
function ln_pieces_data() {
    var _v=global.ln_sprites.art;
    if(is_struct(_v.pieces)) return _v.pieces;
    var _raw=ln3_data_read("actors/ln1/pieces.json"),_n=array_length(_raw.pieces);
    var _uses=array_create(_n,0),_by_piece=array_create(_n,undefined),_keys=variable_struct_get_names(_raw.targets);
    for(var _i=0;_i<_n;_i++) _by_piece[_i]=[];
    for(var _i=0;_i<array_length(_keys);_i++) {
        var _slots=variable_struct_get(_raw.targets,_keys[_i]),_seen=[];
        for(var _j=0;_j<array_length(_slots);_j++) {
            var _p=_slots[_j][0];if(array_contains(_seen,_p)) continue;
            array_push(_seen,_p);_uses[_p]++;array_push(_by_piece[_p],_keys[_i]);
        }
    }
    _v.pieces={raw:_raw.pieces,targets:_raw.targets,uses:_uses,by_piece:_by_piece};
    ln_pieces_sprite();return _v.pieces;
}
/// The original piece masks as a sprite the editor can draw, read and tint.
function ln_pieces_sprite() {
    var _e=global.ln_editor;
    if(variable_struct_exists(_e.sprite_backups,"ln1_pieces")) return variable_struct_get(_e.sprite_backups,"ln1_pieces");
    var _list=global.ln_sprites.art.pieces.raw,_surface=surface_create(24,21),_b=buffer_create(24*21*4,buffer_fixed,1),_sprite=-1;
    for(var _i=0;_i<array_length(_list);_i++) {
        var _hex=_list[_i].bits;
        for(var _y=0;_y<21;_y++) for(var _x=0;_x<24;_x++) {
            var _at=(_y*3+(_x div 8))*2+1,_byte=(string_pos(string_char_at(_hex,_at),"0123456789abcdef")-1)*16+string_pos(string_char_at(_hex,_at+1),"0123456789abcdef")-1;
            buffer_poke(_b,(_y*24+_x)*4,buffer_u32,((_byte>>(7-(_x mod 8)))&1)?$ffffffff:0);
        }
        buffer_set_surface(_b,_surface,0);
        if(_sprite==-1) _sprite=sprite_create_from_surface(_surface,0,0,24,21,false,false,0,0);
        else sprite_add_from_surface(_sprite,_surface,0,0,24,21,false,false);
    }
    buffer_delete(_b);surface_free(_surface);
    variable_struct_set(_e.sprite_backups,"ln1_pieces",_sprite);return _sprite;
}
function ln_pieces_target(_name,_frame) {
    var _d=ln_pieces_data(),_key=ln_sprite_art_key(_name,_frame);
    return variable_struct_exists(_d.targets,_key)?variable_struct_get(_d.targets,_key):undefined;
}
/// A frame edited as a whole frame keeps that artwork instead of its pieces.
function ln_pieces_locked(_name,_frame) {
    var _a=ln_sprite_art_get(_name,_frame);
    return is_struct(_a) && !variable_struct_exists(_a,"pieces");
}
/// Replaces whole LN1 character frames in an item with their pieces, in draw order.
function ln_pieces_expand(_parts) {
    if(!global.ln_sprites.art.pieces_mode) return _parts;
    var _out=[];
    for(var _i=0;_i<array_length(_parts);_i++) {
        var _p=_parts[_i],_slots=ln_pieces_target(_p[0],_p[1]);
        if(!is_array(_slots) || ln_pieces_locked(_p[0],_p[1])) {array_push(_out,_p);continue;}
        for(var _j=0;_j<array_length(_slots);_j++) {
            var _s=_slots[_j],_ex=_s[4],_ey=_s[5];
            array_push(_out,["ln1_pieces",_s[0],_p[2]+_s[1]-48+(_s[3]?24*_ex:0),_p[3]+_s[2]-64,global.ln_paint_palette[_s[6]],_s[3]?-_ex:_ex,_ey]);
        }
    }
    return _out;
}
function ln_pieces_edited(_piece) {return variable_struct_exists(global.ln_editor.sprite_art,ln_sprite_art_key("ln1_pieces",_piece));}
/// Frame pixels from the current pieces (edited or original).
function ln_pieces_compose(_slots,_cache) {
    var _pixels=array_create(96*96,-1);
    for(var _j=0;_j<array_length(_slots);_j++) {
        var _s=_slots[_j],_key=string(_s[0]);
        if(!variable_struct_exists(_cache,_key)) variable_struct_set(_cache,_key,ln_sprite_art_pixels("ln1_pieces",_s[0]));
        var _mask=variable_struct_get(_cache,_key),_x0=_s[1],_y0=_s[2],_flip=_s[3],_ex=_s[4],_ey=_s[5],_colour=global.ln_paint_palette[_s[6]];
        for(var _py=0;_py<21;_py++) for(var _px=0;_px<24;_px++) {
            if(_mask[_py*24+_px]<0) continue;
            for(var _c=0;_c<_ex;_c++) {
                var _col=_px*_ex+_c;if(_flip) _col=24*_ex-1-_col;
                var _x=_x0+_col;if(_x<0 || _x>=96) continue;
                for(var _r=0;_r<_ey;_r++) {var _y=_y0+_py*_ey+_r;if(_y>=0 && _y<96) _pixels[_y*96+_x]=_colour;}
            }
        }
    }
    return _pixels;
}
/// Rebuilds every frame that uses a changed piece and stores it in the project.
/// Runs when the editor closes, before saving, and after loading a project.
function ln_pieces_rebuild() {
    var _v=global.ln_sprites.art,_e=global.ln_editor;
    if(array_length(_v.pieces_dirty)==0) return 0;
    var _d=ln_pieces_data(),_todo={},_cache={},_count=0;
    for(var _i=0;_i<array_length(_v.pieces_dirty);_i++) {
        var _list=_d.by_piece[_v.pieces_dirty[_i]];
        for(var _j=0;_j<array_length(_list);_j++) variable_struct_set(_todo,_list[_j],true);
    }
    _v.pieces_dirty=[];
    var _keys=variable_struct_get_names(_todo);
    for(var _i=0;_i<array_length(_keys);_i++) {
        var _key=_keys[_i],_cut=string_last_pos(":",_key),_name=string_copy(_key,1,_cut-1),_frame=real(string_delete(_key,1,_cut));
        if(ln_pieces_locked(_name,_frame)) continue;
        var _slots=variable_struct_get(_d.targets,_key),_edited=false;
        for(var _j=0;_j<array_length(_slots);_j++) if(ln_pieces_edited(_slots[_j][0])) {_edited=true;break;}
        if(variable_struct_exists(_v.drafts,_key)) variable_struct_remove(_v.drafts,_key);
        if(!_edited) {if(variable_struct_exists(_e.sprite_art,_key)) {variable_struct_remove(_e.sprite_art,_key);_count++;} continue;}
        variable_struct_set(_e.sprite_art,_key,{sprite:_name,frame:_frame,width:96,height:96,mode:1,mc:false,pieces:true,
            data:ln_sprite_art_encode(ln_pieces_compose(_slots,_cache))});
        _count++;
    }
    if(_count>0) {_e.sprite_rev++;_e.enabled=true;_e.dirty=true;}
    return _count;
}
/// After loading a project every stored piece is rebuilt into its frames.
function ln_pieces_rebuild_all() {
    var _v=global.ln_sprites.art,_names=variable_struct_get_names(global.ln_editor.sprite_art);
    for(var _i=0;_i<array_length(_names);_i++) {
        var _a=variable_struct_get(global.ln_editor.sprite_art,_names[_i]);
        if(_a.sprite=="ln1_pieces" && !array_contains(_v.pieces_dirty,_a.frame)) array_push(_v.pieces_dirty,_a.frame);
    }
    return ln_pieces_rebuild();
}
