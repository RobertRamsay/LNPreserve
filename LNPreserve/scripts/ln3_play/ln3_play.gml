function ln3_data_read(_path) {
    var _b=buffer_load(_path),_data=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);return _data;
}

function ln3_room_record(_rooms,_id) {
    for (var _i=0;_i<array_length(_rooms);_i++) if (_rooms[_i].id==_id) return _rooms[_i];
    return undefined;
}

function LN3Play(_level=1) constructor {
    edited_enemy_rooms={};
    map_transit=undefined;map_bypass=false;
    loader=undefined;pickup_assist=undefined;ordinary_death=false;
    one_hit_kills=false;
    game_number=3;level=_level;var _path="play/ln3/level"+string(level)+"/";
    data=ln3_data_read(_path+"runtime.json");world=ln3_data_read(_path+"world.json");
    actions=ln3_data_read(_path+"actions.json");movement=ln3_data_read(_path+"movement.json");
    ln3_costume_walk_fix(actions);
    input=ln3_data_read(_path+"input.json");animation=ln3_data_read(_path+"animation.json");
    collision=ln3_data_read(_path+"collision.json");enemies=ln3_data_read(_path+"enemy.json");
    ln3_exposed_wind_edges(collision);
    combat=ln3_data_read(_path+"combat.json");masks=ln3_data_read(_path+"masks.json");
    items=ln3_data_read(_path+"items.json");found_item=-1;
    scenery=ln3_data_read(_path+"scenery_animation.json");
    special=ln3_data_read(_path+"special.json");mechanisms=ln3_data_read("play/ln3/mechanisms.json");
    state=json_parse(json_stringify(data.initial));title=world.title;room_id=-1;scene_record=undefined;
    state.reverse_roll_enabled=true;state.reverse_roll=undefined;
    var _fields=variable_struct_get_names(special.initial);
    for (var _i=0;_i<array_length(_fields);_i++) variable_struct_set(state,_fields[_i],variable_struct_get(special.initial,_fields[_i]));
    special_sequence=0;special_step=0;special_request=0;special_colours=array_create(8,-1);
    transition=ln3_data_read("play/ln3/transition.json");transition_phase=0;transition_y=[];transition_mode=0;transition_signal=0;transition_wipe=0;ending_requested=false;
    hud_player_health=0;hud_enemy_health=0;hud_honour=0;hud_wait=0;hud_wheel_wait=0;hud_eye_wait=0;hud_eye_phase=0;hud_eye_left=-1;hud_eye_right=-1;
    intro=undefined;ending=undefined;ending_surface=-1;
    palette=[];for (var _i=0;_i<16;_i++) palette[_i]=make_colour_rgb(data.palette[_i][0],data.palette[_i][1],data.palette[_i][2]);
    stage_surface=-1;part_surface=-1;timer=new LNClock();controls=undefined;
    smooth_from=undefined;smooth_frame=0;smooth_period=5;smooth_room=-1;display_prev=undefined;draw_masks_prev=undefined;
    paused=false;music=true;game_over=false;level_complete=false;level_states=array_create(5,undefined);
    room_enemies={};room_age=0;logic_ticks=0;weapon_switch=false;control_previous=[false,false,false,false];
    draw_masks=array_create(8,undefined);render_version=0;
    var _start={destination:state.room_id,spawn_x:state.player_x,spawn_y:state.player_y,
        facing:state.mirror&6,action:state.player_action};
    last_entry=_start;ln3_play_enter(self,_start);
}

function ln3_enemy_remember(_g) {
    if (_g.room_id<0) return;
    var _s=_g.state;
    variable_struct_set(_g.room_enemies,string(_g.room_id),{health:_s.enemy_health,dead:_s.enemy_dead,
        mirror:_s.mirror&96,x:_s.parts[6].x,y:_s.parts[6].y});
}

function ln3_play_enter(_g,_entry) {
    if(ln_map_intercept(_g,_entry)) return true;
    ln_enemy_room_leave(_g);
    ln_rewind_boundary();
    ln3_intro_free(_g);
    _g.loader=undefined;_g.pickup_assist=undefined;_g.food_taps={remaining:0,previous:16};
    var _scene=ln3_room_record(_g.world.rooms,_entry.destination);if (!is_struct(_scene)) return false;
    ln3_enemy_remember(_g);_g.room_id=_entry.destination;_g.last_entry=_entry;_g.scene_record=_scene;_g.room_age=0;
    _g.special_sequence=0;_g.special_request=0;_g.special_colours=array_create(8,-1);
    if (is_struct(_g.ending) && surface_exists(_g.ending.scroll_surface)) surface_free(_g.ending.scroll_surface);
    _g.ending=undefined;
    var _s=_g.state;_s.room_id=_g.room_id;
    var _saved=variable_struct_exists(_g.room_enemies,string(_g.room_id))?variable_struct_get(_g.room_enemies,string(_g.room_id)):
        {health:_g.data.initial_enemy_health[_g.room_id],dead:0,mirror:0,x:0,y:0};
    _s.enemy_health=_saved.health;_s.enemy_dead=_saved.dead;_s.mirror=(_s.mirror&159)|_saved.mirror;
    _s.enemy_x=_saved.x;_s.parts[5].x=_saved.x;_s.parts[6].x=_saved.x;
    _s.enemy_y=_saved.y;_s.parts[6].y=_saved.y;_s.parts[5].y=(_saved.y-21)&255;
    ln3_scene_reset(_s);
    _s.player_x=_entry.spawn_x;_s.parts[1].x=_entry.spawn_x;_s.parts[2].x=_entry.spawn_x;
    _s.player_y=_entry.spawn_y;_s.parts[2].y=_entry.spawn_y;_s.parts[1].y=(_entry.spawn_y-21)&255;
    _s.mirror=_entry.facing;
    ln3_action_set(_s,_g.actions,_entry.action);
    _g.runtime_scene=ln3_room_record(_g.data.rooms,_g.room_id);
    _g.item_records=ln3_room_record(_g.items.rooms,_g.room_id).items;
    _g.bounds=ln_collision_runtime(_g,ln3_room_record(_g.collision.rooms,_g.room_id).boundaries);
    _g.mask_shapes=ln3_room_record(_g.masks.rooms,_g.room_id).shapes;
    _g.scenery_record=ln3_room_record(_g.scenery.rooms,_g.room_id);_g.scenery_frame=-1;_g.scenery_repeating=false;_g.scenery_mechanism=false;
    ln3_enemy_enter(_s,_g.actions,_g.data,_g.runtime_scene);
    // Draw the entry pose without advancing its animation or simulation state.
    var _display=json_parse(json_stringify(_s));ln3_animation_update(_display,_g.animation);
    ln3_play_prepare_draw(_g,_display);return true;
}

function ln3_play_exit(_g) {
    var _s=_g.state;if (_s.stun!=0) return false;
    var _records=_g.scene_record.exits,_skip=0;
    if (_g.level==1 && _s.climb_counter!=0) _skip=_g.room_id==4?8:(_g.room_id==3?10:0);
    var _bytes=0;
    for (var _i=0;_i<array_length(_records);_i++) {
        var _r=_records[_i],_offset=_bytes;_bytes+=array_length(_r.raw);if (_offset<_skip) continue;
        if (!ln3_exit_matches(_s,_r.raw)) continue;
        if (_r.destination==13) {
            ln3_enemy_remember(_g);
            if (_s.selected_item!=6 || (_g.level==3 && _s.water_gate==0)) return false;
            _s.boss_honour=_s.honour;
        }
        return ln3_play_enter(_g,_r);
    }
    return false;
}

function ln3_test_enter(_g,_id) {
    var _entry=undefined;
    var _scene=ln3_room_record(_g.world.rooms,_id);
    if (is_struct(_scene) && variable_struct_exists(_scene,"special_entry")) _entry=_scene.special_entry;
    if (_id==_g.data.initial.room_id) _entry={destination:_id,spawn_x:_g.data.initial.player_x,
        spawn_y:_g.data.initial.player_y,facing:_g.data.initial.mirror&6,action:_g.data.initial.player_action};
    for (var _i=0;!is_struct(_entry) && _i<array_length(_g.world.rooms);_i++) {
        var _exits=_g.world.rooms[_i].exits;
        for (var _j=0;_j<array_length(_exits);_j++) if (_exits[_j].destination==_id) {_entry=_exits[_j];break;}
    }
    if (!is_struct(_entry)) return false;
    _g.game_over=false;_g.state.player_health=max(1,_g.state.player_health);_g.state.lives=max(1,_g.state.lives);
    _g.state.climb_flags=0;_g.state.climb_counter=0;_g.state.player_action=255;
    return ln3_play_enter(_g,_entry);
}

function ln3_exit_test_point(_raw) {
    var _rectangle=_raw[0]>=128 || (_raw[0]&12)==0;
    return _rectangle?[(_raw[1]+_raw[2])/2,(_raw[3]+_raw[4])/2]:[(_raw[0]&4)?16:244,(_raw[1]+_raw[2])/2];
}

function ln3_test_exit(_g,_direction) {
    var _closest=infinity,_chosen=undefined;
    for (var _i=0;_i<array_length(_g.scene_record.exits);_i++) {
        var _r=_g.scene_record.exits[_i],_p=ln3_exit_test_point(_r.raw);
        var _right=(_r.flags&8)!=0,_down=_p[1]>=122;
        var _way=_right?(_down?1:0):(_down?2:3);
        if (_way!=_direction) continue;
        var _distance=point_distance(_g.state.player_x,_g.state.player_y,_p[0],_p[1]);
        if (_distance<_closest) {_closest=_distance;_chosen=_r;}
    }
    if (!is_struct(_chosen)) return 0;
    _g.state.climb_flags=0;_g.state.climb_counter=0;_g.state.player_action=255;_g.game_over=false;
    _g.state.player_health=max(1,_g.state.player_health);_g.state.lives=max(1,_g.state.lives);
    return ln3_play_enter(_g,_chosen)?1:0;
}

function ln3_level_load(_g,_level,_ordinary=false) {
    if (_level>5) {_g.level_complete=true;return false;}
    if (_level<1) return false;
    if (_level==_g.level && !_ordinary) return true;
    ln3_ending_free(_g);
    ln3_enemy_remember(_g);_g.level_states[_g.level-1]={enemies:_g.room_enemies};
    var _inventory=_g.state.inventory,_health=_g.state.player_health,_honour=_g.state.honour,
        _lives=_g.state.lives,_score=_g.state.score_digits;
    var _fresh=new LN3Play(_level),_names=variable_struct_get_names(_fresh);
    for (var _i=0;_i<array_length(_names);_i++) {
        var _name=_names[_i];if (array_contains(["one_hit_kills","level_states","timer","stage_surface","part_surface","controls"],_name)) continue;
        variable_struct_set(_g,_name,variable_struct_get(_fresh,_name));
    }
    var _s=_g.state;
    if (_ordinary) {for (var _i=4;_i<23;_i++) if (_i!=21 || _inventory[21]>=128) _inventory[_i]=0;_health=44;}
    _s.inventory=_inventory;_s.player_health=_health;_s.honour=_honour;_s.lives=_lives;_s.score_digits=_score;
    _s.ammo=_inventory[28];_s.inventory[25]=_honour;_s.inventory[26]=_health;_s.inventory[27]=_lives;_s.inventory[29]=_level-1;
    var _saved=_g.level_states[_level-1];if (is_struct(_saved)) _g.room_enemies=_saved.enemies;
    _g.room_id=-1;ln3_play_enter(_g,_g.last_entry);
    if (_ordinary) ln_frontend_begin(_g);else ln_frontend_music(_g,false);return true;
}

/// LN3 moves and animates only every fourth 50 Hz tick (12.5 Hz), 4 pixels per walking step; the
/// original copies those positions to the hardware sprites unchanged. On a 60 Hz display the
/// 50 Hz ticks bunch, so the steps also land unevenly.
/// Smooth motion draws each character part of the way from its previous to its new position
/// on the frames in between. Logic, collisions and timing are untouched; poses are exact
/// because the whole body shares one offset. Original motion shows the native jumps.
function ln3_smooth_enabled() {return !variable_global_exists("ln_ln3_smooth") || global.ln_ln3_smooth;}
/// 50 Hz ticks since the last logic step, from real time (including the current tick's fraction).
function ln3_smooth_elapsed(_g) {
    var _sub=0;
    if(is_struct(_g.timer)) _sub=clamp(real(_g.timer.credit)/(real(_g.timer.cycles_per_frame)*1000000),0,0.999);
    return _g.smooth_frame+_sub;
}
/// Original motion, steadier cadence: an 80 ms step is 4.8 frames at 60 Hz, so steps land
/// 4 or 5 frames apart; when a step sits on a frame boundary, timing jitter adds extra slips.
/// Holding the previous picture for half a frame (8.3 ms, 0.42 ticks) keeps steps off the
/// boundaries, leaving only the unavoidable 5,5,5,5,4 rhythm.
function ln3_original_hold(_g) {
    if(ln3_smooth_enabled() || !is_struct(_g.display_prev) || !is_array(_g.draw_masks_prev)) return false;
    if(_g.smooth_room!=_g.room_id || _g.special_sequence!=0) return false;
    return ln3_smooth_elapsed(_g)<0.4167;
}
function ln3_smooth_offset(_g,_d,_i) {
    if(!ln3_smooth_enabled() || !is_array(_g.smooth_from) || _g.smooth_room!=_g.room_id || _g.special_sequence!=0) return [0,0];
    if(_d.parts[_i].animation==114) return [0,0]; // thrown weapons fly on their own path
    var _enemy=_i>=4;if(_enemy && ln_enemy_custom(_g)) return [0,0];
    // Progress since the last logic step comes from real time, including the fraction of the
    // current 50 Hz tick, so every 60 Hz display frame gets its own position however ticks bunch.
    var _a=ln3_smooth_elapsed(_g)/max(1,_g.smooth_period);if(_a>=1) return [0,0];
    var _fx=_g.smooth_from[_enemy?2:0],_fy=_g.smooth_from[_enemy?3:1];
    var _dx=(((_enemy?_d.enemy_x:_d.player_x)-_fx+128)&255)-128,_dy=(((_enemy?_d.enemy_y:_d.player_y)-_fy+128)&255)-128;
    if(abs(_dx)>16 || abs(_dy)>16) return [0,0]; // teleports, falls and scene changes snap
    return [round(-_dx*(1-_a)),round(-_dy*(1-_a))];
}
/// The original's fixed sprite priority always puts the ninja (parts 0-3) in front of the
/// enemy (4-7). Draw whichever character stands lower on screen last, so it is in front.
function ln3_draw_order(_g,_d) {
    var _base=_g.animation.order;
    if((_d.enabled&240)==0 || _d.enemy_y<=_d.player_y) return _base;
    var _out=[];
    for(var _i=0;_i<8;_i++) if(_base[_i]<4) array_push(_out,_base[_i]);
    for(var _i=0;_i<8;_i++) if(_base[_i]>=4) array_push(_out,_base[_i]);
    return _out;
}
function ln3_play_prepare_draw(_g,_s) {
    if (_g.special_sequence==0) _g.special_colours=array_create(8,-1);
    _g.display=_s==_g.state?json_parse(json_stringify(_s)):_s;
    var _d=_g.display;
    for (var _order=0;_order<8;_order++) {
        var _i=_g.animation.order[_order];if (_d.draw_frames[_i]<0) continue;
        var _skip=_d.parts[_i].animation==114 || (_g.level==1 && _g.room_id==4 && _i<4 && _d.climb_counter!=0);
        _g.draw_masks[_i]=_skip?array_create(63,255):ln3_mask_bytes(_g.state,_g.mask_shapes,_d.draw_x[_i],_d.draw_y[_i],_d.parts[_i<4?2:6].y);
    }
    _g.render_version++;
}

function ln3_play_tick(_g,_joy) {
    if(ln_map_tick(_g,_joy)) return;
    if (ln3_intro_tick(_g,_joy)) return;
    if (ln_frontend_tick(_g,_joy)) return;
    _joy=ln_frontend_filter(_g,_joy);
    if (_g.game_over) {ln3_restart_splash(_g);return;}
    if (_g.level_complete) {ln3_hud_tick(_g);return;}
    if (is_struct(_g.ending)) {ln3_ending_tick(_g.ending,_joy);return;}
    var _s=_g.state;_g.room_age++;
    // The original PAL IRQ decrements byte timers and wraps its word timer.
    var _timers=["logic_wait","enemy_attack_wait","weapon_notice_timer","scene_wait","regeneration_wait","death_wait","item_wait","special_wait","fire_damage_wait","wind_damage_wait"];
    for (var _i=0;_i<array_length(_timers);_i++) {
        var _key=_timers[_i],_v=variable_struct_get(_s,_key);if (_v!=0) variable_struct_set(_s,_key,_v-1);
    }
    _s.enemy_throw_wait=(_s.enemy_throw_wait-1)&65535;
    ln3_hud_tick(_g);
    if (_g.level==5) ln3_void_flash_tick(_s);
    if (_g.special_sequence!=0) {ln3_special_sequence_tick(_g);return;}
    if (_s.weapon_notice_timer==0) _g.found_item=-1;
    _joy=ln3_item_assist_input(_g,_joy);
    ln3_play_exit(_g);if(ln_map_active(_g)) return;
    if (_s.regeneration_wait==0) {
        _s.regeneration_wait=50;
        for (var _i=0;_i<13;_i++) {
            var _key=string(_i);
            if (!variable_struct_exists(_g.room_enemies,_key)) continue;
            var _enemy=variable_struct_get(_g.room_enemies,_key);if (_enemy.health<44) _enemy.health++;
        }
        if (_s.enemy_dead!=0 && _s.enemy_health<44) _s.enemy_health++;
    }
    if (_s.logic_wait!=0) {_g.smooth_frame++;ln3_play_items(_g);ln3_play_special(_g);return;}
    ln_enemy_runtime(_g);
    // Smooth motion: remember where both characters stood before this logic step.
    _g.smooth_from=[_s.player_x,_s.player_y,_s.enemy_x,_s.enemy_y];_g.smooth_room=_g.room_id;_g.smooth_frame=0;
    _s.logic_wait=4;_g.logic_ticks++;
    if (!is_struct(_g.pickup_assist)) ln3_input_update(_s,_g.actions,_g.input,_joy,_g.weapon_switch);
    _g.weapon_switch=false;
    if (_s.weapon_notice_timer==100) _g.found_item=-1;
    ln3_enemy_recover_action(_s,_g.actions);
    if(ln_enemy_native_ai(_g)) {ln3_enemy_decide(_s,_g.actions,_g.input,_g.enemies);ln3_enemy_attack(_s,_g.actions,_g.enemies,(_g.timer.cycle div 63)&255);}
    _s.one_hit_kills=_g.one_hit_kills;
    ln3_combat_update(_s,_g.actions,_g.combat);ln3_fall_tick(_s,_g.actions,_g.data);
    // Wind drops retain the native falling body, without the water splash pair.
    if(_g.level==2 && _s.input_block!=0) {_s.enabled&=252;_s.waterline=173;}
    ln3_movement_setup(_s,_g.movement);ln3_movement(_s,_g.movement);
    ln3_climb_enter(_s,_g.actions,_g.runtime_scene.climbs,_joy,_g.level);
    ln3_collision_update(_s,_g.actions,_g.collision,_g.bounds);
    ln3_hazard_tick(_s,_g.actions,_g.data);ln3_hazard_contacts(_s,_g.data);
    if(ln_enemy_native_ai(_g)) ln3_enemy_patrol(_s,_g.actions,_g.input,_g.enemies);
    ln3_scenery_tick(_g);
    ln3_animation_update(_s,_g.animation);
    // Original motion holds the previous picture briefly, so keep it for the even-cadence display.
    _g.display_prev=_g.display;_g.draw_masks_prev=is_array(_g.draw_masks)?array_create(array_length(_g.draw_masks),0):undefined;
    if(is_array(_g.draw_masks_prev)) array_copy(_g.draw_masks_prev,0,_g.draw_masks,0,array_length(_g.draw_masks));
    ln3_play_prepare_draw(_g,_s);
    // Shorten only the initial reverse pose; later animation intervals stay native.
    if (variable_struct_exists(_s,"reverse_roll") && is_struct(_s.reverse_roll) && _s.player_action==_s.reverse_roll.action && _s.parts[1].cursor==1)
        _s.logic_wait=ceil(_s.logic_wait/2);
    // Enhanced: somersault jumps (actions 28/29) play 1.5x slower over the same distance.
    if(ln3_smooth_enabled() && (_s.player_action==28 || _s.player_action==29)) _s.logic_wait=ceil(_s.logic_wait*1.5);
    _g.smooth_period=max(1,_s.logic_wait); // logic runs again on the tick the countdown reaches zero
    ln3_projectile_hits(_s,_g.combat);
    if (_g.level==5) {
        var _event=ln3_void_bolt_move(_s);if (_event!=0) {ln3_special_start(_g,_event);return;}
        ln3_void_bolt_spawn(_s);_event=ln3_void_victory(_s);if (_event!=0) {ln3_special_start(_g,_event);return;}
    }
    if (_s.level_requested) {ln3_level_load(_g,_g.level+1,true);return;}
    ln3_play_items(_g);
    if (_s.player_dead!=0 && _s.death_wait==0) {
        _g.ordinary_death=true;_g.pickup_assist=undefined;
        ln3_special_start(_g,5);_s.death_wait=0;
        return;
    }
    ln3_play_special(_g);
}

function ln3_play_items(_g) {
    if (is_struct(_g.pickup_assist)) {
        if (_g.state.player_dead!=0 || _g.state.player_health<_g.pickup_assist.health) _g.pickup_assist=undefined;
    }
    var _found=ln3_items_update(_g.state,_g.items,_g.item_records,true);
    if (_found>=0) {_g.found_item=_found;_g.pickup_assist=undefined;}
    if (is_struct(_g.pickup_assist) && ++_g.pickup_assist.elapsed>80) _g.pickup_assist=undefined;
}

function ln3_controls_update(_g,_keys) {
    if (_keys.pressed[LNKey.Weapon]) _g.weapon_switch=true;
    if (_keys.pressed[LNKey.F1]) {
        _g.music=!_g.music;
        if (variable_global_exists("ln_music_voice") && global.ln_music_voice>=0) {
            if (_g.music) audio_resume_sound(global.ln_music_voice);else audio_pause_sound(global.ln_music_voice);
        }
    }
    if (_keys.pressed[LNKey.F1+3]) _g.paused=!_g.paused;
    var _s=_g.state;
    for (var _direction=0;_direction<2;_direction++) {
        if (!_keys.pressed[LNKey.F1+1+_direction]) continue;
        var _index=max(3,_s.selected_item);
        repeat(20) {
            _index+=_direction==0?1:-1;if (_index<4 || _index>=24) break;
            if (_s.inventory[_index]>0 && _s.inventory[_index]<128) {_s.selected_item=_index;_s.weapon_notice_timer=0;break;}
        }
    }
}

function ln3_part_choice(_g,_d,_i) {
    var _physical=_d.draw_frames[_i];
    if (_i>=4) {
        var _special=_g.world.special_costume_by_animation?_d.parts[4].animation==138:_g.room_id==_g.world.special_costume_scene;
        if (_i==4 || _special) _physical+=_g.world.costume_offsets[_d.enemy_costume];
    }
    if (!variable_struct_exists(_g.world.part_mapping,string(_physical))) return undefined;
    return variable_struct_get(_g.world.part_mapping,string(_physical))[_d.draw_mirror[_i]?1:0];
}

// Presentation-only registration corrections. Original animation state stays intact.
function ln3_part_registration(_g,_d,_i) {
    if(_i!=4 || _d.enemy_costume>=3 || !variable_struct_exists(_g.world,"actor_registration")) return [0,0];
    var _fixes=_g.world.actor_registration;
    for(var _n=0;_n<array_length(_fixes);_n++) {
        var _f=_fixes[_n];
        if(_i==_f.part && _d.draw_frames[_i]==_f.frame && _d.draw_frames[5]==_f.body_frame)
            return [_f.dx*(_d.draw_mirror[_i]?-1:1),_f.dy];
    }
    return [0,0];
}

function ln3_play_actor_part(_g,_d,_i) {
    if (_d.draw_frames[_i]<0) return;
    var _choice=ln3_part_choice(_g,_d,_i);if (!is_struct(_choice)) return;
    if (!surface_exists(_g.part_surface)) _g.part_surface=surface_create(24,21);
    surface_set_target(_g.part_surface);draw_clear_alpha(c_black,0);
    var _bank=asset_get_index(_g.world.actor_bank),_colour=_g.palette[(_g.special_colours[_i]>=0?_g.special_colours[_i]:_d.draw_colours[_i])&15];
    if ((_d.multicolour&(1<<_i))!=0 && array_length(_choice.multicolour)==3) {
        var _colours=[_g.palette[_d.shared_colour1&15],_colour,_g.palette[_d.shared_colour2&15]];
        for (var _j=0;_j<3;_j++) draw_sprite_ext(_bank,_choice.multicolour[_j],0,0,1,1,0,_colours[_j],1);
    } else draw_sprite_ext(_bank,_choice.hires,0,0,1,1,0,_colour,1);
    gpu_set_blendmode_ext(bm_zero,bm_inv_src_alpha);draw_set_colour(c_white);
    var _offset=ln3_part_registration(_g,_d,_i),_smooth=ln3_smooth_offset(_g,_d,_i);
    var _draw_x=_d.draw_x[_i]+_offset[0]+_smooth[0],_draw_y=_d.draw_y[_i]+_offset[1]+_smooth[1];
    var _foot=_d.parts[_i<4?2:6].y+_smooth[1],_mask=_g.draw_masks[_i];
    // Sample depth at the corrected location, so the outline cannot leave a mask behind.
    if(_offset[0]!=0 || _offset[1]!=0)
        _mask=ln3_mask_bytes(_g.state,_g.mask_shapes,_draw_x,_draw_y,_d.parts[6].y+_smooth[1]);
    else if(_smooth[0]!=0 || _smooth[1]!=0)
        _mask=ln3_mask_bytes(_g.state,_g.mask_shapes,_draw_x,_draw_y,_foot);
    for (var _y=0;_y<21;_y++) {
        var _start=-1;
        for (var _x=0;_x<=24;_x++) {
            var _hidden=_x<24 && (ln_modified_hidden(_draw_x-24+_x*((_d.expand_x&(1<<_i))?2:1),_draw_y-50+_y*((_d.expand_y&(1<<_i))?2:1),_foot,(_mask[_y*3+(_x div 8)]&(128>>(_x&7)))==0) || (_i<4 && _draw_y+_y>=_d.waterline+21));
            if (_hidden && _start<0) _start=_x;
            if (!_hidden && _start>=0) {draw_rectangle(_start,_y,_x,_y+1,false);_start=-1;}
        }
    }
    gpu_set_blendmode(bm_normal);surface_reset_target();
    draw_surface_ext(_g.part_surface,_draw_x-24,_draw_y-50,(_d.expand_x&(1<<_i))?2:1,(_d.expand_y&(1<<_i))?2:1,0,c_white,1);
}

function ln3_play_draw(_g) {
    if(ln_map_draw_transit(_g)) return;
    global.ln_editor.context=false;
    if (is_struct(_g.intro)) {ln3_intro_draw(_g);return;}
    if (ln2_loader_active(_g)) {ln_frontend_draw(_g);return;}
    if (is_struct(_g.ending)) {
        ln3_ending_draw(_g);
        if (_g.ending.finished) {
            draw_sprite_ext(asset_get_index(_g.transition.text_sprite),2,160,84,4,4,0,c_white,1);
            draw_text(420,744,"F11 Choose scene    Home Restart");
        }
        return;
    }
    ln_tool_clear();draw_set_colour(c_white);
    ln_paint_sync(_g);
    var _paint_view=matrix_get(matrix_view),_paint_projection=matrix_get(matrix_projection);
    if(global.ln_paint.active) ln_paint_prepare();
    if (!surface_exists(_g.stage_surface)) _g.stage_surface=surface_create(240,144);
    var _modified=ln_modified_begin(_g);
    surface_set_target(_g.stage_surface);draw_clear(c_black);
    if(_modified) draw_surface(global.ln_editor.cache.surface,0,0);else draw_sprite(asset_get_index(_g.scene_record.sprite),0,0,0);
    if (_g.scenery_frame>=0) {
        if(_modified) ln_modified_delta_start(asset_get_index(_g.scene_record.sprite));
        draw_sprite(asset_get_index(_g.scenery_mechanism?_g.mechanisms.sprite:_g.scenery.sprite),_g.scenery_frame,0,0);
        if(_modified) shader_reset();
    }
    if(_modified) ln_modified_delta_start(asset_get_index(_g.scene_record.sprite));
    ln3_mechanism_draw(_g);
    if(_modified) shader_reset();
    var _hold=ln3_original_hold(_g),_live_display=_g.display,_live_masks=_g.draw_masks;
    if(_hold) {_g.display=_g.display_prev;_g.draw_masks=_g.draw_masks_prev;}
    if ((_g.special_sequence<3 || _g.transition_phase<5) && !ln_enemy_draw_group(_g)) {var _draw=ln3_draw_order(_g,_g.display);for (var _order=0;_order<8;_order++) ln3_play_actor_part(_g,_g.display,_draw[_order]);}
    if(_hold) {_g.display=_live_display;_g.draw_masks=_live_masks;}
    ln3_transition_draw(_g);
    if(global.ln_paint.active) {draw_set_colour(c_white);draw_surface(global.ln_paint.surface,0,0);}
    ln_modified_paint_cover();global.ln_editor.context=false;
    surface_reset_target();
    matrix_set(matrix_view,_paint_view);matrix_set(matrix_projection,_paint_projection);
    draw_surface_ext(_g.stage_surface,160,84,3,3,0,c_white,1);
    ln3_status_draw(_g);
    var _s=_g.state;
    draw_text(160,36,"LAST NINJA 3 - "+string_upper(_g.title));draw_text(1000,36,"Scene "+string(_g.room_id+1));
    draw_text(600,36,"F8 One-hit kills: "+(_g.one_hit_kills?"ON":"OFF"));
    draw_text(160,712,"WASD Move    # + direction Action    Space Weapon    F1 F3 F5 F7 Functions");
    draw_text(160,756,"Numpad 7/9/1/3 Direction    F11 Scenes    Home Restart    1/2/3 Games    P Pause");
    if (_g.paused) draw_text(600,60,"PAUSED");
    if (_g.level_complete) draw_text(540,60,"END OF LAST NINJA 3");
}

// Exhausted lives start a new attempt at this level, after the death wipe.
function ln3_restart_splash(_g) {
    ln3_ending_free(_g);
    var _fresh=new LN3Play(_g.level),_names=variable_struct_get_names(_fresh);
    for(var _i=0;_i<array_length(_names);_i++) {
        var _key=_names[_i];
        if(array_contains(["stage_surface","part_surface","timer","controls","one_hit_kills","music"],_key)) continue;
        variable_struct_set(_g,_key,variable_struct_get(_fresh,_key));
    }
    global.ln_rewind_epoch++;
    ln_frontend_begin(_g);_g.loader.fade=25;
}

// Wind scenes 1 and 4: front-facing ledges used solid records. Keep their
// exact slopes/extents, but give them the same fall descriptor as scenes 5-7.
// Back edges, exits and climbing windows retain their original records.
/// The original enemy walk table pairs the reversed body walks (actions 42, 44) with the
/// costume of the other direction (120, 118), so the black costume misses the pink body.
/// Sequences 119 and 121 are the matching reversed costumes and are otherwise unused.
function ln3_costume_walk_fix(_actions) {
    var _a=_actions.actions;
    if(_a[42][0]==120) _a[42][0]=119;
    if(_a[44][0]==118) _a[44][0]=121;
}

function ln3_exposed_wind_edges(_collision) {
    if(_collision.level!=2) return;
    for(var _i=0;_i<array_length(_collision.rooms);_i++) {
        var _room=_collision.rooms[_i];
        if(_room.id!=0 && _room.id!=3) continue;
        var _indices=_room.id==0?[2,3]:[1,2];
        for(var _j=0;_j<array_length(_indices);_j++) {
            var _record=_room.boundaries[_indices[_j]];
            _record[4]|=32;_record[5]=130;
            _room.boundaries[_indices[_j]]=_record;
        }
    }
}
