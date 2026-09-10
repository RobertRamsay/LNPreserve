function ln2_world_checks() {
    var _hole=new LN2Play(1);
    ln2_play_enter(_hole,2);_hole.player.x=160;_hole.player.y=86;_hole.player.facing=1;
    ln2_item_interact(_hole,4);
    ln_check(_hole.inventory[18]!=0,"LN2 wall punch sets the hole switch flag");
    ln2_test_enter(_hole,0);
    _hole.player.boundary_mode=5;_hole.player.boundary_crossings=129;_hole.player.action=0;
    ln_check(ln2_hole_boundary(_hole) && _hole.hole_steps==5 && _hole.inventory[18]==0,
        "LN2 switched hole consumes flag and starts five sink actions");
    repeat(200) {if (_hole.hole_steps>0) ln2_play_tick(_hole,0);}
    ln_check(_hole.hole_steps==0 && _hole.level==1 && _hole.room_id==3,
        "LN2 hole finishes its scripted exit within Central Park");
    var _safe=new LN2Play(7);ln2_play_enter(_safe,1);
    var _ids=[17,18,16,23];
    for (var _stage=0;_stage<4;_stage++) {
        for (var _item_index=0;_item_index<array_length(_safe.world.items);_item_index++) {
            var _item=_safe.world.items[_item_index];
            if (_item.id==_ids[_stage]) ln2_item_complete(_safe,_item,_item.id);
        }
        ln2_refresh_scene(_safe);
        ln_check(_safe.scene_frame==_stage+1 && _safe.scene==asset_get_index("spr_ln2_safe_states"),
            "LN2 successful safe interaction retains its original drawn panel");
    }
    var _b=buffer_load("verification/ln2_combat_vectors.json"),_v=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
    var _level=0,_d=undefined;
    for (var _i=0;_i<array_length(_v.vectors);_i++) {
        var _case=_v.vectors[_i];
        if (_level!=_case.level) {
            _level=_case.level;_b=buffer_load("play/ln2/level"+string(_level)+"/gameplay.json");
            _d=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
        }
        var _a=_case.enemy_attacks?_case.enemy:_case.player,_def=_case.enemy_attacks?_case.player:_case.enemy;
        var _actual=ln2_combat_hit(_a,_def,_case.active,_case.attack_count,_d);
        ln_check(_actual==_case.expected,"LN2 melee "+string(_i)+" got "+string(_actual)+" expected "+string(_case.expected));
    }
    show_debug_message("LN2_COMBAT_PASS: "+string(array_length(_v.vectors))+" original melee range comparisons; complete combat replay remains open.");
    var _rooms=0,_exits=0,_ticks=0;
    for (_level=1;_level<=7;_level++) {
        var _g=new LN2Play(_level);
        _b=buffer_load("play/ln2/level"+string(_level)+"/navigation_vectors.json");
        _v=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
        for (var _i=0;_i<array_length(_v.vectors);_i++) {
            var _case=_v.vectors[_i],_expected=_case.expected;
            if (_expected.level_end) continue;
            ln2_play_enter(_g,_case.room);_g.exit_locked=false;_g.player.x=_case.point[0];_g.player.y=_case.point[1];ln2_play_exit(_g);
            ln_check(_g.room_id==_expected.room && _g.last_entry==_expected.entry,"LN2 original exit destination");
            ln_check(_g.player.x==_expected.x && _g.player.y==_expected.y && _g.player.facing==_expected.facing &&
                     _g.player.frame==_expected.frame && _g.player.boundary_crossings==_expected.crossings,"LN2 original entrance state");
            _exits++;
        }
        for (var _i=0;_i<array_length(_g.world.rooms);_i++) {
            var _room=_g.world.rooms[_i];if (_room.spawn_entry<0) continue;
            ln2_test_enter(_g,_room.spawn_entry);_rooms++;
            repeat(100) { ln2_play_tick(_g,0);_ticks++; }
        }
        var _enemy_room=-1;
        for (var _i=0;_i<array_length(_g.world.rooms);_i++) if (_g.world.rooms[_i].enemy.active>=128) { _enemy_room=_i;break; }
        if (_enemy_room>=0) {
            ln2_test_enter(_g,_g.world.rooms[_enemy_room].spawn_entry);_g.enemy.health=23;ln2_enemy_remember(_g);
            var _id=_g.room_id;ln2_play_enter(_g,_id);
            ln_check(_g.enemy.health==23,"LN2 per-scene health persists");
        }
    }
    show_debug_message("LN2_WORLD_PASS: "+string(_rooms)+" native scenes, "+string(_exits)+" original exits, "+string(_ticks)+" integration ticks. Vehicles, objectives and full-game parity remain incomplete.");
}

function ln2_world_capture() {
    ln2_final_gpu_checks();
    ln2_projectile_gpu_checks();
    for (var _level=1;_level<=7;_level++) {
        var _g=new LN2Play(_level);
        if (_level==6) repeat(64) ln2_play_tick(_g,0);
        ln2_play_draw(_g);
        surface_save(application_surface,"lnpreserve-ln2-level"+string(_level)+".png");
        if (surface_exists(_g.stage_surface)) surface_free(_g.stage_surface);
    }
}

function ln2_routes_checks() {
    var _b=buffer_load("verification/ln2_interior_routes.json"),_v=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
    var _g=undefined,_level=0;
    for(var _i=0;_i<array_length(_v.vectors);_i++) {
        var _c=_v.vectors[_i];
        if(_level!=_c.level || _g.level!=_c.level) {_level=_c.level;_g=new LN2Play(_level);}
        ln2_play_enter(_g,_c.room);_g.last_entry=-1;_g.enemy.active=0;
        var _p=_g.player;_p.x=100;_p.y=80;_p.action=_c.busy?$c300:0;
        _p.boundary_mode=_c.mode;_p.boundary_crossings=_c.flags;_g.exit_locked=_c.locked;
        _g.inventory[17]=_c.gate;_g.inventory[19]=_c.gate;_g.inventory[20]=_c.gate;
        var _ends=_c.entry>=0 && _g.world.tables.exit_destinations[_c.entry]==255;
        ln2_boundary_exit(_g);
        for(var _t=1;_t<=64;_t++) {
            if(!is_undefined(_g.route_descent)) ln2_route_descent_tick(_g,_t);
            else if(_g.fall_remaining>=0) ln2_fall_tick(_g,(_g.fall_clock+2)&255);
            else break;
        }
        ln_check(_ends?(_g.level==_level+1):(_g.last_entry==_c.entry),"LN2 interior case "+string(_i)+" level "+string(_level)+" mode "+string(_c.mode)+" got "+string(_g.last_entry)+" expected "+string(_c.entry));
        if(_c.entry>=0 && !_ends) {
            ln_check(_p.x==_g.world.tables.entry_x[_c.entry] && _p.y==_g.world.tables.entry_y[_c.entry],"interior arrival coordinates");
        }
    }
    for(var _i=0;_i<array_length(_v.sensors);_i++) {
        var _sensor=_v.sensors[_i];
        if(_g.level!=_sensor.level) _g=new LN2Play(_sensor.level);
        ln2_play_enter(_g,_sensor.room);var _line=_g.data.boundaries[_sensor.line],_found=false;
        for(var _x=_line[0];_x<=_line[2] && !_found;_x++) {
            var _y=(_line[1]+(_line[4]>=64?-1:1)*(((_x-_line[0])*(_line[4]&62)) div 16))&255;
            for(var _dx=-4;_dx<=4 && !_found;_dx++) for(var _dy=-3;_dy<=3 && !_found;_dy++)
            for(var _side=-1;_side<=0 && !_found;_side++) {
                _g.player.boundary_crossings=0;_g.player.boundary_mode=0;
                var _collision=ln2_player_boundary(_g.player,_g.data,_x,_y+_side,_x+_dx,_y+_side+_dy);
                if((_collision==0 || (_line[5]>=128 && _g.player.hit_boundary==_sensor.line)) && (_g.player.boundary_mode&63)==_sensor.mode && (_g.player.boundary_crossings&128)) _found=true;
            }
        }
        ln_check(_found,"interior sensor geometry "+string(_i)+" level "+string(_sensor.level)+" room "+string(_sensor.room));
    }
    show_debug_message("LN2_SENSOR_PASS: "+string(array_length(_v.sensors))+" exit detector lines trigger in full scene geometry (including blocking triggers)");
    _g=new LN2Play(1);ln2_play_enter(_g,3);_g.exit_locked=false;_g.enemy.active=0;
    var _p=_g.player;_p.x=94;_p.y=74;_p.depth_y=74;_p.action=0;_p.input_lock=0;
    _p.facing=7;_p.heading=7;_p.turn_lock=0;_p.fraction_x=0;_p.fraction_y=0;
    repeat(24) {if(_g.room_id!=3) break;ln2_play_tick(_g,5);}
    ln_check(_g.room_id==13 && _g.last_entry==5,"actual scene 3 door walk reaches scene 13");
    ln2_curtain_checks();ln2_world_checks();
    show_debug_message("LN2_ROUTES_PASS: "+string(array_length(_v.vectors))+" original interior gate/destination cases; actual scene 3 to 13 door walk.");
}
