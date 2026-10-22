/// Presentation zoom: the finished game picture (after 3D and CRT) is enlarged as a
/// filtered image, from its normal place up to full screen height. Nothing is
/// re-rendered, so scanlines scale with the picture instead of being redrawn.
/// Mouse wheel or Page Up/Down step it; double-tap Page Up for full height,
/// double-tap Page Down or press U for normal size. It never goes below normal.
function ln_zoom_state() {
    if (!variable_global_exists("ln_zoom")) global.ln_zoom={target:0,value:0,up_ms:-1000,down_ms:-1000};
    return global.ln_zoom;
}
function ln_zoom_reset() {var _z=ln_zoom_state();_z.target=0;}
/// While enlarged the picture covers the panels, so their buttons stop taking clicks.
function ln_zoom_covering() {var _z=ln_zoom_state();return _z.target>0 || _z.value>0.001;}

/// Zoom applies during play only, never over editors, menus, the guide or the quit prompt.
function ln_zoom_available(_host) {
    return global.ln_tool.active && is_array(ln_crt_game_region(_host)) && !ln_touch_panel_open(_host) &&
        !ln_quit_active() && !_host.startup_active;
}

function ln_zoom_step(_host) {
    var _z=ln_zoom_state();
    // Editors, menus and the guide return the picture to normal at once.
    if (!ln_zoom_available(_host)) {_z.target=0;_z.value=0;return;}
    var _up=keyboard_check_pressed(vk_pageup),_down=keyboard_check_pressed(vk_pagedown);
    var _step=0.1*((mouse_wheel_up() || _up)-(mouse_wheel_down() || _down));
    _z.target=clamp(_z.target+_step,0,1);
    // Double tap (two presses within 350 ms) jumps straight to either end.
    if (_up) {if (current_time-_z.up_ms<350) _z.target=1;_z.up_ms=current_time;}
    if (_down) {if (current_time-_z.down_ms<350) _z.target=0;_z.down_ms=current_time;}
    _z.value=abs(_z.target-_z.value)<0.002?_z.target:lerp(_z.value,_z.target,0.25);
}

/// Draws the enlarged picture over the normal one on the 1920x1080 canvas.
/// _base is where the picture normally lands: [x,y,w,h].
function ln_zoom_draw(_host,_base) {
    var _z=ln_zoom_state(),_t=global.ln_tool;
    if (_z.value<=0.001 || !ln_zoom_available(_host) || !surface_exists(_t.surface)) return;
    var _source=ln_crt_game_region(_host);
    var _sw=_source[2]-_source[0],_sh=_source[3]-_source[1];
    // Largest size: top and bottom meet the screen edges (width permitting), centred.
    var _fit=min(1080/_sh,1920/_sw),_mw=_sw*_fit,_mh=_sh*_fit;
    var _x=lerp(_base[0],(1920-_mw)/2,_z.value),_y=lerp(_base[1],(1080-_mh)/2,_z.value);
    var _w=lerp(_base[2],_mw,_z.value),_h=lerp(_base[3],_mh,_z.value);
    if (_w<=_base[2]) return;
    var _filter=gpu_get_texfilter();gpu_set_texfilter(true);
    draw_set_colour(c_white);draw_set_alpha(1);
    draw_surface_part_ext(_t.surface,_source[0],_source[1],_sw,_sh,_x,_y,_w/_sw,_h/_sh,c_white,1);
    draw_flush();gpu_set_texfilter(_filter);
}
