/// Presentation only: source surfaces and gameplay pixels remain untouched.
function ln_crt_surface(_surface,_x,_y,_scale,_pixel_scale=1,_region=undefined) {
    var _enabled=variable_global_exists("ln_crt_enabled") && global.ln_crt_enabled && shader_is_compiled(sh_ln_crt);
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
        (_host.play.game_number==3 && is_struct(_host.play.ending))) return [0,0,1280,800];
    if (_host.play.game_number==2) return [160,84,1120,684];
    return [160,84,1120,684];
}

/// Apply once after the game and its surrounding controls are drawn.
function ln_crt_present(_host) {
    if (!global.ln_crt_enabled || !shader_is_compiled(sh_ln_crt) || !surface_exists(application_surface)) return;
    var _region=ln_crt_game_region(_host);
    if (!is_array(_region)) return;
    var _w=surface_get_width(application_surface),_h=surface_get_height(application_surface);
    if (surface_exists(_host.crt_surface) && (surface_get_width(_host.crt_surface)!=_w || surface_get_height(_host.crt_surface)!=_h)) {
        surface_free(_host.crt_surface);_host.crt_surface=-1;
    }
    if (!surface_exists(_host.crt_surface)) _host.crt_surface=surface_create(_w,_h);
    if (!surface_exists(_host.crt_surface)) return;
    // Separate output avoids reading from the surface currently being rendered.
    surface_set_target(_host.crt_surface);
    ln_crt_surface(application_surface,0,0,1,(_host.play.game_number==1 || (_host.play.game_number==2 && _host.play.victory!=2) || (_host.play.game_number==3 && !is_struct(_host.play.ending)))?3:4,_region);
    surface_reset_target();
    draw_surface_part(_host.crt_surface,_region[0],_region[1],_region[2]-_region[0],_region[3]-_region[1],_region[0],_region[1]);
}

function ln_crt_toggle() {
    if (shader_is_compiled(sh_ln_crt)) global.ln_crt_enabled=!global.ln_crt_enabled;
}

function ln_crt_slider_input(_mx,_my,_pressed,_held) {
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

function ln_crt_sliders_draw() {
    if (!global.ln_crt_enabled) return;
    draw_set_colour(make_colour_rgb(24,28,34));draw_rectangle(1128,650,1272,792,false);
    draw_set_colour(make_colour_rgb(150,190,215));draw_text(1136,656,"CRT SETTINGS");
    var _labels=["Pixel blur","Honeycomb","Scanlines"];
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
    return clamp(floor(min((_width-32)/1280,(_height-96)/800)),1,2);
}

function ln_window_preset(_factor) {
    if (_factor==0) _factor=ln_window_fit_factor(display_get_width(),display_get_height());
    window_set_size(1280*_factor,800*_factor);
    window_center();
}

function ln_window_buttons() {
    draw_set_colour(make_colour_rgb(24,28,34));draw_rectangle(1128,602,1272,648,false);
    draw_set_colour(make_colour_rgb(150,190,215));
    draw_text(1136,604,string(window_get_width())+"x"+string(window_get_height()));
    var _labels=["1x","2x","Fit"];
    for (var _i=0;_i<3;_i++) {
        var _x=1132+46*_i,_hover=mouse_x>=_x && mouse_x<_x+42 && mouse_y>=624 && mouse_y<645;
        var _selected=(_i==0 && window_get_width()==1280 && window_get_height()==800) ||
            (_i==1 && window_get_width()==2560 && window_get_height()==1600);
        draw_set_colour(_selected?make_colour_rgb(44,82,110):make_colour_rgb(42,48,57));draw_rectangle(_x,624,_x+42,644,false);
        draw_set_colour(_hover?c_white:make_colour_rgb(180,215,236));draw_text(_x+8,626,_labels[_i]);
        if (_hover) {
            var _tip=_i==0?"1280 x 800":(_i==1?"2560 x 1600":"Largest whole-pixel size that fits");
            draw_set_colour(c_white);draw_text(1120-string_width(_tip),626,_tip);
        }
    }
    draw_set_colour(c_white);
}

function ln_crt_step() {
    if (mouse_check_button_pressed(mb_left) && mouse_y>=624 && mouse_y<645) {
        for (var _i=0;_i<3;_i++) {
            var _x=1132+46*_i;
            if (mouse_x>=_x && mouse_x<_x+42) {ln_window_preset(_i==2?0:_i+1);break;}
        }
    }
    if (keyboard_check_pressed(vk_f10) || (mouse_check_button_pressed(mb_left) &&
        mouse_x>=1128 && mouse_x<1272 && mouse_y>=36 && mouse_y<72)) {
        ln_crt_toggle();
    }
    ln_crt_slider_input(mouse_x,mouse_y,mouse_check_button_pressed(mb_left),mouse_check_button(mb_left));
}

function ln_crt_button() {
    var _available=shader_is_compiled(sh_ln_crt);
    var _hover=mouse_x>=1128 && mouse_x<1272 && mouse_y>=36 && mouse_y<72;
    draw_set_colour(global.ln_crt_enabled?make_colour_rgb(44,82,110):make_colour_rgb(32,37,44));
    draw_rectangle(1128,36,1272,72,false);
    draw_set_colour(_hover?c_white:make_colour_rgb(150,190,215));
    draw_rectangle(1128,36,1272,72,true);
    draw_text(1136,44,_available?("CRT "+(global.ln_crt_enabled?"ON":"OFF")+"  F10"):"CRT unavailable");
    draw_set_colour(c_white);
}

/// GPU readback: switch off is pixel-identical and the effect preserves its input.
function ln_crt_checks() {
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
    ln_check(ln_window_fit_factor(3840,2160)==2 && ln_window_fit_factor(1920,1080)==1,"window Fit selects integer sizes for 4K and 1080p");
    ln_check(surface_getpixel(application_surface,900,100)!=_hud_before,"CRT affects the built-in side HUD");
    ln_check(surface_getpixel(application_surface,200,540)!=_bottom_before,"CRT affects the built-in bottom HUD");
    surface_save(application_surface,"lnpreserve-crt-scene-on.png");
    global.ln_crt_enabled=false;
    if (surface_exists(_preview.stage_surface)) surface_free(_preview.stage_surface);
    show_debug_message("LN_CAPTURE_DIRECTORY:"+game_save_id);
}
