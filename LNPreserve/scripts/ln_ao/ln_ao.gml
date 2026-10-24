/// Ambient shading (SSAO) from the scene depth buffer. Presentation only: soft
/// contact shade where characters, walls and props stand on the ground. It is
/// computed at native resolution and laid smoothly over the picture before any
/// drawn style, 3D and CRT. Strength 0 switches it off.
function ln_ao_state() {
    if (!variable_global_exists("ln_ao")) global.ln_ao={strength:0,radius:0.4,reveal:1,drag:0,surface:-1,applied:-1};
    return global.ln_ao;
}
function ln_ao_active() {
    var _a=ln_ao_state();
    return _a.strength>0 && shader_is_compiled(sh_ln_ao) && shader_is_compiled(sh_ln_ao_apply);
}

/// Occlusion at native resolution, one value per stage pixel (1 open .. 0 shaded).
/// While a scene is still being painted in, its depth already holds the finished
/// scene, so shade would appear ahead of the picture; it waits for the painting to
/// finish and then fades in over about half a second.
function ln_ao_render(_depth) {
    var _a=ln_ao_state(),_w=surface_get_width(_depth),_h=surface_get_height(_depth);
    var _painting=variable_global_exists("ln_paint") && global.ln_paint.active;
    _a.reveal=_painting?0:min(1,_a.reveal+delta_time/500000);
    _a.surface=ln_style_surface(_a.surface,_w,_h);
    var _filter=gpu_get_texfilter(),_texture=surface_get_texture(_depth);
    gpu_set_texfilter(false);
    surface_set_target(_a.surface);draw_clear(c_white);
    shader_set(sh_ln_ao);
    shader_set_uniform_f(shader_get_uniform(sh_ln_ao,"u_texel"),texture_get_texel_width(_texture),texture_get_texel_height(_texture));
    shader_set_uniform_f(shader_get_uniform(sh_ln_ao,"u_radius"),lerp(2,12,_a.radius));
    shader_set_uniform_f(shader_get_uniform(sh_ln_ao,"u_strength"),_a.strength*_a.reveal);
    draw_surface(_depth,0,0);
    shader_reset();surface_reset_target();gpu_set_texfilter(_filter);
    return _a.surface;
}

/// Without a drawn style, the shade is laid over the stage at screen scale.
function ln_ao_apply(_stage,_ao,_scale) {
    var _a=ln_ao_state(),_w=surface_get_width(_stage)*_scale,_h=surface_get_height(_stage)*_scale;
    _a.applied=ln_style_surface(_a.applied,_w,_h);
    var _filter=gpu_get_texfilter(),_texture=surface_get_texture(_ao);
    var _base=shader_get_sampler_index(sh_ln_ao_apply,"gm_BaseTexture"),_sampler=shader_get_sampler_index(sh_ln_ao_apply,"u_ao");
    surface_set_target(_a.applied);draw_clear(c_black);
    shader_set(sh_ln_ao_apply);
    gpu_set_texfilter_ext(_base,false);gpu_set_texfilter_ext(_sampler,true);
    texture_set_stage(_sampler,_texture);
    shader_set_uniform_f(shader_get_uniform(sh_ln_ao_apply,"u_texel"),texture_get_texel_width(_texture),texture_get_texel_height(_texture));
    draw_surface_ext(_stage,0,0,_scale,_scale,0,c_white,1);
    shader_reset();surface_reset_target();
    gpu_set_texfilter_ext(_base,_filter);gpu_set_texfilter_ext(_sampler,_filter);gpu_set_texfilter(_filter);
    return _a.applied;
}

// Controls sit at the right end of the tool frame's third lower row.
// Drag: 0 none, 1 strength, 2 size.
function ln_ao_step(_host) {
    var _a=ln_ao_state();
    var _visible=ln_tool_motion_visible(_host) && !ln_zoom_covering();
    if (!_visible || !mouse_check_button(mb_left)) _a.drag=0;
    if (!_visible) return;
    if (mouse_check_button_pressed(mb_left) && mouse_y>=1048 && mouse_y<1076) {
        if (mouse_x>=1414 && mouse_x<1566) _a.drag=1;
        else if (mouse_x>=1694 && mouse_x<1826) _a.drag=2;
    }
    if (_a.drag==1) _a.strength=round(clamp((mouse_x-1420)/140,0,1)*20)/20;
    if (_a.drag==2) _a.radius=round(clamp((mouse_x-1700)/120,0,1)*20)/20;
}
function ln_ao_ui_draw() {
    var _a=ln_ao_state(),_text=_a.strength>0?c_white:make_colour_rgb(128,128,128);
    draw_set_colour(c_white);draw_text(1310,1053,"Shading");
    draw_set_colour(make_colour_rgb(65,73,84));draw_rectangle(1420,1060,1560,1064,false);
    draw_set_colour(_a.drag==1?c_white:make_colour_rgb(180,215,236));draw_circle(1420+140*_a.strength,1062,6,false);
    draw_set_colour(_text);draw_text(1570,1053,_a.strength>0?string(round(_a.strength*100))+"%":"Off");
    draw_text(1640,1053,"Size");
    draw_set_colour(make_colour_rgb(65,73,84));draw_rectangle(1700,1060,1820,1064,false);
    draw_set_colour(_a.drag==2?c_white:make_colour_rgb(180,215,236));draw_circle(1700+120*_a.radius,1062,6,false);
    draw_set_colour(_text);draw_text(1832,1053,string(round(_a.radius*100))+"%");
    draw_set_colour(c_white);
}

function ln_ao_free() {
    if (!variable_global_exists("ln_ao")) return;
    var _a=global.ln_ao;
    if (surface_exists(_a.surface)) surface_free(_a.surface);
    if (surface_exists(_a.applied)) surface_free(_a.applied);
    _a.surface=-1;_a.applied=-1;
}

/// GPU checks: shading darkens the ground where a character stands, leaves the
/// picture alone at zero strength, and combines with styles and 3D.
function ln_ao_checks() {
    var _a=ln_ao_state(),_s=ln_style_state(),_st=ln_stereo_state(),_saved=[_a.strength,_a.radius,_s.style,_st.enabled];
    var _out=surface_create(1280,800);_a.reveal=1;
    ln_check(shader_is_compiled(sh_ln_ao) && shader_is_compiled(sh_ln_ao_apply),"shading shaders compile on the active GPU");
    for (var _game=1;_game<=3;_game++) {
        var _g,_name="LN"+string(_game)+" ",_file="ao-ln"+string(_game);
        if (_game==1) {_g=new LN1Play();ln1_play_enter(_g,5);_g.player.x=150;_g.player.y=110;_g.room_age=62;}
        else if (_game==2) {_g=new LN2Play(1);ln2_play_enter(_g,1);}
        else _g=new LN3Play(1);
        _st.enabled=false;_s.style=0;_a.strength=0;ln_stereo_check_draw(_g,_out);
        var _flat=ln_stereo_check_sample(_out);surface_save(_out,_file+"-off.png");
        _a.strength=1;_a.radius=0.4;ln_stereo_check_draw(_g,_out);
        ln_check(!array_equals(ln_stereo_check_sample(_out),_flat),_name+"shading changes the picture");
        surface_save(_out,_file+"-on.png");surface_save(_a.surface,_file+"-ao.png");
        if (_game==1) {
            // Ground around the ninja's feet (stage row ~102) gets darker; his own black pixels stay black.
            var _before=0,_after=0;
            for (var _y=84+3*90;_y<84+3*104;_y+=3) for (var _x=160+3*112;_x<160+3*164;_x+=3) {
                _after+=colour_get_value(surface_getpixel(_out,_x,_y));
            }
            _a.strength=0;ln_stereo_check_draw(_g,_out);
            for (var _y=84+3*90;_y<84+3*104;_y+=3) for (var _x=160+3*112;_x<160+3*164;_x+=3) {
                _before+=colour_get_value(surface_getpixel(_out,_x,_y));
            }
            ln_check(_after<_before,"LN1 shading darkens the ground at the ninja's feet: "+string(_after)+" < "+string(_before));
            _a.strength=1;
        }
        _a.radius=1;ln_stereo_check_draw(_g,_out);surface_save(_out,_file+"-wide.png");_a.radius=0.4;
        // While the scene is still painting in, no shade shows.
        var _paint_saved=global.ln_paint.active;global.ln_paint.active=true;
        ln_ao_render(_st.surface);
        var _held=true;
        for (var _y=0;_y<144;_y+=3) for (var _x=0;_x<240;_x+=3) if (surface_getpixel(_a.surface,_x,_y)!=c_white) _held=false;
        global.ln_paint.active=_paint_saved;_a.reveal=1;
        ln_check(_held,_name+"no shading while the scene is still painting");
        _s.style=3;ln_stereo_check_draw(_g,_out);surface_save(_out,_file+"-pencil.png");
        _s.style=1;_st.enabled=true;ln_stereo_check_draw(_g,_out);surface_save(_out,_file+"-ink-3d.png");
        if (surface_exists(_g.stage_surface)) surface_free(_g.stage_surface);
    }
    surface_free(_out);ln_ao_free();ln_style_free();ln_stereo_free();
    _a.strength=_saved[0];_a.radius=_saved[1];_s.style=_saved[2];_st.enabled=_saved[3];
    show_debug_message("LN_AO_PASS: shading on LN1/LN2/LN3, contact shade at feet, with styles and 3D");
}
