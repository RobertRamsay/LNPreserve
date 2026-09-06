function ln3_special_checks() {
    var _o=ln3_data_read("verification/ln3_special_vectors.json"),_level=0,_data=undefined,_items=undefined;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];
        if (_level!=_v.level) {
            _level=_v.level;var _path="play/ln3/level"+string(_level)+"/";
            _data=ln3_data_read(_path+"special.json");_items=ln3_data_read(_path+"items.json");
        }
        var _s=_v.before,_event=0;
        switch (_level) {
            case 1:_event=ln3_earth_ritual(_s);break;
            case 2:_event=_v.operation==0?ln3_wind_carrier(_s,_data):ln3_wind_damage(_s);break;
            case 3:_event=ln3_water_bell(_s);break;
            case 4:
                switch (_v.operation) {
                    case 0:_event=ln3_fire_ignite(_s);break;
                    case 1:_event=ln3_fire_brew(_s,_items);break;
                    case 2:_event=ln3_fire_poison(_s);break;
                    case 3:_event=ln3_fire_gate(_s);break;
                }
                break;
            case 5:
                switch (_v.operation) {
                    case 0:_event=ln3_void_bolt_spawn(_s);break;
                    case 1:_event=ln3_void_bolt_move(_s);break;
                    case 2:_event=ln3_void_victory(_s);break;
                }
                break;
        }
        ln_check(_event==_v.event,"LN3 special request "+string(_i));
        ln3_state_check(_s,_v.expected,"LN3 special "+string(_i));
    }
    ln3_transition_checks();
    ln3_ending_checks();
    show_debug_message("LN3_SPECIAL_PASS: "+string(array_length(_o.vectors))+" original mechanism states and special sequence requests; full interrupt timing excluded.");
}

function ln3_transition_checks() {
    var _o=ln3_data_read("verification/ln3_transition_vectors.json"),_count=0;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];
        for (var _j=0;_j<array_length(_v.trace);_j++) {
            var _t=_v.trace[_j],_g={transition_mode:_v.mode,transition_y:_t.before,transition_signal:_t.signal};
            ln3_transition_motion(_g);
            for (var _p=0;_p<8;_p++) ln_check(_g.transition_y[_p]==_t.after[_p],"LN3 original curtain movement");
            ln_check(_g.transition_signal==_t.expected_signal,"LN3 original curtain stop signal");_count++;
        }
    }
    var _g=new LN3Play(1);ln3_test_enter(_g,8);ln3_special_start(_g,1);
    repeat(53) ln3_play_tick(_g,0);
    ln_check(_g.special_sequence==1,"LN3 Earth fade holds 54 PAL ticks");ln3_play_tick(_g,0);
    ln_check(_g.special_sequence==0 && _g.state.parts[4].move_mode==141,"LN3 Earth ritual resumes statue movement");
    _g=new LN3Play(3);ln3_test_enter(_g,3);ln3_special_start(_g,2);
    repeat(44) ln3_play_tick(_g,0);
    ln_check(_g.special_sequence==2,"LN3 Water fade holds 45 PAL ticks");ln3_play_tick(_g,0);
    ln_check(_g.special_sequence==0 && _g.state.inventory[5]==255,"LN3 Water bell consumes selected object after fade");
    _g=new LN3Play(4);ln3_test_enter(_g,10);var _s=_g.state;
    _s.parts[2].x=96;_s.parts[2].y=104;_s.mirror=0;_s.player_action=27;_s.parts[1].cursor=3;_s.selected_item=23;
    ln3_play_special(_g);ln_check(_s.fire_cauldron==1,"LN3 Fire ignites original cauldron");
    _s.selected_item=19;_s.inventory[11]=1;_s.inventory[16]=1;ln3_play_special(_g);
    ln_check(_s.inventory[18]==1 && _g.found_item==18,"LN3 Fire brew grants poison with FOUND feedback");
    _s.scene_wait=0;ln3_scenery_tick(_g);ln_check(_g.scenery_mechanism,"LN3 lit cauldron selects recovered animation");
    ln3_test_enter(_g,7);_s.parts[2].x=212;_s.parts[2].y=112;_s.player_action=24;_s.mirror=6;_s.selected_item=18;
    ln3_play_special(_g);ln_check(_s.fire_gate==1,"LN3 Fire poison opens original gate");
    _g=new LN3Play(5);ln3_test_enter(_g,11);ln3_special_start(_g,3);
    var _ticks=0;while (_g.room_id!=12 && _ticks<900) {ln3_play_tick(_g,0);_ticks++;}
    ln_check(_g.room_id==12 && _g.special_sequence==0 && _g.state.parts[2].x==104 && _g.state.parts[2].y==124,"LN3 Void portal reaches original final-fight entrance");
    ln3_special_start(_g,4);_ticks=0;while (!_g.ending_requested && _ticks<900) {ln3_play_tick(_g,0);_ticks++;}
    ln_check(_g.ending_requested && _g.state.honour==40,"LN3 final fight requests original ending boundary");
    show_debug_message("LN3_TRANSITION_PASS: "+string(_count)+" original curtain-motion states, ritual/bell PAL waits and native puzzle/final-room integration; full raster timing pending.");
}

function ln3_mechanism_gpu_checks() {
    var _o=ln3_data_read("verification/ln3_mechanism_gpu.json"),_g=undefined,_level=0,_count=0;
    var _b=buffer_create(240*144*4,buffer_fixed,1);
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];
        if (_level!=_v.level) {
            if (is_struct(_g) && surface_exists(_g.stage_surface)) surface_free(_g.stage_surface);
            _level=_v.level;_g=new LN3Play(_level);
        }
        ln3_test_enter(_g,_v.room_id);_g.display.draw_frames=array_create(8,-1);
        switch (_v.kind) {
            case "gate":_g.state.fire_gate=1;break;
            case "cauldron":_g.scenery_frame=_v.frame;_g.scenery_mechanism=true;break;
            case "bolt":_g.scenery_frame=_v.scenery_frame;_g.state.bolt_flash=8;_g.state.bolt_flash_wait=_v.bolt_wait;break;
        }
        ln3_play_draw(_g);buffer_get_surface(_b,_g.stage_surface,0);
        for (var _j=0;_j<array_length(_v.samples);_j++) {
            var _p=_v.samples[_j],_actual=buffer_peek(_b,(_p[1]*240+_p[0])*4,buffer_u32)&$ffffff;
            ln_check(_actual==make_colour_rgb(_p[2],_p[3],_p[4]),"LN3 mechanism pixel "+string(_i)+":"+string(_j));_count++;
        }
    }
    buffer_delete(_b);surface_free(_g.stage_surface);
    show_debug_message("LN3_MECHANISM_GPU_PASS: "+string(_count)+" original gate, cauldron and Void impact bitmap samples.");
}
