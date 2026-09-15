function ln_music_play(_game, _level, _loader) {
    var _role = _loader ? "loader" : "game";
    var _name = "snd_ln" + string(_game) + "_" + _level + "_" + _role;
    var _asset = asset_get_index(_name);
    if (_asset < 0) return -1;
    if (variable_global_exists("ln_music_voice") && global.ln_music_voice >= 0) {
        audio_stop_sound(global.ln_music_voice);
    }
    global.ln_music_voice = audio_play_sound(_asset, 0, true);
    return global.ln_music_voice;
}

// Music auditioning owns its voice and pauses only voices it found playing.
function LNTrackPlayer() constructor {
    open=false; tracks=[]; queue=[]; game=0; group=0; single=false;
    current=-1; voice=-1; playing=false; paused=false; scroll=0; paused_voices=[];
    var _levels=[["wastelands","wilderness","palace_gardens","dungeons","palace","inner_sanctum"],
        ["central_park","street","sewers","basement","office","mansion","final_battle"],
        ["earth","wind","water","fire","void"]];
    for(var _g=1;_g<=3;_g++) for(var _l=0;_l<array_length(_levels[_g-1]);_l++) {
        for(var _r=0;_r<2;_r++) {
            var _level=_levels[_g-1][_l],_role=_r==0?"loader":"game";
            array_push(tracks,{asset:asset_get_index("snd_ln"+string(_g)+"_"+_level+"_"+_role),
                title:"LN"+string(_g)+" / "+string_replace_all(_level,"_"," ")+" / "+(_r==0?"Loader":"In-game"),game:_g,kind:_r+1});
        }
    }
    var _names=["subtune_01_unmapped_cue","subtune_02_unmapped_cue","intro_cue","outro_cue","game_over_cue"];
    var _titles=["Logo","Wind opening","Intro","Outro","Game over"];
    for(var _c=0;_c<5;_c++) array_push(tracks,{asset:asset_get_index("snd_ln3_"+_names[_c]),title:"LN3 / "+_titles[_c],game:3,kind:_c<2?4:(_c<4?3:5)});
}
function ln_track_filter(_p) {
    _p.queue=[];_p.scroll=0;
    for(var _i=0;_i<array_length(_p.tracks);_i++) {
        var _t=_p.tracks[_i];
        if((_p.game==0 || _p.game==_t.game) && (_p.group==0 || _p.group==_t.kind || (_p.group==4 && _t.kind==3))) array_push(_p.queue,_i);
    }
}
function ln_track_stop(_p) {
    if(_p.voice>=0) audio_stop_sound(_p.voice);
    _p.voice=-1;_p.playing=false;_p.paused=false;
}
function ln_track_play(_p,_index) {
    ln_track_stop(_p);_p.current=_index;
    if(_index<0 || _index>=array_length(_p.tracks)) return;
    var _asset=_p.tracks[_index].asset;
    if(_asset<0) return;
    _p.voice=audio_play_sound(_asset,0,false);_p.playing=_p.voice>=0;
}
function ln_track_next_index(_p,_direction) {
    var _count=array_length(_p.queue);if(_count==0) return -1;
    var _at=-1;
    for(var _i=0;_i<_count;_i++) if(_p.queue[_i]==_p.current) {_at=_i;break;}
    if(_at<0) return _p.queue[_direction<0?_count-1:0];
    return _p.queue[(_at+_direction+_count) mod _count];
}
function ln_track_toggle(_host) {
    var _p=global.ln_tracks;
    if(_p.open) {
        ln_track_stop(_p);_p.open=false;
        for(var _i=0;_i<array_length(_p.paused_voices);_i++) if(audio_is_paused(_p.paused_voices[_i])) audio_resume_sound(_p.paused_voices[_i]);
        _p.paused_voices=[];_host.input_state=new LNInput();
    } else {
        var _voices=[];_p.paused_voices=[];
        if(variable_global_exists("ln_music_voice")) array_push(_voices,global.ln_music_voice);
        if(_host.play.game_number==3 && is_struct(_host.play.intro)) array_push(_voices,_host.play.intro.voice);
        for(var _j=0;_j<array_length(_voices);_j++) {
            var _v=_voices[_j];
            if(_v>=0 && audio_is_playing(_v) && !audio_is_paused(_v) && !array_contains(_p.paused_voices,_v)) {
                audio_pause_sound(_v);array_push(_p.paused_voices,_v);
            }
        }
        _p.open=true;if(array_length(_p.queue)==0) ln_track_filter(_p);
    }
}
function ln_track_step(_host) {
    var _p=global.ln_tracks;
    if(global.ln_tool.active && ln_tool_ui_visible() && mouse_check_button_pressed(mb_left) && mouse_x>=940 && mouse_x<1178 && mouse_y>=56 && mouse_y<84) {
        ln_track_toggle(_host);return true;
    }
    if(!_p.open) return false;
    if(keyboard_check_pressed(vk_escape) || ln_edit_hit(1020,20,220,28)) {ln_track_toggle(_host);return true;}
    if(keyboard_check_pressed(vk_f9)) ln_fullscreen_toggle(_host);
    for(var _g=0;_g<4;_g++) if(ln_edit_hit(24+_g*130,76,120,28)) {_p.game=_g;_p.group=0;ln_track_filter(_p);ln_track_stop(_p);}
    var _groups=_p.game==0?1:(_p.game==3?5:3);
    for(var _r=0;_r<_groups;_r++) if(ln_edit_hit(24+_r*185,116,175,28)) {_p.group=_r;ln_track_filter(_p);ln_track_stop(_p);}
    if(ln_edit_hit(850,76,145,28)) _p.single=false;
    if(ln_edit_hit(1005,76,145,28)) _p.single=true;
    if(ln_tool_mouse_x()>=24 && ln_tool_mouse_x()<1240 && ln_tool_mouse_y()>=180 && ln_tool_mouse_y()<628) {
        _p.scroll=clamp(_p.scroll+3*(mouse_wheel_down()-mouse_wheel_up()),0,max(0,array_length(_p.queue)-14));
    }
    for(var _row=0;_row<14;_row++) {
        var _at=_p.scroll+_row;
        if(_at<array_length(_p.queue) && ln_edit_hit(24,180+_row*32,1170,28)) ln_track_play(_p,_p.queue[_at]);
    }
    if(ln_edit_hit(1204,180,40,28)) _p.scroll=max(0,_p.scroll-14);
    if(ln_edit_hit(1204,600,40,28)) _p.scroll=min(max(0,array_length(_p.queue)-14),_p.scroll+14);
    if(ln_edit_hit(24,706,130,28)) ln_track_play(_p,ln_track_next_index(_p,-1));
    if(ln_edit_hit(164,706,130,28)) {
        if(_p.paused) {audio_resume_sound(_p.voice);_p.paused=false;}
        else if(_p.playing) {audio_pause_sound(_p.voice);_p.paused=true;}
        else ln_track_play(_p,array_contains(_p.queue,_p.current)?_p.current:ln_track_next_index(_p,1));
    }
    if(ln_edit_hit(304,706,130,28)) ln_track_play(_p,ln_track_next_index(_p,1));
    if(ln_edit_hit(444,706,130,28)) ln_track_stop(_p);
    ln_track_poll(_p);
    return true;
}
function ln_track_poll(_p) {
    if(_p.playing && !_p.paused && !audio_is_playing(_p.voice)) {
        if(_p.single) ln_track_stop(_p);else ln_track_play(_p,ln_track_next_index(_p,1));
    }
}
function ln_track_draw() {
    var _p=global.ln_tracks;
    shader_reset();draw_set_alpha(1);draw_set_font(font_jansina);draw_set_halign(fa_left);draw_set_valign(fa_top);
    draw_clear(make_colour_rgb(18,20,25));draw_set_colour(c_white);
    draw_text(24,24,"TRACK PLAYER");ln_edit_button(1020,20,220,"Back (Esc)");
    var _games=["ALL","LN1","LN2","LN3"],_labels=["All","Loaders","InGames","Intro+Outro","IO+Pre"];
    for(var _g=0;_g<4;_g++) ln_edit_button(24+_g*130,76,120,_games[_g],_p.game==_g);
    draw_text(650,81,"Playback:");ln_edit_button(850,76,145,"ALL",!_p.single);ln_edit_button(1005,76,145,"Single",_p.single);
    var _groups=_p.game==0?1:(_p.game==3?5:3);
    for(var _r=0;_r<_groups;_r++) ln_edit_button(24+_r*185,116,175,_labels[_r],_p.group==_r);
    draw_text(24,154,string(array_length(_p.queue))+" tracks / click to play / scroll for more");
    for(var _row=0;_row<14;_row++) {
        var _at=_p.scroll+_row;if(_at>=array_length(_p.queue)) break;
        var _id=_p.queue[_at],_track=_p.tracks[_id];
        ln_edit_button(24,180+_row*32,1170,(_id==_p.current?"> ":"")+_track.title+(_track.asset<0?" (missing)":""),_id==_p.current?true:undefined);
    }
    ln_edit_button(1204,180,40,"^");ln_edit_button(1204,600,40,"v");
    var _state=_p.playing?"Playing":"Stopped";
    if(_p.paused) _state="Paused";
    draw_text(24,654,_state+(_p.current>=0?": "+_p.tracks[_p.current].title:" - select a track"));
    ln_edit_button(24,706,130,"Previous");ln_edit_button(164,706,130,_p.playing && !_p.paused?"Pause":"Play");
    ln_edit_button(304,706,130,"Next");ln_edit_button(444,706,130,"Stop");
    draw_text(24,756,_p.single?"Single: play once, then stop.":"ALL: play this group in order, then repeat.");
    if(_p.game==3 && _p.group==4) draw_text(650,756,"IO+Pre: logo, wind, intro and outro.");
}
function ln_track_checks(_host) {
    var _p=global.ln_tracks;ln_track_filter(_p);
    ln_check(array_length(_p.queue)==41,"all 41 music resources included");
    for(var _i=0;_i<array_length(_p.tracks);_i++) ln_check(_p.tracks[_i].asset>=0,"track resource exists: "+_p.tracks[_i].title);
    var _sizes=[12,14,15];
    for(var _g=1;_g<=3;_g++) {
        _p.game=_g;_p.group=0;ln_track_filter(_p);ln_check(array_length(_p.queue)==_sizes[_g-1],"game track count");
        _p.group=1;ln_track_filter(_p);ln_check(array_length(_p.queue)==(_g==1?6:(_g==2?7:5)),"loader count");
        _p.group=2;ln_track_filter(_p);ln_check(array_length(_p.queue)==(_g==1?6:(_g==2?7:5)),"in-game count");
    }
    _p.group=3;ln_track_filter(_p);ln_check(array_length(_p.queue)==2,"intro/outro only");
    _p.group=4;ln_track_filter(_p);ln_check(array_length(_p.queue)==4,"intro/outro plus logo/wind");
    _p.current=_p.queue[3];ln_check(ln_track_next_index(_p,1)==_p.queue[0],"playlist wraps forward");
    _p.current=_p.queue[0];ln_check(ln_track_next_index(_p,-1)==_p.queue[3],"playlist wraps backwards");
    ln_track_toggle(_host);ln_track_play(_p,_p.queue[0]);var _old=_p.voice;
    ln_track_play(_p,_p.queue[1]);ln_check(!audio_is_playing(_old),"new track stops old voice");
    audio_pause_sound(_p.voice);_p.paused=true;_old=_p.voice;ln_track_poll(_p);
    ln_check(_p.voice==_old && audio_is_paused(_old),"paused track does not auto-advance");
    audio_stop_sound(_p.voice);_p.paused=false;_p.single=false;ln_track_poll(_p);
    ln_check(_p.current==_p.queue[2] && _p.playing,"ALL advances at end");
    audio_stop_sound(_p.voice);_p.single=true;ln_track_poll(_p);
    ln_check(_p.voice==-1 && !_p.playing,"Single stops at end");
    ln_track_toggle(_host);ln_check(!_p.open && _p.voice==-1,"closing stops audition");
    var _saved=global.ln_music_voice;
    global.ln_music_voice=audio_play_sound(snd_ln1_wastelands_loader,0,true,0);
    ln_track_toggle(_host);ln_check(audio_is_paused(global.ln_music_voice),"panel pauses game music");
    ln_track_toggle(_host);ln_check(!audio_is_paused(global.ln_music_voice),"close restores game music");
    audio_pause_sound(global.ln_music_voice);ln_track_toggle(_host);ln_track_toggle(_host);
    ln_check(audio_is_paused(global.ln_music_voice),"previously paused music stays paused");
    audio_stop_sound(global.ln_music_voice);global.ln_music_voice=_saved;
    _p.game=0;_p.group=0;_p.single=false;ln_track_filter(_p);_p.current=-1;
    ln_track_toggle(_host);
    global.ln_tool.active=true;
    show_debug_message("LN_TRACK_PLAYER_PASS");
}
