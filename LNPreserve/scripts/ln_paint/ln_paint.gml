// Cosmetic playback, separate from gameplay snapshots and saved games.
function ln_paint_free() {
    if(!variable_global_exists("ln_paint")) return;
    var _p=global.ln_paint;
    if(_p.buffer>=0) buffer_delete(_p.buffer);
    if(surface_exists(_p.surface)) surface_free(_p.surface);
    _p.buffer=-1;_p.surface=-1;_p.active=false;
}
function ln_paint_tick(_g) {
    if(!global.ln_preferences_enabled || _g.game_number!=1) {ln_paint_free();return false;}
    var _p=global.ln_paint;
    var _key=string(_g.level)+"-"+string(_g.room_id)+":"+string(global.ln_rewind_epoch);
    if(_key!=_p.key) {
        ln_paint_free();_p.key=_key;_p.time=0;_p.cursor=8;
        var _file="play/ln1/painting/"+string(_g.level)+"-"+string(_g.room_id)+".bin";
        if(!file_exists(_file)) return false;
        _p.buffer=buffer_load(_file);_p.duration=buffer_peek(_p.buffer,0,buffer_u32)/985248;
        _p.active=true;
    }
    if(!_p.active) return false;
    _p.time+=global.ln_paint_speed*_g.timer.cycles_per_frame/_g.timer.hz;
    if(_p.time>=_p.duration) {ln_paint_free();return false;}
    return true;
}
function ln_paint_prepare() {
    var _p=global.ln_paint;if(!_p.active || _p.buffer<0) return;
    // Rebuild from recorded patches after GPU surface loss.
    if(!surface_exists(_p.surface)) {
        _p.surface=surface_create(240,144);_p.cursor=8;
        surface_set_target(_p.surface);draw_clear(c_black);surface_reset_target();
    }
    surface_set_target(_p.surface);
    var _view=matrix_get(matrix_view),_projection=matrix_get(matrix_projection);
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
        if(mouse_check_button_pressed(mb_left) && mouse_x>=860 && mouse_x<=1130 && abs(mouse_y-587)<=12) global.ln_paint_drag=true;
        if(!mouse_check_button(mb_left)) global.ln_paint_drag=false;
        if(global.ln_paint_drag) global.ln_paint_speed=round((0.25+3.75*clamp((mouse_x-870)/240,0,1))*20)/20;
        if(mouse_check_button_pressed(mb_left) && mouse_x>=860 && mouse_x<=1130 && mouse_y>=606 && mouse_y<=625) global.ln_paint_speed=1;
        return;
    }
    draw_set_colour(c_white);draw_text(862,548,"LN1 SCENE PAINTING");
    draw_text(862,566,"Speed "+string_format(global.ln_paint_speed,1,2)+"x");
    draw_set_colour(make_colour_rgb(75,85,96));draw_rectangle(870,585,1110,589,false);
    draw_set_colour(make_colour_rgb(140,206,233));draw_circle(870+240*(global.ln_paint_speed-0.25)/3.75,587,5,false);
    draw_set_colour(c_white);draw_text(862,608,"Reset to original baseline: 1x");
}

function ln_paint_checks() {
    global.ln_preferences_enabled=true;global.ln_paint_speed=1;
    var _g={game_number:1,level:1,room_id:1,timer:new LNClock()};
    ln_check(ln_paint_tick(_g),"Painting starts on room entry");
    var _p=global.ln_paint,_one=_p.time;
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
    _g.game_number=2;ln_check(!ln_paint_tick(_g) && !_p.active,"Other games release painting");
    global.ln_preferences_enabled=false;global.ln_paint_speed=1;
    show_debug_message("LN_PAINT_PASS");
}
