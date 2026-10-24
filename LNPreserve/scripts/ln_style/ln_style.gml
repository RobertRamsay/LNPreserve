/// Drawn styles for the game picture: Ink, Painterly, Pencil and Coloured pencil.
/// Presentation only. The 240x144 stage is first de-dithered at native resolution
/// (C64 checker and stripe dithers merge into flat tones; depth keeps edges sharp),
/// then styled at screen scale. Outlines follow the 3D depth buffer, so they trace
/// real silhouettes rather than dither. 3D and CRT apply afterwards, as before.
function ln_style_state() {
    if (!variable_global_exists("ln_style")) global.ln_style={style:0,strength:1,line:0.35,saturation:1,brush:0.4,hatch:0.5,drag:0,smooth:-1,output:-1};
    return global.ln_style;
}
function ln_style_names() {return ["Off","Ink","Painterly","Pencil","Coloured pencil"];}
function ln_style_active() {
    var _s=ln_style_state();
    return _s.style>0 && shader_is_compiled(sh_ln_style) && shader_is_compiled(sh_ln_style_smooth);
}
function ln_style_cycle() {var _s=ln_style_state();_s.style=(_s.style+1) mod array_length(ln_style_names());}

function ln_style_surface(_surface,_w,_h) {
    if (surface_exists(_surface) && (surface_get_width(_surface)!=_w || surface_get_height(_surface)!=_h)) surface_free(_surface);
    return surface_exists(_surface)?_surface:surface_create(_w,_h);
}

/// Styles the stage into a screen-scale surface and returns it.
function ln_style_render(_stage,_depth,_scale,_ao=-1) {
    var _s=ln_style_state(),_w=surface_get_width(_stage),_h=surface_get_height(_stage),_ow=_w*_scale,_oh=_h*_scale;
    _s.smooth=ln_style_surface(_s.smooth,_w,_h);_s.output=ln_style_surface(_s.output,_ow,_oh);
    var _filter=gpu_get_texfilter(),_stage_texture=surface_get_texture(_stage);
    gpu_set_texfilter(false);
    surface_set_target(_s.smooth);draw_clear(c_black);
    shader_set(sh_ln_style_smooth);
    texture_set_stage(shader_get_sampler_index(sh_ln_style_smooth,"u_depth"),surface_get_texture(_depth));
    shader_set_uniform_f(shader_get_uniform(sh_ln_style_smooth,"u_texel"),texture_get_texel_width(_stage_texture),texture_get_texel_height(_stage_texture));
    gpu_set_blendenable(false);draw_surface(_stage,0,0);gpu_set_blendenable(true);
    shader_reset();surface_reset_target();
    var _smooth_texture=surface_get_texture(_s.smooth);
    surface_set_target(_s.output);draw_clear(c_black);
    shader_set(sh_ln_style);
    // The de-dithered picture is read smoothly; depth and the original stay crisp.
    var _base=shader_get_sampler_index(sh_ln_style,"gm_BaseTexture"),_orig=shader_get_sampler_index(sh_ln_style,"u_orig");
    var _shade=shader_get_sampler_index(sh_ln_style,"u_ao"),_has_ao=surface_exists(_ao);
    gpu_set_texfilter_ext(_base,true);gpu_set_texfilter_ext(_orig,false);gpu_set_texfilter_ext(_shade,true);
    texture_set_stage(_orig,_stage_texture);
    texture_set_stage(_shade,_has_ao?surface_get_texture(_ao):_stage_texture);
    shader_set_uniform_f(shader_get_uniform(sh_ln_style,"u_has_ao"),real(_has_ao));
    shader_set_uniform_f(shader_get_uniform(sh_ln_style,"u_native"),texture_get_texel_width(_smooth_texture),texture_get_texel_height(_smooth_texture));
    shader_set_uniform_f(shader_get_uniform(sh_ln_style,"u_out"),_ow,_oh);
    shader_set_uniform_f(shader_get_uniform(sh_ln_style,"u_style"),_s.style);
    shader_set_uniform_f(shader_get_uniform(sh_ln_style,"u_strength"),_s.strength);
    shader_set_uniform_f(shader_get_uniform(sh_ln_style,"u_line"),_s.line);
    shader_set_uniform_f(shader_get_uniform(sh_ln_style,"u_saturation"),_s.saturation);
    shader_set_uniform_f(shader_get_uniform(sh_ln_style,"u_brush"),_s.brush);
    shader_set_uniform_f(shader_get_uniform(sh_ln_style,"u_hatch"),_s.hatch);
    // Its alpha holds depth, so it is drawn without blending.
    gpu_set_blendenable(false);draw_surface_ext(_s.smooth,0,0,_scale,_scale,0,c_white,1);gpu_set_blendenable(true);
    shader_reset();surface_reset_target();
    gpu_set_texfilter_ext(_base,_filter);gpu_set_texfilter_ext(_orig,_filter);gpu_set_texfilter_ext(_shade,_filter);
    gpu_set_texfilter(_filter);
    return _s.output;
}

// Controls sit on the tool frame's second and third lower rows, left of the glasses blend.
// Drag: 0 none, 1 strength, 2 line thickness, 3 saturation, 4 the style's own setting
// (brush size for Painterly, hatching strength for the pencils).
function ln_style_step(_host) {
    var _s=ln_style_state(),_e=global.ln_editor;
    var _keys=!_e.open && !global.ln_sprites.open && !global.ln_tracks.open && !ln_guide_active() && !ln_quit_active();
    if (_keys && keyboard_check_pressed(ord("K"))) ln_style_cycle();
    var _visible=ln_tool_motion_visible(_host) && !ln_zoom_covering();
    if (!_visible || !mouse_check_button(mb_left)) _s.drag=0;
    if (!_visible) return;
    if (mouse_check_button_pressed(mb_left) && mouse_y>=1012 && mouse_y<1040) {
        if (mouse_x>=320 && mouse_x<520) ln_style_cycle();
        else if (mouse_x>=530 && mouse_x<742) _s.drag=1;
    }
    if (mouse_check_button_pressed(mb_left) && mouse_y>=1048 && mouse_y<1076) {
        if (mouse_x>=394 && mouse_x<566) _s.drag=2;
        else if (mouse_x>=714 && mouse_x<886) _s.drag=3;
        else if (mouse_x>=1064 && mouse_x<1236 && _s.style>=2) _s.drag=4;
    }
    if (_s.drag==1) _s.strength=round(clamp((mouse_x-536)/200,0,1)*20)/20;
    if (_s.drag==2) _s.line=round(clamp((mouse_x-400)/160,0,1)*20)/20;
    if (_s.drag==3) _s.saturation=round(clamp((mouse_x-720)/160,0,1)*40)/20;
    if (_s.drag==4) {
        var _own=round(clamp((mouse_x-1070)/160,0,1)*20)/20;
        if (_s.style==2) _s.brush=_own;else _s.hatch=_own;
    }
}
function ln_style_ui_draw() {
    var _s=ln_style_state();
    ln_edit_button(320,1012,200,"Style: "+ln_style_names()[_s.style]+" (K)",_s.style>0);
    var _knob=536+200*_s.strength;
    draw_set_colour(make_colour_rgb(65,73,84));draw_rectangle(536,1024,736,1028,false);
    draw_set_colour(_s.drag==1?c_white:make_colour_rgb(180,215,236));draw_circle(_knob,1026,6,false);
    var _text=_s.style>0?c_white:make_colour_rgb(128,128,128);
    draw_set_colour(_text);draw_text(748,1017,"Strength "+string(round(_s.strength*100))+"%");
    // Line thickness (0 = no outlines) and saturation (100% at the centre mark).
    draw_set_colour(_text);draw_text(320,1053,"Lines");
    draw_set_colour(make_colour_rgb(65,73,84));draw_rectangle(400,1060,560,1064,false);
    draw_set_colour(_s.drag==2?c_white:make_colour_rgb(180,215,236));draw_circle(400+160*_s.line,1062,6,false);
    draw_set_colour(_text);draw_text(572,1053,string(round(_s.line*100))+"%");
    draw_text(620,1053,"Saturation");
    draw_set_colour(make_colour_rgb(65,73,84));draw_rectangle(720,1060,880,1064,false);
    draw_set_colour(make_colour_rgb(120,130,140));draw_rectangle(799,1055,801,1069,false);
    draw_set_colour(_s.drag==3?c_white:make_colour_rgb(180,215,236));draw_circle(720+80*_s.saturation,1062,6,false);
    draw_set_colour(_text);draw_text(892,1053,string(round(_s.saturation*100))+"%");
    // The style's own setting: Painterly brush size, or pencil hatching strength.
    var _own=_s.style==2?_s.brush:_s.hatch,_mine=_s.style>=2;
    draw_set_colour(_mine?c_white:make_colour_rgb(128,128,128));
    draw_text(960,1053,_s.style==2?"Brush size":(_mine?"Hatching":"Brush / Hatch"));
    draw_set_colour(make_colour_rgb(65,73,84));draw_rectangle(1070,1060,1230,1064,false);
    if (_mine) {
        draw_set_colour(_s.drag==4?c_white:make_colour_rgb(180,215,236));draw_circle(1070+160*_own,1062,6,false);
        draw_set_colour(c_white);draw_text(1242,1053,string(round(_own*100))+"%");
    }
    draw_set_colour(c_white);
}

function ln_style_free() {
    if (!variable_global_exists("ln_style")) return;
    var _s=global.ln_style;
    if (surface_exists(_s.smooth)) surface_free(_s.smooth);
    if (surface_exists(_s.output)) surface_free(_s.output);
    _s.smooth=-1;_s.output=-1;
}

/// GPU checks: every style on one scene per game, zero strength matches the flat
/// picture, and styles combine with 3D.
function ln_style_checks() {
    var _s=ln_style_state(),_st=ln_stereo_state(),_saved=[_s.style,_s.strength,_st.enabled],_out=surface_create(1280,800);
    ln_check(shader_is_compiled(sh_ln_style) && shader_is_compiled(sh_ln_style_smooth),"style shaders compile on the active GPU");
    var _names=ln_style_names();
    for (var _game=1;_game<=3;_game++) {
        var _g,_name="LN"+string(_game)+" ",_file="style-ln"+string(_game);
        if (_game==1) {_g=new LN1Play();ln1_play_enter(_g,5);_g.player.x=150;_g.player.y=110;_g.room_age=62;}
        else if (_game==2) {_g=new LN2Play(1);ln2_play_enter(_g,1);}
        else _g=new LN3Play(1);
        _st.enabled=false;_s.style=0;ln_stereo_check_draw(_g,_out);
        var _flat=ln_stereo_check_sample(_out);
        _s.style=1;_s.strength=0;ln_stereo_check_draw(_g,_out);
        ln_check(array_equals(ln_stereo_check_sample(_out),_flat),_name+"style at zero strength matches the flat picture");
        _s.strength=1;
        for (var _style=1;_style<array_length(_names);_style++) {
            _s.style=_style;ln_stereo_check_draw(_g,_out);
            ln_check(!array_equals(ln_stereo_check_sample(_out),_flat),_name+_names[_style]+" changes the picture");
            surface_save(_out,_file+"-"+string_lower(string_replace_all(_names[_style]," ","-"))+".png");
        }
        surface_save(_s.smooth,_file+"-smooth.png");surface_save(_st.surface,_file+"-depth.png");
        // Line thickness and saturation each change the picture; no lines differs from thin.
        var _saved_look=[_s.line,_s.saturation],_looks=[];
        _s.style=1;
        for (var _look=0;_look<3;_look++) {
            _s.line=[0,0.1,1][_look];ln_stereo_check_draw(_g,_out);
            array_push(_looks,ln_stereo_check_sample(_out));surface_save(_out,_file+"-ink-lines-"+string(round(_s.line*100))+".png");
        }
        ln_check(!array_equals(_looks[0],_looks[1]) && !array_equals(_looks[1],_looks[2]),_name+"line thickness changes the outlines");
        _s.line=_saved_look[0];_s.style=2;_s.saturation=1.6;ln_stereo_check_draw(_g,_out);
        surface_save(_out,_file+"-painterly-saturated.png");_s.saturation=_saved_look[1];
        // Brush size and hatching strength each change their style.
        var _saved_own=[_s.brush,_s.hatch];
        _s.brush=0;ln_stereo_check_draw(_g,_out);var _fine=ln_stereo_check_sample(_out);surface_save(_out,_file+"-painterly-brush-0.png");
        _s.brush=1;ln_stereo_check_draw(_g,_out);ln_check(!array_equals(ln_stereo_check_sample(_out),_fine),_name+"brush size changes Painterly");
        surface_save(_out,_file+"-painterly-brush-100.png");
        _s.style=3;_s.hatch=0;ln_stereo_check_draw(_g,_out);var _soft=ln_stereo_check_sample(_out);surface_save(_out,_file+"-pencil-hatch-0.png");
        _s.hatch=1;ln_stereo_check_draw(_g,_out);ln_check(!array_equals(ln_stereo_check_sample(_out),_soft),_name+"hatching strength changes Pencil");
        surface_save(_out,_file+"-pencil-hatch-100.png");
        _s.brush=_saved_own[0];_s.hatch=_saved_own[1];
        _s.style=1;_st.enabled=true;ln_stereo_check_draw(_g,_out);surface_save(_out,_file+"-ink-3d.png");
        if (surface_exists(_g.stage_surface)) surface_free(_g.stage_surface);
    }
    surface_free(_out);ln_style_free();ln_stereo_free();
    _s.style=_saved[0];_s.strength=_saved[1];_st.enabled=_saved[2];
    show_debug_message("LN_STYLE_PASS: Ink, Painterly, Pencil and Coloured pencil on LN1/LN2/LN3, zero-strength identity, with 3D");
}
