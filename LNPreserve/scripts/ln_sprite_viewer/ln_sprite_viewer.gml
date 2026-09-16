function LNSpriteViewer() constructor {
    open=false;catalog=undefined;game=1;category=0;list=[];selected=0;
    animation=0;frame=0;elapsed=0;paused=false;cycle=true;mirror=false;
    voices=[];bounds=[0,0,1,1];assets={};
    crt_enabled=false;zoom=3;preview_surface=-1;preview_camera=-1;
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
        _v.open=false;ln_track_stop(global.ln_tracks);
        for(var _i=0;_i<array_length(_v.voices);_i++) if(audio_is_paused(_v.voices[_i])) audio_resume_sound(_v.voices[_i]);
        _v.voices=[];_host.input_state=new LNInput();
    } else {
        if(global.ln_tracks.open) {ln_track_to_sprite();return;}
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
    if(ln_tool_media_hit(0)) {
        ln_sprite_toggle(_host);return true;
    }
    if(!_v.open) return false;
    ln_track_poll(global.ln_tracks);
    if(ln_tool_media_hit(1)) {ln_sprite_to_track();return true;}
    if(keyboard_check_pressed(vk_escape) || ln_edit_hit(1030,20,220,28)) {ln_sprite_toggle(_host);return true;}
    if(keyboard_check_pressed(vk_f9)) ln_fullscreen_toggle(_host);
    if(keyboard_check_pressed(vk_f10) || ln_edit_hit(770,20,240,28)) _v.crt_enabled=!_v.crt_enabled;
    for(var _g=1;_g<=3;_g++) if(ln_edit_hit(24+(_g-1)*160,76,150,28)) {_v.game=_g;ln_sprite_filter();}
    for(var _c=0;_c<3;_c++) if(ln_edit_hit(600+_c*190,76,180,28)) {_v.category=_c;ln_sprite_filter();}
    if(ln_edit_hit(24,116,50,28)) ln_sprite_next(-1);
    if(ln_edit_hit(1200,116,50,28)) ln_sprite_next(1);
    if(ln_edit_hit(24,688,50,28)) ln_sprite_next(-1,true);
    if(ln_edit_hit(1200,688,50,28)) ln_sprite_next(1,true);
    if(ln_edit_hit(24,744,160,28)) _v.paused=!_v.paused;
    if(ln_edit_hit(204,744,220,28)) _v.cycle=!_v.cycle;
    if(ln_edit_hit(444,744,180,28)) _v.mirror=!_v.mirror;
    if(ln_edit_hit(1010,744,40,28)) _v.zoom=max(1,_v.zoom-1);
    if(ln_edit_hit(1210,744,40,28)) _v.zoom=min(6,_v.zoom+1);
    ln_sprite_advance(min(delta_time/1000000,.1));return true;
}
function ln_sprite_draw() {
    var _v=global.ln_sprites;shader_reset();gpu_set_blendmode(bm_normal);gpu_set_texfilter(false);
    draw_set_alpha(1);ln_tool_clear(false);draw_set_font(font_jansina);
    draw_set_halign(fa_left);draw_set_valign(fa_top);draw_set_colour(c_white);
    ln_edit_button(770,20,240,"CRT "+(_v.crt_enabled?"ON":"OFF")+" (F10)",_v.crt_enabled);
    draw_text(24,24,"SPRITE VIEWER");ln_edit_button(1030,20,220,"Back (Esc)");
    for(var _g=1;_g<=3;_g++) ln_edit_button(24+(_g-1)*160,76,150,"Last Ninja "+string(_g),_v.game==_g);
    var _categories=["NINJA","ENEMIES","MISC"];
    for(var _c=0;_c<3;_c++) ln_edit_button(600+_c*190,76,180,_categories[_c],_v.category==_c);
    var _entry=_v.list[_v.selected],_clip=_entry.clips[_v.animation];
    ln_edit_button(24,116,50,"<");ln_edit_button(1200,116,50,">");
    draw_text(100,121,string(_v.selected+1)+" / "+string(array_length(_v.list))+"   "+_entry.name);
    // Canvas dimensions affect centring only; zoom stays fixed across every
    // game, asset and animation. The surface clips large poses to the viewport.
    var _view=matrix_get(matrix_view),_projection=matrix_get(matrix_projection);
    if(!surface_exists(_v.preview_surface)) _v.preview_surface=surface_create(1226,500);
    if(_v.preview_camera<0) _v.preview_camera=camera_create_view(0,0,1226,500);
    surface_set_target(_v.preview_surface);camera_apply(_v.preview_camera);draw_clear_alpha(c_black,0);
    var _b=_clip.visible_bounds,_scale=_v.zoom;
    var _cx=613,_cy=250,_parts=_clip.frames[_v.frame].parts,_flip=_v.mirror?-1:1;
    var _origin_x=round(_cx-(_b[0]+_b[2])/2*_scale*_flip),_origin_y=round(_cy-(_b[1]+_b[3])/2*_scale);
    // One standing anchor per character, shared by all its animations.
    if(variable_struct_exists(_entry,"ground_anchor")) {
        _origin_x=round(_cx-_entry.ground_anchor[0]*_scale*_flip);
        _origin_y=round(_cy+(_entry.standing_height/2-_entry.ground_anchor[1])*_scale);
    }
    for(var _i=0;_i<array_length(_parts);_i++) {
        var _p=_parts[_i],_s=ln_sprite_asset(_p[0]);if(_s<0) continue;
        draw_sprite_ext(_s,_p[1],_origin_x+_p[2]*_scale*_flip,
            _origin_y+_p[3]*_scale,_scale*_flip*(array_length(_p)>5?_p[5]:1),_scale*(array_length(_p)>6?_p[6]:1),0,_p[4],1);
    }
    surface_reset_target();matrix_set(matrix_view,_view);matrix_set(matrix_projection,_projection);
    // Draw only a local grey halo behind the transparent sprite picture.
    var _radius=5*_scale;
    var _lx=clamp(floor(_origin_x+min(_b[0]*_flip,_b[2]*_flip)*_scale-_radius-1),0,1226);
    var _ly=clamp(floor(_origin_y+_b[1]*_scale-_radius-1),0,500);
    var _rx=clamp(ceil(_origin_x+max(_b[0]*_flip,_b[2]*_flip)*_scale+_radius+1),0,1226);
    var _by=clamp(ceil(_origin_y+_b[3]*_scale+_radius+1),0,500);
    draw_set_colour(c_white);
    if(shader_is_compiled(sh_ln_sprite_halo) && _rx>_lx && _by>_ly) {
        shader_set(sh_ln_sprite_halo);
        shader_set_uniform_f(shader_get_uniform(sh_ln_sprite_halo,"u_texel"),1/1226,1/500);
        shader_set_uniform_f(shader_get_uniform(sh_ln_sprite_halo,"u_radius"),_radius);
        var _filter=gpu_get_texfilter();gpu_set_texfilter(true);
        draw_surface_part(_v.preview_surface,_lx,_ly,_rx-_lx,_by-_ly,24+_lx,160+_ly);
        shader_reset();gpu_set_texfilter(_filter);
    }
    ln_crt_surface(_v.preview_surface,24,160,1,_v.zoom,undefined,_v.crt_enabled);
    draw_set_colour(c_white);ln_edit_button(24,688,50,"<");ln_edit_button(1200,688,50,">");
    draw_text(100,693,string(_v.animation+1)+" / "+string(array_length(_entry.clips))+"   "+_clip.name);
    ln_edit_button(24,744,160,_v.paused?"Play":"Pause");
    ln_edit_button(204,744,220,"Cycle animations",_v.cycle);ln_edit_button(444,744,180,"Mirror",_v.mirror);
    draw_text(660,749,"Frame "+string(_v.frame+1)+" / "+string(array_length(_clip.frames)));
    ln_edit_button(1010,744,40,"-");draw_text(1070,749,"Pixels "+string(_scale)+"x");ln_edit_button(1210,744,40,"+");
}
function ln_sprite_checks(_host) {
    var _v=global.ln_sprites;ln_sprite_filter();_v.zoom=3;
    for(var _g=1;_g<=3;_g++) for(var _c=0;_c<3;_c++) {
        _v.game=_g;_v.category=_c;ln_sprite_filter();ln_check(array_length(_v.list)>0,"sprite category populated");
        for(var _e=0;_e<array_length(_v.list);_e++) {
            var _entry=_v.list[_e];
            if(_g==3 && _c==1) ln_check(string_pos("Enemy 3",_entry.name)==0,"special encounter is not a humanoid costume");
            if(_c<2) ln_check(variable_struct_exists(_entry,"ground_anchor"),"character has stable standing anchor");
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
        ln_check(_v.zoom==3,"shared pixel scale survives asset/category/game changes");
    }
    _v.game=1;_v.category=0;ln_sprite_filter();_v.paused=true;ln_sprite_advance(1);ln_check(_v.frame==0,"pause freezes pose");
    _v.paused=false;ln_sprite_advance(.2);ln_check(_v.frame>0,"animation advances");
    ln_sprite_toggle(_host);ln_sprite_toggle(_host);ln_check(!_v.open,"viewer closes");
    ln_sprite_toggle(_host);global.ln_tool.active=true;show_debug_message("LN_SPRITE_VIEWER_PASS");
}
