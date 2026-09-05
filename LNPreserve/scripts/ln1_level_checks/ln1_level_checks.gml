function ln1_level_checks() {
    var _rooms=0,_exits=0,_selectors=0,_ticks=0;
    for (var _level=2;_level<=6;_level++) {
        var _g=new LN1Play(_level);
        ln_check(_g.level==_level && _g.room_id==1,"level starts at original room");
        var _visited=array_create(array_length(_g.world.rooms),false),_pending=[1];
        _visited[0]=true;
        while (array_length(_pending)>0) {
            var _room=array_pop(_pending),_routes=_g.navigation.rooms[_room-1].routes;
            for (var _i=0;_i<array_length(_routes);_i++) {
                var _route=_routes[_i],_destination=_route.entry>>2;
                if (_destination==0) continue;
                ln1_test_enter(_g,_g.navigation.rooms[_room-1].spawn_entry);
                _g.player.x=_route.x;_g.player.y=_route.y;
                ln_check(ln1_test_exit(_g,_route.direction)==1 && _g.last_entry==_route.entry,
                         "nearest original arrow exit "+string(_level)+"/"+string(_room));
                if (!_visited[_destination-1]) { _visited[_destination-1]=true;array_push(_pending,_destination); }
            }
        }
        for (var _i=0;_i<array_length(_visited);_i++)
            ln_check(_visited[_i],"arrow traversal reaches every room "+string(_level)+"/"+string(_i+1));
        var _folder="play/ln1/level"+string(_level)+"/";
        var _buf=buffer_load(_folder+"navigation_vectors.json");
        var _oracle=json_parse(buffer_read(_buf,buffer_text));buffer_delete(_buf);
        for (var _i=0;_i<array_length(_oracle.vectors);_i++) {
            var _v=_oracle.vectors[_i];
            if (_v.expected.room==0) continue;
            ln1_play_enter(_g,_v.room);
            _g.player.x=_v.boundary_point[0];_g.player.y=_v.boundary_point[1];
            ln1_play_exit(_g);
            ln_check(_g.room_id==_v.expected.room && _g.last_entry==_v.expected.entry,"level "+string(_level)+" original exit destination "+string(_i));
            ln_check(_g.player.x==_v.expected.x && _g.player.y==_v.expected.y && _g.player.facing==_v.expected.facing,
                     "level "+string(_level)+" original entrance position/facing "+string(_i));
            _exits++;
        }
        _buf=buffer_load(_folder+"selector_vectors.json");
        _oracle=json_parse(buffer_read(_buf,buffer_text));buffer_delete(_buf);
        for (var _i=0;_i<array_length(_oracle.vectors);_i++) {
            var _v=_oracle.vectors[_i],_e=new LN1Enemy();
            _e.active=_v.active;_e.facing=_v.facing;_e.speed_traits=_v.speed_traits;
            ln1_enemy_begin(_e,_g.data,_v.entry);
            ln_check(_e.action==_v.action && _e.flags==_v.flags && _e.action_mirror==_v.mirror && _e.countdown==_v.countdown,
                     "level "+string(_level)+" original enemy selector "+string(_i));
            _selectors++;
        }
        for (var _room=1;_room<=array_length(_g.world.rooms);_room++) {
            _g=new LN1Play(_level);
            ln1_test_enter(_g,_g.navigation.rooms[_room-1].spawn_entry);
            ln_check(sprite_exists(_g.scene) && sprite_exists(_g.mask),"native room graphics and mask registered");
            ln_check(array_length(_g.data.boundaries)>0,"native room has original collision boundaries");
            for (var _tick=0;_tick<100;_tick++) {
                ln1_play_tick(_g,0);_ticks++;
            }
            ln_check(array_length(_g.pending_events)==0,"room does not silently drop an encountered action event");
            _rooms++;
        }
    }
    var _g=new LN1Play();_g.inventory[13]=1;_g.inventory[8]=1;_g.inventory[14]=133;
    _g.lives_left=2;_g.room_wounds[2]=32;
    ln1_level_load(_g,2,true);
    ln_check(_g.lives_left==3 && _g.inventory[8]==0 && _g.inventory[14]==5 && _g.inventory[13]==1,
             "original extra-life and projectile inventory carry at level end");
    _g.room_wounds[3]=17;ln1_level_load(_g,1);
    ln_check(_g.room_wounds[2]==32,"first-level defeated enemy survives level browsing");
    ln1_level_load(_g,2);
    ln_check(_g.room_wounds[3]==17,"later-level wounds survive level browsing");
    show_debug_message("LN_LEVELS_PASS: "+string(_rooms)+" additional rooms, "+string(_exits)+" original exits, "+
                       string(_selectors)+" original enemy selectors, "+string(_ticks)+" integration ticks and level-state persistence.");
    var _buf=buffer_load("verification/ln1_projectile_vectors.json");
    var _oracle=json_parse(buffer_read(_buf,buffer_text));buffer_delete(_buf);
    var _g=new LN1Play();_g.player.tick=100;_g.enemy.active=0;
    for (var _i=0;_i<array_length(_oracle.vectors);_i++) {
        var _v=_oracle.vectors[_i];_g.projectiles=[new LN1Projectile(),new LN1Projectile()];
        var _s=_g.projectiles[_v.slot];_s.active=_v.kind;_s.life=_v.life;_s.x=_v.x;_s.y=_v.y;
        _s.facing=_v.facing;_s.animation_tick=100;
        ln1_projectile_tick(_g);
        ln_check(_s.active==_v.expected[0] && _s.x==_v.expected[1] && _s.y==_v.expected[2] && _s.life==_v.expected[3],
                 "original projectile lifetime/motion "+string(_i));
    }
    show_debug_message("LN_PROJECTILES_PASS: "+string(array_length(_oracle.vectors))+" original one-tick projectile movement and lifetime cases.");
}

function ln1_level_capture() {
    for (var _level=1;_level<=6;_level++) {
        var _g=new LN1Play(_level),_room=[2,3,1,2,7,11][_level-1];
        ln1_test_enter(_g,_g.navigation.rooms[_room-1].spawn_entry);
        repeat(24) ln1_play_tick(_g,0);
        ln1_play_draw(_g,false);surface_save(application_surface,"lnpreserve-level"+string(_level)+".png");
        surface_free(_g.stage_surface);
    }
}
