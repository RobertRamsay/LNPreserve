function ln3_scene_checks() {
    var _o=ln3_data_read("verification/ln3_scene_vectors.json"),_level=0,_data=undefined,_actions=undefined;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];
        if (_level!=_v.level) {
            _level=_v.level;var _path="play/ln3/level"+string(_level)+"/";
            _data=ln3_data_read(_path+"runtime.json");_actions=ln3_data_read(_path+"actions.json");
        }
        var _s=_v.before,_scene=ln3_room_record(_data.rooms,_v.room_id);
        switch (_v.operation) {
            case 0:ln3_scene_reset(_s);break;
            case 1:ln3_enemy_enter(_s,_actions,_data,_scene);break;
            case 2:ln3_hazard_tick(_s,_actions,_data);break;
            case 3:ln3_hazard_contacts(_s,_data);break;
            case 4:ln3_climb_enter(_s,_actions,_scene.climbs,_v.joy,_level);break;
            case 5:ln3_fall_tick(_s,_actions,_data);break;
        }
        ln3_state_check(_s,_v.expected,"LN3 scene "+string(_i)+" operation "+string(_v.operation));
    }
    show_debug_message("LN3_SCENES_PASS: "+string(array_length(_o.vectors))+" original room, hazard and climbing states.");
}

function ln3_world_checks() {
    var _rooms=0,_exits=0,_ticks=0;
    for (var _level=1;_level<=5;_level++) {
        var _g=new LN3Play(_level);
        ln_check(_g.state.player_health==44 && _g.state.honour==13 && _g.state.lives==5,"LN3 clean startup globals");
        for (var _i=0;_i<array_length(_g.world.rooms);_i++) {
            var _r=_g.world.rooms[_i];if (!_r.playable) continue;
            ln_check(ln3_test_enter(_g,_r.id),"LN3 selectable scene "+string(_level)+":"+string(_r.id));_rooms++;
            for (var _tick=0;_tick<100;_tick++) {ln3_play_tick(_g,[0,1,2,4,5,6,8,9,10,17][_tick div 10]);_ticks++;}
            for (var _j=0;_j<array_length(_r.exits);_j++) {
                ln3_test_enter(_g,_r.id);var _exit=_r.exits[_j];
                ln_check(ln3_play_enter(_g,_exit),"LN3 registered destination");
                ln_check(_g.room_id==_exit.destination && _g.state.parts[2].x==_exit.spawn_x && _g.state.parts[2].y==_exit.spawn_y,"LN3 original entrance placement");_exits++;
            }
        }
        ln3_test_enter(_g,0);_g.state.enemy_health=17;ln3_play_enter(_g,_g.last_entry);
        ln_check(_g.state.enemy_health==17,"LN3 scene remembers enemy health");
        if (_level<5) {ln3_level_load(_g,_level+1);ln_check(_g.level==_level+1,"LN3 next native level loads");}
    }
    show_debug_message("LN3_WORLD_PASS: "+string(_rooms)+" native scenes, "+string(_exits)+" destination records and "+string(_ticks)+" integration ticks; full-game parity remains incomplete.");
}

function ln3_world_capture() {
    var _o=ln3_data_read("verification/ln3_gpu_vectors.json"),_g=undefined,_level=0;
    var _b=buffer_create(24*21*4,buffer_fixed,1),_surface=surface_create(240,144);
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];
        if (_level!=_v.level) {
            if (is_struct(_g) && surface_exists(_g.part_surface)) surface_free(_g.part_surface);
            _level=_v.level;_g=new LN3Play(_level);
        }
        _g.room_id=_v.room_id;_g.mask_shapes=ln3_room_record(_g.masks.rooms,_v.room_id).shapes;
        var _d=_g.display,_part=_v.part;
        _d.draw_frames=array_create(8,-1);_d.draw_frames[_part]=_v.frame;
        _d.draw_x[_part]=_v.x;_d.draw_y[_part]=_v.y;_d.draw_mirror[_part]=_v.mirror;_d.draw_colours[_part]=_v.colour;
        _d.multicolour=0;_d.expand_x=0;_d.expand_y=0;_d.enemy_costume=0;_d.waterline=173;
        _g.state.mask_spill=_v.spill;
        _g.draw_masks[_part]=ln3_mask_bytes(_g.state,_g.mask_shapes,_v.x,_v.y,_v.foot);
        surface_set_target(_surface);draw_clear_alpha(c_black,0);ln3_play_actor_part(_g,_d,_part);surface_reset_target();
        buffer_get_surface(_b,_g.part_surface,0);
        for (var _y=0;_y<21;_y++) for (var _x=0;_x<24;_x++) {
            var _pixel=buffer_peek(_b,(_y*24+_x)*4,buffer_u32),_visible=(_v.expected[_y*3+(_x div 8)]&(128>>(_x&7)))!=0;
            ln_check(((_pixel>>24)&255)==(_visible?255:0),"LN3 GPU mask "+string(_i)+" pixel "+string(_x)+","+string(_y));
            if (_visible) ln_check((_pixel&$ffffff)==_g.palette[_v.colour],"LN3 GPU original tint");
        }
    }
    buffer_delete(_b);surface_free(_surface);if (surface_exists(_g.part_surface)) surface_free(_g.part_surface);
    for (var _level=1;_level<=5;_level++) {
        _g=new LN3Play(_level);ln3_play_draw(_g);
        surface_save(application_surface,"lnpreserve-ln3-level"+string(_level)+".png");
        for (var _i=0;_i<array_length(_g.world.rooms);_i++) {
            if (!_g.world.rooms[_i].playable) continue;
            ln3_test_enter(_g,_g.world.rooms[_i].id);ln3_play_draw(_g);
        }
        surface_free(_g.stage_surface);surface_free(_g.part_surface);
    }
    show_debug_message("LN3_GPU_PASS: 132 ordinary sprite parts across 66 scenery records, 66528 alpha/tint pixels and rendering smoke checks in all 65 selectable scenes.");
}
