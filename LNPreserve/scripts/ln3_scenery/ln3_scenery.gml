function ln3_scenery_select(_s,_level,_sequence) {
    if (_s.scene_wait!=0) return -1;
    var _count=array_length(_sequence);
    if (_s.scene_cursor>=_count) {
        if (_s.scene_cursor==0) return -1;
        if (_level==5 && _s.room_id==11 && (_s.enabled&128)!=0) return -1;
        _s.scene_cursor=0;
    }
    if (_count==0 || (_level==5 && _s.selected_item!=6)) return -1;
    var _phase=_s.scene_cursor;_s.scene_cursor=(_s.scene_cursor+1)&255;_s.scene_wait=4;return _phase;
}

function ln3_scenery_tick(_g) {
    var _sequence=_g.scenery_record.sequence,_cursor=_g.state.scene_cursor;
    var _phase=ln3_scenery_select(_g.state,_g.level,_sequence);if (_phase<0) return;
    if (_cursor>=array_length(_sequence)) _g.scenery_repeating=true;
    _g.scenery_mechanism=_g.level==4 && _g.room_id==10 && _g.state.fire_cauldron!=0;
    var _cycle=_g.scenery_mechanism?_g.mechanisms.cauldron:_g.scenery_record;
    var _record=_g.scenery_repeating?_cycle.repeat[_phase]:_cycle.first[_phase];
    _g.scenery_frame=_record.frame;_g.mask_shapes=_record.shapes;
}

function ln3_scenery_checks() {
    var _o=ln3_data_read("verification/ln3_scenery_vectors.json"),_level=0,_data=undefined;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];
        if (_level!=_v.level) {_level=_v.level;_data=ln3_data_read("play/ln3/level"+string(_level)+"/scenery_animation.json");}
        var _sequence=ln3_room_record(_data.rooms,_v.room_id).sequence;
        var _s={room_id:_v.room_id,scene_cursor:_v.cursor,scene_wait:_v.wait,selected_item:_v.selected,enabled:_v.enabled};
        var _phase=ln3_scenery_select(_s,_level,_sequence),_command=_phase<0?-1:_sequence[_phase];
        ln_check(_command==_v.command && _s.scene_cursor==_v.expected_cursor && _s.scene_wait==_v.expected_wait,"LN3 scenery selector "+string(_i));
    }
    show_debug_message("LN3_SCENERY_PASS: "+string(array_length(_o.vectors))+" original animation selector states; original overlays retain 49 animation steps.");
}

function ln3_scenery_gpu_checks() {
    var _o=ln3_data_read("verification/ln3_scenery_gpu.json"),_g=undefined,_level=0;
    var _b=buffer_create(240*144*4,buffer_fixed,1),_count=0;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];
        if (_level!=_v.level) {
            if (is_struct(_g) && surface_exists(_g.stage_surface)) surface_free(_g.stage_surface);
            _level=_v.level;_g=new LN3Play(_level);
        }
        ln3_test_enter(_g,_v.room_id);_g.display.draw_frames=array_create(8,-1);_g.scenery_frame=_v.frame;
        ln3_play_draw(_g);buffer_get_surface(_b,_g.stage_surface,0);
        for (var _j=0;_j<array_length(_v.samples);_j++) {
            var _p=_v.samples[_j],_actual=buffer_peek(_b,(_p[1]*240+_p[0])*4,buffer_u32)&$ffffff;
            ln_check(_actual==make_colour_rgb(_p[2],_p[3],_p[4]),"LN3 animated scenery pixel "+string(_i)+":"+string(_j));_count++;
        }
    }
    buffer_delete(_b);surface_free(_g.stage_surface);
    show_debug_message("LN3_SCENERY_GPU_PASS: "+string(_count)+" original bitmap samples across "+string(array_length(_o.vectors))+" first-entry/repeating animation steps.");
}
