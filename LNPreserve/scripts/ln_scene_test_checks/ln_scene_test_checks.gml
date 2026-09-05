function ln_scene_test_checks() {
    ln_check(ln_test_direction(true,false,false,false)==0,"Right arrow means NE");
    ln_check(ln_test_direction(false,true,false,false)==1,"Down arrow means SE");
    ln_check(ln_test_direction(false,false,true,false)==2,"Left arrow means SW");
    ln_check(ln_test_direction(false,false,false,true)==3,"Up arrow means NW");
    ln_check(ln_test_direction(true,true,false,false)==-1,"Simultaneous arrows do not chain teleports");
    ln_check(ln_test_direction(false,false,false,false)==-1,"No key edge means no teleport");
    var _buffer = buffer_load("verification/ln1_navigation_vectors.json");
    var _oracle = json_parse(buffer_read(_buffer,buffer_text)); buffer_delete(_buffer);
    for (var _i = 0; _i < array_length(_oracle.vectors); _i++) {
        var _v = _oracle.vectors[_i], _expected = _v.expected;
        var _g = new LN1Play(); ln1_play_enter(_g,_v.room);
        _g.player.x = _v.boundary_point[0]; _g.player.y = _v.boundary_point[1];
        // First compare the ordinary native exit with the actual 6502 result.
        ln1_play_exit(_g);
        if (_expected.room != 0) {
            ln_check(_g.room_id==_expected.room && _g.last_entry==_expected.entry,"source exit destination " + string(_i));
            ln_check(_g.player.x==_expected.x && _g.player.y==_expected.y,"source entrance position " + string(_i));
            ln_check(_g.player.facing==_expected.facing && _g.player.frame==_expected.frame,"source entrance pose " + string(_i));
        } else ln_check(array_length(_g.pending_events)==1,"ordinary level exit remains an explicit pending event");
        _g = new LN1Play(); ln1_play_enter(_g,_v.room);
        _g.player_health = 17; _g.inventory[13] = 1;
        if (_expected.room != 0) _g.room_wounds[_expected.room] = 9;
        _g.player.action = $5d34; _g.player.flags = 255; _g.player.input_lock = 255;
        _g.prayer_phase = 1; _g.water_active = true; _g.death_wait = 20;
        var _result = ln1_test_exit(_g,_v.direction);
        if (_expected.room==0) {
            ln_check(_result==-1 && _g.room_id==_v.room && _g.death_wait==20,"test exit cannot pretend the next level is playable");
            continue;
        }
        ln_check(_result==1 && _g.room_id==_expected.room && _g.last_entry==_expected.entry,"test destination uses original entry " + string(_i));
        ln_check(_g.player.x==_expected.x && _g.player.y==_expected.y,"test spawn uses original position " + string(_i));
        ln_check(_g.player.heading==_expected.heading && _g.player.facing==_expected.facing &&
            _g.player.display_frame==_expected.frame && _g.player.turn_lock==_expected.turn_lock,"test pose uses original facing " + string(_i));
        ln_check(_g.player_health==17 && _g.lives_left==3 && _g.inventory[13]==1 && _g.enemy.wounds==9,"teleport preserves health, lives, inventory and enemy wounds");
        ln_check(_g.room_age==0 && _g.mask==asset_get_index(_g.world.rooms[_g.room_id-1].depth_sprite),"teleport resets entry flashes and loads destination masks");
        ln_check(_g.player.boundary_mode==_g.world.rooms[_g.room_id-1].boundary_mode &&
            _g.player.boundary_crossings==_g.world.rooms[_g.room_id-1].entrance_crossings[_g.last_entry&3],"destination collision state uses the original entrance");
        ln_check(_g.player.action==0 && _g.player.flags==0 && _g.player.input_lock==0 && !_g.water_active &&
            _g.prayer_phase==0 && _g.death_wait==0,"old death, prayer and water state cannot follow a teleport");
    }
    var _g = new LN1Play();
    ln_check(ln1_test_exit(_g,0)==1 && _g.room_id==2,"NE from opening scene reaches scene 2");
    ln_check(ln1_test_exit(_g,2)==1 && _g.room_id==1,"SW returns through scene 1's real entrance");
    ln_check(ln1_test_exit(_g,1)==1 && _g.room_id==14,"SE from opening scene reaches scene 14");
    ln_check(ln1_test_exit(_g,3)==1 && _g.room_id==1,"NW returns from scene 14");
    _g.player.action=12345; var _x=_g.player.x;
    ln_check(ln1_test_exit(_g,2)==0 && _g.player.action==12345 && _g.player.x==_x,"missing exit leaves gameplay state untouched");
    _g.room_wounds[2]=32; ln1_test_exit(_g,0);
    ln_check(_g.enemy.action==0 && _g.enemy.wounds==32,"defeated enemies stay defeated after teleporting");
    _g.player_health=0; _g.lives_left=0; _g.game_over=true; ln1_test_exit(_g,2);
    ln_check(_g.player_health==32 && _g.lives_left==1 && !_g.game_over,"debug travel can recover from a completed death");
    var _seen=array_create(26,false), _queue=[1], _head=0;
    _seen[1]=true;
    while (_head<array_length(_queue)) {
        var _room=_queue[_head++];
        for (var _d=0;_d<4;_d++) {
            var _entry=_g.navigation.rooms[_room-1].entries[_d],_dest=_entry>>2;
            if (_entry>=4 && !_seen[_dest]) { _seen[_dest]=true; array_push(_queue,_dest); }
        }
    }
    ln_check(array_length(_queue)==25,"directional exits reach every Wastelands room");
    _buffer=buffer_load("catalog.json"); var _catalog=json_parse(buffer_read(_buffer,buffer_text));buffer_delete(_buffer);
    var _t=new LNSceneTest(_catalog),_counts=[0,0,0],_playable=0,_ln3=-1;
    for (var _i=0;_i<array_length(_t.levels);_i++) {
        var _level=_t.levels[_i];_counts[_level.game-1]++;
        if (_level.playable) _playable++;
        if (_level.game==3 && _level.number==1) _ln3=_i;
        ln_check(array_length(_level.scenes)>0,"each selectable level has exported scenes");
    }
    ln_check(_counts[0]==6 && _counts[1]==7 && _counts[2]==5 && _playable==1,"picker exposes all 18 available level datasets with honest gameplay availability");
    var _room_before=_g.room_id,_tick_before=_g.player.tick;
    _t.level_index=_ln3;ln_scene_test_open(_t,_g,0);
    ln_check(_t.preview && _g.room_id==_room_before && _g.player.tick==_tick_before,"LN3 preview does not replace or simulate the LN1 game");
    _t.level_index=0;ln_scene_test_open(_t,_g,1);
    ln_check(!_t.preview && !_t.menu && _g.room_id==2,"scene picker enters the selected playable room");
    show_debug_message("LN_NAVIGATION_PASS: 54 original exit vectors, all 25 rooms reachable, direction mapping, state persistence, and 18-level picker availability.");
}

function ln_scene_test_capture(_catalog) {
    var _t=new LNSceneTest(_catalog); _t.menu=true;
    ln_scene_test_draw(_t);surface_save(application_surface,"lnpreserve-scene-picker.png");
    for (var _i=0;_i<array_length(_t.levels);_i++) {
        if (_t.levels[_i].game==3 && _t.levels[_i].number==1) { _t.level_index=_i; break; }
    }
    _t.menu=false;_t.preview=true;ln_scene_test_draw(_t);surface_save(application_surface,"lnpreserve-scene-preview.png");
}
