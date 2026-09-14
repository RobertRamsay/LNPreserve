// Cosmetic playback, separate from gameplay snapshots and saved games.
function ln_paint_free() {
    if(!variable_global_exists("ln_paint")) return;
    var _p=global.ln_paint;
    if(_p.buffer>=0) buffer_delete(_p.buffer);
    if(surface_exists(_p.surface)) surface_free(_p.surface);
    _p.buffer=-1;_p.surface=-1;_p.active=false;
}
function ln_paint_supported(_g) {
    if(!global.ln_preferences_enabled || !array_contains([1,2,3],_g.game_number) || ln2_loader_active(_g)) return false;
    if(_g.game_number==2 && variable_struct_exists(_g,"victory") && _g.victory==2) return false;
    if(_g.game_number==3) {
        if(variable_struct_exists(_g,"intro") && is_struct(_g.intro)) return false;
        if(variable_struct_exists(_g,"ending") && is_struct(_g.ending)) return false;
    }
    return true;
}
function ln_paint_sync(_g) {
    if(!ln_paint_supported(_g)) {ln_paint_free();return false;}
    var _p=global.ln_paint;
    var _key=string(_g.game_number)+":"+string(_g.level)+"-"+string(_g.room_id)+":"+string(global.ln_rewind_epoch);
    if(_key!=_p.key) {
        ln_paint_free();_p.key=_key;_p.time=0;_p.cursor=8;_p.presented=false;
        var _folder="play/ln"+string(_g.game_number)+"/painting/";
        var _file=_folder+string(_g.level)+"-"+string(_g.room_id)+".bin";
        if(!file_exists(_file)) return false;
        _p.buffer=buffer_load(_file);_p.duration=buffer_peek(_p.buffer,0,buffer_u32)/985248;
        var _cache="ln_paint_backgrounds_"+string(_g.game_number);
        if(!variable_global_exists(_cache)) {
            var _bg_buffer=buffer_load(_folder+"backgrounds.json");
            variable_global_set(_cache,json_parse(buffer_read(_bg_buffer,buffer_text)));buffer_delete(_bg_buffer);
        }
        var _backgrounds=variable_global_get(_cache),_index=_g.room_id-(_g.game_number==1?1:0);
        _p.background=global.ln_paint_palette[_backgrounds[_g.level-1][_index]];
        _p.active=true;
    }
    return _p.active;
}
function ln_paint_tick(_g) {
    if(!ln_paint_sync(_g)) return false;
    var _p=global.ln_paint;
    // At least one actual draw must show the plain background, even during catch-up ticks.
    if(!_p.presented) return true;
    _p.time+=global.ln_paint_speed*_g.timer.cycles_per_frame/_g.timer.hz;
    if(_p.time>=_p.duration) {ln_paint_free();return false;}
    return true;
}
function ln_paint_prepare() {
    var _p=global.ln_paint;if(!_p.active || _p.buffer<0) return;
    var _view=matrix_get(matrix_view),_projection=matrix_get(matrix_projection);
    // Rebuild from recorded patches after GPU surface loss.
    if(!surface_exists(_p.surface)) {
        _p.surface=surface_create(240,144);_p.cursor=8;
        surface_set_target(_p.surface);draw_clear(_p.background);surface_reset_target();
    }
    if(!_p.presented) {_p.presented=true;matrix_set(matrix_view,_view);matrix_set(matrix_projection,_projection);return;}
    surface_set_target(_p.surface);
    var _camera=camera_create_view(0,0,240,144);camera_apply(_camera);
    var _palette=global.ln_paint_palette;
    while(_p.cursor<buffer_get_size(_p.buffer)) {
        buffer_seek(_p.buffer,buffer_seek_start,_p.cursor);
        var _cycle=buffer_read(_p.buffer,buffer_u32);
        if(_cycle>_p.time*985248) break;
        var _count=buffer_read(_p.buffer,buffer_u16);
        repeat(_count) {
            var _pixel=buffer_read(_p.buffer,buffer_u16),_colour=buffer_read(_p.buffer,buffer_u8);
            var _x=(_pixel mod 120)*2,_y=_pixel div 120;
            draw_set_colour(_palette[_colour]);draw_rectangle(_x,_y,_x+2,_y+1,false);
        }
        _p.cursor=buffer_tell(_p.buffer);
    }
    surface_reset_target();
    matrix_set(matrix_view,_view);matrix_set(matrix_projection,_projection);camera_destroy(_camera);
    draw_set_colour(c_white);
}
function ln_paint_slider(_input=false) {
    if(_input) {
        if(mouse_check_button_pressed(mb_left) && ln_tool_mouse_x()>=860 && ln_tool_mouse_x()<=1130 && abs(ln_tool_mouse_y()-587)<=12) global.ln_paint_drag=true;
        if(!mouse_check_button(mb_left)) global.ln_paint_drag=false;
        if(global.ln_paint_drag) global.ln_paint_speed=round((0.1+4.9*clamp((ln_tool_mouse_x()-870)/240,0,1))*20)/20;
        if(mouse_check_button_pressed(mb_left) && ln_tool_mouse_x()>=860 && ln_tool_mouse_x()<=1130 && ln_tool_mouse_y()>=606 && ln_tool_mouse_y()<=625) global.ln_paint_speed=1;
        return;
    }
    draw_set_colour(c_white);draw_text(862,548,"SCENE PAINTING");
    draw_text(862,566,"Speed "+string_format(global.ln_paint_speed,1,2)+"x");
    draw_set_colour(make_colour_rgb(75,85,96));draw_rectangle(870,585,1110,589,false);
    draw_set_colour(make_colour_rgb(140,206,233));draw_circle(870+240*(global.ln_paint_speed-0.1)/4.9,587,5,false);
    draw_set_colour(c_white);draw_text(862,608,"Reset to original baseline: 1x");
}

function ln_paint_checks() {
    global.ln_preferences_enabled=true;global.ln_paint_speed=1;
    var _g={game_number:1,level:1,room_id:1,timer:new LNClock()};
    ln_check(ln_paint_tick(_g),"Painting starts on room entry");
    var _p=global.ln_paint;
    repeat(8) ln_paint_tick(_g);
    ln_check(_p.time==0 && !_p.presented,"Catch-up ticks cannot skip entry background");
    ln_paint_prepare();
    var _blank=buffer_create(240*144*4,buffer_fixed,1);buffer_get_surface(_blank,_p.surface,0);
    for(var _pixel=0;_pixel<240*144;_pixel++) ln_check((buffer_peek(_blank,_pixel*4,buffer_u32)&$ffffff)==_p.background,"First frame is solid source background");
    buffer_delete(_blank);
    ln_check(_p.background==global.ln_paint_palette[13],"Wastelands starts light green");
    ln_paint_tick(_g);var _one=_p.time;
    global.ln_paint_speed=2;ln_paint_tick(_g);
    ln_check(abs(_p.time-3*_one)<=0.00001,"Painting speed multiplier");
    var _expected=array_create(17280,0),_buffer=_p.buffer;
    buffer_seek(_buffer,buffer_seek_start,8);
    while(buffer_tell(_buffer)<buffer_get_size(_buffer)) {
        buffer_read(_buffer,buffer_u32);var _n=buffer_read(_buffer,buffer_u16);
        repeat(_n) {var _at=buffer_read(_buffer,buffer_u16);_expected[_at]=buffer_read(_buffer,buffer_u8);}
    }
    _p.time=_p.duration;
    ln_paint_prepare();
    var _out=surface_create(240,144);surface_set_target(_out);draw_clear(c_red);
    var _test_camera=camera_create_view(0,0,240,144);camera_apply(_test_camera);
    draw_surface(_p.surface,0,0);
    // Painting can be composed into a caller-owned bitmap target.
    draw_set_colour(c_white);draw_rectangle(238,143,240,144,false);surface_reset_target();
    ln_check(surface_getpixel(_out,239,143)==c_white,"Painting restores caller render target got "+string(surface_getpixel(_out,239,143)));
    var _pixels=buffer_create(240*144*4,buffer_fixed,1);buffer_get_surface(_pixels,_out,0);
    var _palette=global.ln_paint_palette;
    for(var _y=0;_y<144;_y++) for(var _x=0;_x<120;_x++) {
        if(_y==143 && _x==119) continue;
        ln_check((buffer_peek(_pixels,(_y*240+_x*2)*4,buffer_u32)&$ffffff)==_palette[_expected[_y*120+_x]],"Painting GPU final pixel");
    }
    buffer_delete(_pixels);surface_save(_out,"ln1-painting-complete.png");surface_free(_out);camera_destroy(_test_camera);
    ln_check(!ln_paint_tick(_g) && !_p.active && _p.buffer<0,"Painting finishes and frees resources");
    ln_check(!ln_paint_tick(_g),"Completed room does not restart painting");
    global.ln_rewind_epoch++;ln_check(ln_paint_tick(_g),"Room re-entry repaints");
    _g.loader={active:true};ln_check(!ln_paint_tick(_g) && !_p.active,"Loader releases painting");
    ln_paint_trilogy_checks();
    global.ln_preferences_enabled=false;global.ln_paint_speed=1;
    show_debug_message("LN_PAINT_PASS");
}

function ln_paint_trilogy_checks() {
    var _checked=0;
    for(var _game=2;_game<=3;_game++) for(var _level=1;_level<=(_game==2?7:5);_level++) {
        var _g={game_number:_game,level:_level,room_id:(_game==2 && _level==1)?1:0,timer:new LNClock()};
        global.ln_rewind_epoch++;ln_check(ln_paint_sync(_g),"Room paint starts for LN"+string(_game)+" level "+string(_level));
        var _p=global.ln_paint;
        repeat(5) ln_paint_tick(_g);
        ln_check(_p.time==0,"Entry draw precedes all painting ticks");ln_paint_prepare();
        var _pixels=buffer_create(240*144*4,buffer_fixed,1);buffer_get_surface(_pixels,_p.surface,0);
        for(var _i=0;_i<240*144;_i++) ln_check((buffer_peek(_pixels,_i*4,buffer_u32)&$ffffff)==_p.background,"Source background fills bitmap");
        var _expected=array_create(17280,0);buffer_seek(_p.buffer,buffer_seek_start,8);
        while(buffer_tell(_p.buffer)<buffer_get_size(_p.buffer)) {
            buffer_read(_p.buffer,buffer_u32);var _count=buffer_read(_p.buffer,buffer_u16);
            repeat(_count) {var _pixel=buffer_read(_p.buffer,buffer_u16);_expected[_pixel]=buffer_read(_p.buffer,buffer_u8);}
        }
        _p.time=_p.duration;ln_paint_prepare();buffer_get_surface(_pixels,_p.surface,0);
        for(var _i=0;_i<17280;_i++) ln_check((buffer_peek(_pixels,_i*8,buffer_u32)&$ffffff)==global.ln_paint_palette[_expected[_i]],"LN"+string(_game)+" level "+string(_level)+" final pixel "+string(_i));
        surface_save(_p.surface,"ln"+string(_game)+"-painting-level"+string(_level)+".png");
        // GPU surface loss must reproduce the same completed painting from patches.
        surface_free(_p.surface);ln_paint_prepare();buffer_get_surface(_pixels,_p.surface,0);
        for(var _i=0;_i<17280;_i++) ln_check((buffer_peek(_pixels,_i*8,buffer_u32)&$ffffff)==global.ln_paint_palette[_expected[_i]],"Paint survives GPU surface loss");
        buffer_delete(_pixels);ln_check(!ln_paint_tick(_g),"Painting hands back to gameplay");
        ln_check(!ln_paint_sync(_g),"Finished room does not repaint");
        _g.loader={active:true};ln_check(!ln_paint_sync(_g),"Loader remains outside painting");
        _g.loader=undefined;
        if(_game==3) {
            _g.intro={};ln_check(!ln_paint_sync(_g),"LN3 intro remains outside painting");
            _g.intro=undefined;_g.ending={};ln_check(!ln_paint_sync(_g),"LN3 outro remains outside painting");
        } else {_g.victory=2;ln_check(!ln_paint_sync(_g),"LN2 ending remains outside painting");}
        _checked++;
    }
    show_debug_message("LN_PAINT_TRILOGY_PASS: "+string(_checked)+" LN2/LN3 level backgrounds, final GPU pixels, surface loss and presentation exclusions");
}
