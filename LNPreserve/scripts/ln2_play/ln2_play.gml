function LN2Play(_level=1) constructor {
    game_number=2;level=_level;
    var _folder="play/ln2/level"+string(level)+"/",_buffer=buffer_load(_folder+"gameplay.json");
    data=json_parse(buffer_read(_buffer,buffer_text));buffer_delete(_buffer);
    _buffer=buffer_load(_folder+"world.json");world=json_parse(buffer_read(_buffer,buffer_text));buffer_delete(_buffer);
    title=world.title;player=data.initial;player.display_frame=player.frame;player.mirror=false;player.previous_combat=0;
    inventory=world.initial_inventory;player_health=44;lives_left=world.initial_lives;
    room_id=-1;scene_record=undefined;enemy=undefined;last_entry=world.initial_entry;room_age=0;
    room_enemies={};opened_passages={};level_states=array_create(7,undefined);
    selected_item=0;paused=false;music=true;controls=undefined;control_previous=[16,32,64,8,16];
    notice_item=-1;notice_tick=0;notice_duration=0;notice_label=0;
    tick_epoch=0;respawn_wait=0;game_over=false;level_complete=false;player_projectile_active=false;
    special_mode=0;special_flag=0;special_count=0;exit_locked=false;pending_entry=-1;
    world_clock=player.tick;fall_remaining=-1;fall_clock=player.tick;
    projectile={kind:0,x:0,y:0,phase:0};
    world_state={sequence_lock:0,code_visible:false,boss_defeated:false};pending_events=[];
    random_queue=[];random_head=0;random_pointer=data.random_pointer;random_value=data.random_value;
    timer=new LNClock();timer.cycles_per_frame=data.timer_period_cycles;stage_surface=-1;
    ln2_play_travel(self,last_entry);
}

function ln2_enemy_remember(_g) {
    if (!is_struct(_g.enemy) || _g.room_id<0) return;
    var _e=_g.enemy;
    variable_struct_set(_g.room_enemies,string(_g.room_id),{health:_e.health,knockouts:_e.knockouts,
        recovery_time:_e.recovery_time,x:_e.x,y:_e.y,facing:_e.facing});
}

function ln2_play_enter(_g,_id) {
    ln2_enemy_remember(_g);_g.room_id=_id;_g.player.room_id=_id;
    for (var _i=0;_i<array_length(_g.world.rooms);_i++) if (_g.world.rooms[_i].id==_id) { _g.scene_record=_g.world.rooms[_i];break; }
    var _room=_g.scene_record;_g.data.boundaries=json_parse(json_stringify(_room.boundaries));
    if (variable_struct_exists(_g.opened_passages,string(_id))) ln2_item_open_line(_g);
    _g.mask=asset_get_index(_room.depth_sprite);_g.room_age=0;_g.world_clock=_g.player.tick;_g.pending_entry=-1;_g.fall_remaining=-1;
    var _e=json_parse(json_stringify(_room.enemy));_g.enemy=_e;
    _e.display_frame=_e.active>=128?_e.frame:255;_e.mirror=_e.action_mirror!=0;_e.custom=false;
    _e.decision_tick=_g.player.tick;_e.action_tick=_g.player.tick;
    _e.boundary_hit=255;_e.last_boundary=255;_e.boundary_history1=255;_e.boundary_history2=255;
    _e.actor_blocked=0;_e.edge_blocked=0;_e.attack_count=0;_e.separation_y=6;
    _e.origin_x=_g.player.x;_e.origin_y=_g.player.y;
    if (variable_struct_exists(_g.room_enemies,string(_id))) {
        var _saved=variable_struct_get(_g.room_enemies,string(_id));
        _e.health=_saved.health;_e.knockouts=_saved.knockouts;_e.recovery_time=_saved.recovery_time;
        if (_e.knockouts>=128) {
            _e.x=_saved.x;_e.y=_saved.y;_e.depth_y=_e.y;_e.facing=_saved.facing;
            _e.mode=11;_e.combat_state=36+(_e.facing>>1);_e.separation_y=0;
            _e.action=0;_e.display_frame=46;_e.mirror=(_e.facing&4)==0;
        }
    }
    ln2_entry_hook(_g);ln2_refresh_scene(_g);
}

function ln2_play_travel(_g,_entry) {
    var _t=_g.world.tables,_p=_g.player;
    if (_entry<0 || _entry>=array_length(_t.exit_destinations)) return false;
    if (_t.exit_destinations[_entry]==255) return ln2_level_load(_g,_g.level+1,true);
    _g.last_entry=_entry;_p.x=_t.entry_x[_entry];_p.y=_t.entry_y[_entry];_p.depth_y=_p.y;
    _p.facing=_t.entry_heading[_entry]&7;_p.heading=_p.facing;
    _p.frame=16+(((_p.facing+2)&4)>>2);_p.boundary_crossings=_t.entry_heading[_entry]>>4;_p.turn_lock=255;
    ln2_play_enter(_g,_t.exit_destinations[_entry]);
    ln2_player_render(_p,_g.data.mirror[_p.facing>>1]&(1<<_p.heading));return true;
}

function ln2_play_exit(_g) {
    if (_g.exit_locked) return;
    var _p=_g.player,_perimeter;
    if (_p.y<9) _perimeter=max(0,_p.x-2)>>2;
    else if (_p.y>=189) _perimeter=(max(0,247-_p.x)>>2)+106;
    else if (_p.x>=247) _perimeter=(max(0,_p.y-9)>>2)+61;
    else if (_p.x<2) _perimeter=(max(0,189-_p.y)>>2)+167;
    else return;
    for (var _i=0;_i<array_length(_g.scene_record.entries);_i++) {
        var _entry=_g.scene_record.entries[_i];
        if (_perimeter<_g.world.tables.exit_thresholds[_entry]) { ln2_play_travel(_g,_entry);return; }
    }
}

function ln2_test_enter(_g,_entry) {
    var _p=_g.player;_p.action=0;_p.action_state=0;_p.flags=0;_p.countdown=0;_p.duration=0;
    _p.input_lock=0;_p.stopped=255;_p.fraction_x=0;_p.fraction_y=0;_p.walk_clock=0;
    _p.fire_previous=0;_p.attack_direction=255;_p.attack_previous=255;_p.collision=0;_p.last_tick=_p.tick;
    _g.respawn_wait=0;_g.game_over=false;_g.player_health=max(1,_g.player_health);_g.lives_left=max(1,_g.lives_left);
    _g.notice_item=-1;_g.world_state.sequence_lock=0;
    if (!ln2_play_travel(_g,_entry)) return false;
    _p.combat_state=_p.facing>>1;_p.previous_combat=_p.combat_state;_p.saved_heading=_p.heading;return true;
}

function ln2_test_exit(_g,_direction) {
    var _nearest=infinity,_entry=-1;
    for (var _i=0;_i<array_length(_g.scene_record.routes);_i++) {
        var _r=_g.scene_record.routes[_i];
        if (_r.direction!=_direction) continue;
        var _distance=point_distance(_g.player.x,_g.player.y,_r.x,_r.y);
        if (_distance<_nearest) { _nearest=_distance;_entry=_r.entry; }
    }
    if (_entry<0) return 0;
    return ln2_test_enter(_g,_entry)?1:-1;
}

function ln2_level_load(_g,_level,_ordinary=false) {
    if (_level>7) { _g.level_complete=true;return false; }
    if (_level<1) return false;
    ln2_enemy_remember(_g);
    _g.level_states[_g.level-1]={enemies:_g.room_enemies,passages:_g.opened_passages,world:_g.world_state};
    var _fresh=new LN2Play(_level),_names=variable_struct_get_names(_fresh);
    for (var _i=0;_i<array_length(_names);_i++) {
        var _name=_names[_i];
        if (array_contains(["level_states","inventory","timer","stage_surface","lives_left","player_health","controls"],_name)) continue;
        variable_struct_set(_g,_name,variable_struct_get(_fresh,_name));
    }
    _g.timer.cycles_per_frame=_g.data.timer_period_cycles;
    var _saved=_g.level_states[_level-1];
    if (is_struct(_saved)) { _g.room_enemies=_saved.enemies;_g.opened_passages=_saved.passages;_g.world_state=_saved.world; }
    if (_ordinary) _g.player_health=44;
    // Fresh room creation must not overwrite the saved encounter being restored.
    _g.enemy=undefined;_g.room_id=-1;ln2_play_travel(_g,0);
    ln_music_play(2,["central_park","street","sewers","basement","office","mansion","final_battle"][_level-1],false);
    return true;
}

function ln2_play_tick(_g,_joy) {
    if (_g.game_over || _g.level_complete) return;
    var _p=_g.player,_tick=(_p.tick+1)&255;if (_tick==0) _g.tick_epoch=(_g.tick_epoch+1)&255;
    _g.room_age++;
    if (_g.notice_item>=0 && ((_tick-_g.notice_tick)&255)>=_g.notice_duration) _g.notice_item=-1;
    if (_g.respawn_wait>0) {
        _p.tick=_tick;_p.last_tick=_tick;_g.respawn_wait--;
        if (_g.respawn_wait==0) {
            _g.lives_left--;
            if (_g.lives_left<=0) { _g.game_over=true;return; }
            _g.player_health=44;ln2_test_enter(_g,_g.last_entry);
        }
        return;
    }
    if (_g.fall_remaining>=0) { ln2_fall_tick(_g,_tick);return; }
    _p.enemy_active=_g.enemy.active;_p.enemy_x=_g.enemy.x;_p.enemy_y=_g.enemy.y;_p.separation_y=_g.enemy.separation_y;
    _p.gate_open=_g.inventory[18];_p.gate_mode=_g.inventory[20];
    ln2_player_update(_p,_g.data,_joy,_tick);ln2_enemy_decide(_g);ln2_enemy_action(_g);
    ln2_combat_event(_g,_p.action_state,false);_p.action_state=0;
    ln2_combat_event(_g,_g.enemy.action_state,true);_g.enemy.action_state=0;
    if (_g.fall_remaining>=0) return;
    ln2_play_exit(_g);ln2_level_effect_tick(_g,_joy);ln2_enemy_remember(_g);
    if (_g.pending_entry>=0) { var _entry=_g.pending_entry;_g.pending_entry=-1;ln2_play_travel(_g,_entry); }
    if (_p.input_lock!=0 && _p.action<256 && _g.respawn_wait==0) {
        _g.player_health=0;ln2_player_special(_g,_g.data.enemy_falls[(_p.facing&4)?1:0]);
    }
}

function ln2_play_actor(_g,_a,_enemy) {
    if (_a.display_frame==255 || (_enemy && _a.active<128 && !_a.custom)) return;
    var _extra=_a.display_frame>=64,_index=_extra?-1:_a.display_frame;
    if (_extra) for (var _i=0;_i<array_length(_g.world.actor_frames);_i++) if (_g.world.actor_frames[_i]==_a.display_frame) { _index=_i;break; }
    if (_index<0) return;
    var _enemies=_extra?_g.world.enemy_extra_banks:_g.world.enemy_banks;
    var _players=_extra?_g.world.player_extra_banks:_g.world.player_banks;
    var _name=_enemy && !_a.custom?variable_struct_get(_enemies,string(_a.weapon)+"_"+string(_a.costume)):_players[min(4,_a.weapon)];
    var _sprite=asset_get_index(_name);
    if (_a.mirror) _index+=_extra?array_length(_g.world.actor_frames):64;
    ln_draw_masked_actor(_sprite,_index,_a.x,_a.y,1,1,_g.mask,0,0,240,144,max(0.001,(_a.depth_y-0.25)/255));
}

function ln2_play_draw(_g) {
    draw_clear(c_black);draw_set_colour(c_white);
    if (!surface_exists(_g.stage_surface)) _g.stage_surface=surface_create(240,144);
    surface_set_target(_g.stage_surface);draw_clear(c_black);draw_sprite(_g.scene,0,0,0);
    if (_g.player.depth_y<_g.enemy.depth_y) { ln2_play_actor(_g,_g.player,false);ln2_play_actor(_g,_g.enemy,true); }
    else { ln2_play_actor(_g,_g.enemy,true);ln2_play_actor(_g,_g.player,false); }
    surface_reset_target();draw_surface_ext(_g.stage_surface,160,84,4,4,0,c_white,1);
    draw_text(160,36,"LAST NINJA 2 — "+string_upper(_g.title));draw_text(1000,36,"Scene "+string(_g.room_id));
    draw_text(160,672,"Health "+string(_g.player_health)+"   Lives "+string(_g.lives_left)+"   Enemy "+string(_g.enemy.health));
    draw_text(700,672,_g.notice_item>=0?"FOUND   Item "+string(_g.notice_item):"Item "+string(_g.selected_item)+"   Weapon "+string(_g.player.selected_weapon));
    draw_text(160,712,"WASD Move    J + direction Action    Space Weapon    1 2 3 4 Function keys");
    draw_text(160,744,"Arrows: Right NE / Down SE / Left SW / Up NW    F11 Scenes    Home Restart");
    if (_g.paused) draw_text(600,60,"PAUSED");
    if (_g.game_over) draw_text(540,60,"GAME OVER — HOME TO RESTART");
    if (_g.level_complete) draw_text(530,60,"END OF LAST NINJA 2");
}
