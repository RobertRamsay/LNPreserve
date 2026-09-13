/// Presentation only: source surfaces and gameplay pixels remain untouched.
function ln_crt_surface(_surface,_x,_y,_scale,_pixel_scale=1,_region=undefined,_enabled_override=undefined) {
    ln_crt_tuning_init();
    var _enabled=(is_undefined(_enabled_override)?(variable_global_exists("ln_crt_enabled") && global.ln_crt_enabled):_enabled_override) && shader_is_compiled(sh_ln_crt);
    var _filter=gpu_get_texfilter();
    if (_enabled) {
        shader_set(sh_ln_crt);
        var _bounds=is_array(_region)?_region:[0,0,surface_get_width(_surface),surface_get_height(_surface)];
        shader_set_uniform_f(shader_get_uniform(sh_ln_crt,"u_region"),
            _bounds[0]/surface_get_width(_surface),_bounds[1]/surface_get_height(_surface),
            _bounds[2]/surface_get_width(_surface),_bounds[3]/surface_get_height(_surface));
        shader_set_uniform_f(shader_get_uniform(sh_ln_crt,"u_size"),surface_get_width(_surface),surface_get_height(_surface));
        shader_set_uniform_f(shader_get_uniform(sh_ln_crt,"u_scale"),_scale);
        shader_set_uniform_f(shader_get_uniform(sh_ln_crt,"u_pixel_scale"),_pixel_scale);
        shader_set_uniform_f(shader_get_uniform(sh_ln_crt,"u_time"),(current_time mod 120000)/1000);
        shader_set_uniform_f(shader_get_uniform(sh_ln_crt,"u_blur"),global.ln_crt_blur);
        shader_set_uniform_f(shader_get_uniform(sh_ln_crt,"u_honeycomb"),global.ln_crt_honeycomb);
        shader_set_uniform_f(shader_get_uniform(sh_ln_crt,"u_scanlines"),global.ln_crt_scanlines);
        shader_set_uniform_f(shader_get_uniform(sh_ln_crt,"u_scan_shape"),global.ln_scan_width,global.ln_scan_align,global.ln_scan_soft);
        shader_set_uniform_f(shader_get_uniform(sh_ln_crt,"u_phosphor"),global.ln_crt_phosphor,global.ln_crt_pitch);
        gpu_set_texfilter(true);
    }
    draw_surface_ext(_surface,_x,_y,_scale,_scale,0,c_white,1);
    if (_enabled) {shader_reset();gpu_set_texfilter(_filter);}
}

/// CRT covers only the native picture and built-in HUD, never the debug UI.
function ln_crt_game_region(_host) {
    if (_host.workbench || _host.scene_test.menu || _host.scene_test.preview) return undefined;
    if (_host.play.game_number==1) return [160,84,1120,684];
    if ((_host.play.game_number==2 && _host.play.victory==2) ||
        (_host.play.game_number==3 && (is_struct(_host.play.ending) || is_struct(_host.play.intro)))) return [0,0,1280,800];
    if (_host.play.game_number==2) return [160,84,1120,684];
    return [160,84,1120,684];
}

/// Apply once after the game and its surrounding controls are drawn.
function ln_crt_present(_host) {
    if (!global.ln_crt_enabled || !shader_is_compiled(sh_ln_crt) || !surface_exists(application_surface)) return;
    var _region=ln_crt_game_region(_host);
    if (!is_array(_region)) return;
    var _input=global.ln_tool.drawing?global.ln_tool.surface:application_surface;
    var _w=surface_get_width(_input),_h=surface_get_height(_input);
    if (surface_exists(_host.crt_surface) && (surface_get_width(_host.crt_surface)!=_w || surface_get_height(_host.crt_surface)!=_h)) {
        surface_free(_host.crt_surface);_host.crt_surface=-1;
    }
    if (!surface_exists(_host.crt_surface)) _host.crt_surface=surface_create(_w,_h);
    if (!surface_exists(_host.crt_surface)) return;
    // Separate output avoids reading from the surface currently being rendered.
    surface_set_target(_host.crt_surface);
    ln_crt_surface(_input,0,0,1,(_host.play.game_number==1 || (_host.play.game_number==2 && _host.play.victory!=2) || (_host.play.game_number==3 && !(is_struct(_host.play.ending) || is_struct(_host.play.intro))))?3:4,_region);
    surface_reset_target();
    draw_surface_part(_host.crt_surface,_region[0],_region[1],_region[2]-_region[0],_region[3]-_region[1],_region[0],_region[1]);
}

function ln_crt_toggle() {
    if (shader_is_compiled(sh_ln_crt)) global.ln_crt_enabled=!global.ln_crt_enabled;
}

function ln_crt_slider_input(_mx,_my,_pressed,_held,_tuning=true) {
    if (!_tuning && global.ln_crt_drag>=3) global.ln_crt_drag=-1;
    ln_crt_tuning_init();
    if(_tuning && global.ln_crt_enabled && _pressed && _my>=756 && _my<787 && _mx>=172 && _mx<388) {
        global.ln_crt_phosphor=_mx<280?1:0;global.ln_crt_drag=-1;return;
    }
    if(_tuning && global.ln_crt_enabled && _pressed && _mx>=480 && _mx<=770 && abs(_my-776)<=10) global.ln_crt_drag=5;
    if(_tuning && global.ln_crt_enabled && _held && global.ln_crt_drag==5) {
        global.ln_crt_pitch=0.5+1.5*clamp((_mx-490)/270,0,1);return;
    }
    if (_tuning && global.ln_crt_enabled && _pressed && _my>=716 && _my<745) {
        for (var _preset=0;_preset<4;_preset++) if (_mx>=172+148*_preset && _mx<312+148*_preset) {
            global.ln_scan_preset=_preset;global.ln_scan_align=0.5;
            global.ln_scan_width=[3,3,5,5][_preset];global.ln_scan_soft=_preset==0?0:1;
            global.ln_crt_scanlines=[0.75,0.85,0.85,1.0][_preset];global.ln_crt_drag=-1;return;
        }
    }
    if (_tuning && global.ln_crt_enabled && _pressed && _mx>=800 && _mx<=1100) {
        if (abs(_my-732)<=10) global.ln_crt_drag=3;
        if (abs(_my-776)<=10) global.ln_crt_drag=4;
    }
    if (global.ln_crt_enabled && _held && global.ln_crt_drag>=3) {
        var _t=clamp((_mx-810)/280,0,1);global.ln_scan_soft=1;global.ln_scan_preset=-1;
        if (global.ln_crt_drag==3) global.ln_scan_width=1+6*_t;else global.ln_scan_align=_t;
        return;
    }
    if (!global.ln_crt_enabled || !_held) {global.ln_crt_drag=-1;return;}
    if (_pressed && _mx>=1134 && _mx<=1266) {
        for (var _i=0;_i<3;_i++) {
            if (abs(_my-(698+38*_i))<=12) global.ln_crt_drag=_i;
        }
    }
    if (global.ln_crt_drag<0) return;
    var _value=clamp((_mx-1140)/118,0,1);
    switch (global.ln_crt_drag) {
        case 0:global.ln_crt_blur=_value;break;
        case 1:global.ln_crt_honeycomb=_value;break;
        case 2:global.ln_crt_scanlines=_value;break;
    }
}

function ln_crt_sliders_draw(_tuning=true) {
    if (!global.ln_crt_enabled) return;
    if (_tuning) ln_crt_tuning_draw();
    draw_set_colour(make_colour_rgb(24,28,34));draw_rectangle(1128,650,1272,792,false);
    draw_set_colour(make_colour_rgb(150,190,215));draw_text(1136,656,"CRT SETTINGS");
    var _labels=["Pixel blur",global.ln_crt_phosphor>0.5?"Phosphors":"Honeycomb","Scanlines"];
    var _values=[global.ln_crt_blur,global.ln_crt_honeycomb,global.ln_crt_scanlines];
    for (var _i=0;_i<3;_i++) {
        var _y=698+38*_i,_x=1140+118*_values[_i];
        draw_set_colour(c_white);draw_text_transformed(1136,_y-22,_labels[_i],0.85,0.85,0);
        var _label=string(round(_values[_i]*100))+"%";
        draw_set_colour(make_colour_rgb(150,190,215));
        draw_text_transformed(1264-string_width(_label)*0.85,_y-22,_label,0.85,0.85,0);
        draw_set_colour(make_colour_rgb(65,73,84));draw_rectangle(1140,_y-2,1258,_y+2,false);
        draw_set_colour(make_colour_rgb(91,160,205));draw_rectangle(1140,_y-2,_x,_y+2,false);
        draw_set_colour(global.ln_crt_drag==_i?c_white:make_colour_rgb(180,215,236));
        draw_circle(_x,_y,5,false);
    }
    draw_set_colour(c_white);
}

function ln_window_fit_factor(_width,_height) {
    var _fit=min((_width-32)/1920,(_height-96)/1080);
    return _fit>=1?clamp(floor(_fit),1,2):max(0.1,_fit);
}

function ln_window_preset(_factor) {
    if(_factor==0) _factor=ln_window_fit_factor(display_get_width(),display_get_height());
    var _w=round(1920*_factor),_h=round(1080*_factor);
    if(_w==display_get_width() && _h==display_get_height()) {
        if(!window_get_fullscreen()) ln_fullscreen_toggle(self);
        return;
    }
    if(window_get_fullscreen()) {
        if(variable_instance_exists(self,"cinematic_window") && is_struct(cinematic_window)) ln_cinematic_restore(self);
        else window_set_fullscreen(false);
    }
    window_set_size(_w,_h);window_center();
}

function ln_window_buttons(_tips=true) {
    ln_edit_button(1128,4,144,"Fullscreen F9",window_get_fullscreen());
    draw_set_colour(make_colour_rgb(24,28,34));draw_rectangle(1128,602,1272,648,false);
    draw_set_colour(make_colour_rgb(150,190,215));
    draw_text(1136,604,string(window_get_width())+"x"+string(window_get_height()));
    var _labels=["1x","2x","Fit"];
    for (var _i=0;_i<3;_i++) {
        var _x=1132+46*_i,_hover=ln_tool_mouse_x()>=_x && ln_tool_mouse_x()<_x+42 && ln_tool_mouse_y()>=624 && ln_tool_mouse_y()<645;
        var _selected=(_i==0 && window_get_width()==1920 && window_get_height()==1080) ||
            (_i==1 && window_get_width()==3840 && window_get_height()==2160);
        draw_set_colour(_selected?make_colour_rgb(44,82,110):make_colour_rgb(42,48,57));draw_rectangle(_x,624,_x+42,644,false);
        draw_set_colour(_hover?c_white:make_colour_rgb(180,215,236));draw_text(_x+8,626,_labels[_i]);
        if (_hover && _tips) {
            var _tip=_i==0?"1920 x 1080":(_i==1?"3840 x 2160":"Largest whole-pixel size that fits");
            draw_set_colour(c_white);draw_text(1120-string_width(_tip),626,_tip);
        }
    }
    draw_set_colour(c_white);
}

function ln_crt_controls_visible(_host) {
    if (_host.workbench || _host.scene_test.preview) return false;
    if (_host.scene_test.menu) return true;
    return _host.play.game_number!=3 || (!is_struct(_host.play.intro) && !is_struct(_host.play.ending));
}

function ln_crt_step(_show_controls=true,_tuning=true) {
    if (!_show_controls) {
        global.ln_crt_drag=-1;
        if (keyboard_check_pressed(vk_f10)) ln_crt_toggle();
        return;
    }
    if (mouse_check_button_pressed(mb_left) && ln_tool_mouse_y()>=624 && ln_tool_mouse_y()<645) {
        for (var _i=0;_i<3;_i++) {
            var _x=1132+46*_i;
            if (ln_tool_mouse_x()>=_x && ln_tool_mouse_x()<_x+42) {ln_window_preset(_i==2?0:_i+1);break;}
        }
    }
    if (keyboard_check_pressed(vk_f10) || (mouse_check_button_pressed(mb_left) &&
        ln_tool_mouse_x()>=1128 && ln_tool_mouse_x()<1272 && ln_tool_mouse_y()>=36 && ln_tool_mouse_y()<72)) {
        ln_crt_toggle();
    }
    ln_crt_slider_input(ln_tool_mouse_x(),ln_tool_mouse_y(),mouse_check_button_pressed(mb_left),mouse_check_button(mb_left),_tuning);
}

function ln_crt_button() {
    var _available=shader_is_compiled(sh_ln_crt);
    var _hover=ln_tool_mouse_x()>=1128 && ln_tool_mouse_x()<1272 && ln_tool_mouse_y()>=36 && ln_tool_mouse_y()<72;
    draw_set_colour(global.ln_crt_enabled?make_colour_rgb(44,82,110):make_colour_rgb(32,37,44));
    draw_rectangle(1128,36,1272,72,false);
    draw_set_colour(_hover?c_white:make_colour_rgb(150,190,215));
    draw_rectangle(1128,36,1272,72,true);
    draw_text(1136,44,_available?("CRT "+(global.ln_crt_enabled?"ON":"OFF")+"  F10"):"CRT unavailable");
    draw_set_colour(c_white);
}

/// GPU readback: switch off is pixel-identical and the effect preserves its input.
function ln_crt_checks() {
    ln_crt_preferences_checks();
    ln_check(shader_is_compiled(sh_ln_crt),"CRT shader compiled on the active GPU");
    var _saved=[global.ln_crt_blur,global.ln_crt_honeycomb,global.ln_crt_scanlines];
    global.ln_crt_enabled=true;
    ln_crt_slider_input(1199,698,true,true);
    ln_check(global.ln_crt_blur==0.5,"blur track click selects its midpoint");
    ln_crt_slider_input(1400,698,false,true);
    ln_check(global.ln_crt_blur==1,"drag clamps to the maximum outside track");
    ln_crt_slider_input(1000,698,false,true);
    ln_check(global.ln_crt_blur==0,"drag clamps to the minimum outside track");
    ln_crt_slider_input(1258,736,true,true);
    ln_check(global.ln_crt_honeycomb==1,"honeycomb track updates independently");
    ln_crt_slider_input(1258,774,true,true);
    ln_check(global.ln_crt_scanlines==1,"scanline track updates independently");
    ln_crt_slider_input(1258,774,false,false);
    ln_check(global.ln_crt_drag==-1,"releasing the mouse ends slider drag");
    global.ln_crt_enabled=false;
    ln_crt_slider_input(1140,774,true,true);
    ln_check(global.ln_crt_scanlines==1 && global.ln_crt_drag==-1,"hidden sliders ignore clicks");
    global.ln_crt_blur=_saved[0];global.ln_crt_honeycomb=_saved[1];global.ln_crt_scanlines=_saved[2];
    var _source=surface_create(240,144),_output=surface_create(720,432);
    surface_set_target(_source);draw_clear(make_colour_rgb(60,60,60));
    draw_sprite(spr_ln1_pickup_2,0,120,60);
    draw_set_colour(make_colour_rgb(160,180,200));draw_rectangle(20,20,90,90,false);
    draw_set_colour(c_white);surface_reset_target();
    var _original=surface_getpixel(_source,40,40),_filter=gpu_get_texfilter();
    global.ln_crt_enabled=false;
    surface_set_target(_output);ln_crt_surface(_source,0,0,3);surface_reset_target();
    ln_check(surface_getpixel(_output,120,120)==_original,"CRT off preserves source pixels");
    surface_save(_output,"lnpreserve-crt-off.png");
    global.ln_crt_enabled=true;
    surface_set_target(_output);ln_crt_surface(_source,0,0,3);surface_reset_target();
    ln_check(surface_getpixel(_output,120,120)!=_original,"CRT on changes output pixels");
    ln_check(surface_getpixel(_source,40,40)==_original && gpu_get_texfilter()==_filter,"CRT preserves source and texture filtering");
    for (var _corner=0;_corner<4;_corner++) {
        ln_check(surface_getpixel(_output,(_corner&1)?719:0,(_corner&2)?431:0)!=c_black,"CRT keeps every corner filled without warping or cropping");
    }
    surface_save(_output,"lnpreserve-crt-on.png");
    var _baseline=0.0;
    for (var _setting=-1;_setting<3;_setting++) {
        global.ln_crt_blur=_setting==0?1:0;
        global.ln_crt_honeycomb=_setting==1?1:0;
        global.ln_crt_scanlines=_setting==2?1:0;
        surface_set_target(_output);ln_crt_surface(_source,0,0,3);surface_reset_target();
        var _sum=0.0;
        for (var _y=55;_y<290;_y+=11) for (var _x=55;_x<290;_x+=11) _sum+=surface_getpixel(_output,_x,_y);
        if (_setting<0) _baseline=_sum;
        else ln_check(abs(_sum-_baseline)>10000,"each CRT slider changes rendered pixels");
    }
    global.ln_crt_blur=_saved[0];global.ln_crt_honeycomb=_saved[1];global.ln_crt_scanlines=_saved[2];
    var _style_saved=global.ln_crt_phosphor,_pitch_saved=global.ln_crt_pitch,_strength=global.ln_crt_honeycomb,_hashes=[];
    global.ln_crt_honeycomb=0.8;
    for(var _variant=0;_variant<3;_variant++) {
        global.ln_crt_phosphor=_variant==0?0:1;global.ln_crt_pitch=_variant==2?1.7:1;
        surface_set_target(_output);ln_crt_surface(_source,0,0,3);surface_reset_target();
        var _hash=0.0;
        for(var _py=60;_py<210;_py+=3) for(var _px=60;_px<210;_px+=7) _hash+=surface_getpixel(_output,_px,_py);
        array_push(_hashes,_hash);surface_save(_output,"crt-phosphor-sample-"+string(_variant)+".png");
    }
    ln_check(_hashes[0]!=_hashes[1] && _hashes[1]!=_hashes[2],"phosphor style and spacing independently affect GPU output");
    global.ln_crt_phosphor=_style_saved;global.ln_crt_pitch=_pitch_saved;global.ln_crt_honeycomb=_strength;
    global.ln_crt_enabled=false;
    surface_free(_source);surface_free(_output);
    var _preview=new LN1Play();ln1_play_enter(_preview,5);
    _preview.player.x=185;_preview.player.y=60;
    _preview.player.action=0;_preview.player.input_lock=0;_preview.player.fire_previous=0;
    ln1_player_update(_preview.player,_preview.data,16,(_preview.player.tick+1)&255);
    _preview.room_age=62;
    ln1_play_draw(_preview,false);ln_crt_button();
    surface_save(application_surface,"lnpreserve-crt-scene-off.png");
    global.ln_crt_enabled=true;
    ln1_play_draw(_preview,false);ln_crt_button();
    var _debug_before=surface_getpixel(application_surface,170,40);
    var _button_before=surface_getpixel(application_surface,1150,50);
    var _hud_before=surface_getpixel(application_surface,900,100);
    var _bottom_before=surface_getpixel(application_surface,200,540);
    ln_crt_present(self);
    ln_check(surface_getpixel(application_surface,170,40)==_debug_before &&
        surface_getpixel(application_surface,1150,50)==_button_before,"outer debug UI remains pixel-identical with CRT on");
    ln_check(ln_window_fit_factor(3840,2160)==1 && ln_window_fit_factor(1920,1080)<1,"window Fit preserves whole sizes when possible and fits smaller desktops");
    ln_check(surface_getpixel(application_surface,900,100)!=_hud_before,"CRT affects the built-in side HUD");
    ln_check(surface_getpixel(application_surface,200,540)!=_bottom_before,"CRT affects the built-in bottom HUD");
    surface_save(application_surface,"lnpreserve-crt-scene-on.png");
    global.ln_crt_enabled=false;
    if (surface_exists(_preview.stage_surface)) surface_free(_preview.stage_surface);
    show_debug_message("LN_CAPTURE_DIRECTORY:"+game_save_id);
}

// Temporary comparison controls live below the game picture, outside the shader.
function ln_crt_tuning_init() {
    if (!variable_global_exists("ln_crt_phosphor")) {global.ln_crt_phosphor=1;global.ln_crt_pitch=1;}
    if (variable_global_exists("ln_scan_width")) return;
    global.ln_scan_width=5;global.ln_scan_align=0.5;global.ln_scan_soft=1;global.ln_scan_preset=-1;
}
function ln_crt_tuning_draw() {
    ln_crt_tuning_init();
    draw_set_colour(make_colour_rgb(24,28,34));draw_rectangle(160,690,1120,794,false);
    draw_set_colour(make_colour_rgb(150,190,215));draw_text(172,693,"CRT / SCANLINE SAMPLES");
    var _names=["Previous","Pixel edge","Soft 5","Deep 5"];
    for(var _i=0;_i<4;_i++) {
        var _x=172+148*_i;
        draw_set_colour(global.ln_scan_preset==_i?make_colour_rgb(44,82,110):make_colour_rgb(42,48,57));
        draw_rectangle(_x,716,_x+140,744,false);draw_set_colour(c_white);draw_text(_x+8,721,_names[_i]);
    }
    for(var _style=0;_style<2;_style++) {
        draw_set_colour(global.ln_crt_phosphor==1-_style?make_colour_rgb(44,82,110):make_colour_rgb(42,48,57));
        draw_rectangle(172+108*_style,756,276+108*_style,786,false);
        draw_set_colour(c_white);draw_text(180+108*_style,761,_style==0?"Phosphor":"Classic");
    }
    draw_set_colour(c_white);draw_text_transformed(400,750,"Spacing "+string_format(global.ln_crt_pitch,1,2)+"x",0.85,0.85,0);
    draw_set_colour(make_colour_rgb(65,73,84));draw_rectangle(490,774,760,778,false);
    draw_set_colour(make_colour_rgb(180,215,236));draw_circle(490+270*(global.ln_crt_pitch-0.5)/1.5,776,5,false);
    for(var _i=0;_i<2;_i++) {
        var _y=732+44*_i,_value=_i==0?(global.ln_scan_width-1)/6:global.ln_scan_align;
        var _label=_i==0?"Width "+string_format(global.ln_scan_width,1,1)+" rows":"Alignment "+string(round(global.ln_scan_align*100))+"%";
        draw_set_colour(c_white);draw_text(810,_y-26,_label);
        draw_set_colour(make_colour_rgb(65,73,84));draw_rectangle(810,_y-2,1090,_y+2,false);
        draw_set_colour(make_colour_rgb(180,215,236));draw_circle(810+280*_value,_y,5,false);
    }
    draw_set_colour(c_white);
}


/// Presentation-only fullscreen keeps the normal window geometry for returning.
function ln_cinematic_restore(_host) {
    var _saved=_host.cinematic_window;
    if (!is_struct(_saved)) return;
    window_set_fullscreen(false);
    window_set_size(_saved.width,_saved.height);
    window_set_position(_saved.x,_saved.y);
    window_set_cursor(_saved.cursor);
    _host.cinematic_window=undefined;
}

function ln_fullscreen_toggle(_host) {
    if(!variable_instance_exists(_host,"cinematic_window")) _host.cinematic_window=undefined;
    if(is_struct(_host.cinematic_window)) {ln_cinematic_restore(_host);return;}
    if(window_get_fullscreen()) {window_set_fullscreen(false);return;}
    _host.cinematic_window={x:window_get_x(),y:window_get_y(),width:window_get_width(),height:window_get_height(),cursor:window_get_cursor()};
    window_enable_borderless_fullscreen(true);window_set_fullscreen(true);
}
function ln_cinematic_step(_host) {
    if(!variable_instance_exists(_host,"cinematic_window")) _host.cinematic_window=undefined;
    if(keyboard_check_pressed(vk_f9) || (ln_crt_controls_visible(_host) && mouse_check_button_pressed(mb_left) && ln_tool_mouse_x()>=1128 && ln_tool_mouse_x()<1272 && ln_tool_mouse_y()>=4 && ln_tool_mouse_y()<32)) ln_fullscreen_toggle(_host);
    if(is_struct(_host.cinematic_window)) {
        var _movie=_host.play.game_number==3 && (is_struct(_host.play.intro) || is_struct(_host.play.ending));
        window_set_cursor(_movie && !_host.scene_test.menu && !_host.workbench?cr_none:_host.cinematic_window.cursor);
    }
}

// User preferences are independent of gameplay saves and rewind snapshots.
function ln_crt_preference_fields() {
    return ["ln_crt_enabled","ln_crt_blur","ln_crt_honeycomb","ln_crt_scanlines",
        "ln_scan_width","ln_scan_align","ln_scan_soft","ln_scan_preset","ln_crt_phosphor","ln_crt_pitch"];
}
function ln_crt_preferences_read(_file="LNPreserve.ini") {
    ln_crt_tuning_init();
    var _fields=ln_crt_preference_fields();
    var _defaults=[0,0.15,0.35,0.20,5,0.5,1,-1,1,1];
    var _low=[0,0,0,0,1,0,0,-1,0,0.5],_high=[1,1,1,1,7,1,1,3,1,2];
    ini_open(_file);
    for(var _i=0;_i<array_length(_fields);_i++) {
        var _value=ini_read_real("CRT",_fields[_i],_defaults[_i]);
        if(is_nan(_value) || is_infinity(_value)) _value=_defaults[_i];
        _value=clamp(_value,_low[_i],_high[_i]);
        if(_i==0) _value=(_value>=0.5);
        if(_i==7 || _i==8) _value=round(_value);
        variable_global_set(_fields[_i],_value);
    }
    var _speed=ini_read_real("ScenePainting","speed",1);
    global.ln_paint_speed=(is_nan(_speed) || is_infinity(_speed))?1:clamp(_speed,0.1,4);
    global.ln_tool.ui=ini_read_real("Tool","ui_visible",1)>=0.5;global.ln_tool.background=ini_read_real("Tool","background_visible",1)>=0.5;
    global.ln_editor.crt_enabled=ini_read_real("Editor","crt_enabled",0)>=0.5;
    ini_close();
}
function ln_crt_preferences_signature() {
    var _fields=ln_crt_preference_fields(),_values=[];
    for(var _i=0;_i<array_length(_fields);_i++) array_push(_values,variable_global_get(_fields[_i]));
    array_push(_values,global.ln_paint_speed);array_push(_values,global.ln_editor.crt_enabled);array_push(_values,global.ln_tool.ui);array_push(_values,global.ln_tool.background);
    return json_stringify(_values);
}
function ln_crt_preferences_write(_file="LNPreserve.ini") {
    var _fields=ln_crt_preference_fields();
    ini_open(_file);
    for(var _i=0;_i<array_length(_fields);_i++) ini_write_real("CRT",_fields[_i],real(variable_global_get(_fields[_i])));
    ini_write_real("ScenePainting","speed",global.ln_paint_speed);
    ini_write_real("Editor","crt_enabled",real(global.ln_editor.crt_enabled));
    ini_write_real("Tool","ui_visible",real(global.ln_tool.ui));ini_write_real("Tool","background_visible",real(global.ln_tool.background));
    ini_close();
}
function ln_crt_preferences_flush(_force=false) {
    if(!variable_global_exists("ln_preferences_enabled") || !global.ln_preferences_enabled) return;
    if(!_force && mouse_check_button(mb_left)) return;
    var _signature=ln_crt_preferences_signature();
    if(_signature==global.ln_preferences_saved) return;
    ln_crt_preferences_write();global.ln_preferences_saved=_signature;
}
function ln_crt_preferences_checks() {
    ln_crt_tuning_init();
    var _saved=json_parse(ln_crt_preferences_signature()),_fields=ln_crt_preference_fields();
    var _file="crt_preferences_test_"+string(get_timer())+".ini";
    ln_crt_preferences_read(_file);
    ln_check(!global.ln_crt_enabled && global.ln_crt_blur==0.15,"CRT missing INI uses defaults");
    var _expected=[true,0.23,0.67,0.81,4.25,0.73,0.42,2,1,1.37];
    for(var _i=0;_i<array_length(_fields);_i++) variable_global_set(_fields[_i],_expected[_i]);
    ln_crt_preferences_write(_file);
    for(var _i=0;_i<array_length(_fields);_i++) variable_global_set(_fields[_i],0);
    ln_crt_preferences_read(_file);
    for(var _i=0;_i<array_length(_fields);_i++) ln_check(abs(real(variable_global_get(_fields[_i]))-real(_expected[_i]))<=0.00001,"CRT INI round trip "+_fields[_i]+" got="+string(variable_global_get(_fields[_i]))+" expected="+string(_expected[_i]));
    global.ln_crt_enabled=false;ln_crt_preferences_write(_file);global.ln_crt_enabled=true;
    ln_crt_preferences_read(_file);ln_check(!global.ln_crt_enabled,"CRT off persists with tuning intact");
    ini_open(_file);ini_write_real("CRT","ln_scan_width",99);ini_write_real("CRT","ln_crt_blur",-2);ini_close();
    ln_crt_preferences_read(_file);ln_check(global.ln_scan_width==7 && global.ln_crt_blur==0,"CRT INI clamps invalid ranges");
    global.ln_tool.ui=false;global.ln_tool.background=false;ln_crt_preferences_write(_file);
    global.ln_tool.ui=true;global.ln_tool.background=true;ln_crt_preferences_read(_file);
    ln_check(!global.ln_tool.ui && !global.ln_tool.background,"UI and background visibility persist independently");
    file_delete(_file);
    for(var _i=0;_i<array_length(_fields);_i++) variable_global_set(_fields[_i],_saved[_i]);
    global.ln_editor.crt_enabled=_saved[array_length(_fields)+1];
    global.ln_tool.ui=_saved[array_length(_fields)+2];global.ln_tool.background=_saved[array_length(_fields)+3];
    show_debug_message("LN_CRT_PREFERENCES_PASS");
}


// A 1920x1080 presentation canvas wraps the preserved 1280x800 tool coordinates.
// Native game pixels keep their existing integer scale; UI artwork is independent.
function ln_tool_init() {
    global.ln_tool={active:true,drawing:false,surface:-1,camera:-1,output_camera:-1,ui:true,background:true,view:undefined,projection:undefined,layout_test:false,frame:0};
    for(var _arg=1;_arg<=parameter_count();_arg++) {
        if(string_pos("--",parameter_string(_arg))==1) global.ln_tool.active=false;
        if(parameter_string(_arg)=="--tool-layout-test") global.ln_tool.layout_test=true;
    }
    if(global.ln_tool.layout_test) global.ln_tool.active=true;
}
function ln_tool_begin(_host) {
    var _t=global.ln_tool;if(!_t.active) return;
    if(!surface_exists(_t.surface)) _t.surface=surface_create(1280,800);
    if(_t.camera<0) _t.camera=camera_create_view(0,0,1280,800);
    _t.view=matrix_get(matrix_view);_t.projection=matrix_get(matrix_projection);
    surface_set_target(_t.surface);camera_apply(_t.camera);_t.drawing=true;draw_clear_alpha(c_black,0);
}
function ln_tool_clear(_game=true) {
    if(!global.ln_tool.drawing) {draw_clear(_game?c_black:make_colour_rgb(20,23,28));return;}
    draw_clear_alpha(c_black,0);
    if(_game) {draw_set_colour(c_black);draw_rectangle(160,84,1119,683,false);draw_set_colour(c_white);}
}
function ln_tool_rect(_host) {
    if(global.ln_editor.open) return [24,140,720,432];
    if(_host.workbench || _host.scene_test.menu || _host.scene_test.preview) return [0,0,1280,800];
    var _region=ln_crt_game_region(_host);
    return is_array(_region)?[_region[0],_region[1],_region[2]-_region[0],_region[3]-_region[1]]:[0,0,1280,800];
}
function ln_tool_present(_host) {
    var _t=global.ln_tool,_rect;if(!_t.drawing) return;
    draw_flush();surface_reset_target();
    if(_t.output_camera<0) _t.output_camera=camera_create_view(0,0,1920,1080);
    camera_apply(_t.output_camera);_t.drawing=false;
    shader_reset();gpu_set_blendmode(bm_normal);gpu_set_ztestenable(false);gpu_set_zwriteenable(false);
    draw_clear(c_black);draw_set_colour(c_white);draw_set_alpha(1);
    if(_t.background) draw_sprite_stretched(spr_LNHDbkg,0,0,0,1920,1080);
    if(_t.ui) draw_surface(_t.surface,320,140);
    else {_rect=ln_tool_rect(_host);draw_surface_part(_t.surface,_rect[0],_rect[1],_rect[2],_rect[3],(1920-_rect[2])/2,(1080-_rect[3])/2);}
    draw_flush();
    // Visibility buttons remain reachable when the other controls are hidden.
    draw_set_font(font_jansina);draw_set_halign(fa_left);draw_set_valign(fa_top);
    ln_edit_button(320,96,160,"UI "+(_t.ui?"ON":"OFF")+" (U)",_t.ui);
    ln_edit_button(492,96,240,"Background "+(_t.background?"ON":"OFF")+" (B)",_t.background);draw_flush();
    ln_edit_button(1100,96,60,"1x");ln_edit_button(1168,96,60,"2x");ln_edit_button(1236,96,60,"Fit");
    ln_edit_button(1310,96,210,"Fullscreen (F9)",window_get_fullscreen());draw_flush();
}
function ln_tool_step(_host) {
    var _t=global.ln_tool,_click=mouse_check_button_pressed(mb_left),_typing=global.ln_editor.open && global.ln_editor.depth_edit;
    if(!_t.active) return;
    if(_click && mouse_y>=96 && mouse_y<124) {
        if(mouse_x>=1100 && mouse_x<1160) ln_window_preset(1);
        if(mouse_x>=1168 && mouse_x<1228) ln_window_preset(2);
        if(mouse_x>=1236 && mouse_x<1296) ln_window_preset(0);
        if(mouse_x>=1310 && mouse_x<1520) ln_fullscreen_toggle(_host);
    }
    if(!_typing && (keyboard_check_pressed(ord("U")) || (_click && mouse_x>=320 && mouse_x<480 && mouse_y>=96 && mouse_y<124))) _t.ui=!_t.ui;
    if(!_typing && (keyboard_check_pressed(ord("B")) || (_click && mouse_x>=492 && mouse_x<732 && mouse_y>=96 && mouse_y<124))) _t.background=!_t.background;
    ln_crt_preferences_flush();
}
function ln_tool_mouse_x() {
    if(!global.ln_tool.active) return mouse_x;
    if(global.ln_tool.ui) return mouse_x-320;
    if(global.ln_editor.open && mouse_x>=600 && mouse_x<1320 && mouse_y>=324 && mouse_y<756) return mouse_x-576;
    return -10000;
}
function ln_tool_mouse_y() {
    if(!global.ln_tool.active) return mouse_y;
    if(global.ln_tool.ui) return mouse_y-140;
    if(global.ln_editor.open && mouse_x>=600 && mouse_x<1320 && mouse_y>=324 && mouse_y<756) return mouse_y-184;
    return -10000;
}
function ln_tool_free() {
    var _t=global.ln_tool;if(surface_exists(_t.surface)) surface_free(_t.surface);
    if(_t.camera>=0) camera_destroy(_t.camera);
    if(_t.output_camera>=0) camera_destroy(_t.output_camera);
}
