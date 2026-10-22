/// Red/blue (anaglyph) 3D. Presentation only: each game draws its 240x144 stage as
/// before, a matching depth buffer is built alongside it, and the stage is
/// re-projected for each eye when it is scaled onto the screen. CRT applies on top.
///
/// Depth follows the games' own occlusion data. Open ground recedes up the screen;
/// props stand upright at their mask baseline (LN1/LN2 depth sprites, LN3 mask
/// shapes, editor depth); characters stand upright at their feet.
function ln_stereo_state() {
    if (!variable_global_exists("ln_stereo"))
        global.ln_stereo={enabled:false,separation:6,mode:0,drag:false,capturing:false,offset:8,focus:0.5,surface:-1,raw_surface:-1,raw_ready:false,ln3_shapes:undefined,ln3_surface:-1};
    return global.ln_stereo;
}
function ln_stereo_ready() {
    var _st=ln_stereo_state();
    return _st.enabled && shader_is_compiled(sh_ln_anaglyph) && shader_is_compiled(sh_ln_stereo_depth) &&
        shader_is_compiled(sh_ln_stereo_fill) && shader_is_compiled(sh_ln_occlusion);
}
function ln_stereo_toggle() {var _st=ln_stereo_state();_st.enabled=!_st.enabled;}
function ln_stereo_capturing() {var _st=ln_stereo_state();return _st.capturing && surface_exists(_st.surface);}

/// Foot units (actor y, as the depth masks store it) to stored depth: 0 top/far, 1 bottom/near.
/// LN1/LN2 characters are double height with feet at y-8; LN3 single sprites end at y-29.
function ln_stereo_depth_value(_units) {var _st=ln_stereo_state();return clamp((_units-_st.offset)/144,0,1);}

/// Start this frame's depth buffer: ground by screen height, then the room's occluders.
function ln_stereo_begin(_g) {
    var _st=ln_stereo_state();_st.capturing=false;
    if (!ln_stereo_ready()) return;
    if (!surface_exists(_st.surface)) _st.surface=surface_create(240,144);
    _st.offset=_g.game_number==3?29:8;
    // The player's feet sit on the screen plane, so the character in view carries no
    // red/blue outline; the camera eases there after room changes and falls.
    var _feet=_g.game_number==1?_g.player.y:(_g.game_number==2?_g.player.depth_y:_g.state.player_y);
    var _focus=ln_stereo_depth_value(_feet);
    _st.focus=abs(_focus-_st.focus)<0.004?_focus:lerp(_st.focus,_focus,0.15);
    var _has_mask=false,_mask=sprite_get_texture(spr_depth_fixture,0),_uv=[0,0,1,1];
    if (_g.game_number==3) {
        var _shapes=ln_stereo_ln3_mask(_g);
        if (surface_exists(_shapes)) {_has_mask=true;_mask=surface_get_texture(_shapes);}
    } else if (variable_struct_exists(_g,"mask") && _g.mask>=0 && sprite_exists(_g.mask)) {
        _has_mask=true;_mask=sprite_get_texture(_g.mask,0);_uv=sprite_get_uvs(_g.mask,0);
    }
    var _e=global.ln_editor,_editor=(_e.native_preview || _e.context) && is_struct(_e.cache) &&
        variable_struct_exists(_e.cache,"depth_surface") && surface_exists(_e.cache.depth_surface);
    surface_set_target(_st.surface);draw_clear(c_black);
    shader_set(sh_ln_stereo_depth);
    texture_set_stage(shader_get_sampler_index(sh_ln_stereo_depth,"u_mask"),_mask);
    shader_set_uniform_f(shader_get_uniform(sh_ln_stereo_depth,"u_mask_uv"),_uv[0],_uv[1],_uv[2],_uv[3]);
    shader_set_uniform_f(shader_get_uniform(sh_ln_stereo_depth,"u_has_mask"),real(_has_mask));
    texture_set_stage(shader_get_sampler_index(sh_ln_stereo_depth,"u_editor"),_editor?surface_get_texture(_e.cache.depth_surface):_mask);
    shader_set_uniform_f(shader_get_uniform(sh_ln_stereo_depth,"u_has_editor"),real(_editor));
    shader_set_uniform_f(shader_get_uniform(sh_ln_stereo_depth,"u_offset"),_st.offset);
    draw_set_colour(c_white);draw_rectangle(0,0,240,144,false);
    shader_reset();surface_reset_target();
    _st.capturing=true;
}

/// LN3 masks are C64 shape records; decode them once per room into baseline alpha.
/// Shape cell (x,y) sits at stage (8x-128, 8y-152), matching ln3_mask_bytes.
function ln_stereo_ln3_mask(_g) {
    var _st=ln_stereo_state(),_shapes=_g.mask_shapes;
    if (_st.ln3_shapes==_shapes && surface_exists(_st.ln3_surface)) return _st.ln3_surface;
    var _alpha=array_create(240*144,0);
    if (is_array(_shapes)) for (var _n=0;_n<array_length(_shapes);_n++) {
        var _shape=_shapes[_n],_a=_shape.baseline<0?255:clamp(_shape.baseline,1,254);
        var _ox=8*_shape.x-128,_oy=8*_shape.y-152,_w=_shape.width,_bitmap=_shape.bitmap,_size=array_length(_bitmap);
        for (var _row=0;_row<_shape.height*8;_row++) {
            var _py=_oy+_row;if (_py<0 || _py>=144) continue;
            for (var _col=0;_col<_w;_col++) {
                var _at=((_row div 8)*_w+_col)*8+(_row mod 8);if (_at>=_size) continue;
                var _byte=_bitmap[_at];if (_byte==0) continue;
                // Multicolour pairs: any set bit makes both pixels opaque, as in the original.
                for (var _pair=0;_pair<4;_pair++) if (_byte&(192>>(_pair*2))) {
                    for (var _half=0;_half<2;_half++) {
                        var _px=_ox+_col*8+_pair*2+_half;
                        if (_px>=0 && _px<240) _alpha[_py*240+_px]=max(_alpha[_py*240+_px],_a);
                    }
                }
            }
        }
    }
    var _b=buffer_create(240*144*4,buffer_fixed,1);
    for (var _i=0;_i<240*144;_i++) buffer_poke(_b,_i*4,buffer_u32,$ffffff|(_alpha[_i]<<24));
    if (!surface_exists(_st.ln3_surface)) _st.ln3_surface=surface_create(240,144);
    buffer_set_surface(_b,_st.ln3_surface,0);buffer_delete(_b);
    _st.ln3_shapes=_shapes;return _st.ln3_surface;
}

/// Keep an LN3 part before its mask is applied, so holes in the sprite can be told
/// apart from pixels that scenery hides.
function ln_stereo_keep_raw(_surface) {
    var _st=ln_stereo_state(),_w=surface_get_width(_surface),_h=surface_get_height(_surface);
    if (surface_exists(_st.raw_surface) && (surface_get_width(_st.raw_surface)!=_w || surface_get_height(_st.raw_surface)!=_h)) surface_free(_st.raw_surface);
    if (!surface_exists(_st.raw_surface)) _st.raw_surface=surface_create(_w,_h);
    surface_copy(_st.raw_surface,0,0,_surface);_st.raw_ready=true;
}

/// Stamp an already-masked sprite surface (LN3 actor parts) at one foot depth.
function ln_stereo_stamp_surface(_surface,_x,_y,_xscale,_yscale,_units) {
    if (!ln_stereo_capturing()) return;
    var _st=global.ln_stereo,_raw=_st.raw_ready && surface_exists(_st.raw_surface);_st.raw_ready=false;
    surface_set_target(_st.surface);shader_set(sh_ln_stereo_fill);
    shader_set_uniform_f(shader_get_uniform(sh_ln_stereo_fill,"u_value"),ln_stereo_depth_value(_units));
    texture_set_stage(shader_get_sampler_index(sh_ln_stereo_fill,"u_raw"),surface_get_texture(_raw?_st.raw_surface:_surface));
    shader_set_uniform_f(shader_get_uniform(sh_ln_stereo_fill,"u_gap"),real(_raw),texture_get_texel_width(surface_get_texture(_surface)),
        texture_get_texel_width(surface_get_texture(_surface))*surface_get_width(_surface));
    draw_surface_ext(_surface,_x,_y,_xscale,_yscale,0,c_white,1);
    shader_reset();surface_reset_target();
}

/// Replaces the stage blit. Flat frames (fades, messages) draw unchanged.
function ln_stereo_draw_stage(_surface,_x,_y,_scale,_flat=false) {
    var _st=ln_stereo_state();_st.capturing=false;
    if (_flat || !ln_stereo_ready() || !surface_exists(_st.surface)) {draw_surface_ext(_surface,_x,_y,_scale,_scale,0,c_white,1);return;}
    var _texture=surface_get_texture(_surface),_tw=texture_get_texel_width(_texture),_th=texture_get_texel_height(_texture);
    var _filter=gpu_get_texfilter();gpu_set_texfilter(false);
    shader_set(sh_ln_anaglyph);
    texture_set_stage(shader_get_sampler_index(sh_ln_anaglyph,"u_depth"),surface_get_texture(_st.surface));
    shader_set_uniform_f(shader_get_uniform(sh_ln_anaglyph,"u_bounds"),_tw*0.5,_th*0.5,
        _tw*(surface_get_width(_surface)-0.5),_th*(surface_get_height(_surface)-0.5));
    shader_set_uniform_f(shader_get_uniform(sh_ln_anaglyph,"u_texel"),_tw);
    shader_set_uniform_f(shader_get_uniform(sh_ln_anaglyph,"u_separation"),_st.separation);
    shader_set_uniform_f(shader_get_uniform(sh_ln_anaglyph,"u_mode"),_st.mode);
    shader_set_uniform_f(shader_get_uniform(sh_ln_anaglyph,"u_focus"),_st.focus);
    draw_surface_ext(_surface,_x,_y,_scale,_scale,0,c_white,1);
    shader_reset();gpu_set_texfilter(_filter);
}

// Controls sit on the tool frame's lower row (1920x1080 output space), beside the save prompt.
function ln_stereo_step(_host) {
    var _st=ln_stereo_state(),_e=global.ln_editor;
    var _keys=!_e.open && !global.ln_sprites.open && !global.ln_tracks.open && !ln_guide_active() && !ln_quit_active();
    if (_keys && keyboard_check_pressed(ord("V"))) ln_stereo_toggle();
    var _visible=ln_tool_motion_visible(_host);
    if (!_visible || !mouse_check_button(mb_left)) _st.drag=false;
    if (!_visible) return;
    if (mouse_check_button_pressed(mb_left) && mouse_y>=976 && mouse_y<1004) {
        if (mouse_x>=870 && mouse_x<1020) ln_stereo_toggle();
        else if (mouse_x>=1030 && mouse_x<1170) _st.mode=1-_st.mode;
        else if (mouse_x>=1180 && mouse_x<1482) _st.drag=true;
    }
    if (_st.drag) _st.separation=round((-16+32*clamp((mouse_x-1186)/290,0,1))*2)/2;
}
function ln_stereo_ui_draw() {
    var _st=ln_stereo_state();
    ln_edit_button(870,976,150,"3D "+(_st.enabled?"ON":"OFF")+" (V)",_st.enabled);
    ln_edit_button(1030,976,140,_st.mode==0?"Red / Cyan":"Red / Blue",_st.enabled);
    var _knob=1186+290*(_st.separation+16)/32;
    draw_set_colour(make_colour_rgb(65,73,84));draw_rectangle(1186,988,1476,992,false);
    draw_set_colour(make_colour_rgb(120,130,140));draw_rectangle(1330,983,1332,997,false);
    draw_set_colour(_st.drag?c_white:make_colour_rgb(180,215,236));draw_circle(_knob,990,6,false);
    draw_set_colour(_st.enabled?c_white:make_colour_rgb(128,128,128));
    draw_text(1492,981,"Separation "+(_st.separation>0?"+":"")+string_format(_st.separation,1,1));
    draw_set_colour(c_white);
}

/// GPU checks: one scene per game, 3D off / zero separation / on, both glasses.
function ln_stereo_checks() {
    var _st=ln_stereo_state(),_saved=[_st.enabled,_st.separation,_st.mode],_out=surface_create(1280,800);
    ln_check(shader_is_compiled(sh_ln_anaglyph) && shader_is_compiled(sh_ln_stereo_depth) && shader_is_compiled(sh_ln_stereo_fill),"3D shaders compile on the active GPU");
    for (var _game=1;_game<=3;_game++) {
        var _g,_name="LN"+string(_game)+" ",_file="stereo-ln"+string(_game);
        if (_game==1) {_g=new LN1Play();ln1_play_enter(_g,5);_g.player.x=185;_g.player.y=60;_g.room_age=62;}
        else if (_game==2) {_g=new LN2Play(1);ln2_play_enter(_g,1);}
        else _g=new LN3Play(1);
        _st.enabled=false;ln_stereo_check_draw(_g,_out);
        var _flat=ln_stereo_check_sample(_out);surface_save(_out,_file+"-off.png");
        _st.enabled=true;_st.separation=0;_st.mode=0;ln_stereo_check_draw(_g,_out);
        ln_check(array_equals(ln_stereo_check_sample(_out),_flat),_name+"3D at zero separation matches the flat picture");
        ln_check(surface_exists(_st.surface),_name+"depth buffer exists");
        surface_save(_st.surface,_file+"-depth.png");
        var _top=0,_bottom=0,_upright=0;
        for (var _x=0;_x<240;_x+=4) {_top+=colour_get_red(surface_getpixel(_st.surface,_x,1));_bottom+=colour_get_red(surface_getpixel(_st.surface,_x,142));}
        ln_check(_bottom>_top,_name+"depth recedes up the screen");
        for (var _y=0;_y<144;_y+=2) for (var _x=0;_x<240;_x+=2)
            if (abs(colour_get_red(surface_getpixel(_st.surface,_x,_y))-round(255*(_y+0.5)/144))>3) _upright++;
        ln_check(_upright>20,_name+"depth carries upright props or characters, not only ground: "+string(_upright));
        if (_game==1) {
            // Player foot y=60: every visible ninja pixel stands at depth (60-8)/144.
            var _stamped=0,_value=round(255*52/144);
            for (var _y=14;_y<52;_y++) for (var _x=161;_x<185;_x++) if (abs(colour_get_red(surface_getpixel(_st.surface,_x,_y))-_value)<=1) _stamped++;
            ln_check(_stamped>20,"LN1 ninja pixels stand at foot depth: "+string(_stamped));
        }
        if (_game==3) ln_check(surface_exists(_st.ln3_surface),"LN3 mask shapes decode into a depth layer");
        _st.separation=10;ln_stereo_check_draw(_g,_out);
        ln_check(!array_equals(ln_stereo_check_sample(_out),_flat),_name+"3D separation changes the picture");
        surface_save(_out,_file+"-redcyan.png");
        _st.mode=1;ln_stereo_check_draw(_g,_out);
        var _green=0;
        for (var _y=90;_y<510;_y+=12) for (var _x=166;_x<874;_x+=12) _green+=colour_get_green(surface_getpixel(_out,_x,_y));
        ln_check(_green==0,_name+"red/blue glasses carry no green");
        surface_save(_out,_file+"-redblue.png");
        _st.separation=-10;_st.mode=0;ln_stereo_check_draw(_g,_out);surface_save(_out,_file+"-reversed.png");
        if (_game==1) {
            // Ninja on open road at the default separation, where sprite holes show most.
            _st.separation=16;_g.player.x=150;_g.player.y=110;
            repeat(60) ln_stereo_check_draw(_g,_out);
            surface_save(_out,_file+"-road.png");surface_save(_st.surface,_file+"-road-depth.png");
            var _on=[];
            for (var _y=84+3*62;_y<84+3*102;_y+=2) for (var _x=160+3*126;_x<160+3*150;_x+=2) array_push(_on,surface_getpixel(_out,_x,_y));
            _st.enabled=false;ln_stereo_check_draw(_g,_out);surface_save(_out,_file+"-road-off.png");_st.enabled=true;
            // The player's feet are the screen plane: his own pixels carry no red/blue outline.
            var _ghost=0,_n=0,_player=round(255*ln_stereo_depth_value(110));
            for (var _y=84+3*62;_y<84+3*102;_y+=2) for (var _x=160+3*126;_x<160+3*150;_x+=2) {
                var _flat_pixel=surface_getpixel(_out,_x,_y);
                // Only the player's own pixels, not scenery at other depths.
                var _depth=colour_get_red(surface_getpixel(_st.surface,(_x-160) div 3,(_y-84) div 3));
                if (abs(_depth-_player)<=1 && _flat_pixel==c_black && _on[_n]!=c_black) _ghost++;
                _n++;
            }
            ln_check(_ghost==0,"LN1 player on the screen plane has no red/blue outline at +16: "+string(_ghost));
        }
        if (surface_exists(_g.stage_surface)) surface_free(_g.stage_surface);
    }
    surface_free(_out);ln_stereo_free();
    _st.enabled=_saved[0];_st.separation=_saved[1];_st.mode=_saved[2];
    show_debug_message("LN_STEREO_PASS: LN1/LN2/LN3 depth buffers, zero-separation identity, red/cyan and red/blue output");
    show_debug_message("LN_CAPTURE_DIRECTORY:"+game_save_id);
}
function ln_stereo_check_draw(_g,_out) {
    surface_set_target(_out);draw_clear(c_black);
    if (_g.game_number==1) ln1_play_draw(_g,false);else if (_g.game_number==2) ln2_play_draw(_g);else ln3_play_draw(_g);
    draw_flush();surface_reset_target();
}
function ln_stereo_check_sample(_out) {
    var _pixels=[];
    for (var _y=86;_y<516;_y+=7) for (var _x=161;_x<880;_x+=5) array_push(_pixels,surface_getpixel(_out,_x,_y));
    return _pixels;
}

function ln_stereo_free() {
    if (!variable_global_exists("ln_stereo")) return;
    var _st=global.ln_stereo;
    if (surface_exists(_st.surface)) surface_free(_st.surface);
    if (surface_exists(_st.ln3_surface)) surface_free(_st.ln3_surface);
    if (surface_exists(_st.raw_surface)) surface_free(_st.raw_surface);
    _st.surface=-1;_st.ln3_surface=-1;_st.raw_surface=-1;_st.raw_ready=false;_st.ln3_shapes=undefined;
}
