function ln2_world_checks() {
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
    for (var _level=1;_level<=7;_level++) {
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
    for (var _level=1;_level<=7;_level++) {
        var _g=new LN2Play(_level);
        if (_level==6) repeat(64) ln2_play_tick(_g,0);
        ln2_play_draw(_g);
        surface_save(application_surface,"lnpreserve-ln2-level"+string(_level)+".png");
        if (surface_exists(_g.stage_surface)) surface_free(_g.stage_surface);
    }
}
