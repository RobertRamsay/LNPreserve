function LN3Ending() constructor {
    data=ln3_data_read("play/ln3/ending.json");phase=0;wait=0;reveal=252;
    frame=data.panels[0];background=0;animation_index=0;animation_cycles=0;flash_step=0;
    scroll_counter=0;scroll_cursor=0;scroll_marker=128;scroll_pixels=0;exit_requested=false;finished=false;
    scroll_surface=-1;
}

function ln3_ending_free(_g) {
    if (variable_struct_exists(_g,"ending") && is_struct(_g.ending) && surface_exists(_g.ending.scroll_surface)) surface_free(_g.ending.scroll_surface);
    if (variable_struct_exists(_g,"ending_surface") && surface_exists(_g.ending_surface)) surface_free(_g.ending_surface);
    _g.ending=undefined;_g.ending_surface=-1;
}

function ln3_ending_scroll_tick(_e) {
    if (_e.scroll_marker<128) return;
    if ((_e.scroll_counter&3)==0) {
        if (_e.scroll_cursor>=string_length(_e.data.text)) {_e.scroll_marker=36;return;}
        _e.scroll_cursor++;
    }
    _e.scroll_counter=(_e.scroll_counter+1)&255;_e.scroll_pixels+=2;
}

function ln3_ending_tick(_e,_joy) {
    if (_e.finished) return;
    if (_e.phase==16) {
        ln3_ending_scroll_tick(_e);
        if ((_joy&16)!=0) _e.exit_requested=true;
        if (_e.exit_requested && _e.scroll_marker<128) {_e.phase=17;_e.reveal=8;}
        return;
    }
    if (_e.phase==17) {
        _e.reveal=min(252,_e.reveal+4);
        if (_e.reveal==252) _e.finished=true;
        return;
    }
    if (_e.phase==0) {
        _e.reveal=max(0,_e.reveal-4);
        if (_e.reveal==0) {_e.phase=1;_e.wait=250;}
        return;
    }
    if (_e.wait>0) _e.wait--;
    if (_e.phase==2) {
        // Original RLE update costs include the caller's JSR/poll/branch.
        // Whole-image completion is scheduled here; mid-draw VIC output is pending.
        _e.animation_cycles+=19656;
        while (_e.animation_cycles>=_e.data.animation[_e.animation_index].cycles) {
            _e.animation_cycles-=_e.data.animation[_e.animation_index].cycles;
            _e.frame=_e.data.animation[_e.animation_index].frame;
            _e.animation_index=(_e.animation_index+1) mod 4;
        }
    }
    if (_e.wait>0) return;
    switch (_e.phase) {
        case 1:_e.phase=2;_e.wait=250;_e.animation_index=0;_e.animation_cycles=0;break;
        case 2:_e.phase=3;_e.frame=_e.data.flash_panel;_e.flash_step=8;_e.background=_e.data.background_fade[8];_e.wait=2;break;
        case 3:
            _e.flash_step--;
            if (_e.flash_step>=0) {_e.background=_e.data.background_fade[_e.flash_step];_e.wait=2;}
            else {_e.phase=4;_e.wait=25;}
            break;
        case 4:_e.phase=5;_e.flash_step=0;_e.background=_e.data.background_fade[0];_e.wait=2;break;
        case 5:
            _e.flash_step++;
            if (_e.flash_step<9) {_e.background=_e.data.background_fade[_e.flash_step];_e.wait=2;}
            else {_e.phase=6;_e.frame=_e.data.silhouette;_e.flash_step=5;_e.background=1;_e.wait=4;}
            break;
        case 6:
            _e.flash_step--;
            if (_e.flash_step>=0) {_e.background=_e.flash_step&1;_e.wait=4;}
            else {_e.phase=7;_e.wait=250;}
            break;
        case 7:_e.phase=8;_e.background=0;_e.frame=_e.data.panels[2];_e.wait=250;break;
        case 8:_e.phase=9;_e.frame=_e.data.panels[3];_e.wait=250;break;
        case 9:_e.phase=10;_e.wait=250;break;
        case 10:_e.phase=11;_e.wait=50;break;
        case 11:_e.phase=16;_e.frame=_e.data.panels[5];break;
    }
}

function ln3_ending_scroll_draw(_e) {
    if (!surface_exists(_e.scroll_surface)) _e.scroll_surface=surface_create(128,8);
    surface_set_target(_e.scroll_surface);draw_clear(c_black);
    var _start=max(0,(_e.scroll_pixels-128) div 8),_end=min(_e.scroll_cursor,string_length(_e.data.text));
    for (var _i=_start;_i<_end;_i++) {
        var _char=string_char_at(_e.data.text,_i+1),_frame=variable_struct_get(_e.data.characters,_char);
        draw_sprite(asset_get_index(_e.data.font_sprite),_frame,128-_e.scroll_pixels+_i*8,0);
    }
    surface_reset_target();draw_surface(_e.scroll_surface,104,152);
}

function ln3_ending_draw(_g) {
    var _e=_g.ending;
    if (!surface_exists(_g.ending_surface)) _g.ending_surface=surface_create(320,200);
    surface_set_target(_g.ending_surface);draw_clear(_g.palette[_e.background&15]);
    draw_sprite(asset_get_index(_e.data.sprite),_e.frame,0,0);
    if (_e.phase>=16) ln3_ending_scroll_draw(_e);
    surface_reset_target();draw_clear(c_black);
    draw_surface_part_ext(_g.ending_surface,0,0,320,max(0,200-_e.reveal),0,_e.reveal*4,4,4,c_white,1);
}

function ln3_ending_checks() {
    var _e=new LN3Ending(),_o=ln3_data_read("verification/ln3_ending_vectors.json");
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];ln3_ending_scroll_tick(_e);
        ln_check(_e.scroll_counter==_v.counter && _e.scroll_cursor==_v.cursor && _e.scroll_marker==_v.marker,"LN3 original ending scroll state "+string(_i));
    }
    _e=new LN3Ending();var _ticks=0;
    while (_e.phase!=16 && _ticks<2000) {ln3_ending_tick(_e,0);_ticks++;}
    ln_check(_e.phase==16 && _e.frame==_e.data.panels[5],"LN3 original ending sequence reaches final text panel");
    repeat(1736) ln3_ending_tick(_e,0);
    ln_check(!_e.finished && _e.scroll_marker==36,"LN3 ending waits for action after original text");
    ln3_ending_tick(_e,16);repeat(61) ln3_ending_tick(_e,0);
    ln_check(_e.finished,"LN3 ending reaches original high-score request boundary");
    show_debug_message("LN3_ENDING_PASS: "+string(array_length(_o.vectors))+" original scroll states and native sequence completion; raster reveal/mid-draw timing and high-score program pending.");
}

function ln3_ending_gpu_checks() {
    var _e=new LN3Ending(),_o=ln3_data_read("verification/ln3_ending_vectors.json"),_surface=surface_create(320,200);
    var _b=buffer_create(128*8*4,buffer_fixed,1),_count=0;
    var _palette=ln3_data_read("play/ln3/level5/runtime.json").palette;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        ln3_ending_scroll_tick(_e);if (_i mod 31!=0 && _i!=array_length(_o.vectors)-1) continue;
        surface_set_target(_surface);ln3_ending_scroll_draw(_e);surface_reset_target();buffer_get_surface(_b,_e.scroll_surface,0);
        var _v=_o.vectors[_i];
        for (var _y=0;_y<8;_y++) for (var _x=0;_x<128;_x++) {
            var _code=(_v.bitmap[(_x div 8)*8+_y]>>(6-(_x mod 8 div 2)*2))&3;
            var _rgb=_palette[_e.data.scroll_colours[_code]],_actual=buffer_peek(_b,(_y*128+_x)*4,buffer_u32)&$ffffff;
            ln_check(_actual==make_colour_rgb(_rgb[0],_rgb[1],_rgb[2]),"LN3 original ending scroll pixel "+string(_i)+":"+string(_x)+":"+string(_y));_count++;
        }
    }
    buffer_delete(_b);surface_free(_surface);surface_free(_e.scroll_surface);
    show_debug_message("LN3_ENDING_GPU_PASS: "+string(_count)+" original ending scroll pixels rendered from editable font PNGs.");
}
