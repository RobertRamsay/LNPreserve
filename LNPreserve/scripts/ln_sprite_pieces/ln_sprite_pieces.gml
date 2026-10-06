/// All three games build actors from original 24x21 hardware sprites, mirrored in code.
/// LN1/LN2 frames are composed from body and weapon pieces; LN3 stores each piece as
/// several masks (hi-res, multicolour, mirrored) in spr_ln3_actor_parts. The editor edits
/// the pieces (dynamic sprites of white masks) and rebuilds every frame derived from them.
/// Frames the data does not reproduce exactly stay whole-frame editable.
function ln_pieces_sets() {return ["ln1_pieces","ln2_pieces","ln3_pieces"];}
function ln_pieces_is_set(_name) {return _name=="ln1_pieces" || _name=="ln2_pieces" || _name=="ln3_pieces";}
function ln_pieces_label(_name) {return _name=="ln1_pieces"?"LN1 piece":(_name=="ln2_pieces"?"LN2 piece":(_name=="ln3_pieces"?"LN3 piece":_name));}
/// Slot: [piece, x, y, flip, expand_x, expand_y, colour], back to front, in 96x96 frame pixels.
function ln_pieces_data() {
    var _v=global.ln_sprites.art;
    if(is_struct(_v.pieces)) return _v.pieces;
    var _sets={},_targets={},_target_set={},_names=ln_pieces_sets();
    for(var _s=0;_s<array_length(_names);_s++) {
        var _raw=ln3_data_read("actors/"+string_copy(_names[_s],1,3)+"/pieces.json"),_n=array_length(_raw.pieces);
        if(_names[_s]=="ln3_pieces") {
            // LN3: stored mask frame -> [piece, role, flip]; role -1 hi-res, 0..2 multicolour codes 1..3.
            var _uses=array_create(_n,0),_by_piece=array_create(_n,undefined),_fk=variable_struct_get_names(_raw.frames);
            for(var _i=0;_i<_n;_i++) _by_piece[_i]=[];
            for(var _i=0;_i<array_length(_fk);_i++) {
                var _m=variable_struct_get(_raw.frames,_fk[_i]),_key="spr_ln3_actor_parts:"+_fk[_i];
                variable_struct_set(_targets,_key,_m);variable_struct_set(_target_set,_key,"ln3_pieces");
                _uses[_m[0]]++;array_push(_by_piece[_m[0]],_key);
            }
            variable_struct_set(_sets,"ln3_pieces",{raw:_raw.pieces,uses:_uses,by_piece:_by_piece});continue;
        }
        var _uses=array_create(_n,0),_by_piece=array_create(_n,undefined),_keys=variable_struct_get_names(_raw.targets);
        for(var _i=0;_i<_n;_i++) _by_piece[_i]=[];
        for(var _i=0;_i<array_length(_keys);_i++) {
            var _slots=variable_struct_get(_raw.targets,_keys[_i]),_seen=[];
            variable_struct_set(_targets,_keys[_i],_slots);variable_struct_set(_target_set,_keys[_i],_names[_s]);
            for(var _j=0;_j<array_length(_slots);_j++) {
                var _p=_slots[_j][0];if(array_contains(_seen,_p)) continue;
                array_push(_seen,_p);_uses[_p]++;array_push(_by_piece[_p],_keys[_i]);
            }
        }
        variable_struct_set(_sets,_names[_s],{raw:_raw.pieces,uses:_uses,by_piece:_by_piece});
    }
    _v.pieces={sets:_sets,targets:_targets,target_set:_target_set};
    for(var _s=0;_s<array_length(_names);_s++) ln_pieces_sprite(_names[_s]);
    return _v.pieces;
}
function ln_pieces_set(_name) {return variable_struct_get(ln_pieces_data().sets,_name);}
/// The original piece masks as a sprite the editor can draw, read and tint.
function ln_pieces_sprite(_name) {
    var _e=global.ln_editor;
    if(variable_struct_exists(_e.sprite_backups,_name)) return variable_struct_get(_e.sprite_backups,_name);
    var _list=variable_struct_get(global.ln_sprites.art.pieces.sets,_name).raw,_surface=surface_create(24,21),_b=buffer_create(24*21*4,buffer_fixed,1),_sprite=-1;
    if(_name=="ln3_pieces") {
        // Each LN3 piece is its stored unmirrored hi-res mask.
        for(var _i=0;_i<array_length(_list);_i++) {
            var _px=ln_sprite_art_read("spr_ln3_actor_parts",_list[_i].base);
            for(var _j=0;_j<504;_j++) buffer_poke(_b,_j*4,buffer_u32,_px[_j]>=0?$ffffffff:0);
            buffer_set_surface(_b,_surface,0);
            if(_sprite==-1) _sprite=sprite_create_from_surface(_surface,0,0,24,21,false,false,0,0);
            else sprite_add_from_surface(_sprite,_surface,0,0,24,21,false,false);
        }
        buffer_delete(_b);surface_free(_surface);
        variable_struct_set(_e.sprite_backups,_name,_sprite);return _sprite;
    }
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
    variable_struct_set(_e.sprite_backups,_name,_sprite);return _sprite;
}
function ln_pieces_target(_name,_frame) {
    var _d=ln_pieces_data(),_key=ln_sprite_art_key(_name,_frame);
    return variable_struct_exists(_d.targets,_key)?variable_struct_get(_d.targets,_key):undefined;
}
function ln_pieces_target_set(_name,_frame) {
    var _d=ln_pieces_data(),_key=ln_sprite_art_key(_name,_frame);
    return variable_struct_exists(_d.target_set,_key)?variable_struct_get(_d.target_set,_key):"";
}
/// A frame edited as a whole frame keeps that artwork instead of its pieces.
function ln_pieces_locked(_name,_frame) {
    var _a=ln_sprite_art_get(_name,_frame);
    return is_struct(_a) && !variable_struct_exists(_a,"pieces");
}
/// Replaces whole character frames in an item with their pieces, in draw order.
function ln_pieces_expand(_parts) {
    if(!global.ln_sprites.art.pieces_mode) return _parts;
    var _out=[];
    for(var _i=0;_i<array_length(_parts);_i++) {
        var _p=_parts[_i],_slots=ln_pieces_target(_p[0],_p[1]);
        if(!is_array(_slots) || ln_pieces_locked(_p[0],_p[1])) {array_push(_out,_p);continue;}
        var _set=ln_pieces_target_set(_p[0],_p[1]);
        if(_set=="ln3_pieces") {
            if(_slots[1]!=-1) {array_push(_out,_p);continue;} // rare multicolour masks stay whole frames
            var _sx=array_length(_p)>5?_p[5]:1;
            array_push(_out,["ln3_pieces",_slots[0],_p[2]+(_slots[2]?24*_sx:0),_p[3],_p[4],_slots[2]?-_sx:_sx,array_length(_p)>6?_p[6]:1]);continue;
        }
        for(var _j=0;_j<array_length(_slots);_j++) {
            var _s=_slots[_j],_ex=_s[4],_ey=_s[5];
            array_push(_out,[_set,_s[0],_p[2]+_s[1]-48+(_s[3]?24*_ex:0),_p[3]+_s[2]-64,global.ln_paint_palette[_s[6]],_s[3]?-_ex:_ex,_ey]);
        }
    }
    return _out;
}
function ln_pieces_edited(_set,_piece) {return variable_struct_exists(global.ln_editor.sprite_art,ln_sprite_art_key(_set,_piece));}
/// Frame pixels from the current pieces (edited or original).
function ln_pieces_compose(_set,_slots,_cache) {
    var _pixels=array_create(96*96,-1);
    for(var _j=0;_j<array_length(_slots);_j++) {
        var _s=_slots[_j],_key=string(_s[0]);
        if(!variable_struct_exists(_cache,_key)) variable_struct_set(_cache,_key,ln_sprite_art_pixels(_set,_s[0]));
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
/// LN3 stored mask from its piece: optional bit reversal (mirror), then hi-res or one multicolour code.
function ln_pieces_derive(_bits,_role,_flip) {
    var _out=array_create(504,-1);
    for(var _y=0;_y<21;_y++) for(var _x=0;_x<24;_x++) {
        var _sx=_flip?23-_x:_x;
        if(_role<0) {if(_bits[_y*24+_sx]>=0) _out[_y*24+_x]=c_white;continue;}
        var _pair=_x div 2,_a=_flip?23-_pair*2:_pair*2,_b=_flip?22-_pair*2:_pair*2+1;
        var _code=(_bits[_y*24+_a]>=0?2:0)+(_bits[_y*24+_b]>=0?1:0);
        if(_code==_role+1) _out[_y*24+_x]=c_white;
    }
    return _out;
}
/// Marks an edited piece ("set:piece") so its frames are rebuilt.
function ln_pieces_mark(_set,_piece) {
    var _v=global.ln_sprites.art,_key=ln_sprite_art_key(_set,_piece);
    if(!array_contains(_v.pieces_dirty,_key)) array_push(_v.pieces_dirty,_key);
}
/// Rebuilds every frame that uses a changed piece and stores it in the project.
/// Runs when the editor closes, before saving, and after loading a project.
function ln_pieces_rebuild() {
    var _v=global.ln_sprites.art,_e=global.ln_editor;
    if(array_length(_v.pieces_dirty)==0) return 0;
    var _d=ln_pieces_data(),_todo={},_caches={},_count=0;
    for(var _i=0;_i<array_length(_v.pieces_dirty);_i++) {
        var _mark=_v.pieces_dirty[_i],_cut=string_last_pos(":",_mark);
        var _list=variable_struct_get(_d.sets,string_copy(_mark,1,_cut-1)).by_piece[real(string_delete(_mark,1,_cut))];
        for(var _j=0;_j<array_length(_list);_j++) variable_struct_set(_todo,_list[_j],true);
    }
    _v.pieces_dirty=[];
    var _keys=variable_struct_get_names(_todo);
    for(var _i=0;_i<array_length(_keys);_i++) {
        var _key=_keys[_i],_cut=string_last_pos(":",_key),_name=string_copy(_key,1,_cut-1),_frame=real(string_delete(_key,1,_cut));
        if(ln_pieces_locked(_name,_frame)) continue;
        var _slots=variable_struct_get(_d.targets,_key),_set=variable_struct_get(_d.target_set,_key),_edited=false;
        if(_set=="ln3_pieces") _edited=ln_pieces_edited(_set,_slots[0]);
        else for(var _j=0;_j<array_length(_slots);_j++) if(ln_pieces_edited(_set,_slots[_j][0])) {_edited=true;break;}
        if(variable_struct_exists(_v.drafts,_key)) variable_struct_remove(_v.drafts,_key);
        if(!_edited) {if(variable_struct_exists(_e.sprite_art,_key)) {variable_struct_remove(_e.sprite_art,_key);_count++;} continue;}
        if(!variable_struct_exists(_caches,_set)) variable_struct_set(_caches,_set,{});
        if(_set=="ln3_pieces") {
            variable_struct_set(_e.sprite_art,_key,{sprite:_name,frame:_frame,width:24,height:21,mode:1,mc:false,pieces:true,
                data:ln_sprite_art_encode(ln_pieces_derive(ln_sprite_art_pixels("ln3_pieces",_slots[0]),_slots[1],_slots[2]))});
            _count++;continue;
        }
        variable_struct_set(_e.sprite_art,_key,{sprite:_name,frame:_frame,width:96,height:96,mode:1,mc:false,pieces:true,
            data:ln_sprite_art_encode(ln_pieces_compose(_set,_slots,variable_struct_get(_caches,_set)))});
        _count++;
    }
    if(_count>0) {_e.sprite_rev++;_e.enabled=true;_e.dirty=true;}
    return _count;
}
/// After loading a project every stored piece is rebuilt into its frames.
function ln_pieces_rebuild_all() {
    var _names=variable_struct_get_names(global.ln_editor.sprite_art);
    for(var _i=0;_i<array_length(_names);_i++) {
        var _a=variable_struct_get(global.ln_editor.sprite_art,_names[_i]);
        if(ln_pieces_is_set(_a.sprite)) ln_pieces_mark(_a.sprite,_a.frame);
    }
    return ln_pieces_rebuild();
}
