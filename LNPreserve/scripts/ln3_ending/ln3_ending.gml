function LN3Ending() constructor {
    data=ln3_data_read("play/ln3/ending.json");phase=0;wait=0;reveal=252;
    frame=data.panels[0];background=0;animation_index=0;animation_cycles=0;flash_step=0;
    scroll_counter=0;scroll_cursor=0;scroll_marker=128;scroll_pixels=0;exit_requested=false;finished=false;
    scroll_surface=-1;
}

function ln3_ending_free(_g) {
    ln3_intro_free(_g);
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

/// Original intro display frames, recovered offline. No emulator runs in-game.
function ln3_intro_free(_g) {
    if (!variable_struct_exists(_g,"intro") || !is_struct(_g.intro)) return;
    var _p=_g.intro;
    if (buffer_exists(_p.stream)) buffer_delete(_p.stream);
    if (buffer_exists(_p.pixels)) buffer_delete(_p.pixels);
    if (surface_exists(_p.surface)) surface_free(_p.surface);
    _g.intro=undefined;
}

function LN3Intro() constructor {
    stream=buffer_load("play/ln3/intro.bin");
    if (buffer_read(stream,buffer_u32)!=$33494e4c) throw "Invalid LN3 intro data";
    count=buffer_read(stream,buffer_u32);tick=0;previous_fire=true;
    pixels=buffer_create(320*200*4,buffer_fixed,1);
    buffer_fill(pixels,0,buffer_u32,$ff000000,320*200*4);
    surface=-1;dirty=true;
}

function ln3_intro_frame(_p) {
    if (_p.tick>=_p.count) return;
    var _runs=buffer_read(_p.stream,buffer_u16);
    repeat(_runs) {
        var _start=buffer_read(_p.stream,buffer_u16)*4,_bytes=buffer_read(_p.stream,buffer_u16)*4;
        var _offset=buffer_tell(_p.stream);
        buffer_copy(_p.stream,_offset,_bytes,_p.pixels,_start);
        buffer_seek(_p.stream,buffer_seek_relative,_bytes);
    }
    _p.tick++;if (_runs>0) _p.dirty=true;
}

function ln3_presentation_music(_g,_intro) {
    if (variable_global_exists("ln_music_voice") && global.ln_music_voice>=0) audio_stop_sound(global.ln_music_voice);
    var _asset=asset_get_index(_intro?"snd_ln3_intro_cue":"snd_ln3_outro_cue");
    global.ln_music_voice=audio_play_sound(_asset,0,true);
    if (!_g.music) audio_pause_sound(global.ln_music_voice);
}

function ln3_presentation_open(_t,_g,_intro) {
    var _music=_g.music;
    ln_game_select(_g,3,_intro?1:5);ln3_ending_free(_g);
    _g.music=_music;_g.loader=undefined;_g.paused=false;
    _g.game_over=false;_g.level_complete=false;
    if (_intro) _g.intro=new LN3Intro();else _g.ending=new LN3Ending();
    ln3_presentation_music(_g,_intro);
    _t.game=3;_t.menu=false;_t.preview=false;
    for (var _i=0;_i<array_length(_t.levels);_i++) {
        if (_t.levels[_i].game==3 && _t.levels[_i].number==_g.level) {_t.level_index=_i;break;}
    }
    _t.scene_index=0;
}

function ln3_intro_tick(_g,_joy) {
    if (!is_struct(_g.intro)) return false;
    var _p=_g.intro,_fire=(_joy&16)!=0,_pressed=_fire&&!_p.previous_fire;
    _p.previous_fire=_fire;
    if (_pressed || _p.tick>=_p.count) {
        ln3_intro_free(_g);ln3_test_enter(_g,_g.data.initial.room_id);
        ln_frontend_begin(_g);return true;
    }
    ln3_intro_frame(_p);return true;
}

function ln3_intro_draw(_g) {
    var _p=_g.intro;
    if (!surface_exists(_p.surface)) {_p.surface=surface_create(320,200);_p.dirty=true;}
    if (_p.dirty) {buffer_set_surface(_p.pixels,_p.surface,0);_p.dirty=false;}
    draw_clear(c_black);draw_set_colour(c_white);
    draw_surface_ext(_p.surface,0,0,4,4,0,c_white,1);
}

function ln3_intro_checks() {
    var _p=new LN3Intro(),_meta=ln3_data_read("play/ln3/intro.json"),_index=0;
    while (_p.tick<_p.count) {
        ln3_intro_frame(_p);
        if (_index<array_length(_meta.checks) && _p.tick==_meta.checks[_index].tick) {
            ln_check(buffer_md5(_p.pixels,0,320*200*4)==_meta.checks[_index].md5,"LN3 original intro pixels "+string(_p.tick));
            _index++;
        }
    }
    ln_check(_index==array_length(_meta.checks) && buffer_tell(_p.stream)==buffer_get_size(_p.stream),"LN3 complete intro stream consumed");
    var _holder={intro:_p};ln3_intro_free(_holder);
    var _g=new LN3Play(1);_g.intro=new LN3Intro();
    ln3_intro_tick(_g,16);ln_check(is_struct(_g.intro),"held fire cannot skip intro on entry");
    ln3_intro_tick(_g,0);ln3_intro_tick(_g,16);
    ln_check(!is_struct(_g.intro) && ln2_loader_active(_g) && _g.level==1,"fresh fire opens Earth frontend");
    _g.intro=new LN3Intro();ln3_test_enter(_g,_g.data.initial.room_id);
    ln_check(!is_struct(_g.intro),"scene selection frees intro buffers");
    ln3_ending_free(_g);
    show_debug_message("LN3_INTRO_PASS: complete source capture, input release and cleanup");
}


function ln3_presentation_checks(_catalog) {
    ln3_intro_checks();
    var _t=new LNSceneTest(_catalog),_g=new LN1Play();
    _g.music=false;ln3_presentation_open(_t,_g,true);
    ln_check(_g.game_number==3 && _g.level==1 && is_struct(_g.intro) && !_t.menu && !_g.music,"intro selection from LN1, muted");
    repeat(2201) ln3_intro_frame(_g.intro);
    ln3_intro_draw(_g);surface_save(_g.intro.surface,"ln3-intro-preview.png");
    var _b=buffer_create(320*200*4,buffer_fixed,1);
    buffer_get_surface(_b,_g.intro.surface,0);
    ln_check(buffer_md5(_b,0,320*200*4)==buffer_md5(_g.intro.pixels,0,320*200*4),"intro GPU upload matches original RGBA pixels");
    buffer_delete(_b);
    var _stream=_g.intro.stream;
    ln3_presentation_open(_t,_g,false);
    ln_check(!buffer_exists(_stream) && is_struct(_g.ending) && _g.level==5,"outro replaces and frees intro");
    repeat(300) ln3_ending_tick(_g.ending,0);ln3_ending_draw(_g);
    surface_save(_g.ending_surface,"ln3-outro-preview.png");
    _t.menu=true;
    var _menu_surface=surface_create(1280,800);
    surface_set_target(_menu_surface);ln_scene_test_draw(_t);surface_reset_target();
    surface_save(_menu_surface,"ln3-presentation-menu.png");surface_free(_menu_surface);
    ln_scene_test_open(_t,_g,0);
    ln_check(!is_struct(_g.ending) && !is_struct(_g.intro),"normal scene selection closes presentation");
    ln3_ending_free(_g);
    show_debug_message("LN3_PRESENTATION_PASS: intro, outro, GPU pixels, selector and resource cleanup");
    show_debug_message("LN_CAPTURE_DIRECTORY:"+game_save_id);
}
