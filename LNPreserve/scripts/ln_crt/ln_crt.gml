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
        shader_set_uniform_f(shader_get_uniform(sh_ln_crt,"u_tone"),global.ln_crt_exposure,global.ln_crt_contrast);
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
    if (_tuning && global.ln_crt_enabled && _pressed && _mx>=800 && _mx<=940) {
        if (abs(_my-732)<=10) global.ln_crt_drag=3;
        if (abs(_my-776)<=10) global.ln_crt_drag=4;
    }
    if (_tuning && global.ln_crt_enabled && _pressed && _mx>=955 && _mx<=1100) {
        if (abs(_my-732)<=10) global.ln_crt_drag=6;
        if (abs(_my-776)<=10) global.ln_crt_drag=7;
    }
    if (global.ln_crt_enabled && _held && global.ln_crt_drag>=6) {
        var _tone=clamp((_mx-965)/125,0,1);
        if(global.ln_crt_drag==6) global.ln_crt_exposure=-2+4*_tone;
        else global.ln_crt_contrast=0.5+1.5*_tone;
        return;
    }
    if (global.ln_crt_enabled && _held && global.ln_crt_drag>=3) {
        var _t=clamp((_mx-810)/125,0,1);global.ln_scan_soft=1;global.ln_scan_preset=-1;
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

function ln_window_preset_factor(_factor,_width,_height) {
    if(_factor==0) return ln_window_fit_factor(_width,_height);
    // Leave room for window borders, title bar and the taskbar, like Fit.
    return min(_factor,max(0.1,min((_width-32)/1920,(_height-96)/1080)));
}

function ln_window_preset(_factor) {
    _factor=ln_window_preset_factor(_factor,display_get_width(),display_get_height());
    var _w=round(1920*_factor),_h=round(1080*_factor);
    if(window_get_fullscreen()) {
        if(variable_instance_exists(self,"cinematic_window") && is_struct(cinematic_window)) ln_cinematic_restore(self);
        else window_set_fullscreen(false);
    }
    window_set_size(_w,_h);window_center();
}

function ln_window_buttons(_tips=true) {
    draw_set_colour(make_colour_rgb(24,28,34));draw_rectangle(1128,602,1272,648,false);
    draw_set_colour(make_colour_rgb(150,190,215));
    draw_text(1136,604,string(window_get_width())+"x"+string(window_get_height()));
    var _labels=["1x","2x","Fit"];
    for (var _i=0;_i<3;_i++) {
        var _x=1132+46*_i,_hover=ln_tool_mouse_x()>=_x && ln_tool_mouse_x()<_x+42 && ln_tool_mouse_y()>=624 && ln_tool_mouse_y()<645;
        var _selected=(_i==0 && window_get_width()==1920 && window_get_height()==1080) ||
            (_i==1 && window_get_width()==3840 && window_get_height()==2160);
        ln_ui_button_background(_x,624,42,20,_selected);
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
    ln_ui_button_background(1128,36,144,36,global.ln_crt_enabled);
    var _label_colour=_hover?c_white:make_colour_rgb(150,190,215);
    draw_set_colour(global.ln_crt_enabled?_label_colour:merge_colour(_label_colour,c_black,0.5));
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
    global.ln_crt_enabled=true;var _tone_saved=[global.ln_crt_exposure,global.ln_crt_contrast],_tone_pixels=[];
    for(var _tone_case=0;_tone_case<3;_tone_case++) {
        global.ln_crt_exposure=_tone_case==1?1:0;global.ln_crt_contrast=_tone_case==2?1.5:1;
        surface_set_target(_output);ln_crt_surface(_source,0,0,3);surface_reset_target();
        array_push(_tone_pixels,colour_get_red(surface_getpixel(_output,300,300)));
    }
    ln_check(_tone_pixels[1]>_tone_pixels[0] && _tone_pixels[2]<_tone_pixels[0],"exposure brightens and contrast deepens dark tones on GPU");
    ln_crt_slider_input(1090,732,true,true);ln_crt_slider_input(1090,732,false,false);
    ln_check(global.ln_crt_exposure==2 && global.ln_crt_drag==-1,"exposure track updates and releases");
    ln_crt_slider_input(965,776,true,true);ln_crt_slider_input(965,776,false,false);
    ln_check(global.ln_crt_contrast==0.5,"contrast track updates independently");
    global.ln_crt_exposure=_tone_saved[0];global.ln_crt_contrast=_tone_saved[1];global.ln_crt_enabled=false;
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
    if (!variable_global_exists("ln_crt_exposure")) {global.ln_crt_exposure=0;global.ln_crt_contrast=1;}
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
        ln_ui_button_background(_x,716,140,28,global.ln_scan_preset==_i);draw_set_colour(c_white);draw_text(_x+8,721,_names[_i]);
    }
    for(var _style=0;_style<2;_style++) {
        ln_ui_button_background(172+108*_style,756,104,30,global.ln_crt_phosphor==1-_style);
        draw_set_colour(c_white);draw_text(180+108*_style,761,_style==0?"Phosphor":"Classic");
    }
    draw_set_colour(c_white);draw_text_transformed(400,750,"Spacing "+string_format(global.ln_crt_pitch,1,2)+"x",0.85,0.85,0);
    draw_set_colour(make_colour_rgb(65,73,84));draw_rectangle(490,774,760,778,false);
    draw_set_colour(make_colour_rgb(180,215,236));draw_circle(490+270*(global.ln_crt_pitch-0.5)/1.5,776,5,false);
    for(var _i=0;_i<2;_i++) {
        var _y=732+44*_i,_value=_i==0?(global.ln_scan_width-1)/6:global.ln_scan_align;
        var _label=_i==0?"Width "+string_format(global.ln_scan_width,1,1)+" rows":"Alignment "+string(round(global.ln_scan_align*100))+"%";
        draw_set_colour(c_white);draw_text_transformed(810,_y-24,_label,0.75,0.75,0);
        draw_set_colour(make_colour_rgb(65,73,84));draw_rectangle(810,_y-2,935,_y+2,false);
        draw_set_colour(make_colour_rgb(180,215,236));draw_circle(810+125*_value,_y,5,false);
        var _tone_value=_i==0?(global.ln_crt_exposure+2)/4:(global.ln_crt_contrast-0.5)/1.5;
        var _tone_label=_i==0?"Exposure "+string_format(global.ln_crt_exposure,1,1):"Contrast "+string(round(global.ln_crt_contrast*100))+"%";
        draw_set_colour(c_white);draw_text_transformed(965,_y-24,_tone_label,0.75,0.75,0);
        draw_set_colour(make_colour_rgb(65,73,84));draw_rectangle(965,_y-2,1090,_y+2,false);
        draw_set_colour(make_colour_rgb(180,215,236));draw_circle(965+125*_tone_value,_y,5,false);
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
    if(keyboard_check_pressed(vk_f9)) ln_fullscreen_toggle(_host);
    if(is_struct(_host.cinematic_window)) {
        var _movie=_host.play.game_number==3 && (is_struct(_host.play.intro) || is_struct(_host.play.ending));
        window_set_cursor(_movie && !_host.scene_test.menu && !_host.workbench?cr_none:_host.cinematic_window.cursor);
    }
}

// User preferences are independent of gameplay saves and rewind snapshots.
function ln_crt_preference_fields() {
    return ["ln_crt_enabled","ln_crt_blur","ln_crt_honeycomb","ln_crt_scanlines",
        "ln_scan_width","ln_scan_align","ln_scan_soft","ln_scan_preset","ln_crt_phosphor","ln_crt_pitch","ln_crt_exposure","ln_crt_contrast"];
}
function ln_crt_preferences_read(_file="LNPreserve.ini") {
    ln_crt_tuning_init();
    var _fields=ln_crt_preference_fields();
    var _defaults=[0,0.15,0.35,0.20,5,0.5,1,-1,1,1,0,1];
    var _low=[0,0,0,0,1,0,0,-1,0,0.5,-2,0.5],_high=[1,1,1,1,7,1,1,3,1,2,2,2];
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
    global.ln_paint_speed=(is_nan(_speed) || is_infinity(_speed))?1:clamp(_speed,0.1,5);
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
    var _expected=[true,0.23,0.67,0.81,4.25,0.73,0.42,2,1,1.37,0.75,1.25];
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
    if(ln_tool_ui_visible() && (_host.workbench || _host.scene_test.menu || _host.scene_test.preview)) return [0,0,1280,800];
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
    if(_host.startup_active) {ln_startup_draw(_host);draw_flush();return;}
    if(ln_tool_ui_visible()) draw_surface(_t.surface,320,140);
    else {_rect=ln_tool_rect(_host);draw_surface_part(_t.surface,_rect[0],_rect[1],_rect[2],_rect[3],(1920-_rect[2])/2,(1080-_rect[3])/2);}
    draw_flush();
    if(!ln_tool_ui_visible()) return;
    // F6 always shows the editor; U controls gameplay UI only.
    draw_set_font(font_jansina);draw_set_halign(fa_left);draw_set_valign(fa_top);
    ln_edit_button(320,96,160,global.ln_editor.open?"USER INT. (ON)":"USER INT. (U)",true);
    ln_edit_button(492,96,240,"Background "+(_t.background?"ON":"OFF")+" (B)",_t.background);draw_flush();
    var _media=ln_tool_media_rect();
    ln_edit_button(_media[0],_media[1],150,global.ln_sprites.open?"Close sprites":"Sprite viewer");
    ln_edit_button(_media[0]+160,_media[1],140,global.ln_tracks.open?"Close tracks":"Track player");
    var _music=ln_tool_music_enabled(_host.play);
    if(global.ln_editor.open && !is_undefined(global.ln_editor.test_music_restore)) _music=global.ln_editor.test_music_restore;
    ln_edit_button(_media[0]+310,_media[1],120,"Music "+(_music?"ON":"OFF"),_music);
    if(ln_track_message()!="") {
        draw_set_colour(c_white);
        draw_text(_media[0],_media[1]+32,global.ln_tracks.paused?"PAUSED: Track:":"PLAYING: Track:");
        draw_text(_media[0],_media[1]+54,global.ln_tracks.tracks[global.ln_tracks.current].title);
    }
    if(!global.ln_editor.open && !global.ln_tracks.open && !global.ln_sprites.open) ln_edit_button(748,96,180,"EDITOR (F6)");
    if(!global.ln_editor.open && !global.ln_tracks.open && !global.ln_sprites.open) ln_edit_button(940,96,238,_host.scene_test.menu?"Back to game (F11)":"GAME/LEVELS (F11)");
    ln_edit_button(1256,96,48,"1x");ln_edit_button(1312,96,48,"2x");ln_edit_button(1368,96,48,"Fit");
    ln_edit_button(1424,96,176,"Fullscreen (F9)");draw_flush();
}
function ln_tool_step(_host) {
    var _t=global.ln_tool,_click=mouse_check_button_pressed(mb_left),_typing=global.ln_editor.open && global.ln_editor.depth_edit;
    if(!_t.active) return;
    if(ln_tool_media_hit(2)) {
        var _e=global.ln_editor;
        if(_e.open && !is_undefined(_e.test_music_restore)) _e.test_music_restore=!_e.test_music_restore;
        else ln_tool_music_set(_host.play,!ln_tool_music_enabled(_host.play));
    }
    if(ln_tool_ui_visible() && _click && mouse_y>=96 && mouse_y<124) {
        if(!global.ln_editor.open && !global.ln_tracks.open && !global.ln_sprites.open && mouse_x>=748 && mouse_x<928) global.ln_editor.toggle_requested=true;
        if(mouse_x>=1256 && mouse_x<1304) ln_window_preset(1);
        if(mouse_x>=1312 && mouse_x<1360) ln_window_preset(2);
        if(mouse_x>=1368 && mouse_x<1416) ln_window_preset(0);
        if(mouse_x>=1424 && mouse_x<1600) ln_fullscreen_toggle(_host);
    }
    if(!_typing && !global.ln_editor.open && (keyboard_check_pressed(ord("U")) || (ln_tool_ui_visible() && _click && mouse_x>=320 && mouse_x<480 && mouse_y>=96 && mouse_y<124))) _t.ui=!_t.ui;
    if(!_typing && (keyboard_check_pressed(ord("B")) || (ln_tool_ui_visible() && _click && mouse_x>=492 && mouse_x<732 && mouse_y>=96 && mouse_y<124))) _t.background=!_t.background;
    ln_crt_preferences_flush();
}
function ln_tool_mouse_x() {
    if(!global.ln_tool.active) return mouse_x;
    if(ln_tool_ui_visible()) return mouse_x-320;
    if(global.ln_editor.open && mouse_x>=600 && mouse_x<1320 && mouse_y>=324 && mouse_y<756) return mouse_x-576;
    return -10000;
}
function ln_tool_mouse_y() {
    if(!global.ln_tool.active) return mouse_y;
    if(ln_tool_ui_visible()) return mouse_y-140;
    if(global.ln_editor.open && mouse_x>=600 && mouse_x<1320 && mouse_y>=324 && mouse_y<756) return mouse_y-184;
    return -10000;
}
function ln_tool_free() {
    var _t=global.ln_tool;if(surface_exists(_t.surface)) surface_free(_t.surface);
    if(_t.camera>=0) camera_destroy(_t.camera);
    if(_t.output_camera>=0) camera_destroy(_t.output_camera);
}

function ln_tool_ui_visible() {return global.ln_editor.open || global.ln_tool.ui || (variable_global_exists("ln_tracks") && global.ln_tracks.open) || (variable_global_exists("ln_sprites") && global.ln_sprites.open);}

function ln_tool_menu_pressed() {
    return global.ln_tool.active && ln_tool_ui_visible() && !global.ln_editor.open &&
        mouse_check_button_pressed(mb_left) && mouse_x>=940 && mouse_x<1178 && mouse_y>=96 && mouse_y<124;
}

function ln_startup_step(_host) {
    _host.startup_time+=_host.startup_test?1/60:min(delta_time/1000000,0.05);
    if(_host.startup_test) _host.startup_frame++;
    if(!_host.startup_sound_started && _host.startup_time>=0.15) {
        _host.startup_sound_started=true;_host.startup_sound=audio_play_sound(sfx_sword,10,false);
    }
    if(keyboard_check_pressed(vk_f9)) ln_fullscreen_toggle(_host);
    if(_host.startup_time>=1.05 && mouse_check_button_pressed(mb_left) && mouse_x>=750 && mouse_x<1170 && mouse_y>=640 && mouse_y<704) ln_startup_finish(_host);
    if(_host.startup_test && _host.startup_frame==110) ln_startup_finish(_host);
}
function ln_startup_finish(_host) {
    global.ln_tool.ui=true;
    _host.startup_active=false;
    if(_host.startup_music>=0 && audio_is_paused(_host.startup_music)) audio_resume_sound(_host.startup_music);
    _host.input_state=new LNInput();
}
function ln_startup_draw(_host) {
    // Startup owns the complete 1920x1080 canvas, independent of UI/B preferences.
    draw_sprite_stretched(spr_LNHDbkg,0,0,0,1920,1080);
    draw_set_colour(c_black);draw_set_alpha(0.56);draw_rectangle(0,0,1920,1080,false);draw_set_alpha(1);
    var _t=_host.startup_time;
    if(_t>=0.15 && _t<1.05) {
        // Integrating exponential velocity gives 1x at the start, 2x at
        // the end, relative to the old 0.9-second traversal speed.
        var _duration=0.9*ln(2),_elapsed=_t-0.15;
        // Six historical poses, oldest/faintest first, behind the crisp sword.
        for(var _trail=6;_trail>=0;_trail--) {
            var _sample=_elapsed-_trail*0.014;
            if(_sample<0 || _sample>_duration) continue;
            var _progress=power(2,_sample/_duration)-1;
            var _opacity=_trail==0?1:0.28*(7-_trail)/6;
            draw_sprite_ext(spr_sword,0,1540,lerp(100,1190,_progress),1,1,
                lerp(-22,18,_progress),c_white,_opacity);
        }
    }
    if(_t>=1.05) {
        var _alpha=clamp((_t-1.05)/0.25,0,1);
        draw_set_font(font_jansina);draw_set_halign(fa_center);draw_set_valign(fa_middle);draw_set_colour(c_white);draw_set_alpha(_alpha);
        draw_set_font(font_jansina_big);draw_text(960,430,"LAST NINJA REVISITED");
        draw_set_font(font_jansina);draw_text(960,525,"PLAYER  -  EDITOR  -  V "+_host.startup_version);
        draw_set_alpha(1);ln_ui_button_background(750,640,420,64,true);
        draw_set_colour(c_white);draw_set_font(font_jansina_big);draw_text(960,672,"CLICK TO BEGIN");
        draw_set_font(font_jansina);
        draw_set_halign(fa_left);draw_set_valign(fa_top);
    }
    draw_set_alpha(1);draw_set_colour(c_white);
}

// Window preferences have their own debounce; CRT changes never overwrite them.
function ln_window_size_limit(_w,_h,_dw,_dh) {
    var _maxw=max(240,_dw-32),_maxh=max(160,_dh-96);
    if(is_nan(_w) || is_infinity(_w) || _w<240 || is_nan(_h) || is_infinity(_h) || _h<160) {
        var _fit=ln_window_fit_factor(_dw,_dh);_w=round(1920*_fit);_h=round(1080*_fit);
    }
    var _scale=min(1,_maxw/_w,_maxh/_h);
    return [max(1,round(_w*_scale)),max(1,round(_h*_scale))];
}
function ln_window_preferences_read(_file="LNPreserve.ini") {
    ini_open(_file);
    var _w=ini_read_real("Window","width",0),_h=ini_read_real("Window","height",0);
    var _full=ini_read_real("Window","fullscreen",0);ini_close();
    var _size=ln_window_size_limit(_w,_h,display_get_width(),display_get_height());
    return {width:_size[0],height:_size[1],fullscreen:!is_nan(_full) && !is_infinity(_full) && _full>=0.5};
}
function ln_window_preferences_write(_state,_file="LNPreserve.ini") {
    ini_open(_file);ini_write_real("Window","width",_state.width);ini_write_real("Window","height",_state.height);
    ini_write_real("Window","fullscreen",real(_state.fullscreen));ini_close();
}
function ln_window_preferences_restore(_host,_file="LNPreserve.ini") {
    var _state=ln_window_preferences_read(_file);
    window_set_fullscreen(false);_host.cinematic_window=undefined;
    window_set_size(_state.width,_state.height);window_center();
    if(_state.fullscreen) {
        // Keep the windowed dimensions even when fullscreen changes are asynchronous.
        _host.cinematic_window={width:_state.width,height:_state.height,x:window_get_x(),y:window_get_y(),cursor:window_get_cursor()};
        window_enable_borderless_fullscreen(true);window_set_fullscreen(true);
    }
    global.ln_window_preferences={state:_state,saved:json_stringify(_state),pending:json_stringify(_state),quiet:0};
}
function ln_window_preferences_capture(_host) {
    var _full=window_get_fullscreen(),_w=window_get_width(),_h=window_get_height();
    if(_full) {
        if(variable_instance_exists(_host,"cinematic_window") && is_struct(_host.cinematic_window)) {
            _w=_host.cinematic_window.width;_h=_host.cinematic_window.height;
        } else if(variable_global_exists("ln_window_preferences")) {
            _w=global.ln_window_preferences.state.width;_h=global.ln_window_preferences.state.height;
        }
    }
    return {width:_w,height:_h,fullscreen:_full};
}
function ln_window_preferences_flush(_host,_force=false) {
    if(!global.ln_preferences_enabled || !variable_global_exists("ln_window_preferences")) return;
    var _p=global.ln_window_preferences,_state=ln_window_preferences_capture(_host);
    if(_state.width<=0 || _state.height<=0) return;
    var _signature=json_stringify(_state);
    if(_signature!=_p.pending) {_p.pending=_signature;_p.quiet=0;}
    else _p.quiet+=min(delta_time/1000000,.1);
    _p.state=_state;
    if(_signature==_p.saved || (!_force && (_p.quiet<.4 || mouse_check_button(mb_left)))) return;
    ln_window_preferences_write(_state);_p.saved=_signature;
}
function ln_window_preferences_test_step(_host) {
    var _phase=_host.window_preferences_frame++;
    if(_phase==0) {
        _host.window_preferences_file="window_preferences_test_"+string(get_timer())+".ini";
        var _file=_host.window_preferences_file;
        ini_open(_file);ini_write_real("CRT","keep",42);ini_close();
        ln_window_preferences_write({width:960,height:540,fullscreen:false},_file);
        var _round=ln_window_preferences_read(_file);
        ln_check(_round.width==960 && _round.height==540 && !_round.fullscreen,"window INI round trip");
        ini_open(_file);ln_check(ini_read_real("CRT","keep",0)==42,"window preferences preserve other sections");ini_close();
        var _small=ln_window_size_limit(3840,2160,1920,1080);
        ln_check(_small[0]<=1888 && _small[1]<=984,"large window fits smaller display");
        var _bad=ln_window_size_limit(-1,0,1920,1080);
        ln_check(_bad[0]>0 && _bad[1]>0 && _bad[1]<=984,"invalid dimensions use Fit");
        ln_window_preferences_restore(_host,_file);
    } else if(_phase==3) {
        ln_check(!window_get_fullscreen() && window_get_width()==960 && window_get_height()==540,"startup restores window size");
        ln_fullscreen_toggle(_host);
    } else if(_phase==6) {
        var _state=ln_window_preferences_capture(_host);
        ln_check(_state.fullscreen && _state.width==960 && _state.height==540,"fullscreen capture retains windowed dimensions");
        ln_window_preferences_write(_state,_host.window_preferences_file);
        ln_cinematic_restore(_host);
    } else if(_phase==9) {
        ln_window_preferences_restore(_host,_host.window_preferences_file);
    } else if(_phase==12) {
        ln_check(window_get_fullscreen(),"startup restores fullscreen");ln_fullscreen_toggle(_host);
    } else if(_phase==15) {
        ln_check(!window_get_fullscreen() && window_get_width()==960 && window_get_height()==540,"F9 restores remembered window after fullscreen restart");
        file_delete(_host.window_preferences_file);show_debug_message("LN_WINDOW_PREFERENCES_PASS");game_end();
    }
}

function LNEscapeControl() constructor {
    down=false;held=0;gap=1;armed=false;fired=false;can_die=false;
}
// Returns 1 for a gameplay hold, 2 for two short presses. Key repeat cannot retrigger it.
function ln_escape_gesture(_c,_down,_dt,_eligible) {
    if(!_down) {
        if(_c.down) {_c.armed=!_c.fired && _c.held<.35;_c.gap=0;}
        _c.down=false;_c.held=0;_c.fired=false;_c.gap+=_dt;
        if(_c.gap>.35) _c.armed=false;
        return 0;
    }
    if(!_c.down) {
        _c.down=true;_c.held=0;_c.can_die=_eligible;
        if(_c.armed && _c.gap<=.35) {_c.armed=false;_c.fired=true;return 2;}
    }
    _c.held+=_dt;
    if(!_eligible) _c.can_die=false;
    if(!_c.fired && _c.can_die && _c.held>=1) {_c.fired=true;_c.armed=false;return 1;}
    return 0;
}
function ln_escape_gameplay(_host) {
    if(_host.startup_active || _host.workbench || _host.scene_test.menu || _host.scene_test.preview ||
        global.ln_editor.open || global.ln_tracks.open || global.ln_sprites.open) return false;
    var _g=_host.play;
    if(_g.game_over || _g.level_complete || is_struct(_g.loader)) return false;
    if(variable_struct_exists(_g,"paused") && _g.paused) return false;
    if(_g.game_number==1) return _host.control_state_ln1.pause==0 && _g.player_health>0 && _g.death_wait==0 && !is_struct(_g.death_transition);
    if(_g.game_number==2) return _g.player_health>0 && _g.respawn_wait==0 && !is_struct(_g.life_transition) && _g.victory==0;
    return _g.state.player_health>0 && _g.state.player_dead==0 && _g.special_sequence==0 && !is_struct(_g.intro) && !is_struct(_g.ending);
}
function ln_self_death(_g) {
    // Enter native death playback; life deduction and game-over remain game-owned.
    if(_g.game_number==1) {
        if(_g.player_health<=0 || _g.death_wait>0) return false;
        var _p=_g.player;
        _g.pickup_assist=undefined;_p.jump_assist=undefined;_g.sequence_kind=0;_g.water_active=false;
        _g.player_health=0;_p.facing=((_p.facing&4)^6)>>1;
        _p.action=23860;_p.flags=variable_struct_get(_g.data.actions,string(_p.action)).flags;
        _p.countdown=0;_p.saved_heading=_p.heading;_p.action_mirror=_p.facing&2;_p.input_lock=255;
    } else if(_g.game_number==2) {
        if(_g.player_health<=0 || _g.respawn_wait>0) return false;
        _g.pickup_assist=undefined;_g.keypad=undefined;_g.fall_remaining=-1;
        ln2_fall_death_begin(_g);
    } else {
        var _s=_g.state;if(_s.player_health<=0 || _s.player_dead!=0) return false;
        _g.pickup_assist=undefined;_s.reverse_roll=undefined;_s.input_block=0;_s.climb_flags=0;_s.stun=0;
        _s.player_health=0;_s.inventory[26]=0;_s.player_dead=1;_s.death_wait=50;_s.logic_wait=0;
        ln3_action_set(_s,_g.actions,20);
    }
    return true;
}
function ln_escape_step(_host) {
    var _event=ln_escape_gesture(_host.escape_control,keyboard_check(vk_escape),min(delta_time/1000000,.1),ln_escape_gameplay(_host));
    if(_event==2) {
        ln_window_preferences_flush(_host,true);ln_crt_preferences_flush(true);
        game_restart();return true;
    }
    if(_event==1) ln_self_death(_host.play);
    return false;
}
function ln_escape_checks() {
    var _c=new LNEscapeControl();
    ln_check(ln_escape_gesture(_c,true,.05,true)==0,"single press stays available to panels");
    ln_escape_gesture(_c,false,.05,true);
    ln_check(ln_escape_gesture(_c,true,.05,true)==2,"fast second press requests app reset");
    repeat(30) ln_check(ln_escape_gesture(_c,true,.1,true)==0,"held second press cannot trigger death or more resets");
    _c=new LNEscapeControl();var _deaths=0;
    repeat(30) _deaths+=ln_escape_gesture(_c,true,.1,true)==1;
    ln_check(_deaths==1,"one-second hold requests exactly one death");
    ln_escape_gesture(_c,false,.01,true);
    ln_check(ln_escape_gesture(_c,true,.05,true)==0,"hold then tap is not a reset");
    _c=new LNEscapeControl();ln_escape_gesture(_c,true,.1,false);
    repeat(20) ln_check(ln_escape_gesture(_c,true,.1,true)==0,"hold begun in panel cannot kill after closing it");
    _c=new LNEscapeControl();ln_escape_gesture(_c,true,.05,true);ln_escape_gesture(_c,false,.5,true);
    ln_check(ln_escape_gesture(_c,true,.05,true)==0,"slow taps do not reset");
    for(var _game=1;_game<=3;_game++) {
        var _g=_game==1?new LN1Play():(_game==2?new LN2Play():new LN3Play());
        var _lives=_game==3?_g.state.lives:_g.lives_left;
        ln_check(ln_self_death(_g),"self-death begins in LN"+string(_game));
        ln_check(!ln_self_death(_g),"self-death cannot restart an active death");
        var _ticks=0;
        while((_game==3?_g.state.lives:_g.lives_left)==_lives && _ticks++<3000) {
            if(_game==1) ln1_play_tick(_g,0);else if(_game==2) ln2_play_tick(_g,0);else ln3_play_tick(_g,0);
        }
        ln_check((_game==3?_g.state.lives:_g.lives_left)==_lives-1,"native death deducts one life in LN"+string(_game));
    }
    show_debug_message("LN_ESCAPE_CONTROLS_PASS");
}

// Shared drawing/hit rectangles keep the compact media row together on each screen.
function ln_tool_media_rect() {

    if(instance_exists(obj_ln_preserve) && obj_ln_preserve.scene_test.menu) return [1080,814];
    return [1080+40,900+40];
}
function ln_tool_media_hit(_button) {
    var _r=ln_tool_media_rect(),_offset=[0,160,310],_width=[150,140,120];
    return global.ln_tool.active && ln_tool_ui_visible() && mouse_check_button_pressed(mb_left) &&
        mouse_x>=_r[0]+_offset[_button] && mouse_x<_r[0]+_offset[_button]+_width[_button] && mouse_y>=_r[1] && mouse_y<_r[1]+28;
}
function ln_tool_music_enabled(_g) {
    return _g.game_number==1?(!is_struct(_g.controls) || _g.controls.music!=0):_g.music;
}
function ln_tool_music_set(_g,_enabled) {
    if(_g.game_number==1) {if(is_struct(_g.controls)) _g.controls.music=_enabled?255:0;}
    else _g.music=_enabled;
    if(variable_global_exists("ln_music_voice") && global.ln_music_voice>=0) {
        if(global.ln_tracks.open) global.ln_tracks.paused_voices=ln_tool_music_resume_list(global.ln_tracks.paused_voices,_enabled && !global.ln_editor.open);
        if(global.ln_sprites.open) global.ln_sprites.voices=ln_tool_music_resume_list(global.ln_sprites.voices,_enabled && !global.ln_editor.open);
        if(!_enabled || global.ln_editor.open || global.ln_tracks.open || global.ln_sprites.open) audio_pause_sound(global.ln_music_voice);
        else audio_resume_sound(global.ln_music_voice);
    }
}

function ln_tool_music_resume_list(_voices,_enabled) {
    var _result=[];
    for(var _i=0;_i<array_length(_voices);_i++) if(_voices[_i]!=global.ln_music_voice) array_push(_result,_voices[_i]);
    if(_enabled) array_push(_result,global.ln_music_voice);
    return _result;
}
