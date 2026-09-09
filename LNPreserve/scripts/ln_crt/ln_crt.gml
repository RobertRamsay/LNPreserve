/// Presentation only: source surfaces and gameplay pixels remain untouched.
function ln_crt_surface(_surface,_x,_y,_scale,_pixel_scale=1) {
    var _enabled=variable_global_exists("ln_crt_enabled") && global.ln_crt_enabled && shader_is_compiled(sh_ln_crt);
    var _filter=gpu_get_texfilter();
    if (_enabled) {
        shader_set(sh_ln_crt);
        shader_set_uniform_f(shader_get_uniform(sh_ln_crt,"u_size"),surface_get_width(_surface),surface_get_height(_surface));
        shader_set_uniform_f(shader_get_uniform(sh_ln_crt,"u_scale"),_scale);
        shader_set_uniform_f(shader_get_uniform(sh_ln_crt,"u_pixel_scale"),_pixel_scale);
        shader_set_uniform_f(shader_get_uniform(sh_ln_crt,"u_time"),(current_time mod 120000)/1000);
        gpu_set_texfilter(true);
    }
    draw_surface_ext(_surface,_x,_y,_scale,_scale,0,c_white,1);
    if (_enabled) {shader_reset();gpu_set_texfilter(_filter);}
}

/// Apply once after all screen content, including the native HUD, is drawn.
function ln_crt_present(_host) {
    if (!global.ln_crt_enabled || !shader_is_compiled(sh_ln_crt) || !surface_exists(application_surface)) return;
    var _w=surface_get_width(application_surface),_h=surface_get_height(application_surface);
    if (surface_exists(_host.crt_surface) && (surface_get_width(_host.crt_surface)!=_w || surface_get_height(_host.crt_surface)!=_h)) {
        surface_free(_host.crt_surface);_host.crt_surface=-1;
    }
    if (!surface_exists(_host.crt_surface)) _host.crt_surface=surface_create(_w,_h);
    if (!surface_exists(_host.crt_surface)) return;
    // Separate output avoids reading from the surface currently being rendered.
    surface_set_target(_host.crt_surface);
    ln_crt_surface(application_surface,0,0,1,_host.play.game_number==1?3:4);
    surface_reset_target();
    draw_surface(_host.crt_surface,0,0);
}

function ln_crt_toggle() {
    if (shader_is_compiled(sh_ln_crt)) global.ln_crt_enabled=!global.ln_crt_enabled;
}

function ln_crt_step() {
    if (keyboard_check_pressed(vk_f10) || (mouse_check_button_pressed(mb_left) &&
        mouse_x>=1128 && mouse_x<1272 && mouse_y>=36 && mouse_y<72)) {
        ln_crt_toggle();
    }
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
    var _hud_before=surface_getpixel(application_surface,900,100);
    var _bottom_before=surface_getpixel(application_surface,200,540);
    ln_crt_present(self);
    ln_check(surface_getpixel(application_surface,900,100)!=_hud_before,"CRT affects the built-in side HUD");
    ln_check(surface_getpixel(application_surface,200,540)!=_bottom_before,"CRT affects the built-in bottom HUD");
    surface_save(application_surface,"lnpreserve-crt-scene-on.png");
    global.ln_crt_enabled=false;
    if (surface_exists(_preview.stage_surface)) surface_free(_preview.stage_surface);
    show_debug_message("LN_CAPTURE_DIRECTORY:"+game_save_id);
}
