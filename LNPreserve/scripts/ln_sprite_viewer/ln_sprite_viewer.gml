function LNSpriteViewer() constructor {
    open=false;catalog=undefined;game=1;category=0;list=[];selected=0;
    animation=0;frame=0;elapsed=0;paused=false;cycle=true;mirror=false;
    voices=[];bounds=[0,0,1,1];assets={};
}
function ln_sprite_asset(_name) {
    var _v=global.ln_sprites;
    if(!variable_struct_exists(_v.assets,_name)) variable_struct_set(_v.assets,_name,asset_get_index(_name));
    return variable_struct_get(_v.assets,_name);
}
function ln_sprite_filter() {
    var _v=global.ln_sprites;_v.list=[];
    if(!is_struct(_v.catalog)) _v.catalog=ln3_data_read("sprite_viewer.json");
    for(var _i=0;_i<array_length(_v.catalog.entries);_i++) {
        var _e=_v.catalog.entries[_i];
        if(_e.game==_v.game && _e.category==_v.category) array_push(_v.list,_e);
    }
    _v.selected=0;_v.animation=0;ln_sprite_reset();
}
function ln_sprite_reset() {
    var _v=global.ln_sprites;_v.frame=0;_v.elapsed=0;
    var _frames=_v.list[_v.selected].clips[_v.animation].frames;
    var _left=100000,_top=100000,_right=-100000,_bottom=-100000;
    for(var _i=0;_i<array_length(_frames);_i++) {
        var _parts=_frames[_i].parts;
        for(var _j=0;_j<array_length(_parts);_j++) {
            var _p=_parts[_j],_s=ln_sprite_asset(_p[0]);if(_s<0) continue;
            var _sx=array_length(_p)>5?_p[5]:1,_sy=array_length(_p)>6?_p[6]:1;
            var _x=_p[2]-sprite_get_xoffset(_s)*_sx,_y=_p[3]-sprite_get_yoffset(_s)*_sy;
            _left=min(_left,_x+sprite_get_bbox_left(_s)*_sx);_top=min(_top,_y+sprite_get_bbox_top(_s)*_sy);
            _right=max(_right,_x+(sprite_get_bbox_right(_s)+1)*_sx);_bottom=max(_bottom,_y+(sprite_get_bbox_bottom(_s)+1)*_sy);
        }
    }
    _v.bounds=_right>_left?[_left,_top,_right,_bottom]:[0,0,1,1];
}
function ln_sprite_next(_direction,_animation=false) {
    var _v=global.ln_sprites;
    if(_animation) {
        var _count=array_length(_v.list[_v.selected].clips);
        _v.animation=(_v.animation+_direction+_count) mod _count;
    } else {_v.selected=(_v.selected+_direction+array_length(_v.list)) mod array_length(_v.list);_v.animation=0;}
    ln_sprite_reset();
}
function ln_sprite_toggle(_host) {
    var _v=global.ln_sprites;
    if(_v.open) {
        _v.open=false;
        for(var _i=0;_i<array_length(_v.voices);_i++) if(audio_is_paused(_v.voices[_i])) audio_resume_sound(_v.voices[_i]);
        _v.voices=[];_host.input_state=new LNInput();
    } else {
        if(global.ln_tracks.open) ln_track_toggle(_host);
        var _voices=[];_v.voices=[];
        if(variable_global_exists("ln_music_voice")) array_push(_voices,global.ln_music_voice);
        if(_host.play.game_number==3 && is_struct(_host.play.intro)) array_push(_voices,_host.play.intro.voice);
        for(var _j=0;_j<array_length(_voices);_j++) {
            var _voice=_voices[_j];
            if(_voice>=0 && audio_is_playing(_voice) && !audio_is_paused(_voice) && !array_contains(_v.voices,_voice)) {
                audio_pause_sound(_voice);array_push(_v.voices,_voice);
            }
        }
        if(!is_struct(_v.catalog)) ln_sprite_filter();
        _v.open=true;
    }
}
function ln_sprite_advance(_seconds) {
    var _v=global.ln_sprites;if(_v.paused) return;
    _v.elapsed+=_seconds;
    var _clip=_v.list[_v.selected].clips[_v.animation],_guard=0;
    while(_v.elapsed>=_clip.frames[_v.frame].seconds && _guard++<100) {
        _v.elapsed-=_clip.frames[_v.frame].seconds;_v.frame++;
        if(_v.frame>=array_length(_clip.frames)) {
            if(_v.cycle) ln_sprite_next(1,true);else _v.frame=0;
            _clip=_v.list[_v.selected].clips[_v.animation];
        }
    }
}
function ln_sprite_step(_host) {
    var _v=global.ln_sprites,_click=mouse_check_button_pressed(mb_left);
    if(global.ln_tool.active && ln_tool_ui_visible() && _click && mouse_x>=688 && mouse_x<926 && mouse_y>=56 && mouse_y<84) {
        ln_sprite_toggle(_host);return true;
    }
    if(!_v.open) return false;
    if(_click && mouse_x>=940 && mouse_x<1178 && mouse_y>=56 && mouse_y<84) {ln_sprite_toggle(_host);return false;}
    if(keyboard_check_pressed(vk_escape) || ln_edit_hit(1030,20,220,28)) {ln_sprite_toggle(_host);return true;}
    if(keyboard_check_pressed(vk_f9)) ln_fullscreen_toggle(_host);
    for(var _g=1;_g<=3;_g++) if(ln_edit_hit(24+(_g-1)*160,76,150,28)) {_v.game=_g;ln_sprite_filter();}
    for(var _c=0;_c<3;_c++) if(ln_edit_hit(600+_c*190,76,180,28)) {_v.category=_c;ln_sprite_filter();}
    if(ln_edit_hit(24,116,50,28)) ln_sprite_next(-1);
    if(ln_edit_hit(1200,116,50,28)) ln_sprite_next(1);
    if(ln_edit_hit(24,688,50,28)) ln_sprite_next(-1,true);
    if(ln_edit_hit(1200,688,50,28)) ln_sprite_next(1,true);
    if(ln_edit_hit(24,744,160,28)) _v.paused=!_v.paused;
    if(ln_edit_hit(204,744,220,28)) _v.cycle=!_v.cycle;
    if(ln_edit_hit(444,744,180,28)) _v.mirror=!_v.mirror;
    ln_sprite_advance(min(delta_time/1000000,.1));return true;
}
function ln_sprite_draw() {
    var _v=global.ln_sprites;shader_reset();gpu_set_blendmode(bm_normal);gpu_set_texfilter(false);
    draw_set_alpha(1);draw_clear(make_colour_rgb(18,20,25));draw_set_font(font_jansina);
    draw_set_halign(fa_left);draw_set_valign(fa_top);draw_set_colour(c_white);
    draw_text(24,24,"SPRITE VIEWER");ln_edit_button(1030,20,220,"Back (Esc)");
    for(var _g=1;_g<=3;_g++) ln_edit_button(24+(_g-1)*160,76,150,"Last Ninja "+string(_g),_v.game==_g);
    var _categories=["NINJA","ENEMIES","MISC"];
    for(var _c=0;_c<3;_c++) ln_edit_button(600+_c*190,76,180,_categories[_c],_v.category==_c);
    var _entry=_v.list[_v.selected],_clip=_entry.clips[_v.animation];
    ln_edit_button(24,116,50,"<");ln_edit_button(1200,116,50,">");
    draw_text(100,121,string(_v.selected+1)+" / "+string(array_length(_v.list))+"   "+_entry.name);
    draw_set_colour(make_colour_rgb(100,105,112));draw_rectangle(24,160,1250,660,false);
    var _b=_v.bounds,_scale=max(1,min(6,floor(min(1160/max(1,_b[2]-_b[0]),440/max(1,_b[3]-_b[1])))));
    var _cx=637,_cy=410,_parts=_clip.frames[_v.frame].parts,_flip=_v.mirror?-1:1;
    for(var _i=0;_i<array_length(_parts);_i++) {
        var _p=_parts[_i],_s=ln_sprite_asset(_p[0]);if(_s<0) continue;
        draw_sprite_ext(_s,_p[1],_cx+(_p[2]-(_b[0]+_b[2])/2)*_scale*_flip,
            _cy+(_p[3]-(_b[1]+_b[3])/2)*_scale,_scale*_flip*(array_length(_p)>5?_p[5]:1),_scale*(array_length(_p)>6?_p[6]:1),0,_p[4],1);
    }
    draw_set_colour(c_white);ln_edit_button(24,688,50,"<");ln_edit_button(1200,688,50,">");
    draw_text(100,693,string(_v.animation+1)+" / "+string(array_length(_entry.clips))+"   "+_clip.name);
    ln_edit_button(24,744,160,_v.paused?"Play":"Pause");
    ln_edit_button(204,744,220,"Cycle animations",_v.cycle);ln_edit_button(444,744,180,"Mirror",_v.mirror);
    draw_text(660,749,"Frame "+string(_v.frame+1)+" / "+string(array_length(_clip.frames))+"   "+string(_scale)+"x");
}
function ln_sprite_checks(_host) {
    var _v=global.ln_sprites;ln_sprite_filter();
    for(var _g=1;_g<=3;_g++) for(var _c=0;_c<3;_c++) {
        _v.game=_g;_v.category=_c;ln_sprite_filter();ln_check(array_length(_v.list)>0,"sprite category populated");
        for(var _e=0;_e<array_length(_v.list);_e++) {
            var _entry=_v.list[_e];
            for(var _a=0;_a<array_length(_entry.clips);_a++) {
                var _clip=_entry.clips[_a];ln_check(array_length(_clip.frames)>0,"animation has frames");
                for(var _f=0;_f<array_length(_clip.frames);_f++) {
                    var _frame=_clip.frames[_f];ln_check(_frame.seconds>0,"positive frame duration");
                    for(var _p=0;_p<array_length(_frame.parts);_p++) {
                        var _part=_frame.parts[_p],_s=ln_sprite_asset(_part[0]);
                        ln_check(_s>=0 && _part[1]>=0 && _part[1]<sprite_get_number(_s),"valid sprite pose");
                    }
                }
            }
        }
        ln_sprite_next(-1);ln_check(_v.selected==array_length(_v.list)-1,"previous wraps");ln_sprite_next(1);
        ln_check(_v.selected==0,"next wraps");
    }
    _v.game=1;_v.category=0;ln_sprite_filter();_v.paused=true;ln_sprite_advance(1);ln_check(_v.frame==0,"pause freezes pose");
    _v.paused=false;ln_sprite_advance(.2);ln_check(_v.frame>0,"animation advances");
    ln_sprite_toggle(_host);ln_sprite_toggle(_host);ln_check(!_v.open,"viewer closes");
    ln_sprite_toggle(_host);global.ln_tool.active=true;show_debug_message("LN_SPRITE_VIEWER_PASS");
}
