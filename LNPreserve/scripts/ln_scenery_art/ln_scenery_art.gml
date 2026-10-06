/// Scenery-only pixel artwork stored inside the user's scene project.
function LNSceneryArt() constructor {
    open=false;draft=undefined;asset_id=0;tool=0;colour=c_white;undo=[];redo=[];
    stroke=undefined;stroke_button=mb_left;last_x=-1;last_y=-1;surface=-1;dirty=true;message="";
}
function ln_art_key(_game,_level,_id) {return string(_game)+":"+string(_level)+":"+string(_id);}
function ln_art_get(_game,_level,_id) {
    var _e=global.ln_editor,_key=ln_art_key(_game,_level,_id);
    return variable_struct_exists(_e.artworks,_key)?variable_struct_get(_e.artworks,_key):undefined;
}
function ln_art_quantize(_colour,_mode) {
    if(_colour<0) return -1;
    if(_mode<2) {
        var _best=0,_distance=infinity;
        for(var _i=0;_i<16;_i++) {
            var _c=global.ln_paint_palette[_i],_d=sqr(colour_get_red(_c)-colour_get_red(_colour))+sqr(colour_get_green(_c)-colour_get_green(_colour))+sqr(colour_get_blue(_c)-colour_get_blue(_colour));
            if(_d<_distance) {_distance=_d;_best=_c;}
        }
        return _best;
    }
    if(_mode==3) return make_colour_rgb(round(colour_get_red(_colour)/17)*17,round(colour_get_green(_colour)/17)*17,round(colour_get_blue(_colour)/17)*17);
    return _colour;
}
/// Thick swatch frames: white for the hovered colour, yellow for the selected one,
/// each with black edges so they read against any palette colour.
function ln_art_swatch_ring(_x1,_y1,_x2,_y2,_from,_to,_colour) {
    draw_set_colour(_colour);
    for(var _k=_from;_k<=_to;_k++) draw_rectangle(_x1-_k,_y1-_k,_x2+_k,_y2+_k,true);
}
function ln_art_swatch_frame(_x1,_y1,_x2,_y2,_hover,_selected) {
    if(!_hover && !_selected) return;
    ln_art_swatch_ring(_x1,_y1,_x2,_y2,-1,-1,c_black);
    ln_art_swatch_ring(_x1,_y1,_x2,_y2,0,2,_selected?make_colour_rgb(255,220,40):c_white);
    ln_art_swatch_ring(_x1,_y1,_x2,_y2,3,3,c_black);
    if(_hover && _selected) {ln_art_swatch_ring(_x1,_y1,_x2,_y2,4,5,c_white);ln_art_swatch_ring(_x1,_y1,_x2,_y2,6,6,c_black);}
    draw_set_colour(c_white);
}
function ln_art_put(_a,_x,_y,_colour) {
    if(_x<0 || _y<0 || _x>=_a.width || _y>=_a.height) return false;
    var _step=_a.mode<2 && _a.mc?2:1;_x=(_x div _step)*_step;
    _colour=ln_art_quantize(_colour,_a.mode);
    if(_a.mode==0) {
        var _used=_a.mc?[_a.background]:[],_limit=_a.mc?4:2;
        for(var _yy=(_y div 8)*8;_yy<min(_a.height,(_y div 8)*8+8);_yy++)
        for(var _xx=(_x div 8)*8;_xx<min(_a.width,(_x div 8)*8+8);_xx++) {
            var _c=(_yy==_y && _xx>=_x && _xx<_x+_step)?_colour:_a.pixels[_yy*_a.width+_xx];
            if(_c<0) _c=_a.background;
            if(!array_contains(_used,_c)) array_push(_used,_c);
        }
        if(array_length(_used)>_limit) return false;
    }
    for(var _j=0;_j<_step;_j++) _a.pixels[_y*_a.width+_x+_j]=_colour;
    return true;
}
function ln_art_conform(_a) {
    var _old=_a.pixels;_a.pixels=array_create(_a.width*_a.height,-1);
    var _step=_a.mode<2 && _a.mc?2:1;
    _a.background=ln_art_quantize(_a.background,_a.mode);
    for(var _y=0;_y<_a.height;_y++) for(var _x=0;_x<_a.width;_x+=_step) {
        var _c=ln_art_quantize(_old[_y*_a.width+_x],_a.mode);
        if(!ln_art_put(_a,_x,_y,_c)) {
            var _best=_a.background,_dist=infinity;
            for(var _yy=(_y div 8)*8;_yy<min(_a.height,(_y div 8)*8+8);_yy++)
            for(var _xx=(_x div 8)*8;_xx<min(_a.width,(_x div 8)*8+8);_xx++) {
                var _v=_a.pixels[_yy*_a.width+_xx];if(_v<0) _v=_a.background;
                var _d=sqr(colour_get_red(_v)-colour_get_red(_c))+sqr(colour_get_green(_v)-colour_get_green(_c))+sqr(colour_get_blue(_v)-colour_get_blue(_c));
                if(_d<_dist) {_dist=_d;_best=_v;}
            }
            ln_art_put(_a,_x,_y,_best);
        }
    }
}
function ln_art_valid(_art) {
    if(!is_struct(_art)) return false;
    var _keys=variable_struct_get_names(_art),_total=0;if(array_length(_keys)>512) return false;
    for(var _i=0;_i<array_length(_keys);_i++) {
        var _a=variable_struct_get(_art,_keys[_i]);if(!is_struct(_a)) return false;
        var _fields=["game","level","id","width","height","mode","mc","background","pixels"];
        for(var _j=0;_j<array_length(_fields);_j++) if(!variable_struct_exists(_a,_fields[_j])) return false;
        var _ints=[_a.game,_a.level,_a.id,_a.width,_a.height,_a.mode,_a.background];
        for(var _j=0;_j<array_length(_ints);_j++) if(!ln_enemy_number(_ints[_j])) return false;
        if(!array_contains([1,2,3],_a.game) || _a.level<1 || _a.level>(_a.game==1?6:(_a.game==2?7:5)) || _a.id<0 || _a.id>1000000 || _a.mode<0 || _a.mode>4 || !is_bool(_a.mc)) return false;
        if(_a.width<8 || _a.height<8 || _a.width>240 || _a.height>144 || _a.width mod 8!=0 || _a.height mod 8!=0 || _a.background<0 || _a.background>16777215) return false;
        if(_keys[_i]!=ln_art_key(_a.game,_a.level,_a.id) || !is_array(_a.pixels) || array_length(_a.pixels)!=_a.width*_a.height) return false;
        _total+=array_length(_a.pixels);if(_total>1000000) return false;
        var _d=ln_edit_data(_a.game,_a.level);
        if(_a.id<10000) {
            if(!variable_struct_exists(_d.objects,string(_a.id))) return false;
            var _o=variable_struct_get(_d.objects,string(_a.id));if(_o.width!=_a.width || _o.height!=_a.height) return false;
        }
        for(var _j=0;_j<array_length(_a.pixels);_j++) if(!ln_enemy_number(_a.pixels[_j]) || _a.pixels[_j]<-1 || _a.pixels[_j]>16777215 || ln_art_quantize(_a.pixels[_j],_a.mode)!=_a.pixels[_j]) return false;
        if(ln_art_quantize(_a.background,_a.mode)!=_a.background) return false;
        if(_a.mode<2 && _a.mc) for(var _j=0;_j<array_length(_a.pixels);_j+=2) if(_a.pixels[_j]!=_a.pixels[_j+1]) return false;
        if(_a.mode==0) for(var _cy=0;_cy<_a.height;_cy+=8) for(var _cx=0;_cx<_a.width;_cx+=8) {
            var _used=_a.mc?[_a.background]:[];
            for(var _yy=_cy;_yy<_cy+8;_yy++) for(var _xx=_cx;_xx<_cx+8;_xx++) {
                var _c=_a.pixels[_yy*_a.width+_xx];if(_c<0) _c=_a.background;
                if(!array_contains(_used,_c)) array_push(_used,_c);
            }
            if(array_length(_used)>(_a.mc?4:2)) return false;
        }
    }
    return true;
}
function ln_art_refresh() {
    var _e=global.ln_editor,_sets=variable_struct_get_names(_e.datasets);
    for(var _i=0;_i<array_length(_sets);_i++) {
        var _d=variable_struct_get(_e.datasets,_sets[_i]);if(!is_struct(_d) || !variable_struct_exists(_d,"objects")) continue;
        var _ids=variable_struct_get_names(_d.objects);
        for(var _j=0;_j<array_length(_ids);_j++) if(real(_ids[_j])>=10000) variable_struct_remove(_d.objects,_ids[_j]);
    }
    var _keys=variable_struct_get_names(_e.artworks);
    for(var _i=0;_i<array_length(_keys);_i++) {
        var _a=variable_struct_get(_e.artworks,_keys[_i]);if(_a.id<10000) continue;
        var _d=ln_edit_data(_a.game,_a.level),_cells=(_a.width div 8)*(_a.height div 8);
        variable_struct_set(_d.objects,string(_a.id),{width:_a.width,height:_a.height,bitmap:array_create(_cells*8,0),screen:array_create(_cells,0),colour:array_create(_cells,0)});
    }
    var _sprites=variable_struct_get_names(_e.art_sprites);
    for(var _i=0;_i<array_length(_sprites);_i++) {var _s=variable_struct_get(_e.art_sprites,_sprites[_i]);if(sprite_exists(_s)) sprite_delete(_s);}
    _e.art_sprites={};_e.decoded={};_e.revision++;_e.dirty_rect=undefined;ln_edit_free_cache();
}
function ln_art_surface(_a) {
    var _s=surface_create(_a.width,_a.height),_b=buffer_create(_a.width*_a.height*4,buffer_fixed,1);
    for(var _i=0;_i<array_length(_a.pixels);_i++) buffer_poke(_b,_i*4,buffer_u32,_a.pixels[_i]<0?0:(_a.pixels[_i]|$ff000000));
    buffer_set_surface(_b,_s,0);buffer_delete(_b);return _s;
}
function ln_art_thumbnail(_id,_x,_y,_w,_h) {
    var _e=global.ln_editor,_a=ln_art_get(_e.game,_e.level,_id);if(!is_struct(_a)) return false;
    var _key=ln_art_key(_e.game,_e.level,_id);
    if(!variable_struct_exists(_e.art_sprites,_key)) {var _s=ln_art_surface(_a),_sprite=sprite_create_from_surface(_s,0,0,_a.width,_a.height,false,false,0,0);surface_free(_s);variable_struct_set(_e.art_sprites,_key,_sprite);}
    var _sprite=variable_struct_get(_e.art_sprites,_key),_scale=min(_w/_a.width,_h/_a.height);
    draw_sprite_ext(_sprite,0,_x,_y,_scale,_scale,0,c_white,1);return true;
}
function ln_art_open(_id) {
    var _e=global.ln_editor,_v=_e.art,_a=ln_art_get(_e.game,_e.level,_id);
    if(is_struct(_a)) _a=ln_enemy_copy(_a);
    else {
        var _o=variable_struct_get(ln_edit_data(_e.game,_e.level).objects,string(_id));
        var _p={asset:_id,recolour:[]};
        if(_e.part>=0 && _e.scene.parts[_e.part].asset==_id) _p=_e.scene.parts[_e.part];
        var _raw=ln_edit_decode(_e.scene,_p,_o,true),_pixels=[];
        for(var _i=0;_i<array_length(_raw.codes);_i++) array_push(_pixels,_raw.codes[_i]==0?-1:_raw.colours[_i]);
        _a={game:_e.game,level:_e.level,id:_id,width:_o.width,height:_o.height,mode:1,mc:true,background:global.ln_paint_palette[_e.scene.background],pixels:_pixels};
    }
    _v.draft=_a;_v.open=true;_v.asset_id=_id;_v.undo=[];_v.redo=[];_v.stroke=undefined;_v.dirty=true;
    _v.message="Editing a shared asset updates every placement of it. Duplicate for an independent copy.";
}
function ln_art_checkpoint() {
    var _v=global.ln_editor.art;array_push(_v.undo,json_stringify(_v.draft));if(array_length(_v.undo)>40) array_delete(_v.undo,0,1);_v.redo=[];_v.dirty=true;
}
function ln_art_history(_redo) {
    var _v=global.ln_editor.art,_from=_redo?_v.redo:_v.undo;if(array_length(_from)==0) return;
    var _text=array_pop(_from);
    if(_redo) {array_push(_v.undo,json_stringify(_v.draft));_v.redo=_from;}else {array_push(_v.redo,json_stringify(_v.draft));_v.undo=_from;}
    _v.draft=json_parse(_text);_v.dirty=true;
}
function ln_art_new(_duplicate) {
    var _e=global.ln_editor,_v=_e.art;ln_art_checkpoint();
    var _id=10000,_d=ln_edit_data(_e.game,_e.level);while(variable_struct_exists(_d.objects,string(_id)) || is_struct(ln_art_get(_e.game,_e.level,_id))) _id++;
    if(!_duplicate) _v.draft={game:_e.game,level:_e.level,id:_id,width:32,height:32,mode:_v.draft.mode,mc:_v.draft.mc,background:_v.draft.background,pixels:array_create(1024,-1)};
    variable_struct_set(_v.draft,"id",_id);_v.message=_duplicate?"Independent copy. Apply, then add it from the room asset list.":"New transparent scenery asset.";_v.dirty=true;
}
function ln_art_apply() {
    var _e=global.ln_editor,_v=_e.art,_a=ln_enemy_copy(_v.draft),_pack={};variable_struct_set(_pack,ln_art_key(_a.game,_a.level,_a.id),_a);
    if(!ln_art_valid(_pack)) {_v.message="Artwork exceeds project limits or selected colour rules.";return false;}
    var _trial=ln_enemy_copy(_e.artworks);variable_struct_set(_trial,ln_art_key(_a.game,_a.level,_a.id),_a);
    if(!ln_art_valid(_trial)) {_v.message="Project artwork limit reached.";return false;}
    _e.artworks=_trial;ln_art_refresh();_e.enabled=true;_e.dirty=true;_e.reference=false;_e.build=-1;_e.autosave_us=1000000;
    var _ids=variable_struct_get_names(ln_edit_data(_e.game,_e.level).objects);array_sort(_ids,function(a,b){return real(a)-real(b);});
    for(var _i=0;_i<array_length(_ids);_i++) if(real(_ids[_i])==_a.id) {_e.asset=_i;_e.asset_scroll=max(0,_i-17);}
    _v.message="Applied to project. Save file includes this artwork. Modified ON.";return true;
}
function ln_art_fill(_a,_x,_y,_colour) {
    var _old=_a.pixels[_y*_a.width+_x];_colour=ln_art_quantize(_colour,_a.mode);if(_old==_colour) return;
    var _stack=[_y*_a.width+_x],_seen=array_create(array_length(_a.pixels),false);
    while(array_length(_stack)>0) {
        var _at=array_pop(_stack);if(_seen[_at]) continue;_seen[_at]=true;
        if(_a.pixels[_at]!=_old) continue;var _px=_at mod _a.width,_py=_at div _a.width;
        var _step=_a.mode<2 && _a.mc?2:1;
        if(_px>=_step) array_push(_stack,_at-_step);if(_px+_step<_a.width) array_push(_stack,_at+_step);
        if(_py>0) array_push(_stack,_at-_a.width);if(_py+1<_a.height) array_push(_stack,_at+_a.width);
        ln_art_put(_a,_px,_py,_colour);
    }
}
function ln_art_canvas() {
    var _a=global.ln_editor.art.draft,_z=max(1,floor(min(704/_a.width,552/_a.height)));
    return [24+floor((704-_a.width*_z)/2),116+floor((552-_a.height*_z)/2),_z];
}
function ln_art_resize(_dw,_dh) {
    var _v=global.ln_editor.art,_a=_v.draft;if(_a.id<10000) {_v.message="Duplicate first to change canvas size.";return;}
    var _w=clamp(_a.width+_dw,8,240),_h=clamp(_a.height+_dh,8,144);if(_w==_a.width && _h==_a.height) return;
    ln_art_checkpoint();var _pixels=array_create(_w*_h,-1);
    for(var _y=0;_y<min(_h,_a.height);_y++) for(var _x=0;_x<min(_w,_a.width);_x++) _pixels[_y*_w+_x]=_a.pixels[_y*_a.width+_x];
    _a.width=_w;_a.height=_h;_a.pixels=_pixels;
}
function ln_art_step() {
    var _e=global.ln_editor,_v=_e.art,_a=_v.draft;
    if(ln_edit_hit(24,18,170,28)) ln_art_apply();
    if(ln_edit_hit(206,18,170,28) || keyboard_check_pressed(vk_escape)) {_v.open=false;if(surface_exists(_v.surface)) surface_free(_v.surface);_v.surface=-1;return true;}
    if(ln_edit_hit(388,18,130,28)) ln_art_new(false);
    if(ln_edit_hit(530,18,130,28)) ln_art_new(true);
    if(ln_edit_hit(672,18,130,28) || (keyboard_check(vk_control) && keyboard_check_pressed(ord("Z")))) ln_art_history(false);
    if(ln_edit_hit(814,18,130,28) || (keyboard_check(vk_control) && keyboard_check_pressed(ord("Y")))) ln_art_history(true);
    _a=_v.draft;
    for(var _i=0;_i<5;_i++) if(ln_edit_hit(760,82+_i*36,490,28) && _a.mode!=_i) {ln_art_checkpoint();_a.mode=_i;if(_i>=2) _a.mc=false;ln_art_conform(_a);_v.message="Palette/pixel conversion can be undone with Ctrl+Z.";}
    if(_a.mode<2 && ln_edit_hit(760,270,230,28)) {ln_art_checkpoint();_a.mc=!_a.mc;ln_art_conform(_a);}
    for(var _i=0;_i<4;_i++) if(ln_edit_hit(760+_i*124,314,116,28)) _v.tool=_i;
    for(var _i=0;_i<16;_i++) if(ln_edit_hit(760+(_i mod 8)*58,358+(_i div 8)*38,52,32)) _v.colour=global.ln_paint_palette[_i];
    for(var _i=0;_i<3;_i++) if(mouse_check_button(mb_left) && ln_edit_inside(802,458+_i*38,430,24)) {
        var _rgb=[colour_get_red(_v.colour),colour_get_green(_v.colour),colour_get_blue(_v.colour)];_rgb[_i]=round(clamp((ln_tool_mouse_x()-802)/430,0,1)*255);
        _v.colour=ln_art_quantize(make_colour_rgb(_rgb[0],_rgb[1],_rgb[2]),_a.mode);
    }
    if(ln_edit_hit(760,580,230,28)) {
        ln_art_checkpoint();var _old=_a.pixels;_a.pixels=array_create(_a.width*_a.height,-1);
        for(var _y=0;_y<_a.height;_y++) for(var _x=0;_x<_a.width;_x++) _a.pixels[_y*_a.width+_x]=_old[_y*_a.width+_a.width-1-_x];
    }
    if(ln_edit_hit(1002,580,230,28)) {
        ln_art_checkpoint();var _old=_a.pixels;_a.pixels=array_create(_a.width*_a.height,-1);
        for(var _y=0;_y<_a.height;_y++) for(var _x=0;_x<_a.width;_x++) _a.pixels[_y*_a.width+_x]=_old[(_a.height-1-_y)*_a.width+_x];
    }
    var _n=ln_edit_value_repeat(760,624,40,28);if(_n) ln_art_resize(-8*_n,0);
    _n=ln_edit_value_repeat(952,624,40,28);if(_n) ln_art_resize(8*_n,0);
    _n=ln_edit_value_repeat(1002,624,40,28);if(_n) ln_art_resize(0,-8*_n);
    _n=ln_edit_value_repeat(1192,624,40,28);if(_n) ln_art_resize(0,8*_n);
    var _r=ln_art_canvas(),_x=floor((ln_tool_mouse_x()-_r[0])/_r[2]),_y=floor((ln_tool_mouse_y()-_r[1])/_r[2]);
    var _inside=_x>=0 && _y>=0 && _x<_a.width && _y<_a.height;
    if(mouse_check_button_pressed(mb_left) && _inside) {
        if(_v.tool==3 || keyboard_check(vk_alt)) {var _c=_a.pixels[_y*_a.width+_x];if(_c>=0) _v.colour=_c;return true;}
        ln_art_checkpoint();_v.stroke=true;_v.stroke_button=mb_left;_v.last_x=_x;_v.last_y=_y;
        if(_v.tool==2) {ln_art_fill(_a,_x,_y,_v.colour);_v.stroke=undefined;}
    }
    // Right mouse button erases with any tool.
    if(mouse_check_button_pressed(mb_right) && _inside && is_undefined(_v.stroke)) {ln_art_checkpoint();_v.stroke=true;_v.stroke_button=mb_right;_v.last_x=_x;_v.last_y=_y;}
    if(mouse_check_button(_v.stroke_button) && _inside && !is_undefined(_v.stroke)) {
        var _steps=max(1,max(abs(_x-_v.last_x),abs(_y-_v.last_y))),_ok=true,_erase=_v.stroke_button==mb_right || _v.tool==1;
        for(var _i=0;_i<=_steps;_i++) _ok=ln_art_put(_a,round(lerp(_v.last_x,_x,_i/_steps)),round(lerp(_v.last_y,_y,_i/_steps)),_erase?-1:_v.colour) && _ok;
        _v.last_x=_x;_v.last_y=_y;_v.dirty=true;
        if(!_ok) _v.message="C64 Strict: this cell already uses its allowed colours.";
    }
    if(!mouse_check_button(_v.stroke_button)) _v.stroke=undefined;
    return true;
}
function ln_art_draw() {
    var _v=global.ln_editor.art,_a=_v.draft;ln_tool_clear(false);draw_set_font(font_jansina);draw_set_halign(fa_left);draw_set_valign(fa_top);draw_set_colour(c_white);
    ln_edit_button(24,18,170,"Apply to project");ln_edit_button(206,18,170,"Back to room");ln_edit_button(388,18,130,"New asset");ln_edit_button(530,18,130,"Duplicate");ln_edit_button(672,18,130,"Undo (^Z)");ln_edit_button(814,18,130,"Redo (^Y)");
    draw_text(24,70,"SCENERY ART / Ninja "+string(_a.game)+" / Level "+string(_a.level)+" / Asset "+string(_a.id));
    var _names=["C64 Strict","C64 Loose","C64 HiRes - any colour","16bit AMIGA - 4096 colours","32bit AMIGA AGA - 24bit colour"];
    for(var _i=0;_i<5;_i++) ln_edit_button(760,82+_i*36,490,_names[_i],_a.mode==_i);
    if(_a.mode<2) ln_edit_button(760,270,230,_a.mc?"Multicolour (2x1)":"Hi-res (1x1)");
    else {draw_set_colour(c_white);draw_text(760,274,"1x1 pixels");}
    var _tools=["Pencil","Eraser","Fill","Pick colour"];
    for(var _i=0;_i<4;_i++) ln_edit_button(760+_i*124,314,116,_tools[_i],_v.tool==_i);
    for(var _i=0;_i<16;_i++) {draw_set_colour(global.ln_paint_palette[_i]);draw_rectangle(760+(_i mod 8)*58,358+(_i div 8)*38,812+(_i mod 8)*58,390+(_i div 8)*38,false);}
    var _shown=ln_art_quantize(_v.colour,_a.mode);
    for(var _i=0;_i<16;_i++) {var _sx=760+(_i mod 8)*58,_sy=358+(_i div 8)*38;ln_art_swatch_frame(_sx,_sy,_sx+52,_sy+32,ln_edit_inside(_sx,_sy,52,32),global.ln_paint_palette[_i]==_shown);}
    draw_set_colour(ln_art_quantize(_v.colour,_a.mode));draw_rectangle(760,436,790,562,false);
    var _rgb=[colour_get_red(_v.colour),colour_get_green(_v.colour),colour_get_blue(_v.colour)],_labels=["R","G","B"];
    for(var _i=0;_i<3;_i++) {
        draw_set_colour(c_white);draw_text(802,438+_i*38,_labels[_i]+" "+string(_rgb[_i]));
        draw_set_colour(make_colour_rgb(75,80,85));draw_rectangle(802,470+_i*38,1232,474+_i*38,false);
        draw_set_colour(c_white);draw_circle(802+430*_rgb[_i]/255,472+_i*38,5,false);
    }
    ln_edit_button(760,580,230,"Flip horizontal");ln_edit_button(1002,580,230,"Flip vertical");
    ln_edit_button(760,624,40,"-");ln_edit_button(952,624,40,"+");ln_edit_button(1002,624,40,"-");ln_edit_button(1192,624,40,"+");
    draw_set_colour(c_white);draw_text(814,630,"Width "+string(_a.width));draw_text(1054,630,"Height "+string(_a.height));
    draw_text(760,664,_a.id<10000?"Duplicate to resize an original asset.":"New/copy canvas: 8-pixel size steps.");
    var _r=ln_art_canvas(),_w=_a.width*_r[2],_h=_a.height*_r[2];
    for(var _y=0;_y<_h;_y+=16) for(var _x=0;_x<_w;_x+=16) {draw_set_colour(((_x div 16+_y div 16) mod 2)==0?make_colour_rgb(40,42,46):make_colour_rgb(60,62,66));draw_rectangle(_r[0]+_x,_r[1]+_y,_r[0]+min(_w,_x+16),_r[1]+min(_h,_y+16),false);}
    if(_v.dirty || !surface_exists(_v.surface)) {if(surface_exists(_v.surface)) surface_free(_v.surface);_v.surface=ln_art_surface(_a);_v.dirty=false;}
    draw_set_colour(c_white);draw_surface_stretched(_v.surface,_r[0],_r[1],_w,_h);
    if(_r[2]>=6) {draw_set_alpha(.22);draw_set_colour(c_white);for(var _x=0;_x<=_a.width;_x+=(_a.mode<2 && _a.mc?2:1)) draw_line(_r[0]+_x*_r[2],_r[1],_r[0]+_x*_r[2],_r[1]+_h);for(var _y=0;_y<=_a.height;_y++) draw_line(_r[0],_r[1]+_y*_r[2],_r[0]+_w,_r[1]+_y*_r[2]);draw_set_alpha(1);}
    draw_set_colour(c_white);draw_text(24,704,"Right-drag: erase.  Alt-click: pick colour. Transparent pixels show the checkerboard.");
    draw_text(24,730,"Apply keeps artwork in this project. Back discards unapplied changes. Save file stores applied artwork.");
    draw_set_colour(make_colour_rgb(150,210,220));draw_text(24,764,_v.message);
}
function ln_art_level_has(_game,_level) {
    var _keys=variable_struct_get_names(global.ln_editor.artworks);
    for(var _i=0;_i<array_length(_keys);_i++) {var _a=variable_struct_get(global.ln_editor.artworks,_keys[_i]);if(_a.game==_game && _a.level==_level) return true;}
    return false;
}
function ln_art_checks() {
    var _e=global.ln_editor,_saved=ln_enemy_copy(ln_edit_pack());
    var _a={game:1,level:1,id:10000,width:8,height:8,mode:0,mc:true,background:global.ln_paint_palette[0],pixels:array_create(64,-1)};
    ln_check(ln_art_put(_a,1,0,global.ln_paint_palette[1]) && _a.pixels[0]==_a.pixels[1],"MC paints aligned two-pixel pairs");
    ln_check(ln_art_put(_a,2,0,global.ln_paint_palette[2]) && ln_art_put(_a,4,0,global.ln_paint_palette[3]),"strict MC allows three foreground colours");
    ln_check(!ln_art_put(_a,6,0,global.ln_paint_palette[4]),"strict MC rejects fourth foreground colour");
    _a.mode=1;ln_check(ln_art_put(_a,6,0,global.ln_paint_palette[4]),"loose C64 removes cell colour limit");
    _a.mode=0;_a.mc=false;_a.pixels=array_create(64,-1);
    ln_check(ln_art_put(_a,0,0,global.ln_paint_palette[1]) && !ln_art_put(_a,1,0,global.ln_paint_palette[2]),"strict HR counts visible background in cell budget");
    _a.mode=2;var _rgb=make_colour_rgb(23,71,193);ln_check(ln_art_put(_a,1,0,_rgb) && _a.pixels[1]==_rgb,"C64 HiRes allows arbitrary RGB single pixels");
    _a.mode=3;ln_art_conform(_a);ln_check(colour_get_red(_a.pixels[1]) mod 17==0 && colour_get_green(_a.pixels[1]) mod 17==0 && colour_get_blue(_a.pixels[1]) mod 17==0,"Amiga quantizes every channel to 4 bits");
    _a.mode=4;ln_art_put(_a,1,0,_rgb);ln_check(_a.pixels[1]==_rgb,"AGA keeps full 24bit colour");
    for(var _game=1;_game<=3;_game++) {
        _e.scenes={};_e.scene=undefined;_e.artworks={};ln_art_refresh();ln_edit_select(_game,1,ln_edit_rooms(_game,1)[0]);
        var _part=_e.scene.parts[array_length(_e.scene.parts)-1];ln_art_open(_part.asset);
        _e.art.draft.mode=4;_e.art.draft.mc=false;_e.art.draft.pixels[0]=_rgb;
        ln_check(ln_art_apply(),"existing scenery artwork applies in LN"+string(_game));
        var _o=variable_struct_get(ln_edit_data(_game,1).objects,string(_part.asset));
        var _decoded=ln_edit_decode(_e.scene,_part,_o);
        ln_check(_decoded.colours[0]==_rgb && _decoded.codes[0]==1,"room decoder uses custom RGB");
        var _source=ln_edit_decode(_e.scene,_part,_o,true);ln_check(_source.colours[0]!=_rgb,"source decoder stays original");
        ln_art_new(false);_e.art.draft.mode=4;_e.art.draft.mc=false;_e.art.draft.pixels[0]=_rgb;
        ln_check(ln_art_apply(),"new scenery registers in asset list");
        ln_edit_add_asset(_e.art.draft.id);var _last=_e.scene.parts[array_length(_e.scene.parts)-1];_last.x=100;_last.y=80;
        var _under=ln_edit_build(_e.scene,array_length(_e.scene.parts)-1,"preview").colours[80*240+101];ln_edit_free_cache();
        var _c=ln_edit_build(_e.scene,-1,"preview");ln_check(_c.colours[80*240+100]==_rgb,"new opaque pixel composites over original room");
        ln_check(_c.colours[80*240+101]==_under,"new transparent pixels retain the room underneath");
        variable_struct_set(_e.scenes,ln_edit_key(_game,1,_e.room_id),ln_enemy_copy(_e.scene));
        var _pack=ln_enemy_copy(ln_edit_pack());ln_check(ln_edit_validate(_pack),"artwork and new asset references validate together");
        ln_check(ln_edit_save("scenery-art-test.json") && ln_edit_load("scenery-art-test.json"),"artwork survives project file roundtrip");
        ln_check(ln_rewind_equal(_pack.artworks,_e.artworks),"project retains exact artwork colours and alpha");
        var _bad=ln_enemy_copy(_pack),_keys=variable_struct_get_names(_bad.artworks);variable_struct_get(_bad.artworks,_keys[0]).pixels[0]=16777216;
        ln_check(!ln_edit_validate(_bad),"out-of-range artwork is rejected");
    }
    _e.art.open=true;_e.open=true;ln_art_draw();surface_save(application_surface,"scenery-art-editor.png");
    _e.art.open=false;_e.artworks=_saved.artworks;_e.scenes=_saved.scenes;_e.maps=_saved.maps;ln_art_refresh();
    show_debug_message("LN_SCENERY_ART_PASS: palette restrictions, MC pixels, source isolation, new assets, RGB composition, project roundtrip");
}
