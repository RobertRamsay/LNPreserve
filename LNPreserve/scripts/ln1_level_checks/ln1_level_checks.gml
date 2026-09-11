function ln1_level_checks() {
    ln1_find_sack_checks();
    var _hidden=new LN1Play(3),_hidden_item=undefined;
    for (var _hi=0;_hi<array_length(_hidden.world.items);_hi++) {
        if (ln1_hidden_apple(_hidden,_hidden.world.items[_hi])) _hidden_item=_hidden.world.items[_hi];
    }
    ln_check(is_struct(_hidden_item),"Palace room 11 source apple exists");
    _hidden.room_id=11;_hidden.inventory[2]=1;_hidden.inventory[8]=1;
    _hidden.room_age=0;
    ln_check(ln1_hidden_apple_flash(_hidden,_hidden_item),"hidden apple flashes even when another apple is held");
    _hidden.room_age=8;
    ln_check(!ln1_hidden_apple_flash(_hidden,_hidden_item),"hidden apple clue blinks off");
    _hidden.room_age=62;
    ln_check(!ln1_hidden_apple_flash(_hidden,_hidden_item),"hidden apple clue ends after entry");
    _hidden.player.x=_hidden_item.x_min;_hidden.player.y=_hidden_item.y_min;_hidden.player.facing=1;
    ln1_item_interact(_hidden);
    ln_check(_hidden.inventory[8]==2,"Palace hidden apple stacks through manual pickup");
    _hidden.room_age=0;
    ln_check(!ln1_hidden_apple_flash(_hidden,_hidden_item),"collected hidden apple never flashes again");
    ln1_pickup_assist_checks();
    ln1_jump_assist_checks();
    ln1_reverse_roll_checks();
    var _apple = new LN1Play();
    _apple.world.items = [{id:8, room:1, x_min:0, x_max:20, y_min:0, y_max:20}];
    _apple.room_id=1; _apple.player.x=10; _apple.player.y=10; _apple.player.facing=0;
    _apple.inventory[2]=1; _apple.inventory[8]=0;
    _apple.lives_left=2; _apple.player_health=7;
    ln1_item_interact(_apple);
    ln_check(_apple.lives_left==2 && _apple.player_health==7 && _apple.inventory[8]==1,
        "LN1 apple pickup banks reward");
    _apple.controls=ln3_data_read("actors/ln1/initial_control_state.json");_apple.controls.item=8;
    ln1_apple_input(_apple,16);repeat(22) ln1_apple_input(_apple,16);
    ln_check(_apple.lives_left==2,"holding fire does not eat apple");
    ln1_apple_input(_apple,0);ln1_apple_input(_apple,16);ln1_apple_input(_apple,0);ln1_apple_input(_apple,16);
    ln_check(_apple.lives_left==3 && _apple.player_health==32 && _apple.inventory[8]==128,"double fire consumes apple once");
    ln1_item_interact(_apple);
    ln_check(_apple.lives_left==3,"LN1 credited apple cannot be collected twice");
    ln1_level_load(_apple,2,true);
    ln_check(_apple.lives_left==3 && _apple.inventory[8]==0,
        "LN1 credited apple does not grant another life at level exit");
    var _stack=new LN1Play();_stack.inventory[2]=1;
    _stack.world.items=[{id:8,room:1,x_min:0,x_max:20,y_min:0,y_max:20}];
    _stack.player.x=10;_stack.player.y=10;_stack.player.facing=0;
    ln1_item_interact(_stack);ln1_item_interact(_stack);
    ln_check(_stack.inventory[8]==1,"same apple cannot be harvested twice");
    ln1_level_load(_stack,2,true);
    _stack.world.items=[{id:8,room:_stack.room_id,x_min:0,x_max:20,y_min:0,y_max:20}];
    _stack.player.x=10;_stack.player.y=10;_stack.player.facing=0;
    ln1_item_interact(_stack);
    ln_check(_stack.inventory[8]==2,"apple carried into next level does not hide its apple");
    _stack=ln_save_restore(json_parse(json_stringify(ln_save_capture(_stack))));
    ln_check(_stack.inventory[8]==2 && !ln1_item_available(_stack,_stack.world.items[0]),"saved apple count and collected locations persist");
    _stack.controls=ln3_data_read("actors/ln1/initial_control_state.json");_stack.controls.item=8;
    var _stack_lives=_stack.lives_left;
    ln1_apple_input(_stack,16);ln1_apple_input(_stack,0);ln1_apple_input(_stack,16);
    ln_check(_stack.inventory[8]==1 && _stack.controls.item==8 && _stack.lives_left==_stack_lives+1,"double fire consumes only one stacked apple");
    var _banked=new LN1Play();_banked.inventory[8]=1;_banked.controls=ln3_data_read("actors/ln1/initial_control_state.json");
    _banked.controls.item=8;_banked.player_health=7;_banked.lives_left=2;
    var _loaded=ln_save_restore(json_parse(json_stringify(ln_save_capture(_banked))));
    ln_check(_loaded.inventory[8]==1 && _loaded.controls.item==8 && _loaded.player_health==7 && _loaded.lives_left==2,"saved apple remains held without reward");
    _loaded.controls.item=10;ln1_apple_input(_loaded,16);ln1_apple_input(_loaded,0);ln1_apple_input(_loaded,16);
    ln_check(_loaded.inventory[8]==1 && _loaded.lives_left==2,"unselected apple is not consumed");
    var _dungeon=new LN1Play(4);
    for (var _i=0;_i<array_length(_dungeon.world.dungeon_spider_vectors);_i++) {
        var _v=_dungeon.world.dungeon_spider_vectors[_i];
        _dungeon.enemy=new LN1Enemy();
        _dungeon.enemy.x=_v.ex;_dungeon.enemy.y=_v.ey;
        _dungeon.enemy.facing=1;_dungeon.enemy.heading=1;_dungeon.enemy.action=$5145;
        _dungeon.player.x=_v.px;_dungeon.player.y=_v.py;_dungeon.player.input_lock=0;
        _dungeon.world_state.mode=_v.mode;
        ln1_level_events(_dungeon);
        var _actual=[_dungeon.world_state.mode,_dungeon.enemy.facing,_dungeon.enemy.heading,
                     _dungeon.enemy.action,_dungeon.player.input_lock,_dungeon.enemy.speed];
        for (var _j=0;_j<6;_j++) ln_check(_actual[_j]==_v.expected[_j],
            "dungeon spider original steering "+string(_i)+"/"+string(_j));
    }
    show_debug_message("LN_DUNGEON_PASS: 1024 original spider steering/approach/capture states.");
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
    var _g=new LN1Play();_g.inventory[4]=255;_g.inventory[8]=1;_g.inventory[11]=1;
    _g.inventory[13]=1;_g.inventory[14]=133;_g.player_health=7;
    _g.lives_left=2;_g.room_wounds[2]=32;
    ln1_level_load(_g,2,true);
    ln_check(_g.player_health==32 && _g.lives_left==2 && _g.inventory[8]==1 && _g.inventory[14]==5 &&
             _g.inventory[4]==255 && _g.inventory[11]==1 && _g.inventory[13]==1,
             "health reset, banked apple, items and weapons carry at level end");
    _g.room_wounds[3]=17;ln1_level_load(_g,1);
    ln_check(_g.room_wounds[2]==32,"first-level defeated enemy survives level browsing");
    ln1_level_load(_g,2);
    ln_check(_g.room_wounds[3]==17,"later-level wounds survive level browsing");
    var _dye=new LN1Play(6);
    _dye.world_state.protection=2;_dye.world_state.protection_tick=250;
    _dye.player.tick=243;ln1_level_effect_tick(_dye);
    ln_check(_dye.world_state.protection==2,"red dye persists through 249 ticks across byte wrap");
    _dye.player.tick=244;ln1_level_effect_tick(_dye);
    ln_check(_dye.world_state.protection==0,"red dye expires at 250 ticks across byte wrap");
    var _final=new LN1Play(6);
    ln1_test_enter(_final,48);_final.player.x=247;_final.player.y=85;ln1_play_exit(_final);
    ln_check(_final.level==6 && _final.room_id==13,"final approach room 12 exits to 13 without changing level");
    _final.player.x=0;_final.player.y=79;ln1_play_exit(_final);
    ln_check(_final.level==6 && _final.room_id==14,"final approach room 13 exits to 14 without changing level");
    _final.player.x=0;_final.player.y=112;ln1_play_exit(_final);
    ln_check(_final.level==6 && _final.room_id==15,"final approach room 14 exits to 15 without changing level");
    var _boss=new LN1Play(6);ln1_test_enter(_boss,56);
    _boss.enemy.active=136;_boss.enemy.wounds=1;_boss.enemy.facing=3;
    ln1_combat_hurt(_boss,true);
    ln_check(_boss.enemy.action==$50c7,"Shogun uses original special hurt record");
    ln1_play_tick(_boss,0);
    ln_check(_boss.enemy.display_frame==158,"Shogun hurt retains original boss pose");
    _boss.enemy.wounds=32;_boss.room_wounds[14]=32;ln1_combat_hurt(_boss,true);
    ln_check(_boss.enemy.action==$507e && _boss.enemy.mode==7,"Shogun uses original defeat sequence");
    repeat(240) {if (_boss.room_id==14) ln1_play_tick(_boss,0);}
    ln_check(_boss.level==6 && _boss.room_id==15 && _boss.last_entry==60,
        "Shogun defeat reaches scroll room through original action event and exit");
    var _dog=new LN1Play(6);ln1_test_enter(_dog,45);
    ln1_play_tick(_dog,0);ln1_play_tick(_dog,0);
    ln_check(_dog.room_id==11 && _dog.enemy.active==134 && _dog.enemy.display_frame==142 &&
        _dog.enemy.action==0,"Inner Sanctum dog waits in original idle pose $4e08");
    var _dog_x=_dog.enemy.x,_dog_y=_dog.enemy.y;
    for (var _idle_tick=0;_idle_tick<32;_idle_tick++) ln1_play_tick(_dog,0);
    ln_check(_dog.enemy.x==_dog_x && _dog.enemy.y==_dog_y && _dog.enemy.display_frame==142,
        "dog does not pursue before its approach boundary is crossed");
    _dog.player.boundary_crossings=1;ln1_level_hazard(_dog,13);
    ln_check(_dog.enemy.action==$4e0c && _dog.enemy.speed==3,"approach boundary releases dog pursuit");
    for (var _dog_tick=0;_dog_tick<16;_dog_tick++) ln1_play_tick(_dog,0);
    ln_check(_dog.enemy.active==134 && _dog.enemy.display_frame>=133 && _dog.enemy.display_frame<=141,
        "Inner Sanctum dog pursuit retains special dog frames instead of ordinary humanoid combat frames");
    _dog.player.x=_dog.enemy.x;_dog.player.y=_dog.enemy.y;
    ln1_level_events(_dog);
    ln_check(_dog.enemy.action==$4e20 && _dog.world_state.mode==0,
        "Inner Sanctum dog contact enters original tail-called record $4e20");
    for (var _contact_tick=0;_contact_tick<24;_contact_tick++) ln1_play_tick(_dog,0);
    ln_check(array_length(_dog.pending_events)==0,"Inner Sanctum dog contact animation stays in the recovered action graph");
    _dog.world_state.mode=7;ln1_test_enter(_dog,40);
    ln_check(_dog.room_id==10 && _dog.world_state.mode==0,
        "leaving the Inner Sanctum dog room clears its encounter-only pursuit mode");
    show_debug_message("LN_LEVELS_PASS: "+string(_rooms)+" additional rooms, "+string(_exits)+" original exits, "+
                       string(_selectors)+" original enemy selectors, "+string(_ticks)+" integration ticks and level-state persistence.");
    var _buf=buffer_load("verification/ln1_projectile_vectors.json");
    var _oracle=json_parse(buffer_read(_buf,buffer_text));buffer_delete(_buf);
    _g=new LN1Play();_g.player.tick=100;_g.enemy.active=0;
    for (var _i=0;_i<array_length(_oracle.vectors);_i++) {
        var _v=_oracle.vectors[_i];_g.projectiles=[new LN1Projectile(),new LN1Projectile()];
        var _s=_g.projectiles[_v.slot];_s.active=_v.kind;_s.life=_v.life;_s.x=_v.x;_s.y=_v.y;
        _s.facing=_v.facing;_s.animation_tick=100;
        ln1_projectile_tick(_g);
        ln_check(_s.active==_v.expected[0] && _s.x==_v.expected[1] && _s.y==_v.expected[2] && _s.life==_v.expected[3],
                 "original projectile lifetime/motion "+string(_i));
    }
    global.ln_test_no_enemy_damage=false;_g=new LN1Play();_g.enemy.active=128;_g.enemy.combat_state=20;
    var _shot=_g.projectiles[1];_shot.active=1;_shot.life=7;_shot.x=_g.player.x;_shot.y=_g.player.y;
    ln1_projectile_tick(_g);ln_check(_g.player_health==16,"LN1 hostile projectile reduces health normally");
    global.ln_test_no_enemy_damage=true;_g=new LN1Play();_g.enemy.active=128;_g.enemy.combat_state=20;
    _shot=_g.projectiles[1];_shot.active=1;_shot.life=7;_shot.x=_g.player.x;_shot.y=_g.player.y;
    ln1_projectile_tick(_g);ln_check(_g.player_health==32 && _shot.active==0,"F11 protection absorbs LN1 hostile projectile damage");
    global.ln_test_no_enemy_damage=false;
    show_debug_message("LN_PROJECTILES_PASS: "+string(array_length(_oracle.vectors))+" original one-tick projectile movement and lifetime cases.");
}

function ln1_level_capture() {
    var _dungeon_rooms=[2,3,8,20];
    for (var _i=0;_i<array_length(_dungeon_rooms);_i++) {
        var _g=new LN1Play(4),_room=_dungeon_rooms[_i];
        ln1_test_enter(_g,_g.navigation.rooms[_room-1].spawn_entry);
        repeat(90) ln1_play_tick(_g,0);
        ln1_play_draw(_g,false);
        surface_save(application_surface,"lnpreserve-dungeon-room"+string(_room)+".png");
        surface_free(_g.stage_surface);
    }
    for (var _level=1;_level<=6;_level++) {
        var _g=new LN1Play(_level),_room=[2,3,1,2,7,11][_level-1];
        ln1_test_enter(_g,_g.navigation.rooms[_room-1].spawn_entry);
        repeat(24) ln1_play_tick(_g,0);
        ln1_play_draw(_g,false);surface_save(application_surface,"lnpreserve-level"+string(_level)+".png");
        surface_free(_g.stage_surface);
    }
}
