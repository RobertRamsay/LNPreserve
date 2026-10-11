/// Touch controls for phones and tablets.
/// Left: a black C64-style joystick with a red knob (eight directions).
/// Right: two red buttons, FIRE (the # fire key) and SPACE (next weapon).
/// Along the bottom: function keys labelled by what they do, with a KEYS toggle that hides them.
/// Top-left: ESC (Back; asks to quit when no panel is open). Top-right: TOUCH settings.
/// The joystick and both buttons can be dragged to new places from TOUCH > ARRANGE.
/// With the UI hidden, double-tap the top of the screen to bring it back.
/// Touches feed LNInput as held keys, exactly like the keyboard and the Xbox pad.

enum LNTouchAction { Key, Save }

/// UI text font. Android and iOS use Roboto Medium (a plain Android-style font, Apache 2.0,
/// datafiles/fonts) for every label and button; desktop keeps Jansina. [Touch] clear_font=1
/// in LNPreserve.ini uses Roboto on desktop too. Sizes 12 and 18 match Jansina's text widths.
function ln_ui_font_init() {
    global.ln_ui_font=font_jansina;
    global.ln_ui_font_big=font_jansina_big;
    var _clear=false;
    if(os_type==os_android || os_type==os_ios) _clear=true;
    if(global.ln_preferences_enabled) {
        ini_open("LNPreserve.ini");
        if(ini_read_real("Touch","clear_font",0)>=0.5) _clear=true;
        ini_close();
    }
    if(!_clear) return;
    var _font=font_add("fonts/Roboto-Medium.ttf",12,false,false,32,255);
    var _big=font_add("fonts/Roboto-Medium.ttf",18,false,false,32,255);
    if(font_exists(_font)) global.ln_ui_font=_font;
    if(font_exists(_big)) global.ln_ui_font_big=_big;
}
function ln_ui_font() {return global.ln_ui_font;}
function ln_ui_font_big() {return global.ln_ui_font_big;}
enum LNTouchDrag { None, Stick, Fire, Space }

function ln_touch_init() {
    var _mobile=false;
    if(os_type==os_android || os_type==os_ios) _mobile=true;
    global.ln_touch={
        mobile:_mobile,
        desktop:false,
        active:_mobile,
        controls:true,
        keys:true,
        size:1,
        opacity:0.7,
        zoom:3,
        options:false,
        arrange:false,
        drag:LNTouchDrag.None,
        drag_dx:0,
        drag_dy:0,
        devices:5,
        values:array_create(LNKey.Count,false),
        pad:{x:0,y:0,up:false,down:false,left:false,right:false,a:false,b:false,xbutton:false,ybutton:false,lb:false,rb:false,lt:false,rt:false,start:false},
        stick_device:-1,
        stick_dx:0,
        stick_dy:0,
        stick_px:-1,
        stick_py:-1,
        stick_x:175,
        stick_y:740,
        stick_r:150,
        fire_px:-1,
        fire_py:-1,
        fire_x:1775,
        fire_y:935,
        fire_r:120,
        fire_down:false,
        space_px:-1,
        space_py:-1,
        space_x:1690,
        space_y:715,
        space_r:90,
        space_down:false,
        escape_x:20,
        escape_y:20,
        escape_w:130,
        escape_h:64,
        options_x:1760,
        options_y:20,
        options_w:140,
        options_h:64,
        strip_y:988,
        strip_h:84,
        toggle_x:330,
        toggle_w:120,
        toggle_down:false,
        strip:[
            {label:"MUSIC",action:LNTouchAction.Key,key:LNKey.F1,x:460,w:150,down:false},
            {label:"ITEM >",action:LNTouchAction.Key,key:LNKey.F3,x:620,w:150,down:false},
            {label:"< ITEM",action:LNTouchAction.Key,key:LNKey.F5,x:780,w:150,down:false},
            {label:"PAUSE",action:LNTouchAction.Key,key:LNKey.F7,x:940,w:150,down:false},
            {label:"< WEAPON",action:LNTouchAction.Key,key:LNKey.WeaponPrev,x:1100,w:150,down:false},
            {label:"CRT",action:LNTouchAction.Key,key:LNKey.CRT,x:1260,w:150,down:false},
            {label:"SAVE",action:LNTouchAction.Save,key:-1,x:1420,w:150,down:false}
        ],
        escape_release:false,
        escape_cooldown:0,
        top_tap_ms:-100000,
        top_tap_x:0
    };
    ln_touch_preferences_read();
    ln_touch_layout();
}

function ln_touch_ini_number(_key,_default) {
    var _value=ini_read_real("Touch",_key,_default);
    if(is_nan(_value) || is_infinity(_value)) _value=_default;
    return _value;
}
/// [Touch] in LNPreserve.ini. desktop=1 turns the overlay on for Windows/macOS testing with the mouse.
function ln_touch_preferences_read() {
    var _t=global.ln_touch;
    if(!global.ln_preferences_enabled) return;
    ini_open("LNPreserve.ini");
    _t.desktop=ln_touch_ini_number("desktop",0)>=0.5;
    _t.controls=ln_touch_ini_number("controls",1)>=0.5;
    _t.keys=ln_touch_ini_number("keys",1)>=0.5;
    _t.size=clamp(round(ln_touch_ini_number("size",1)*10)/10,0.7,1.5);
    _t.opacity=clamp(round(ln_touch_ini_number("opacity",0.7)*10)/10,0.2,1);
    _t.zoom=clamp(round(ln_touch_ini_number("zoom",3)),3,5);
    _t.stick_px=ln_touch_ini_number("stick_x",-1);
    _t.stick_py=ln_touch_ini_number("stick_y",-1);
    _t.fire_px=ln_touch_ini_number("fire_x",-1);
    _t.fire_py=ln_touch_ini_number("fire_y",-1);
    _t.space_px=ln_touch_ini_number("space_x",-1);
    _t.space_py=ln_touch_ini_number("space_y",-1);
    ini_close();
    _t.active=_t.mobile || _t.desktop;
}
function ln_touch_preferences_write() {
    var _t=global.ln_touch;
    if(!global.ln_preferences_enabled) return;
    ini_open("LNPreserve.ini");
    ini_write_real("Touch","desktop",real(_t.desktop));
    ini_write_real("Touch","controls",real(_t.controls));
    ini_write_real("Touch","keys",real(_t.keys));
    ini_write_real("Touch","size",_t.size);
    ini_write_real("Touch","opacity",_t.opacity);
    ini_write_real("Touch","zoom",_t.zoom);
    ini_write_real("Touch","stick_x",_t.stick_px);
    ini_write_real("Touch","stick_y",_t.stick_py);
    ini_write_real("Touch","fire_x",_t.fire_px);
    ini_write_real("Touch","fire_y",_t.fire_py);
    ini_write_real("Touch","space_x",_t.space_px);
    ini_write_real("Touch","space_y",_t.space_py);
    ini_close();
}

/// Default places sit in the side margins of the 1920x1080 canvas. A position dragged in
/// ARRANGE (-1 means default) replaces the default; every control stays fully on screen.
function ln_touch_layout() {
    var _t=global.ln_touch,_s=_t.size;
    _t.stick_r=150*_s;
    _t.fire_r=120*_s;
    _t.space_r=90*_s;
    _t.stick_x=25+_t.stick_r;
    _t.stick_y=740;
    _t.fire_x=1895-_t.fire_r;
    _t.fire_y=1055-_t.fire_r;
    _t.space_x=max(1600+_t.space_r,_t.fire_x-(_t.fire_r+_t.space_r)*0.55);
    _t.space_y=_t.fire_y-(_t.fire_r+_t.space_r)*1.05;
    if(_t.stick_px>=0) {_t.stick_x=_t.stick_px;_t.stick_y=_t.stick_py;}
    if(_t.fire_px>=0) {_t.fire_x=_t.fire_px;_t.fire_y=_t.fire_py;}
    if(_t.space_px>=0) {_t.space_x=_t.space_px;_t.space_y=_t.space_py;}
    _t.stick_x=clamp(_t.stick_x,_t.stick_r,1920-_t.stick_r);
    _t.stick_y=clamp(_t.stick_y,_t.stick_r,1080-_t.stick_r);
    _t.fire_x=clamp(_t.fire_x,_t.fire_r,1920-_t.fire_r);
    _t.fire_y=clamp(_t.fire_y,_t.fire_r,1080-_t.fire_r);
    _t.space_x=clamp(_t.space_x,_t.space_r,1920-_t.space_r);
    _t.space_y=clamp(_t.space_y,_t.space_r,1080-_t.space_r);
}

/// Where the game picture lands on the 1920x1080 canvas with the UI hidden: [x,y,w,h,scale].
/// Game size is a whole number of canvas pixels per C64 pixel (3x, 4x or 5x), so the CRT
/// output, made at the tool surface's 3x, scales by the same pattern on every C64 row and
/// every scanline keeps the same height. 5x (1600x1000) is the largest that fits 1080.
function ln_game_view(_host,_rect) {
    var _scale=1;
    if(is_array(ln_crt_game_region(_host))) _scale=max(1,global.ln_touch.zoom*320/_rect[2]);
    _scale=min(_scale,1920/_rect[2],1080/_rect[3]);
    var _w=_rect[2]*_scale,_h=_rect[3]*_scale;
    return [floor((1920-_w)/2),floor((1080-_h)/2),_w,_h,_scale];
}
function ln_touch_zoom_label(_zoom) {
    if(_zoom==4) return "133%";
    if(_zoom==5) return "167% MAX";
    return "100%";
}

function ln_touch_panel_open(_host) {
    return _host.workbench || _host.scene_test.menu || _host.scene_test.preview || global.ln_editor.open ||
        global.ln_tracks.open || global.ln_sprites.open || ln_guide_active();
}
/// ESC and TOUCH stay available on every screen, including the startup screen.
function ln_touch_corner_visible(_host) {
    var _t=global.ln_touch;
    return _t.active && global.ln_tool.active && !_t.options && !_t.arrange && !ln_quit_active();
}
/// Joystick, FIRE, SPACE and the key row show during play only; menus and editors take taps directly.
function ln_touch_controls_visible(_host) {
    var _t=global.ln_touch;
    if(!_t.active || !_t.controls || _t.options || _t.arrange || !global.ln_tool.active) return false;
    if(_host.startup_active || ln_quit_active()) return false;
    return !ln_touch_panel_open(_host);
}

function ln_touch_hit_rect(_x,_y,_rx,_ry,_rw,_rh) {
    return _x>=_rx && _x<_rx+_rw && _y>=_ry && _y<_ry+_rh;
}
function ln_touch_corner_hit(_x,_y) {
    var _t=global.ln_touch;
    if(ln_touch_hit_rect(_x,_y,_t.escape_x,_t.escape_y,_t.escape_w,_t.escape_h)) return true;
    return ln_touch_hit_rect(_x,_y,_t.options_x,_t.options_y,_t.options_w,_t.options_h);
}
function ln_touch_pressed_rect(_rx,_ry,_rw,_rh) {
    var _t=global.ln_touch;
    for(var _d=0;_d<_t.devices;_d++) {
        if(!device_mouse_check_button_pressed(_d,mb_left)) continue;
        if(ln_touch_hit_rect(device_mouse_x(_d),device_mouse_y(_d),_rx,_ry,_rw,_rh)) return true;
    }
    return false;
}
/// Held by any finger except the one steering the joystick, so a thumb can slide between buttons.
function ln_touch_held_rect(_rx,_ry,_rw,_rh) {
    var _t=global.ln_touch;
    for(var _d=0;_d<_t.devices;_d++) {
        if(_d==_t.stick_device || !device_mouse_check_button(_d,mb_left)) continue;
        if(ln_touch_hit_rect(device_mouse_x(_d),device_mouse_y(_d),_rx,_ry,_rw,_rh)) return true;
    }
    return false;
}
function ln_touch_held_circle(_cx,_cy,_r) {
    var _t=global.ln_touch;
    for(var _d=0;_d<_t.devices;_d++) {
        if(_d==_t.stick_device || !device_mouse_check_button(_d,mb_left)) continue;
        if(point_distance(device_mouse_x(_d),device_mouse_y(_d),_cx,_cy)<=_r) return true;
    }
    return false;
}

function ln_touch_release(_t) {
    for(var _i=0;_i<LNKey.Count;_i++) _t.values[_i]=false;
    _t.stick_device=-1;
    _t.stick_dx=0;
    _t.stick_dy=0;
    _t.fire_down=false;
    _t.space_down=false;
    _t.toggle_down=false;
    for(var _i=0;_i<array_length(_t.strip);_i++) _t.strip[_i].down=false;
}

/// Back: closes the quit prompt, sends one Escape press to an open panel,
/// otherwise asks to quit. The cooldown stops two quick taps restarting the app.
function ln_touch_back(_host) {
    var _t=global.ln_touch;
    if(ln_quit_active()) {ln_quit_close(_host);return;}
    if(_host.startup_active || !ln_touch_panel_open(_host)) {ln_touch_release(_t);ln_quit_open();return;}
    if(_t.escape_cooldown>0) return;
    keyboard_key_press(vk_escape);
    _t.escape_release=true;
    _t.escape_cooldown=0.5;
}

/// With the UI hidden, a double tap above the game picture brings it back. At the larger
/// game sizes the strip above the picture is thin, so the top 140 pixels always count.
function ln_touch_restore_ui(_host) {
    var _t=global.ln_touch;
    if(_host.startup_active || ln_tool_ui_visible() || ln_quit_active()) {_t.top_tap_ms=-100000;return;}
    var _view=ln_game_view(_host,ln_tool_rect(_host)),_top=max(_view[1],140);
    for(var _d=0;_d<_t.devices;_d++) {
        if(!device_mouse_check_button_pressed(_d,mb_left)) continue;
        var _x=device_mouse_x(_d),_y=device_mouse_y(_d);
        if(_y>=_top) continue;
        if(ln_touch_corner_visible(_host) && ln_touch_corner_hit(_x,_y)) continue;
        if(current_time-_t.top_tap_ms<=400 && abs(_x-_t.top_tap_x)<=240) {
            global.ln_tool.ui=true;
            global.ln_tool.ui_hint_us=0;
            _t.top_tap_ms=-100000;
            return;
        }
        _t.top_tap_ms=current_time;
        _t.top_tap_x=_x;
    }
}

/// Returns true while settings or ARRANGE are open; the game waits, as it does for the quit prompt.
function ln_touch_step(_host) {
    var _t=global.ln_touch;
    if(_t.escape_release) {keyboard_key_release(vk_escape);_t.escape_release=false;}
    if(_t.escape_cooldown>0) _t.escape_cooldown-=min(delta_time/1000000,0.1);
    if(!_t.active) return false;
    if(_t.arrange) {ln_touch_arrange_step(_host);return true;}
    if(_t.options) {ln_touch_options_step(_host);return true;}
    // Android's Back button arrives as Backspace; the help guide already uses it.
    if(os_type==os_android && keyboard_check_pressed(vk_backspace) && !ln_guide_active()) ln_touch_back(_host);
    else if(ln_touch_corner_visible(_host)) {
        if(ln_touch_pressed_rect(_t.escape_x,_t.escape_y,_t.escape_w,_t.escape_h)) ln_touch_back(_host);
        else if(ln_touch_pressed_rect(_t.options_x,_t.options_y,_t.options_w,_t.options_h)) {ln_touch_release(_t);_t.options=true;return true;}
    }
    ln_touch_restore_ui(_host);
    if(ln_touch_controls_visible(_host)) ln_touch_read(_host);
    else ln_touch_release(_t);
    return false;
}

function ln_touch_read(_host) {
    var _t=global.ln_touch;
    for(var _i=0;_i<LNKey.Count;_i++) _t.values[_i]=false;
    // The finger that lands on the joystick keeps it until lifted, wherever it slides.
    if(_t.stick_device>=0 && !device_mouse_check_button(_t.stick_device,mb_left)) _t.stick_device=-1;
    if(_t.stick_device<0) {
        for(var _d=0;_d<_t.devices;_d++) {
            if(!device_mouse_check_button_pressed(_d,mb_left)) continue;
            if(point_distance(device_mouse_x(_d),device_mouse_y(_d),_t.stick_x,_t.stick_y)<=_t.stick_r*1.4) {_t.stick_device=_d;break;}
        }
    }
    _t.stick_dx=0;
    _t.stick_dy=0;
    if(_t.stick_device>=0) {
        var _dx=(device_mouse_x(_t.stick_device)-_t.stick_x)/_t.stick_r;
        var _dy=(device_mouse_y(_t.stick_device)-_t.stick_y)/_t.stick_r;
        var _length=sqrt(_dx*_dx+_dy*_dy);
        if(_length>1) {_dx/=_length;_dy/=_length;}
        _t.stick_dx=_dx;
        _t.stick_dy=_dy;
    }
    // Same eight-way split and dead zone as the Xbox stick.
    _t.pad.x=_t.stick_dx;
    _t.pad.y=_t.stick_dy;
    var _map=ln_xbox_map(_t.pad);
    _t.values[LNKey.Up]=_map[LNKey.Up];
    _t.values[LNKey.Down]=_map[LNKey.Down];
    _t.values[LNKey.Left]=_map[LNKey.Left];
    _t.values[LNKey.Right]=_map[LNKey.Right];
    _t.fire_down=ln_touch_held_circle(_t.fire_x,_t.fire_y,_t.fire_r*1.15);
    _t.space_down=ln_touch_held_circle(_t.space_x,_t.space_y,_t.space_r*1.15);
    _t.values[LNKey.Fire]=_t.fire_down;
    _t.values[LNKey.Weapon]=_t.space_down;
    var _toggle=ln_touch_held_rect(_t.toggle_x,_t.strip_y,_t.toggle_w,_t.strip_h);
    if(_toggle && !_t.toggle_down) {_t.keys=!_t.keys;ln_touch_preferences_write();}
    _t.toggle_down=_toggle;
    for(var _i=0;_i<array_length(_t.strip);_i++) {
        var _b=_t.strip[_i];
        var _held=_t.keys && ln_touch_held_rect(_b.x,_t.strip_y,_b.w,_t.strip_h);
        if(_b.action==LNTouchAction.Key) {
            if(_held) _t.values[_b.key]=true;
        } else if(_held && !_b.down) ln_touch_save(_host);
        _b.down=_held;
    }
}

function ln_touch_save(_host) {
    var _g=_host.play;
    if(_g.game_number==3 && (is_struct(_g.intro) || is_struct(_g.ending))) return;
    ln_save_add(_host.saves,_g);
}

/// Settings panel. Tap outside it to close.
function ln_touch_options_step(_host) {
    var _t=global.ln_touch;
    if(keyboard_check_pressed(vk_escape) || (os_type==os_android && keyboard_check_pressed(vk_backspace))) {_t.options=false;return;}
    if(!mouse_check_button_pressed(mb_left)) return;
    var _x=mouse_x,_y=mouse_y,_changed=false;
    if(!ln_touch_hit_rect(_x,_y,660,240,600,560)) {_t.options=false;return;}
    if(ln_touch_hit_rect(_x,_y,1000,310,220,56)) {_t.controls=!_t.controls;_changed=true;}
    if(ln_touch_hit_rect(_x,_y,1000,380,64,56)) {_t.size=clamp(round((_t.size-0.1)*10)/10,0.7,1.5);_changed=true;}
    if(ln_touch_hit_rect(_x,_y,1156,380,64,56)) {_t.size=clamp(round((_t.size+0.1)*10)/10,0.7,1.5);_changed=true;}
    if(ln_touch_hit_rect(_x,_y,1000,450,64,56)) {_t.opacity=clamp(round((_t.opacity-0.1)*10)/10,0.2,1);_changed=true;}
    if(ln_touch_hit_rect(_x,_y,1156,450,64,56)) {_t.opacity=clamp(round((_t.opacity+0.1)*10)/10,0.2,1);_changed=true;}
    if(ln_touch_hit_rect(_x,_y,1000,520,220,56)) {_t.keys=!_t.keys;_changed=true;}
    if(ln_touch_hit_rect(_x,_y,1000,590,220,56)) {
        _t.zoom++;
        if(_t.zoom>5) _t.zoom=3;
        _changed=true;
    }
    if(ln_touch_hit_rect(_x,_y,700,710,240,60)) {_t.options=false;_t.arrange=true;_t.drag=LNTouchDrag.None;}
    if(ln_touch_hit_rect(_x,_y,980,710,240,60)) _t.options=false;
    if(_changed) {ln_touch_layout();ln_touch_preferences_write();}
}

/// ARRANGE: drag the joystick, FIRE or SPACE anywhere on screen. RESET restores the defaults.
function ln_touch_arrange_step(_host) {
    var _t=global.ln_touch;
    if(keyboard_check_pressed(vk_escape) || (os_type==os_android && keyboard_check_pressed(vk_backspace))) {
        _t.arrange=false;_t.drag=LNTouchDrag.None;ln_touch_preferences_write();return;
    }
    if(mouse_check_button_pressed(mb_left)) {
        if(ln_touch_hit_rect(mouse_x,mouse_y,780,500,170,64)) {_t.arrange=false;_t.drag=LNTouchDrag.None;ln_touch_preferences_write();return;}
        if(ln_touch_hit_rect(mouse_x,mouse_y,970,500,170,64)) {
            _t.stick_px=-1;_t.stick_py=-1;_t.fire_px=-1;_t.fire_py=-1;_t.space_px=-1;_t.space_py=-1;
            ln_touch_layout();return;
        }
        // The nearest control under the finger, measured against each control's own size.
        var _best=LNTouchDrag.None,_best_distance=1.2;
        var _d=point_distance(mouse_x,mouse_y,_t.stick_x,_t.stick_y)/_t.stick_r;
        if(_d<_best_distance) {_best=LNTouchDrag.Stick;_best_distance=_d;}
        _d=point_distance(mouse_x,mouse_y,_t.fire_x,_t.fire_y)/_t.fire_r;
        if(_d<_best_distance) {_best=LNTouchDrag.Fire;_best_distance=_d;}
        _d=point_distance(mouse_x,mouse_y,_t.space_x,_t.space_y)/_t.space_r;
        if(_d<_best_distance) {_best=LNTouchDrag.Space;_best_distance=_d;}
        _t.drag=_best;
        if(_best==LNTouchDrag.Stick) {_t.drag_dx=_t.stick_x-mouse_x;_t.drag_dy=_t.stick_y-mouse_y;}
        if(_best==LNTouchDrag.Fire) {_t.drag_dx=_t.fire_x-mouse_x;_t.drag_dy=_t.fire_y-mouse_y;}
        if(_best==LNTouchDrag.Space) {_t.drag_dx=_t.space_x-mouse_x;_t.drag_dy=_t.space_y-mouse_y;}
    }
    if(_t.drag==LNTouchDrag.None) return;
    if(!mouse_check_button(mb_left)) {_t.drag=LNTouchDrag.None;return;}
    var _x=round(mouse_x+_t.drag_dx),_y=round(mouse_y+_t.drag_dy);
    if(_t.drag==LNTouchDrag.Stick) {_t.stick_px=_x;_t.stick_py=_y;}
    if(_t.drag==LNTouchDrag.Fire) {_t.fire_px=_x;_t.fire_py=_y;}
    if(_t.drag==LNTouchDrag.Space) {_t.space_px=_x;_t.space_py=_y;}
    ln_touch_layout();
    // Keep the stored place equal to the clamped one, so it never drifts off screen.
    if(_t.drag==LNTouchDrag.Stick) {_t.stick_px=_t.stick_x;_t.stick_py=_t.stick_y;}
    if(_t.drag==LNTouchDrag.Fire) {_t.fire_px=_t.fire_x;_t.fire_py=_t.fire_y;}
    if(_t.drag==LNTouchDrag.Space) {_t.space_px=_t.space_x;_t.space_py=_t.space_y;}
}

function ln_touch_key(_x,_y,_w,_h,_label,_down,_alpha) {
    var _fill=make_colour_rgb(20,20,24);
    if(_down) _fill=make_colour_rgb(150,30,30);
    draw_set_alpha(_alpha);
    draw_set_colour(_fill);draw_roundrect_ext(_x,_y,_x+_w,_y+_h,18,18,false);
    draw_set_colour(make_colour_rgb(190,190,190));draw_roundrect_ext(_x,_y,_x+_w,_y+_h,18,18,true);
    draw_set_colour(c_white);draw_text(_x+_w/2,_y+_h/2,_label);
}
function ln_touch_round_button(_x,_y,_r,_label,_down,_alpha) {
    var _fill=make_colour_rgb(200,22,22);
    if(_down) _fill=make_colour_rgb(255,70,60);
    draw_set_alpha(_alpha);
    draw_set_colour(make_colour_rgb(12,12,12));draw_circle(_x,_y,_r,false);
    draw_set_colour(_fill);draw_circle(_x,_y,_r*0.84,false);
    draw_set_colour(make_colour_rgb(255,150,140));draw_circle(_x-_r*0.3,_y-_r*0.3,_r*0.12,false);
    draw_set_colour(c_white);draw_text(_x,_y,_label);
}
function ln_touch_joystick_draw(_t) {
    var _cx=_t.stick_x,_cy=_t.stick_y,_r=_t.stick_r;
    var _kx=_cx+_t.stick_dx*_r*0.6,_ky=_cy+_t.stick_dy*_r*0.6;
    draw_set_alpha(_t.opacity);
    draw_set_colour(make_colour_rgb(8,8,8));draw_circle(_cx,_cy,_r,false);
    draw_set_colour(make_colour_rgb(80,80,80));draw_circle(_cx,_cy,_r,true);draw_circle(_cx,_cy,_r-1,true);
    draw_set_colour(make_colour_rgb(55,55,55));
    for(var _i=0;_i<8;_i++) {
        var _a=_i*45;
        draw_circle(_cx+lengthdir_x(_r*0.82,_a),_cy+lengthdir_y(_r*0.82,_a),max(3,_r*0.04),false);
    }
    draw_set_colour(make_colour_rgb(32,32,32));draw_circle(_cx,_cy,_r*0.42,false);
    draw_set_colour(make_colour_rgb(18,18,18));draw_line_width(_cx,_cy,_kx,_ky,_r*0.2);
    draw_set_colour(make_colour_rgb(200,20,20));draw_circle(_kx,_ky,_r*0.32,false);
    draw_set_colour(make_colour_rgb(255,130,120));draw_circle(_kx-_r*0.1,_ky-_r*0.1,_r*0.09,false);
}
function ln_touch_options_draw() {
    var _t=global.ln_touch;
    draw_set_alpha(0.6);draw_set_colour(c_black);draw_rectangle(0,0,1920,1080,false);
    draw_set_alpha(1);draw_set_colour(make_colour_rgb(16,18,26));draw_rectangle(660,240,1260,800,false);
    draw_set_colour(make_colour_rgb(255,220,40));draw_rectangle(660,240,1260,800,true);draw_rectangle(661,241,1259,799,true);
    draw_set_halign(fa_center);draw_set_valign(fa_middle);draw_set_colour(c_white);
    draw_set_font(ln_ui_font_big());draw_text(960,274,"TOUCH CONTROLS");draw_set_font(ln_ui_font());
    draw_set_halign(fa_left);
    draw_text(700,338,"Controls");draw_text(700,408,"Button size");draw_text(700,478,"Opacity");
    draw_text(700,548,"Extra keys");draw_text(700,618,"Game size");
    draw_set_colour(make_colour_rgb(150,210,220));draw_text(700,664,"Game size applies with the UI hidden (U).");
    draw_set_halign(fa_center);
    var _controls="OFF",_keys="HIDDEN";
    if(_t.controls) _controls="ON";
    if(_t.keys) _keys="SHOWN";
    ln_touch_key(1000,310,220,56,_controls,_t.controls,1);
    ln_touch_key(1000,380,64,56,"-",false,1);ln_touch_key(1156,380,64,56,"+",false,1);
    draw_set_colour(c_white);draw_text(1110,408,string(round(_t.size*100))+"%");
    ln_touch_key(1000,450,64,56,"-",false,1);ln_touch_key(1156,450,64,56,"+",false,1);
    draw_set_colour(c_white);draw_text(1110,478,string(round(_t.opacity*100))+"%");
    ln_touch_key(1000,520,220,56,_keys,_t.keys,1);
    ln_touch_key(1000,590,220,56,ln_touch_zoom_label(_t.zoom),false,1);
    ln_touch_key(700,710,240,60,"ARRANGE",false,1);
    ln_touch_key(980,710,240,60,"CLOSE",false,1);
}
function ln_touch_arrange_draw() {
    var _t=global.ln_touch;
    ln_touch_joystick_draw(_t);
    ln_touch_round_button(_t.fire_x,_t.fire_y,_t.fire_r,"FIRE",_t.drag==LNTouchDrag.Fire,max(0.6,_t.opacity));
    ln_touch_round_button(_t.space_x,_t.space_y,_t.space_r,"SPACE",_t.drag==LNTouchDrag.Space,max(0.6,_t.opacity));
    draw_set_alpha(1);draw_set_colour(make_colour_rgb(255,220,40));
    draw_circle(_t.stick_x,_t.stick_y,_t.stick_r+4,true);
    draw_circle(_t.fire_x,_t.fire_y,_t.fire_r+4,true);
    draw_circle(_t.space_x,_t.space_y,_t.space_r+4,true);
    draw_set_colour(c_black);draw_set_alpha(0.75);draw_rectangle(740,420,1180,584,false);
    draw_set_alpha(1);draw_set_colour(c_white);
    draw_text(960,456,"Drag the joystick, FIRE or SPACE");
    ln_touch_key(780,500,170,64,"DONE",false,1);
    ln_touch_key(970,500,170,64,"RESET",false,1);
}

function ln_touch_draw(_host) {
    var _t=global.ln_touch;
    if(!_t.active || !global.ln_tool.active) return;
    var _alpha=draw_get_alpha(),_colour=draw_get_colour(),_font=draw_get_font();
    draw_set_font(ln_ui_font());draw_set_halign(fa_center);draw_set_valign(fa_middle);
    if(ln_touch_corner_visible(_host)) {
        ln_touch_key(_t.escape_x,_t.escape_y,_t.escape_w,_t.escape_h,"ESC",false,max(0.5,_t.opacity));
        ln_touch_key(_t.options_x,_t.options_y,_t.options_w,_t.options_h,"TOUCH",false,max(0.5,_t.opacity));
    }
    if(ln_touch_controls_visible(_host)) {
        ln_touch_joystick_draw(_t);
        ln_touch_round_button(_t.fire_x,_t.fire_y,_t.fire_r,"FIRE",_t.fire_down,_t.opacity);
        ln_touch_round_button(_t.space_x,_t.space_y,_t.space_r,"SPACE",_t.space_down,_t.opacity);
        var _toggle="KEYS +";
        if(_t.keys) _toggle="KEYS -";
        ln_touch_key(_t.toggle_x,_t.strip_y,_t.toggle_w,_t.strip_h,_toggle,_t.toggle_down,_t.opacity);
        if(_t.keys) for(var _i=0;_i<array_length(_t.strip);_i++) {
            var _b=_t.strip[_i];
            ln_touch_key(_b.x,_t.strip_y,_b.w,_t.strip_h,_b.label,_b.down,_t.opacity);
        }
    }
    if(_t.arrange) ln_touch_arrange_draw();
    if(_t.options) ln_touch_options_draw();
    draw_flush();
    draw_set_alpha(_alpha);draw_set_colour(_colour);draw_set_font(_font);
    draw_set_halign(fa_left);draw_set_valign(fa_top);
}
