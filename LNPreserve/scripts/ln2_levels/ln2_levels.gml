function ln2_environment_action(_g,_address) {
    _g.enemy.custom=true;_g.enemy.depth_y=1;ln2_enemy_special(_g,_address);
}

/// Central Park $9fd8 / $a081: switched hole, five original sink actions,
/// then outgoing slot zero. Other boundary modes remain separate work.
function ln2_hole_boundary(_g) {
    var _p=_g.player;
    if (_g.level!=1 || (_p.boundary_mode&63)!=5 || !(_p.boundary_crossings&128)) return false;
    if (!(_p.boundary_mode&64) && _p.action>=256) return false;
    if (!(_p.boundary_crossings&1) || _g.inventory[18]==0) return false;
    _g.inventory[18]=0;_g.exit_locked=true;_g.hole_steps=5;
    ln2_player_special(_g,((_p.facing+2)&4)?$cd02:$ccf9);
    return true;
}

function ln2_hole_tick(_g,_tick) {
    var _p=_g.player;
    ln2_player_update(_p,_g.data,0,_tick);
    ln2_enemy_decide(_g);ln2_enemy_action(_g);
    ln2_combat_event(_g,_p.action_state,false);_p.action_state=0;
    ln2_combat_event(_g,_g.enemy.action_state,true);_g.enemy.action_state=0;
    ln2_projectile_motion(_g,_p.tick);ln2_projectile_present(_g);ln2_enemy_remember(_g);
    if (_p.action>=256) return;
    _g.hole_steps--;
    if (_g.hole_steps>0) {
        ln2_player_special(_g,((_p.facing+2)&4)?$cd02:$ccf9);return;
    }
    _g.exit_locked=false;
    ln2_play_travel(_g,_g.scene_record.entries[0]);
}

/// Original per-entrance vehicle modes, scenery actors, and inventory gates.
function ln2_entry_hook(_g) {
    var _p=_g.player,_id=_g.room_id;_p.vehicle=0;
    _g.special_mode=0;_g.special_flag=0;_g.exit_locked=false;_p.height_fixed=0;
    if (variable_struct_exists(_g.world.entry_modes,string(_g.last_entry))) {
        var _mode=variable_struct_get(_g.world.entry_modes,string(_g.last_entry));
        _p.vehicle=_mode.mode;_p.vehicle_limit=_mode.limit;
    }
    switch (_g.level) {
        case 1:
            if (_g.last_entry==23) { _p.depth_y=152;_p.height_fixed=255; }
            if (_id==13 && _g.inventory[17]!=0) { ln2_item_open_line(_g);return; }
            if (_id==10) { ln2_environment_action(_g,$cd0b);_g.enemy.facing=3;_g.enemy.heading=3; }
            if (_id==14) { ln2_environment_action(_g,$cd57);_g.special_mode=1; }
            if (_id==16 && _g.inventory[19]==0) ln2_environment_action(_g,$cd72);
            if (_id==17 && _g.inventory[19]!=0) { ln2_environment_action(_g,$cd79);_g.special_mode=8; }
            if (_id==15) ln2_environment_action(_g,$cd90);
            return;
        case 2:
            if (_id==3 && _g.inventory[17]!=0) ln2_item_open_line(_g);
            if (_id==5) { _g.special_mode=4;ln2_environment_action(_g,$c7b6); }
            if (_id==7) { _g.special_mode=3;ln2_environment_action(_g,$c7d5); }
            return;
        case 3:
            if (_id==4) _g.special_mode=5;
            if (_id==10) { ln2_environment_action(_g,$b3c5);_g.special_mode=6; }
            if (_id==14) { ln2_environment_action(_g,$b3ef);_g.special_mode=7; }
            return;
        case 4:
            if (_id==3) _g.special_mode=9;
            if (_id==13) { ln2_environment_action(_g,_g.inventory[18]==0?$c739:$c740);_g.special_mode=11; }
            return;
        case 5:
            if (_id==5 && _g.inventory[17]!=0) { ln2_item_open_line(_g);return; }
            if (_id==9) { ln2_environment_action(_g,$c527);if (_g.inventory[20]!=0) ln2_item_open_line(_g); }
            if (_id==14 && _g.inventory[21]==0) { ln2_environment_action(_g,$c546);_g.special_mode=10; }
            if (_id==10) ln2_environment_action(_g,$c602);
            return;
        case 6:
            if (_g.last_entry==0) {
                ln2_environment_action(_g,$ca1b);_g.special_mode=12;_p.depth_y=192;_p.height_fixed=255;
                _g.special_flag=255;_g.exit_locked=true;_p.countdown=255;_p.action=(_p.action&255)|65280;return;
            }
            if (_id==12) ln2_environment_action(_g,_g.inventory[21]==0?$cb26:$cb1f);
            return;
    }
}

/// Mansion's original helicopter attachment and release ($9b9a-$9c30).
function ln2_level_effect_tick(_g,_joy) {
    var _p=_g.player,_e=_g.enemy;
    if (_g.level==2 && _e.custom && _e.frame==114 && (_e.x>240 || _e.action<256)) {
        _e.action=0;_e.x=0;_e.y=0;_e.display_frame=255;
    }
    switch (_g.special_mode) {
        case 0:return;
        case 1:
            if (_e.x>=240) { _g.special_mode=0;_e.action&=255; }return;
        case 2:
            if (_e.x<4) { _g.special_mode=0;_e.action&=255;_e.display_frame=255; }return;
        case 3:case 4:
            if (_e.action<256) {
                _p.boundary_crossings&=1;
                if (_p.boundary_crossings) ln2_enemy_special(_g,_g.special_mode==3?$c7dc:$c7bd);
            }return;
        case 5:
            if (_e.action<256 && _p.x>=48 && _p.x<128) ln2_environment_action(_g,$b377);
            else if (_e.x<4) { _e.x=0;_e.y=0;_e.depth_y=0;_e.action&=255; }
            if (((((_e.x+6)&255)-_p.x)&255)>=26) return;
            if (_e.y>=88 && (_p.combat_state&252)!=12) ln2_damage(_g,2,false);
            return;
        case 6:
            if (_e.x<4) { _e.x=_g.data.sewer_actor_reset[0];_e.y=_g.data.sewer_actor_reset[1]; }
            if (((((_e.x+6)&255)-_p.x)&255)<26 && ((_e.y-72-_p.y)&255)<16 && (_p.combat_state&252)!=12)
                ln2_damage(_g,2,false);
            return;
        case 7:
            var _q=_g.projectile;
            if (_q.kind==7 && _q.phase<8 && _q.y<122 && ((_q.x-_e.x)&255)<32) {
                ln2_enemy_special(_g,$b444);_g.special_mode=0;return;
            }
            if (_p.x>=_e.x && ((_p.y-22)&255)<_e.y && _g.pending_entry<0) { _p.input_lock=255;_g.exit_locked=true; }
            return;
        case 8:
            // A room transition can reach this hook before the first spawn action.
            if (_e.action==$cd79) return;
            if (_e.x<88) { _g.special_mode=0;_e.action&=255; }return;
        case 9:
            if (_e.x<8) { _e.x=172;_e.y=90;_e.depth_y=90;_g.world_clock=_p.tick;_e.action&=255; }
            var _ticks=(_p.tick-_g.world_clock)&255;
            if (_ticks>=2) {
                _g.world_clock=_p.tick;
                repeat(_ticks) {
                    if (_e.x<4) { _e.x=172;_e.y=90;_e.depth_y=90;_g.world_clock=_p.tick;_e.action&=255;break; }
                    _e.x-=4;_e.y=(_e.y+1)&255;_e.depth_y=_e.y;
                }
                _e.custom=true;_e.display_frame=99;_e.mirror=false;
            }
            if ((_p.combat_state&252)==12 || _p.x+48>255) return;
            var _dx=(_p.x+48-_e.x)&255;
            if (_dx>=80) return;
            var _dy=(_p.y+12-_e.y)&255,_index=_dx>>2;
            if (_dy>=_g.data.basement_hazard_y_min[_index] && _dy<_g.data.basement_hazard_y_max[_index]) _p.input_lock=255;
            return;
        case 10:
            if (_g.pending_entry<0 && _g.special_flag!=0) {
                _p.x=(_e.x+4)&255;_p.y=(_e.y+12)&255;ln2_player_render(_p,0);
            }return;
        case 11:
            if (_g.inventory[18]!=0 || _e.action>=256) return;
            if (_g.inventory[20]==0) {
                if (_p.y>=117 && _p.x>=147) { ln2_enemy_special(_g,$c747);_g.inventory[20]=1; }
            } else if (_p.x<147) { ln2_enemy_special(_g,$c750);_g.inventory[20]=0; }
            else if (_g.inventory[20]==1 && _p.x>=168) { ln2_enemy_special(_g,$c759);_g.inventory[20]=2; }
            return;
    }
    if (_g.special_mode!=12) return;
    if (_g.special_flag==0) return;
    if (_g.special_flag<128) {
        if (_p.x>=22 && _p.x<49 && _p.y+8>=61) {
            _p.y=61;_p.depth_y=192;ln2_player_special(_g,$c00e);
            _g.special_mode=0;_g.special_flag=0;_g.exit_locked=false;return;
        }
        _p.y=(_p.y+8)&255;_p.depth_y=_p.y;
        if (_p.y>=96) { _p.input_lock=255;_g.special_mode=0;_p.action&=255; }
    } else {
        if (_e.action<256) { _g.special_mode=0;_p.action&=255;return; }
        if (_e.x<20) return;
        _p.x=_e.x-20;
        if (_joy&18) _g.special_flag=127;
        _p.y=(_e.y-40)&255;
    }
    _p.frame=83;ln2_player_render(_p,64);_p.countdown=255;
}

/// Source forced exits address an outgoing slot within the current scene.
function ln2_force_exit(_g,_slot) {
    if (_g.exit_locked || _slot>=array_length(_g.scene_record.entries)) return;
    _g.pending_entry=_g.scene_record.entries[_slot];
}

/// The Mansion drop runs its own original two-tick fall loop, keeping the
/// scenery actor moving while ordinary controls and combat are suspended.
function ln2_fall_begin(_g,_distance,_depth) {
    var _p=_g.player;_p.depth_y=_depth;_p.height_fixed=255;_g.fall_exit_slot=-1;
    _g.fall_remaining=_distance;_g.fall_clock=_p.tick;_g.exit_locked=true;
}

function ln2_fall_tick(_g,_tick) {
    var _p=_g.player;_p.tick=_tick;var _elapsed=(_tick-_g.fall_clock)&255;
    if (_elapsed>=2) {
        var _step=(_elapsed<<2)&255;_p.y=(_p.y+_step)&255;_g.fall_clock=_tick;
        _p.display_frame=((_p.facing+2)&4)?83:78;_p.mirror=(_p.facing&2)!=0;
        _g.fall_remaining-=_step;
        if (_g.fall_remaining<0 || _p.y>=189) {
            _g.fall_remaining=-1;
            if (variable_struct_exists(_g,"fall_exit_slot") && _g.fall_exit_slot>=0) {
                var _slot=_g.fall_exit_slot;_g.fall_exit_slot=-1;_g.exit_locked=false;
                _p.input_lock=0;_p.boundary_crossings=0;
                ln2_play_travel(_g,_g.scene_record.entries[_slot]);return;
            }
            ln2_fall_death_begin(_g);return;
        }
    }
    ln2_enemy_action(_g);
}

/// Original numbered interior exits: modes 1..4 select outgoing slots 0..3.
function ln2_boundary_exit(_g) {
    var _p=_g.player,_mode=_p.boundary_mode&63,_slot=-1;
    if (!(_p.boundary_crossings&128)) return false;
    if (_g.exit_locked && !(_g.level==6 && _mode==54)) return false;
    if (!(_p.boundary_mode&64) && _p.action>=256) return false;
    if (_mode>=1 && _mode<=4) _slot=_mode-1;
    else if (_g.level==1 && _mode==6 && (_p.boundary_crossings&1)) _slot=1;
    else if ((_g.level==2 && _mode==38 && _g.inventory[19]!=0) ||
             (_g.level==3 && _mode==41 && _g.inventory[20]!=0)) {
        if (!(_p.boundary_crossings&1)) return false;
        _g.route_descent={elapsed:0,slot:_g.level==2?2:1,unarmed:_g.level==3};
        _p.depth_y=0;_g.exit_locked=true;return true;
    } else if (_g.level==4 && _mode==48) {
        if (_g.inventory[17]==0) {_p.input_lock=255;return false;}
        _slot=0;
    } else if (_g.level==6 && _mode==54) {
        ln2_fall_begin(_g,46,48);_g.fall_exit_slot=0;return true;
    }
    if (_slot<0 || _slot>=array_length(_g.scene_record.entries)) return false;
    return ln2_play_travel(_g,_g.scene_record.entries[_slot]);
}

/// Original Street/Sewers exit approach: sixteen two-pixel downward steps.
function ln2_route_descent_tick(_g,_tick) {
    var _p=_g.player,_route=_g.route_descent;
    _p.tick=_tick;_p.last_tick=_tick;_route.elapsed++;
    _p.y=(_p.y+2)&255;
    ln2_enemy_decide(_g);ln2_enemy_action(_g);
    if (_route.elapsed<16) return;
    var _slot=_route.slot;
    if (_route.unarmed) _p.weapon=0;
    _g.route_descent=undefined;_g.exit_locked=false;
    ln2_play_travel(_g,_g.scene_record.entries[_slot]);
}

function ln2_curtain_checks() {
    var _g=undefined,_p=undefined;
    for (var _flags=0;_flags<4;_flags++) for (var _busy=0;_busy<2;_busy++)
    for (var _interrupt=0;_interrupt<2;_interrupt++) for (var _lock=0;_lock<2;_lock++) {
        _g=new LN2Play(1);_p=_g.player;
        _p.boundary_crossings=(_flags&1)|((_flags&2)?128:0);
        _p.boundary_mode=2|(_interrupt?64:0);_p.action=_busy?$c300:0;_g.exit_locked=_lock;
        var _expected=(_flags&2)!=0 && (!_busy || _interrupt) && !_lock;
        ln_check(ln2_boundary_exit(_g)==_expected,"curtain crossing obeys original new-crossing/action/exit locks");
        ln_check(_g.room_id==(_expected?2:1),"curtain uses original scene 2 entrance");
    }
    _g=new LN2Play(1);_p=_g.player;
    _g.enemy.active=0;_p.x=70;_p.y=49;_p.depth_y=49;_p.action=0;_p.input_lock=0;
    _p.facing=1;_p.heading=1;_p.turn_lock=0;_p.fraction_x=0;_p.fraction_y=0;
    var _joy=0;
    for (var _i=0;_i<16;_i++) if (_g.data.directions[_i]==1) {_joy=_i;break;}
    repeat(24) {if (_g.room_id!=1) break;ln2_play_tick(_g,_joy);}
    ln_check(_g.room_id==2 && _g.last_entry==3,"walking through actual curtain geometry reaches scene 2 without fire");
    ln_check(_p.x==_g.world.tables.entry_x[3] && _p.y==_g.world.tables.entry_y[3],"curtain uses recovered arrival coordinates");
    _p.x=0;_p.y=133;ln2_play_exit(_g);
    ln_check(_g.room_id==1 && _g.last_entry==4,"ordinary route returns from scene 2 to scene 1");
    var _arrival=_g.room_id;ln2_play_tick(_g,0);
    ln_check(_g.room_id==_arrival,"return does not replay a stale curtain crossing");
    show_debug_message("LN2_CURTAIN_PASS: 32 original trigger combinations, real walking approach, arrival and return");
}

/// Central Park event 16 ($a9ba): three jittering bees, pursuit and contact damage.
function ln2_swarm_offsets(_g) {
    if (!variable_struct_exists(_g.world_state,"swarm"))
        _g.world_state.swarm={x:[56,56,56],y:[-5,-5,-5]};
    return _g.world_state.swarm;
}

function ln2_swarm_tick(_g) {
    var _s=ln2_swarm_offsets(_g),_e=_g.enemy,_p=_g.player;
    for(var _i=2;_i>=0;_i--) {
        var _v;
        do {_v=(_s.x[_i]-50+((ln2_enemy_random(_g)&1)?1:-1))&255;} until(_v<8);
        _s.x[_i]=50+_v;
        do {_v=(_s.y[_i]+5+((ln2_enemy_random(_g)&1)?1:-1))&255;} until(_v<8);
        _s.y[_i]=_v-5;
    }
    _e.x=(_e.x+2*sign(_p.x-_e.x))&255;
    _e.y=(_e.y+2*sign(_p.y-_e.y))&255;
    if (abs(_e.x-_p.x)<8 && abs(_e.y-_p.y)<10) ln2_damage(_g,1,false);
}

function ln2_swarm_draw(_g) {
    var _s=ln2_swarm_offsets(_g),_e=_g.enemy;
    // Source part offsets include the compositor's 48-pixel X origin and
    // the VIC playfield border offsets (24,50). Keep the ordinary depth mask.
    for(var _i=2;_i>=0;_i--)
        ln_draw_masked_actor(spr_ln2_bee_parts,_i,_e.x+_s.x[_i]-72,_e.y+_s.y[_i]-50,
            1,1,_g.mask,0,0,240,144,max(0.001,(_e.depth_y-0.25)/255));
}

function ln2_reported_encounter_checks() {
    var _g=new LN2Play(1),_cases=ln3_data_read("play/ln2/swarm_checks.json");
    ln2_play_enter(_g,15);
    if (!_g.enemy.custom) throw "Bees missing from scene 15 entry";
    for(var _i=0;_i<array_length(_cases);_i++) {
        var _c=_cases[_i];
        _g.player.x=_c.xy[0];_g.player.y=_c.xy[1];_g.enemy.x=_c.xy[2];_g.enemy.y=_c.xy[3];
        _g.player_health=44;_g.world_state.swarm={x:_c.x,y:_c.y};
        _g.random_queue=_c.random;_g.random_head=0;
        ln2_combat_event(_g,16,true);
        if (_g.enemy.x!=_c.result_xy[0] || _g.enemy.y!=_c.result_xy[1] ||
            _g.player_health!=44-_c.damage || _g.random_head!=array_length(_c.random))
            throw "Bee source movement/damage/random mismatch "+string(_i);
        for(var _j=0;_j<3;_j++) if (_g.world_state.swarm.x[_j]!=_c.result_x[_j] ||
            _g.world_state.swarm.y[_j]!=_c.result_y[_j]) throw "Bee source part mismatch "+string(_i);
    }
    for(var _l=1;_l<=7;_l++) {
        var _icons=asset_get_index("spr_ln2_level"+string(_l)+"_status_icons");
        if (_icons<0 || sprite_get_number(_icons)!=17) throw "Missing level HUD icons";
    }
    if (sprite_get_number(spr_ln2_park_boats)!=6 || sprite_get_number(spr_ln2_bee_parts)!=3)
        throw "Missing park encounter art";
    _g.random_queue=[];_g.random_head=0;
    for(var _room=14;_room<=17;_room++) {
        _g.player.x=120;_g.player.y=120;_g.player.depth_y=120;
        _g.inventory[19]=(_room==17)?255:0;
        ln2_play_enter(_g,_room);
        for(var _t=0;_t<120;_t++) {
            _g.player.tick=(_g.player.tick+1)&255;ln2_enemy_action(_g);
            if (_g.enemy.action_state>0) {ln2_combat_event(_g,_g.enemy.action_state,true);_g.enemy.action_state=0;}
        }
        ln2_play_draw(_g);
        surface_save(_g.stage_surface,"ln2-encounter-"+string(_room)+".png");
    }
    show_debug_message("LN2_REPORTED_ENCOUNTERS_PASS: 256 original bee cases; seven icon banks; boat art");
}

/// Original $b626: scenery knives reuse the enemy projectile slot, without melee.
function ln2_juggler_throw(_g,_kind) {
    var _q=_g.projectiles[1];if (_q.kind!=0) return;
    var _state=ln2_projectile_state(_g,_g.player.tick);
    ln2_projectile_spawn_rule(_state,_g.projectile_data,1);
    if (_q.kind!=0) _q.kind=_kind;
    _g.enemy.projectile_active=_q.kind;
}

/// Original $a25f: boat footprint, crossing parity and the scene 17 lip.
function ln2_water_boat_supported(_g) {
    var _p=_g.player,_e=_g.enemy;
    if (!(_p.boundary_crossings&1)) {_p.boundary_crossings=0;return true;}
    var _dx=(_g.room_id==17?_e.x+12-_p.x:_p.x+48-_e.x)&255;
    if (_dx<56) {
        var _i=_dx>>2,_dy=(_p.y-_e.y)&255;
        if (_dy>=_g.boat_support.min_y[_i]) {
            if (_dy<_g.boat_support.max_y[_i]) return true;
            if (((_dy-8)&255)<_g.boat_support.max_y[_i] && _g.room_id==17) _p.y=(_p.y+8)&255;
            return false;
        }
    }
    _g.world_state.water_splash_flag=32;return false;
}

function ln2_drowning_begin(_g,_offset,_entry) {
    var _p=_g.player;
    _g.world_state.drowning={phase:0,water:true,saved_y:_p.y,saved_facing:_p.facing};
    _g.player_health=0;
    _p.boundary_crossings=0;_g.exit_locked=true;
    _p.y=(_p.y-_offset)&255;
    var _side=((_p.facing+2)&4)?3:0;
    ln2_player_special(_g,_g.water_data.entries[_side+_entry]);
}

function ln2_drowning_tick(_g,_tick) {
    var _p=_g.player,_d=_g.world_state.drowning;
    _p.tick=_tick;_p.last_tick=_tick;
    ln2_player_action(_p,_g.data,1);
    ln2_enemy_decide(_g);ln2_enemy_action(_g);
    ln2_projectile_present(_g);
    if (_p.action>=256) return;
    if (_d.phase==2 && --_d.steps>0) {
        ln2_player_special(_g,((_p.facing+2)&4)?$cd02:$ccf9);return;
    }
    if (_d.phase==1 || _d.phase==4 ||
        (_d.phase==2 && variable_struct_exists(_d,"water") && _d.water)) {
        // Water finishes with submersion/splash, never the land-death poses.
        _d.phase=4;_g.player_health=0;_p.display_frame=255;_p.action_state=0;
        _p.input_lock=255;_p.facing=_d.saved_facing;
        if (_g.status.health[0]>0) return;
        _g.world_state.drowning=undefined;_g.respawn_wait=20;return;
    }
    if (_d.phase==2) {
        _d.phase=3;_p.facing=_d.saved_facing;_p.depth_y=_p.y;_p.height_fixed=0;
        _g.player_health=0;_p.input_lock=255;_p.action_state=0;
        _p.combat_state=36+(_p.facing>>1);
        ln2_player_special(_g,_g.data.enemy_falls[(_p.facing&4)?1:0]);return;
    }
    if (_d.phase==3) {
        // Keep the fallen body at its landing point while the health spiral empties.
        _p.action_state=0;
        if (_g.status.health[0]>0) return;
        _g.world_state.drowning=undefined;_g.respawn_wait=20;return;
    }
    if (_d.phase==0) {
        _d.phase=1;_p.facing=(_p.facing&4)>>1;
        ln2_player_special(_g,_g.water_data.splash);return;
    }
    _p.facing=_d.saved_facing;_p.y=_d.saved_y;_p.action_state=0;
    _p.display_frame=255;_g.world_state.drowning=undefined;_g.respawn_wait=20;
}

function ln2_hazard_boundary(_g) {
    if (_g.level==2) return ln2_street_traffic_boundary(_g);
    if (_g.level!=1) return false;
    if (ln2_park_traversal_boundary(_g)) return true;
    var _p=_g.player,_mode=_p.boundary_mode&63;
    if (!(_p.boundary_crossings&128) || (!(_p.boundary_mode&64) && _p.action>=256)) return false;
    if (_g.level==1 && array_contains([28,32,33,34],_mode)) {
        ln2_juggler_throw(_g,_mode==28?2:_mode-29);_p.boundary_crossings=0;return false;
    }
    if (_mode==30 || _mode==31) {
        if (_g.level!=1) return false;
        if (ln2_water_boat_supported(_g)) return false;
        _mode=_mode==30?11:16;
    }
    // Island's eastern edge uses the original fixed-depth eight-step sink.
    if (_mode==43) {
        _g.world_state.drowning={phase:2,water:true,steps:8,saved_y:_p.y,saved_facing:_p.facing};
        _g.player_health=0;
        _p.depth_y=158;_p.height_fixed=255;_g.exit_locked=true;_p.boundary_crossings=0;
        ln2_player_special(_g,((_p.facing+2)&4)?$cd02:$ccf9);return true;
    }
    if (_mode==11 || _mode==16) {
        ln2_drowning_begin(_g,_mode==11?14:7,_mode==11?0:1);return true;
    }
    return false;
}

function ln2_water_knife_checks() {
    var _v=ln3_data_read("play/ln2/water_knife_checks.json"),_g=new LN2Play(1),_p=_g.player;
    for(var _i=0;_i<array_length(_v.boat);_i++) {
        var _c=_v.boat[_i];_g.room_id=_c.room;_p.x=_c.xy[0];_p.y=_c.xy[1];
        _g.enemy.x=_c.xy[2];_g.enemy.y=_c.xy[3];_p.boundary_crossings=_c.flags;
        _g.world_state.water_splash_flag=0;
        ln_check(ln2_water_boat_supported(_g)==_c.supported && _p.y==_c.y &&
            _p.boundary_crossings==_c.result_flags && _g.world_state.water_splash_flag==_c.splash_flag,
            "boat footprint matches original "+string(_i));
    }
    for(var _i=0;_i<array_length(_v.knives);_i++) {
        var _c=_v.knives[_i],_q=_g.projectiles[1];
        _g.enemy.x=_c.x;_g.enemy.y=56;_g.enemy.facing=_c.facing;
        _q.kind=_c.before[0];_q.facing=_c.before[1];_q.x=_c.before[2];_q.y=_c.before[3];_q.life=_c.before[4];_q.buffer=_c.before[5];
        ln2_juggler_throw(_g,_c.kind);
        ln_check(_q.kind==_c.after[0] && _q.facing==_c.after[1] && _q.x==_c.after[2] &&
            _q.y==_c.after[3] && _q.life==_c.after[4] && _q.buffer==_c.after[5],"knife spawn matches original "+string(_i));
    }
    _g=new LN2Play(1);_p=_g.player;ln2_play_enter(_g,10);
    for(var _i=0;_i<4;_i++) {
        _g.projectiles[1].kind=0;_p.boundary_mode=[92,96,97,98][_i];_p.boundary_crossings=129;
        ln2_hazard_boundary(_g);ln_check(_g.projectiles[1].kind==_i+2,"juggler approach launches knife");
    }
    _g.enemy.x=112;_g.enemy.y=56;_g.enemy.facing=3;_g.projectiles[1].kind=0;
    _g.enemy.display_frame=100;_g.enemy.mirror=true;ln2_juggler_throw(_g,2);
    ln2_projectile_present(_g);ln2_play_draw(_g);surface_save(_g.stage_surface,"ln2-juggler-knives.png");
    _g=new LN2Play(1);_p=_g.player;ln2_play_enter(_g,14);
    _g.enemy.x=240;_g.enemy.y=40;_p.x=100;_p.y=112;_p.action=0;_p.boundary_crossings=0;
    ln2_player_boundary(_p,_g.data,100,110,100,112);
    ln_check((_p.boundary_mode&63)==30,"real shore geometry reports water");
    ln_check(ln2_hazard_boundary(_g),"walking off shore starts drowning");
    var _x=_p.x,_life=_g.lives_left,_seen=false,_ticks=0;
    while(is_struct(_g.world_state.drowning) && _ticks<200) {
        ln2_play_tick(_g,31);_ticks++;
        ln_check(_p.x==_x,"drowning prevents movement/fire input");
        ln_check(_p.display_frame!=44 && _p.display_frame!=45 && _p.display_frame!=46,"river never plays land-death poses");
        if (_p.display_frame>=88 && _p.display_frame<=98) {
            if (!_seen) {ln2_play_draw(_g);surface_save(_g.stage_surface,"ln2-water-splash.png");}
            _seen=true;
        }
    }
    ln_check(_seen && _ticks<200 && _g.respawn_wait==20,"original splash completes before respawn");
    ln_check(_p.display_frame==255 && _g.status.health[0]==0,"river splash ends submerged with empty health");
    repeat(20) ln2_play_tick(_g,0);ln2_test_finish_life_transition(_g);
    ln_check(_g.lives_left==_life-1 && _g.player_health==44,"drowning loses exactly one life and restores health");
    for(var _mode_index=0;_mode_index<5;_mode_index++) {
        _g=new LN2Play(1);_p=_g.player;ln2_play_enter(_g,16);
        _p.action=0;_p.boundary_mode=[11,16,30,31,43][_mode_index];_p.boundary_crossings=129;
        _g.enemy.x=250;_g.enemy.y=0;_p.x=100;_p.y=100;
        ln_check(ln2_hazard_boundary(_g),"every Central Park water mode starts death when unsupported");
        var _weapon=_p.selected_weapon,_item=_g.selected_item;
        ln2_controls_update(_g,0,0);
        ln_check(_p.selected_weapon==_weapon && _g.selected_item==_item,"water death locks selection inputs");
        var _wait=0;while(is_struct(_g.world_state.drowning) && _wait++<200) {
            ln2_play_tick(_g,31);
            ln_check(_p.display_frame!=44 && _p.display_frame!=45 && _p.display_frame!=46,"all water modes exclude land-death poses");
        }
        ln_check(_g.respawn_wait==20,"water and island sink both finish");
    }
    show_debug_message("LN2_WATER_KNIFE_PASS: 512 original boat cases, 160 knife spawns, shore/splash/respawn integration");
}

/// Central Park $a0ac/$a0e6: fence ascent/descent runs a blocking source action sequence.
function ln2_fence_begin(_g,_descending) {
    var _p=_g.player,_actions=_descending?[ $c3e4,$c3f6,$c3f6,$c40b]:[ $c3ab,$c3b0,$c3b0,$c3c5];
    _g.world_state.fence={actions:_actions,index:0,descending:_descending,exit_locked:_g.exit_locked};
    _g.exit_locked=true;
    if (_descending) {_p.depth_y=_p.y;_p.height_fixed=0;}
    ln2_player_special(_g,_actions[0]);
}

function ln2_fence_tick(_g,_tick) {
    var _p=_g.player,_f=_g.world_state.fence;
    _p.tick=_tick;_p.last_tick=_tick;ln2_player_action(_p,_g.data,1);
    ln2_enemy_decide(_g);ln2_enemy_action(_g);ln2_projectile_present(_g);
    if (_p.action>=256) return;
    _f.index++;
    if (_f.index<array_length(_f.actions)) {ln2_player_special(_g,_f.actions[_f.index]);return;}
    if (!_f.descending) {_p.depth_y=152;_p.height_fixed=255;}
    _p.boundary_crossings=0;_p.action_state=0;_p.walk_clock=0;
    _g.exit_locked=_f.exit_locked;_g.world_state.fence=undefined;
}

function ln2_park_traversal_boundary(_g) {
    if (_g.level!=1 || (_g.room_id!=11 && _g.room_id!=12)) return false;
    var _p=_g.player,_mode=_p.boundary_mode&63;
    if (!(_p.boundary_crossings&128) || (!(_p.boundary_mode&64) && _p.action>=256)) return false;
    if (_g.room_id==11 && (_mode==10 || _mode==9)) {
        if (_p.facing==7 && _p.weapon==0) {ln2_fence_begin(_g,_mode==9);return true;}
        if (_mode==10) {_p.boundary_crossings=0;return false;}
        _mode=8;
    }
    if (!array_contains([7,8,14,15,20],_mode)) return false;
    if (_mode>=14 && !(_p.boundary_crossings&1)) {_p.boundary_crossings=0;return false;}
    if (_mode==8) _p.depth_y=_p.y;
    if (_mode==15 || _mode==20) {_p.depth_y=_mode==15?4:12;_p.height_fixed=255;}
    _g.world_state.drowning={phase:2,steps:_mode>=14?7:8,saved_y:_p.y,saved_facing:_p.facing,landing_death:_g.room_id==12};
    _g.exit_locked=true;_p.boundary_crossings=0;
    ln2_player_special(_g,((_p.facing+2)&4)?$cd02:$ccf9);return true;
}

function ln2_blocking_sequence(_g) {
    if (!variable_struct_exists(_g,"world_state")) return false;
    return (variable_struct_exists(_g.world_state,"drowning") && is_struct(_g.world_state.drowning)) ||
        (variable_struct_exists(_g.world_state,"fence") && is_struct(_g.world_state.fence));
}

function ln2_fence_gap_boat_checks() {
    var _cases=ln3_data_read("play/ln2/fence_gap_checks.json"),_g=new LN2Play(1),_p=_g.player;
    for(var _i=0;_i<array_length(_cases);_i++) {
        var _c=_cases[_i];_g.room_id=_c.mode>=14 && _c.mode!=138?12:11;
        _p.boundary_mode=_c.mode;_p.boundary_crossings=_c.flags;_p.facing=_c.facing;_p.weapon=_c.weapon;
        _p.action=_c.busy?256:0;_p.y=120;_p.depth_y=100;_p.height_fixed=0;
        _g.world_state.fence=undefined;_g.world_state.drowning=undefined;_g.exit_locked=false;
        var _handled=ln2_park_traversal_boundary(_g);
        ln_check(_handled==(array_length(_c.calls)>0 || _c.steps>0),"original fence/gap trigger "+string(_i));
        if (_c.steps>0) ln_check(_g.world_state.drowning.steps==_c.steps && _p.depth_y==_c.depth && _p.height_fixed==_c.fixed,"original gap depth and fall count");
        if (array_length(_c.calls)>0) ln_check(json_stringify(_g.world_state.fence.actions)==json_stringify(_c.calls),"original climb action sequence");
    }
    _g=new LN2Play(1);_p=_g.player;ln2_play_enter(_g,11);
    _p.x=110;_p.y=117;_p.depth_y=117;_p.weapon=0;_p.facing=7;_p.action=0;_p.boundary_crossings=0;
    ln2_player_boundary(_p,_g.data,110,117,110,115);
    ln_check(_p.boundary_mode==138 && ln2_hazard_boundary(_g),"actual fence line starts climb");
    var _start_y=_p.y,_ticks=0;
    while(is_struct(_g.world_state.fence) && _ticks++<250) {
        ln2_play_tick(_g,31);
        if (_ticks==24) {ln2_play_draw(_g);surface_save(_g.stage_surface,"ln2-scene11-climb.png");}
    }
    ln_check(_ticks<250 && _p.y<_start_y && _p.depth_y==152 && _p.height_fixed==255,"climb reaches raised walkway");
    _p.boundary_mode=9;_p.boundary_crossings=129;_p.action=0;_p.facing=7;
    ln_check(ln2_hazard_boundary(_g),"fence descent starts");
    _ticks=0;while(is_struct(_g.world_state.fence) && _ticks++<250) ln2_play_tick(_g,0);
    ln_check(_ticks<250 && _p.height_fixed==0,"descent restores ordinary ground depth");
    for(var _mode_index=0;_mode_index<3;_mode_index++) {
        _g=new LN2Play(1);_p=_g.player;ln2_play_enter(_g,12);
        _p.x=90;_p.y=80;_p.action=0;_p.boundary_mode=[14,15,20][_mode_index];_p.boundary_crossings=129;
        var _life=_g.lives_left;ln_check(ln2_hazard_boundary(_g),"gap causes drop");
        _ticks=0;while(is_struct(_g.world_state.drowning) && _ticks++<240) {
            ln2_play_tick(_g,31);if(_ticks==8) {ln2_play_draw(_g);surface_save(_g.stage_surface,"ln2-scene12-drop-"+string(_mode_index)+".png");}
        }
        repeat(20) ln2_play_tick(_g,0);ln2_test_finish_life_transition(_g);
        ln_check(_g.lives_left==_life-1,"gap costs one life");
        _p.action=0;_p.boundary_mode=[14,15,20][_mode_index];_p.boundary_crossings=130;
        _g.room_id=12;ln_check(!ln2_hazard_boundary(_g),"jump across both gap edges remains safe");
    }
    _g=new LN2Play(1);_p=_g.player;ln2_play_enter(_g,16);
    var _item=undefined;for(var _i=0;_i<array_length(_g.world.items);_i++) if(_g.world.items[_i].id==19) _item=_g.world.items[_i];
    _p.weapon=2;_p.selected_weapon=2;_p.facing=_item.facing;_p.x=_item.x_min;_p.y=_item.y_min;
    ln2_item_interact(_g,_item.action);ln_check(_g.inventory[19]!=0,"staff jab releases boat");
    _g=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));_p=_g.player;
    ln_check(_g.inventory[19]!=0,"boat release survives save/load");
    var _legacy=ln_save_capture(_g);
    variable_struct_remove(_legacy.state.data.actions,string($c3ab));
    variable_struct_remove(_legacy.state.data.actions,string($c3e4));
    _g=ln_save_restore(json_parse(json_stringify(_legacy)));_p=_g.player;
    ln_check(variable_struct_exists(_g.data.actions,string($c3ab)) && variable_struct_exists(_g.data.actions,string($c3e4)),"older saves acquire missing climb actions");

    var _entry=-1;for(var _i=0;_i<array_length(_g.world.tables.exit_destinations);_i++) if(_g.world.tables.exit_destinations[_i]==17) {_entry=_i;break;}
    ln2_play_travel(_g,_entry);ln2_level_effect_tick(_g,0);
    ln_check(_g.enemy.action==$cd79 && _g.special_mode==8,"arrival frame must not cancel boat spawn");
    _legacy=ln_save_capture(_g);_legacy.state.special_mode=0;_legacy.state.enemy.action=$cd79&255;
    _legacy.state.enemy.display_frame=255;
    _g=ln_save_restore(json_parse(json_stringify(_legacy)));_p=_g.player;
    ln_check(_g.special_mode==8 && _g.enemy.action==$cd79,"older cancelled-boat save resumes arrival");

    _ticks=0;while(_g.special_mode==8 && _ticks++<400) {
        _p.tick=(_p.tick+1)&255;ln2_enemy_action(_g);ln2_combat_event(_g,_g.enemy.action_state,true);_g.enemy.action_state=0;ln2_level_effect_tick(_g,0);
    }
    ln_check(_ticks<400 && _g.enemy.x<88 && _g.enemy.display_frame==104,"released boat enters and stops at landing");
    ln2_play_draw(_g);surface_save(_g.stage_surface,"ln2-scene17-boat-arrival.png");
    show_debug_message("LN2_FENCE_GAP_BOAT_PASS: 336 original triggers, climb/descent, gap deaths, safe crossings, saved jab-to-arrival");
}

function ln2_gap_landing_checks() {
    for(var _facing=1;_facing<8;_facing+=2) for(var _health_index=0;_health_index<3;_health_index++) {
        var _g=new LN2Play(1),_p=_g.player;ln2_play_enter(_g,12);
        _p.x=90;_p.y=80;_p.depth_y=80;_p.facing=_facing;_p.action=0;
        _g.player_health=[1,22,44][_health_index];_g.status.health[0]=_g.player_health;
        _p.boundary_mode=14;_p.boundary_crossings=129;ln2_hazard_boundary(_g);
        var _frames=[],_landing_y=-1,_ticks=0,_lives=_g.lives_left;
        while(is_struct(_g.world_state.drowning) && _ticks++<240) {
            ln2_play_tick(_g,31);
            if (is_struct(_g.world_state.drowning) && _g.world_state.drowning.phase==3) {
                if (_landing_y<0) _landing_y=_p.y;
                ln_check(_p.y==_landing_y && _p.depth_y==_landing_y,"death stays on landing ground");
                ln_check(_p.display_frame!=255,"ninja remains visible during health drain");
                if (!array_contains(_frames,_p.display_frame)) array_push(_frames,_p.display_frame);
                if (_p.display_frame==46 && _facing==7 && _health_index==2) {
                    ln2_play_draw(_g);surface_save(_g.stage_surface,"ln2-chasm-landed-death.png");
                }
            }
        }
        ln_check(_ticks<240 && array_contains(_frames,44) && array_contains(_frames,45) && array_contains(_frames,46),"complete facing-correct death animation after fall");
        ln_check(_g.status.health[0]==0 && _p.display_frame==46 && _g.respawn_wait==20,"corpse persists after health empties");
        repeat(19) {ln2_play_tick(_g,31);ln_check(_p.display_frame==46 && _p.y==_landing_y,"corpse does not vanish during respawn delay");}
        ln2_play_tick(_g,0);ln2_test_finish_life_transition(_g);ln_check(_g.lives_left==_lives-1 && _g.player_health==44,"single life loss after visible death");
    }
    show_debug_message("LN2_GAP_LANDING_PASS: 12 facing/health cases; visible landing death, health drain and one-life respawn");
}

function ln2_fall_death_begin(_g) {
    var _p=_g.player;
    _p.y=min(_p.y,180);_p.depth_y=_p.y;_p.height_fixed=0;
    _g.world_state.drowning={phase:3,saved_y:_p.y,saved_facing:_p.facing};
    _g.player_health=0;_g.exit_locked=true;_p.input_lock=255;_p.action_state=0;
    ln2_player_special(_g,_g.data.enemy_falls[(_p.facing&4)?1:0]);
}

function ln2_life_transition_tick(_g,_tick) {
    var _t=_g.life_transition;_g.player.tick=_tick;_g.player.last_tick=_tick;_t.tick++;
    if (_t.phase==0 && _t.tick>=80) {
        _g.lives_left=max(0,_g.lives_left-1);_t.phase=4;_t.tick=0;return;
    }
    if (_t.phase==4 && _t.tick>=80) {_t.phase=1;_t.tick=0;return;}
    if (_t.phase==1 && _t.tick>=75) {
        if (_g.lives_left<=0) {_g.game_over=true;_t.phase=3;return;}
        _g.player_health=44;ln2_test_enter(_g,_g.last_entry);_g.status.health[0]=44;
        // The raised curtain has already revealed the lives message.
        _g.life_transition=undefined;return;
    }
    // Older saves may still contain the previous game-reveal phase.
    if (_t.phase==2 && _t.tick>=80) _g.life_transition=undefined;
}

function ln2_life_transition_draw(_g) {
    if (!variable_struct_exists(_g,"life_transition") || !is_struct(_g.life_transition)) return;
    var _t=_g.life_transition;
    // Original $93af/$1d13: expanded multicolour sprites sweep the bitmap.
    if (_t.phase==0 || _t.phase==2) {
        var _frame=_t.phase==0?_t.tick:80-_t.tick;
        draw_sprite_ext(spr_ln2_death_wipe,clamp(_frame,0,80),160,84,3,3,0,c_white,1);
    } else {
        draw_set_colour(c_black);draw_rectangle(160,84,880,516,false);draw_set_colour(c_white);
    }
    if (_t.phase==1 || _t.phase==3 || _t.phase==4) {
        var _text=_g.lives_left==0?"GAME OVER":string(_g.lives_left)+(_g.lives_left==1?" LIFE REMAINING":" LIVES LEFT");
        // Centre within the 240x144 gameplay bitmap, drawn at (160,84) at 3x scale.
        var _x=160+240*3/2-string_length(_text)*12;
        for(var _i=1;_i<=string_length(_text);_i++) {
            var _c=ord(string_char_at(_text,_i)),_code=_c>=48 && _c<=57?_c-48+27:(_c==32?0:_c&63);
            draw_sprite_ext(spr_ln2_message_font,_code,_x+(_i-1)*24,84+(144*3-24)/2,3,3,0,c_white,1);
        }
    }
    if (_t.phase==4) {
        // Draw the text first so the rising curtain uncovers it.
        draw_sprite_ext(spr_ln2_death_wipe,clamp(80-_t.tick,0,80),160,84,3,3,0,c_white,1);
    }
}

function ln2_pickup_assist_input(_g,_joy) {
    if (!variable_struct_exists(_g,"pickup_fire_previous")) _g.pickup_fire_previous=0;
    var _fire=_joy&16,_edge=_fire!=0 && _g.pickup_fire_previous==0;_g.pickup_fire_previous=_fire;
    var _p=_g.player,_e=_g.enemy;
    if (!_edge || (_joy&15)!=0 || _p.vehicle!=0 || _p.action>=256 || _p.input_lock!=0 || _g.player_health<=0 ||
        ln2_blocking_sequence(_g) || _g.respawn_wait>0 || is_struct(_g.keypad) || _g.victory!=0 ||
        _g.fall_remaining>=0 || _g.hole_steps>0 || is_struct(_g.route_descent)) return _joy;
    if (_e.active>=128 && _e.health>0 && point_distance(_p.x,_p.y,_e.x,_e.y)<=20) return _joy;
    var _best=325,_target=undefined,_x=0,_y=0,_target_use=false;
    for(var _i=0;_i<array_length(_g.world.items);_i++) {
        var _item=_g.world.items[_i];
        var _use=ln2_item_use_ready(_g,_item);
        if (_item.room!=_g.room_id || (_item.id>=17 && !_use) || _item.action>2 || _g.inventory[_item.id]!=0) continue;
        var _tx=clamp(_p.x,_item.x_min,_item.x_max-1),_ty=clamp(_p.y,_item.y_min,_item.y_max-1);
        var _distance=sqr(_p.x-_tx)+sqr(_p.y-_ty);
        if (_distance>324) continue; // 18-pixel assist range.
        if ((_use && !_target_use) || (_use==_target_use && _distance<_best)) {
            _best=_distance;_target=_item;_x=_tx;_y=_ty;_target_use=_use;
        }
    }
    if (!is_struct(_target)) return _joy;
    // Keep the nearest approach point. Large source rectangles (toilet interiors)
    // describe valid interactions, not destinations at their far-away centres.
    _p.x=_x;_p.y=_y;_p.depth_y=_y;_p.fraction_x=0;_p.fraction_y=0;
    if (_target.facing!=0) _p.facing=_target.facing;
    _p.heading=_p.facing;_p.stopped=255;_p.turn_lock=0;_p.action_state=0;
    // The original pickup chain visits each object height; the matching item's
    // event ends it at the appropriate pose through ln2_item_animation_finish.
    ln2_player_begin(_p,_g.data,20);return 0;
}

function ln2_test_finish_life_transition(_g) {
    var _ticks=0;
    while(is_struct(_g.life_transition) && _g.life_transition.phase!=3 && _ticks++<240) ln2_play_tick(_g,0);
    ln_check(_ticks<240,"life transition completes");
}

function ln2_lives_pickup_checks() {
    var _g=undefined,_p=undefined;
    for(var _level_index=0;_level_index<2;_level_index++) {
        _g=new LN2Play(_level_index==0?1:6);_p=_g.player;
        _p.x=120;_p.y=110;_p.facing=3;_g.lives_left=3;_g.player_health=44;
        ln2_fall_begin(_g,16,100);var _ticks=0,_death_seen=false;
        while(_g.respawn_wait==0 && _ticks++<240) {
            ln2_play_tick(_g,31);
            if (_p.display_frame==44 || _p.display_frame==45 || _p.display_frame==46) _death_seen=true;
        }
        ln_check(_death_seen && _g.respawn_wait==20,"every fatal fall cuts to death animation");
        repeat(20) ln2_play_tick(_g,0);
        ln_check(is_struct(_g.life_transition) && _g.lives_left==3,"fade begins before deducting life");
        repeat(80) ln2_play_tick(_g,0);
        ln_check(_g.life_transition.phase==4 && _g.lives_left==2,"curtain rises over lives message after one life loss");
        repeat(40) ln2_play_tick(_g,0);
        _g=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));
        ln_check(_g.life_transition.phase==4 && _g.life_transition.tick==40,"saved rising curtain resumes in place");
        ln2_play_draw(_g);surface_save(application_surface,"ln2-curtain-revealing-lives.png");
        repeat(40) ln2_play_tick(_g,0);
        ln_check(_g.life_transition.phase==1 && _g.lives_left==2,"lives message shows decremented count");
        ln2_play_draw(_g);surface_save(application_surface,"ln2-lives-message.png");
        _g=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));
        ln2_test_finish_life_transition(_g);
        ln_check(_g.lives_left==2 && _g.player_health==44 && !is_struct(_g.life_transition),"saved transition resumes without double life loss");
    }
    _g=new LN2Play(1);_g.lives_left=1;_g.respawn_wait=1;ln2_play_tick(_g,0);
    ln2_test_finish_life_transition(_g);ln_check(_g.game_over && _g.lives_left==0 && _g.life_transition.phase==3,"last life displays game over");
    var _collected=0;
    for(var _level=1;_level<=7;_level++) {
        _g=new LN2Play(_level);
        for(var _i=0;_i<array_length(_g.world.items);_i++) {
            var _item=_g.world.items[_i];if(_item.id>=17 || _item.handler!=0 || _item.action>2) continue;
            var _entry=-1;for(var _j=0;_j<array_length(_g.world.tables.exit_destinations);_j++) if(_g.world.tables.exit_destinations[_j]==_item.room) {_entry=_j;break;}
            ln_check(_entry>=0,"pickup fixture has valid room entrance");ln2_test_enter(_g,_entry);_p=_g.player;_g.inventory[_item.id]=0;
            // Place the fixture on the ground beside the item, past entrance climbing.
            _p.vehicle=0;_p.height_fixed=0;_p.x=_item.x_min-3;_p.y=_item.y_min;_p.action=0;_p.input_lock=0;_g.enemy.active=0;_g.pickup_fire_previous=0;
            ln2_pickup_assist_input(_g,16);
            for(var _tick=0;_tick<100 && _g.inventory[_item.id]==0;_tick++) ln2_play_tick(_g,0);
            ln_check(_g.inventory[_item.id]!=0,"fire alone collects nearby source item in level "+string(_level)+" id "+string(_item.id)+" action "+string(_p.action)+" xy "+string(_p.x)+","+string(_p.y)+" state "+string(_p.action_state)+" vehicle "+string(_p.vehicle));_collected++;break;
        }
    }
    _g=new LN2Play(1);
    var _nearby_item=undefined;
    for(var _candidate_index=0;_candidate_index<array_length(_g.world.items);_candidate_index++) {
        var _candidate=_g.world.items[_candidate_index];
        if(_candidate.id<17 && _candidate.action<=2 && _candidate.handler==0) {
            _nearby_item=_candidate;break;
        }
    }
    var _nearby_entry=-1;
    for(var _entry_index=0;_entry_index<array_length(_g.world.tables.exit_destinations);_entry_index++) {
        if(_g.world.tables.exit_destinations[_entry_index]==_nearby_item.room) {
            _nearby_entry=_entry_index;break;
        }
    }
    ln_check(_nearby_entry>=0,"pickup fixture has valid room entrance");
    ln2_test_enter(_g,_nearby_entry);_p=_g.player;
    _g.inventory[_nearby_item.id]=0;_p.vehicle=0;_p.height_fixed=0;
    _p.x=_nearby_item.x_min;_p.y=_nearby_item.y_min;_p.action=0;_p.input_lock=0;
    _g.enemy.active=128;_g.enemy.health=44;_g.enemy.x=_p.x+20;_g.enemy.y=_p.y;_g.pickup_fire_previous=0;
    ln_check(ln2_pickup_assist_input(_g,16)==16 && _p.action==0,"enemy within 20 pixels leaves fire for combat");
    _g.enemy.x=_p.x+21;_g.pickup_fire_previous=0;
    ln_check(ln2_pickup_assist_input(_g,16)==0 && _p.action>=256,"outside enemy range permits pickup");
    show_debug_message("LN2_LIVES_PICKUP_PASS: falls, fades, source font, saved lives count and "+string(_collected)+" level pickups with enemy range guard");
}


/// Street $9ac4: $b0 increments each fourth game tick, toggles flag 18 at 50.
function ln2_street_clock_tick(_g,_tick) {
    if (_g.level!=2) return;
    if (!variable_struct_exists(_g.world_state,"traffic_clock")) _g.world_state.traffic_clock=0;
    if ((_tick&3)!=0) return;
    if (++_g.world_state.traffic_clock<50) return;
    _g.world_state.traffic_clock=0;_g.inventory[18]^=255;
}

function ln2_street_lights_draw(_g) {
    if (_g.level!=2) return;
    var _rooms=[1,4,5,8,9,11];
    for(var _i=0;_i<array_length(_rooms);_i++) if (_g.room_id==_rooms[_i]) {
        draw_sprite(spr_ln2_street_lights,_i*2+real(_g.inventory[18]!=0),0,0);return;
    }
}

/// Source $9db1/$9dcb/$9de5: crossing against the lights summons a fatal bike.
function ln2_street_traffic_boundary(_g) {
    var _p=_g.player,_mode=_p.boundary_mode&63,_e=_g.enemy;
    if (!(_p.boundary_crossings&128) || (!(_p.boundary_mode&64) && _p.action>=256)) return false;
    if (_mode<35 || _mode>37) return false;
    var _danger=_mode==36?_g.inventory[18]!=0:_g.inventory[18]==0;
    if (_danger && _e.y==0) {
        _e.x=0;_e.fraction_x=0;_e.fraction_y=0;
        ln2_environment_action(_g,_mode==35?$c8ce:(_mode==36?$c8ec:$c8f8));
        ln2_damage(_g,44,false);
    }
    _p.boundary_crossings=0;return false;
}

function ln2_street_snag_checks() {
    var _g=new LN2Play(2),_p=_g.player;
    var _tick=0,_room_index=0,_room=0,_item=0,_j=0;
    // Clock parity, including pause/save midway through a cycle.
    _g.inventory[18]=0;_g.world_state.traffic_clock=0;
    for(_tick=1;_tick<=199;_tick++) ln2_street_clock_tick(_g,_tick);
    ln_check(_g.inventory[18]==0,"traffic does not change early");
    _g=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));_p=_g.player;
    ln2_street_clock_tick(_g,200);ln_check(_g.inventory[18]==255,"saved traffic clock changes at 200");
    for(_tick=201;_tick<=400;_tick++) ln2_street_clock_tick(_g,_tick);
    ln_check(_g.inventory[18]==0,"traffic completes both source phases");
    var _vectors=_g.data.street_traffic_checks;
    for(var _i=0;_i<array_length(_vectors);_i++) {
        var _v=_vectors[_i];
        _p.boundary_mode=_v.mode;_p.boundary_crossings=_v.crossings;_p.action=_v.action;
        _g.inventory[18]=_v.flag;_g.enemy.y=_v.enemy_y;_g.enemy.action=0;_g.player_health=44;
        ln2_street_traffic_boundary(_g);
        ln_check(_p.boundary_crossings==_v.expected[0] && _g.enemy.action==_v.expected[1] &&
            44-_g.player_health==_v.expected[2],"original traffic dispatch "+string(_i));
    }
    // Every source road approach, both signals, occupied and free actor slot.
    for(var _mode=35;_mode<=37;_mode++) for(var _flag=0;_flag<=1;_flag++) for(var _busy=0;_busy<=1;_busy++) {
        ln2_play_enter(_g,1);_g.inventory[18]=_flag*255;_g.enemy.y=_busy*20;
        _g.enemy.action=0;_p.action=0;_p.boundary_crossings=129;_p.boundary_mode=_mode;
        _g.player_health=44;_p.input_lock=0;
        ln2_street_traffic_boundary(_g);
        var _danger=(_mode==36?_flag==1:_flag==0) && !_busy;
        ln_check(_g.player_health==(_danger?0:44),"bike respects traffic phase and actor occupancy");
        ln_check((_g.enemy.action>=256)==_danger && _p.boundary_crossings==0,"bike source dispatch and crossing reset");
    }
    ln2_play_enter(_g,1);_g.enemy.x=0;_g.enemy.y=0;_p.action=0;_p.input_lock=0;
    _p.boundary_mode=99;_p.boundary_crossings=129;_g.inventory[18]=0;
    ln2_street_traffic_boundary(_g);
    repeat(16) {_p.tick=(_p.tick+1)&255;ln2_enemy_action(_g);}
    ln_check(_g.enemy.display_frame==114 && _g.enemy.x>32,"bike enters the street");
    ln2_play_draw(_g);surface_save(_g.stage_surface,"ln2-street-motorcycle.png");
    repeat(90) {_p.tick=(_p.tick+1)&255;ln2_enemy_action(_g);ln2_level_effect_tick(_g,0);}
    ln_check(_g.enemy.y==0 && _g.enemy.display_frame==255,"bike leaves and frees source actor slot");
    // Play both pot animations to their smash poses and capture native rendering.
    for(_room_index=0;_room_index<2;_room_index++) {
        _room=_room_index==0?5:7;
        ln2_play_enter(_g,_room);_p.input_lock=0;_p.action=0;_p.x=20;_p.y=100;
        _g.player_health=44;_p.tick=(_p.tick+1)&255;ln2_enemy_action(_g);
        ln2_enemy_special(_g,_room==5?$c7bd:$c7dc);
        var _smash=false;
        repeat(90) {
            _p.tick=(_p.tick+1)&255;ln2_enemy_action(_g);
            if (_g.enemy.display_frame==(_room==5?107:113)) {
                _smash=true;ln2_play_draw(_g);surface_save(_g.stage_surface,"ln2-pot-smash-"+string(_room)+".png");
            }
        }
        ln_check(_smash,"pot reaches complete source smash pose");
    }
    ln2_play_enter(_g,8);_g.inventory[10]=0;ln2_refresh_scene(_g);
    ln2_play_draw(_g);surface_save(_g.stage_surface,"ln2-street-bottle.png");
    ln_check(_g.scene_frame==0,"uncollected bottle panel is visible");
    _p.x=84;_p.y=105;_p.facing=1;_p.input_lock=0;_p.action=0;_p.stopped=255;_g.enemy.active=0;
    _g.last_joy=0;ln2_pickup_assist_input(_g,0);ln2_pickup_assist_input(_g,16);
    repeat(100) {if (_g.inventory[10]!=0) break;ln2_play_tick(_g,0);}
    ln_check(_g.inventory[10]!=0 && _g.scene_frame==1,"bottle pickup removes only its original panel");
    // Manhole requires the selected wrench, with actual pickup input and saved open art.
    ln2_play_enter(_g,14);_g.inventory[19]=0;_g.inventory[11]=255;_g.selected_item=0;
    _p.x=90;_p.y=120;_p.facing=3;_p.input_lock=0;_p.action=0;_g.enemy.active=0;
    ln2_item_interact(_g,2);ln_check(_g.inventory[19]==0,"manhole rejects unselected wrench");
    _g.selected_item=11;ln2_pickup_assist_input(_g,0);ln2_pickup_assist_input(_g,16);
    repeat(100) {if (_g.inventory[19]!=0) break;ln2_play_tick(_g,0);}
    ln_check(_g.inventory[19]!=0 && _g.scene_frame==1,"wrench and fire open manhole");
    ln2_play_draw(_g);surface_save(_g.stage_surface,"ln2-manhole-open.png");
    _g=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));_p=_g.player;
    ln_check(_g.scene==spr_ln2_street_manhole_states && _g.scene_frame==1,"saved open manhole remains visible");
    _p.x=104;_p.y=119;_p.boundary_mode=38;_p.boundary_crossings=129;_p.action=0;
    ln_check(ln2_boundary_exit(_g) && is_struct(_g.route_descent),"open manhole starts sewer descent");
    // Both chains: stay near the door, collect, then walk out again.
    _g=new LN2Play(1);_p=_g.player;
    for(_room_index=0;_room_index<2;_room_index++) {
        _room=_room_index==0?5:7;_item=_room_index==0?5:6;
        ln2_play_enter(_g,_room);_g.enemy.active=0;_p.enemy_active=0;
        _p.x=_room==5?210:218;_p.y=75;_p.depth_y=75;_p.input_lock=0;_p.action=0;_p.facing=1;
        var _x=_p.x,_y=_p.y;
        ln2_pickup_assist_input(_g,0);ln2_pickup_assist_input(_g,16);
        ln_check(_p.x==_x && _p.y==_y,"toilet pickup does not teleport through back wall");
        repeat(100) {if (_g.inventory[_item]!=0) break;ln2_play_tick(_g,0);}
        ln_check(_g.inventory[_item]!=0,"toilet pull chain can be collected");
        _p.action=0;_p.flags=0;_p.facing=1;_p.heading=1;_p.stopped=0;_p.turn_lock=0;
        var _joy=0;for(_j=1;_j<16;_j++) if (_g.data.directions[_j]==1) {_joy=_j;break;}
        repeat(100) ln2_play_tick(_g,_joy);
        ln_check(_p.y>=68 && _p.x<232,"toilet back wall stops forward walking");
        _p.action=0;_p.flags=0;_p.facing=5;_p.heading=5;_p.stopped=0;_p.turn_lock=0;
        for(_j=1;_j<16;_j++) if (_g.data.directions[_j]==5) {_joy=_j;break;}
        var _back_y=_p.y;repeat(24) ln2_play_tick(_g,_joy);
        ln_check(_p.y>_back_y,"ninja can walk back out of toilet");
    }
    for(_room_index=0;_room_index<2;_room_index++) {
        _p.room_id=_room_index==0?5:7;_p.x=_room_index==0?196:164;_p.y=_room_index==0?62:56;
        ln_check(ln2_toilet_backstop(_p,_g.data,_p.x+2,_p.y-1),"other toilet back wall is closed");
        ln_check(!ln2_toilet_backstop(_p,_g.data,_p.x-2,_p.y+1),"toilet caps allow outward movement");
    }
    ln_check(_g.inventory[3]!=0,"both toilet chains combine into nunchakus");
    show_debug_message("LN2_STREET_SNAGS_PASS: pots, bottle, traffic/bikes, wrench manhole, both toilet chains and return, saves");
}

function ln2_sewer_flame_room(_room) {
    var _rooms=[0,1,3,5,10,11,13];
    for(var _i=0;_i<array_length(_rooms);_i++) if (_rooms[_i]==_room) return _i;
    return -1;
}

/// Original $8683: six-tick cadence, three panel frames, clocks at $03e9/$03ea.
function ln2_sewer_flame_tick(_g,_tick) {
    if (_g.level!=3 || ((_tick-_g.inventory[17])&255)<6) return;
    _g.inventory[17]=_tick;
    if (ln2_sewer_flame_room(_g.room_id)<0) return;
    var _phase=(_g.inventory[18]+1)&255;
    _g.inventory[18]=_phase>=3?0:_phase;
}

function ln2_sewer_flame_draw(_g) {
    if (_g.level!=3) return;
    var _room=ln2_sewer_flame_room(_g.room_id);
    if (_room>=0) draw_sprite(spr_ln2_sewer_flames,_room*3+clamp(_g.inventory[18],0,2),0,0);
}

function ln2_sewer_flame_checks() {
    var _g=new LN2Play(3),_rooms=[0,1,3,5,10,11,13];
    var _xy=[[96,48],[200,32],[112,48],[24,64],[200,8],[208,48],[144,24]];
    _g.inventory[17]=250;_g.inventory[18]=0;
    ln2_sewer_flame_tick(_g,255);ln_check(_g.inventory[18]==0,"flames do not advance before six ticks");
    ln2_sewer_flame_tick(_g,0);ln_check(_g.inventory[18]==1 && _g.inventory[17]==0,"flame clock wraps correctly");
    _g=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));
    ln2_sewer_flame_tick(_g,6);ln_check(_g.inventory[18]==2,"saved flame phase resumes");
    ln2_sewer_flame_tick(_g,12);ln_check(_g.inventory[18]==0,"three frames loop");
    var _surface=surface_create(240,144);
    for(var _i=0;_i<array_length(_rooms);_i++) {
        ln2_play_enter(_g,_rooms[_i]);var _hashes=[];
        for(var _phase=0;_phase<3;_phase++) {
            _g.inventory[18]=_phase;
            surface_set_target(_surface);draw_clear(c_black);draw_sprite(_g.scene,_g.scene_frame,0,0);
            ln2_sewer_flame_draw(_g);surface_reset_target();
            var _hash=0;for(var _pixel=0;_pixel<64;_pixel++)
                _hash+=surface_getpixel(_surface,_xy[_i][0]+(_pixel mod 8),_xy[_i][1]+(_pixel div 8))*(_pixel+1);
            array_push(_hashes,_hash);
            if (_rooms[_i]==5) surface_save(_surface,"ln2-sewer-flame-"+string(_phase)+".png");
        }
        ln_check(_hashes[0]!=_hashes[1] && _hashes[1]!=_hashes[2] && _hashes[0]!=_hashes[2],"three distinct rendered flame frames in room "+string(_rooms[_i]));
    }
    surface_free(_surface);
    ln2_play_enter(_g,2);_g.inventory[17]=0;_g.inventory[18]=1;ln2_sewer_flame_tick(_g,6);
    ln_check(_g.inventory[17]==6 && _g.inventory[18]==1,"unlisted rooms update clock without flame phase");
    ln2_play_enter(_g,5);_g.inventory[20]=255;ln2_refresh_scene(_g);
    ln_check(_g.scene==spr_ln2_sewer_grate_states && _g.scene_frame==1,"flames preserve open grate background");
    show_debug_message("LN2_SEWER_FLAMES_PASS: seven rooms, 21 rendered frames, six-tick cadence, wrap, save phase, open grate");
}

/// Retain original routes and migrate saves from the withdrawn experiments.
function ln2_sewer_network_prepare(_g) {
    if (_g.level!=3) return;
    _g.data.sewer_recessed=_g.room_id==10;
    _g.water_data=undefined;
    if (variable_struct_exists(_g.world,"sewer_network_version") && _g.world.sewer_network_version==3) return;
    var _fresh=ln3_data_read("play/ln2/level3/world.json");
    _g.world.tables=_fresh.tables;
    _g.world.rooms=array_filter(_g.world.rooms,function(_room,_index) {return _room.id!=15;});
    if (variable_struct_exists(_g.world,"sewer_doors")) variable_struct_remove(_g.world,"sewer_doors");
    _g.world.sewer_wrong_doors=_fresh.sewer_wrong_doors;_g.world.sewer_network_version=3;
    _g.world_state.sewer_door_lock=-1;
    if (_g.room_id==15) {
        var _target=_g.last_entry==40?12:10,_entry=0;
        for(var _i=0;_i<array_length(_g.world.rooms);_i++) if (_g.world.rooms[_i].id==_target) _entry=_g.world.rooms[_i].spawn_entry;
        var _p=_g.player;_p.action=0;_p.action_state=0;_p.flags=0;_p.countdown=0;
        _p.input_lock=0;_p.stopped=255;_p.fraction_x=0;_p.fraction_y=0;
        ln2_play_travel(_g,_entry);_p.boundary_crossings=0;_p.collision=0;
        if (_g.player_health<=0) _g.respawn_wait=20;
    } else if (_g.last_entry>=31) {
        // Keep the current position; respawn through this room's original entry.
        _g.last_entry=_g.scene_record.spawn_entry;
    }
}

/// Original Sewer mode 24 at $89bd calls $9b18 with A=2, then clears $81.
function ln2_sewer_wrong_door(_g) {
    if (_g.level!=3) return;
    var _p=_g.player;
    if (_p.action>=256 || _p.input_lock!=0 || _g.player_health<=0) return;
    var _touch=(_p.boundary_crossings&128) && ((_p.boundary_mode&63)==24);
    if (!_touch && _g.room_id!=10 && _p.collision==255 && _p.hit_side==1 && _p.stopped==0) {
        // Reach recessed original sensors from their solid front lip.
        var _doors=_g.world.sewer_wrong_doors;
        for(var _i=0;_i<array_length(_doors);_i++) {
            var _door=_doors[_i];
            if (_door.room==_g.room_id && abs(_p.x-_door.x)<=7 && _p.y>=_door.y && _p.y<=_door.y+12) {_touch=true;break;}
        }
    }
    if (_touch) {ln2_damage(_g,2,false);_p.boundary_crossings=0;}
}

function ln2_sewer_original_checks() {
    var _g=new LN2Play(3),_doors=_g.world.sewer_wrong_doors;
    ln_check(array_length(_g.world.rooms)==15 && array_length(_g.world.tables.entry_x)==31 && !variable_struct_exists(_g.world,"sewer_doors"),"original rooms and entrances only");
    ln_check(array_length(_doors)==7,"seven original mode 24 doors");
    for(var _i=0;_i<array_length(_doors);_i++) {
        var _door=_doors[_i];ln2_play_enter(_g,_door.room);var _p=_g.player;
        _p.action=0;_p.input_lock=0;_g.player_health=44;_p.boundary_crossings=129;_p.boundary_mode=152;
        ln2_sewer_wrong_door(_g);
        ln_check(_g.player_health==42 && _p.boundary_crossings==0 && _g.room_id==_door.room,"original two-point damage, no teleport: "+_door.name);
        repeat(21) {_p.boundary_crossings=129;ln2_sewer_wrong_door(_g);}
        ln_check(_g.player_health==0 && _p.input_lock==255,"false door can kill: "+_door.name);
        var _killed=false;
        for(var _joy=1;_joy<16 && !_killed;_joy++) {
            var _trial=new LN2Play(3);ln2_play_enter(_trial,_door.room);ln2_test_enter(_trial,_trial.scene_record.spawn_entry);
            _trial.enemy.active=0;_trial.enemy.custom=false;_trial.special_mode=0;
            _trial.player.x=_door.x+(_door.facing==3?10:-10);_trial.player.y=_door.y+8;
            _trial.player.depth_y=_trial.player.y;_trial.player.facing=_door.facing;
            _trial.player.action=0;_trial.player.input_lock=0;
            repeat(100) {ln2_play_tick(_trial,_joy);if (_trial.player_health==0 || _trial.room_id!=_door.room) break;}
            _killed=_trial.player_health==0 && _trial.room_id==_door.room;
            if (_killed) ln_check(_trial.player.action>=256,"wrong door starts death animation");
        }
        ln_check(_killed,"walking into false door kills without teleport: "+_door.name);

    }
    // The source rat action must produce three visible, distinct frames.
    _g=new LN2Play(3);ln2_play_enter(_g,10);_g.enemy.x=0;_g.enemy.y=0;
    var _surface=surface_create(240,144),_seen=[],_moved=false,_old_x=-1;
    repeat(100) {
        _g.player.tick=(_g.player.tick+1)&255;ln2_enemy_action(_g);ln2_level_effect_tick(_g,0);
        var _e=_g.enemy;
        if (_e.x<20 || _e.x>220) continue;
        _moved=_moved || (_old_x>=0 && _old_x!=_e.x);_old_x=_e.x;
        if (array_contains(_seen,_e.display_frame)) continue;
        array_push(_seen,_e.display_frame);
        surface_set_target(_surface);draw_clear_alpha(c_black,0);ln2_play_actor(_g,_e,true);surface_reset_target();
        var _visible=0;
        for(var _y=0;_y<144;_y++) for(var _x=0;_x<240;_x++) if ((surface_getpixel_ext(_surface,_x,_y)>>24)&255) _visible++;
        ln_check(_visible>10,"rat frame visibly renders "+string(_e.display_frame));
        surface_set_target(_surface);draw_clear(c_black);draw_sprite(_g.scene,0,0,0);ln2_play_actor(_g,_e,true);surface_reset_target();
        surface_save(_surface,"ln2-sewer-rat-"+string(_e.display_frame)+".png");
    }
    surface_free(_surface);ln_check(array_length(_seen)==3 && _moved,"three animated scurrying rat frames");
    _g.enemy.x=120;_g.enemy.y=160;_g.player.x=120;_g.player.y=88;_g.player.combat_state=0;_g.player_health=44;
    ln2_level_effect_tick(_g,0);ln_check(_g.player_health==42,"visible rat retains source damage");
    _g.player.x=20;ln2_level_effect_tick(_g,0);ln_check(_g.player_health==42,"rat out of range does not hurt");
    ln2_play_enter(_g,10);_g.last_entry=37;_g.inventory[20]=255;
    var _save=ln_save_capture(_g);_save.state.world.sewer_network_version=2;
    _g=ln_save_restore(_save);
    ln_check(_g.room_id==10 && _g.last_entry<31 && _g.inventory[20]==255,"shortcut save keeps position/progress and gets original respawn");
    show_debug_message("LN2_SEWER_ORIGINAL_PASS: original entrances, seven false doors, source damage, three visible rat frames, save migration");
}

function ln2_alligator_continue(_g) {
    var _x=_g.enemy.x;
    if (_x<60) _g.inventory[21]=255;
    else if (_x>=142) _g.inventory[21]=0;
    if (_x>=76 && _x<126 && ln2_enemy_random(_g)<64) _g.inventory[21]^=255;
    var _right=_g.inventory[21]!=0,_edge=(_x+(_right?8:-8))&255;
    var _near=_edge<_g.player.x || _edge-_g.player.x<48;
    _g.enemy.action=_right?(_near?$b430:$b408):(_near?$b41c:$b3f4);
}

/// Only the two scene-10 door apertures are recessed; source data stays intact.
function ln2_door_recess(_s,_d,_ox,_oy,_nx,_ny) {
    if (!variable_struct_exists(_d,"sewer_recessed") || !_d.sewer_recessed) return -1;
    var _centres=[76,108],_ys=[73,65];
    for(var _i=0;_i<2;_i++) {
        var _cx=_centres[_i],_line=_ys[_i]+2-floor((_nx-_cx)/4);
        if (abs(_ox-_cx)>8 || abs(_nx-_cx)>6) continue;
        if (_oy>=_line && _ny<=_line+1 && (_ny<_oy || _nx<_ox)) {
            _s.boundary_mode=152;_s.boundary_crossings=((_s.boundary_crossings+1)&255)|128;
            _s.hit_boundary=_i==0?9:13;_s.hit_side=1;return 1;
        }
        if (_oy>=_line && _ny>=_line) return 0;
    }
    return -1;
}

function ln2_loader_active(_g) {
    return variable_struct_exists(_g,"loader") && is_struct(_g.loader) && _g.loader.active;
}

function ln2_level_track(_level) {
    return ["central_park","street","sewers","basement","office","mansion","final_battle"][_level-1];
}

function ln2_loader_begin(_g) {
    _g.loader={active:true,released:false,fire_blocked:false};_g.paused=false;
    ln_music_play(2,ln2_level_track(_g.level),true);
    if (!_g.music && variable_global_exists("ln_music_voice")) audio_pause_sound(global.ln_music_voice);
}

function ln2_loader_tick(_g,_joy) {
    if (!ln2_loader_active(_g)) return false;
    if (!(_joy&16)) _g.loader.released=true;
    else if (_g.loader.released) {
        _g.loader.active=false;_g.loader.fire_blocked=true;
        _g.player.fire_previous=16;
        ln_music_play(2,ln2_level_track(_g.level),false);
        if (!_g.music && variable_global_exists("ln_music_voice")) audio_pause_sound(global.ln_music_voice);
    }
    return true;
}

function ln2_loader_draw(_g) {
    var _sprite=asset_get_index("spr_ln2_loader_level"+string(_g.level)+"_location_00");
    draw_set_colour(c_black);draw_rectangle(160,84,1120,684,false);draw_set_colour(c_white);
    draw_sprite_ext(_sprite,0,280,168,3,3,0,c_white,1);
    draw_text(160,36,"LAST NINJA 2 — "+string_upper(_g.title));
    draw_text(1000,36,"Scene 0");
    draw_text(160,700,"Press # or Xbox A to begin");
}

function ln2_followup_checks() {
    ln_trilogy_frontend_checks();
    ln2_road_probe();
    ln2_molotov_checks();
    var _v=ln3_data_read("verification/ln2_alligator_checks.json"),_g=new LN2Play(3);
    ln2_play_enter(_g,14);
    for(var _i=0;_i<array_length(_v.cases);_i++) {
        var _c=_v.cases[_i];_g.enemy.x=_c.ex;_g.player.x=_c.px;_g.inventory[21]=_c.flag;
        _g.random_queue=[_c.random];_g.random_head=0;_g.player.weapon=1;_g.player.selected_weapon=2;
        ln2_combat_event(_g,12,true);
        ln_check(_g.enemy.action==_c.action && _g.inventory[21]==_c.expected_flag && _g.random_head==_c.used,"source alligator continuation "+string(_i));
        ln_check(_g.player.weapon==1,"alligator event does not change ninja weapon");
    }
    _g=new LN2Play(3);ln2_play_enter(_g,14);ln2_test_enter(_g,_g.scene_record.spawn_entry);_g.player.y=180;_g.player.x=120;
    var _lunge=false,_moves=false,_previous=0;
    repeat(350) {
        ln2_play_tick(_g,0);
        _moves=_moves || (_previous!=0 && _previous!=_g.enemy.x);_previous=_g.enemy.x;
        if (_g.enemy.display_frame==108 || _g.enemy.display_frame==109) _lunge=true;
    }
    ln_check(_moves && _lunge,"alligator walks and lunges over repeated continuations");
    var _surface=surface_create(240,144);
    _g.enemy.x=100;_g.enemy.y=70;_g.enemy.depth_y=70;_g.enemy.display_frame=108;
    surface_set_target(_surface);draw_clear_alpha(c_black,0);ln2_play_actor(_g,_g.enemy,true);surface_reset_target();
    var _pixels=0;for(var _y=0;_y<144;_y++) for(var _x=0;_x<240;_x++) if ((surface_getpixel_ext(_surface,_x,_y)>>24)&255) _pixels++;
    ln_check(_pixels>40,"lunge sprite visible");
    surface_set_target(_surface);draw_clear(c_black);draw_sprite(_g.scene,0,0,0);ln2_play_actor(_g,_g.enemy,true);surface_reset_target();
    surface_save(_surface,"ln2-alligator-lunge.png");surface_free(_surface);
    ln2_test_enter(_g,0);ln2_play_enter(_g,10);
    for(var _door=0;_door<2;_door++) {
        var _cx=_door==0?76:108,_y=_door==0?73:65,_p=_g.player;
        _p.action=0;_p.input_lock=0;_p.stopped=0;_g.player_health=44;_p.x=_cx;
        _p.boundary_crossings=0;_p.collision=ln2_player_boundary(_p,_g.data,_cx,_y+9,_cx,_y+5);_p.y=_y+5;
        ln2_sewer_wrong_door(_g);ln_check(_p.collision==0 && _g.player_health==44,"door approach is safe inside front lip");
        _p.collision=ln2_player_boundary(_p,_g.data,_cx,_y+3,_cx,_y+1);_p.y=_y+3;
        ln2_sewer_wrong_door(_g);ln_check(_p.collision==255 && _g.player_health==42,"damage starts at recessed doorway stop");
    }
    var _picker=new LNSceneTest(ln3_data_read("catalog.json"));
    for(var _level=1;_level<=7;_level++) {
        _g=new LN2Play(_level);
        for(var _index=0;_index<array_length(_picker.levels);_index++) if (_picker.levels[_index].game==2 && _picker.levels[_index].number==_level) _picker.level_index=_index;
        ln_check(ln_scene_test_open(_picker,_g,-1) && ln2_loader_active(_g) && _g.room_id==_picker.levels[_picker.level_index].scenes[0].id,"scene zero opens title before scene one");
        var _tick=_g.player.tick,_room=_g.room_id,_health=_g.player_health;
        repeat(4) ln2_play_tick(_g,16);
        ln_check(ln2_loader_active(_g) && _g.player.tick==_tick,"held fire cannot skip loader or advance gameplay");
        ln2_play_tick(_g,0);_g=ln_save_restore(ln_save_capture(_g));ln2_play_tick(_g,16);ln_check(ln2_loader_active(_g),"restored loader requires release");ln2_play_tick(_g,0);ln2_play_tick(_g,16);
        ln_check(!ln2_loader_active(_g) && _g.room_id==_room && _g.player_health==_health && _g.player.tick==_tick,"fresh fire starts level from saved loader");
        ln_check(ln_scene_test_open(_picker,_g,0) && !ln2_loader_active(_g) && _g.room_id==_picker.levels[_picker.level_index].scenes[0].id,"scene one selection opens gameplay directly");
        ln_check(asset_get_index("spr_ln2_loader_level"+string(_level)+"_location_00")>=0,"loader art exists");
        ln2_loader_begin(_g);
        var _s=surface_create(1280,800);surface_set_target(_s);draw_clear(c_black);ln2_loader_draw(_g);surface_reset_target();surface_save(_s,"ln2-loader-"+string(_level)+".png");surface_free(_s);
        ln_check(ln2_scene_number(_g)==0,"loader displays scene zero");
        ln_check(ln_scene_test_open(_picker,_g,0) && !ln2_loader_active(_g) && ln2_scene_number(_g)==1,"direct loader bypass enters displayed scene one");
        ln_check(audio_is_playing(asset_get_index("snd_ln2_"+ln2_level_track(_level)+"_game")),"direct loader bypass switches to game music");
    }
    show_debug_message("LN2_FOLLOWUP_PASS: 440 source alligator cases, lunge render, recessed doors, seven loaders, fire and save handling");
}

/// Display numbering matches the picker; source room IDs stay unchanged.
function ln2_scene_number(_g) {
    if (ln2_loader_active(_g)) return 0;
    var _number=0;
    for(var _i=0;_i<array_length(_g.world.rooms);_i++) {
        if (_g.world.rooms[_i].spawn_entry<0) continue;
        _number++;
        if (_g.world.rooms[_i].id==_g.room_id) return _number;
    }
    return _g.room_id;
}

function ln2_road_probe() {
    for(var _ri=0;_ri<3;_ri++) {
        var _room=[1,4,8][_ri];
        for(var _signal=0;_signal<2;_signal++) {
            var _hit=false,_seen=false;
            for(var _joy=1;_joy<=15;_joy++) {
                var _g=new LN2Play(2);ln2_play_enter(_g,_room);ln2_test_enter(_g,_g.scene_record.spawn_entry);
                var _p=_g.player;_p.vehicle=0;_p.action=0;_p.input_lock=0;_g.inventory[18]=_signal*255;
                _p.x=_ri==1?210:40;_p.y=_ri==0?130:(_ri==1?127:134);_p.depth_y=_p.y;
                repeat(22) {
                    ln2_play_tick(_g,_joy);
                    if (_g.enemy.custom && _g.enemy.display_frame==114) _seen=true;
                    if (_g.player_health==0) _hit=true;
                }
            }
            ln_check(_hit==(_ri==1?(_signal==1):(_signal==0)) && _seen==_hit,"real walking summons visible bike only against lights");
            show_debug_message("ROAD_PROBE room="+string(_room)+" signal="+string(_signal)+" hit="+string(_hit)+" seen="+string(_seen));
        }
    }
}

function ln_frontend_music(_g,_intro) {
    ln_music_play(_g.game_number,string_replace_all(string_lower(_g.title)," ","_"),_intro && _g.game_number!=3);
    var _muted=_g.game_number==1?(is_struct(_g.controls) && !_g.controls.music):!_g.music;
    if (_muted && variable_global_exists("ln_music_voice")) audio_pause_sound(global.ln_music_voice);
}
function ln_frontend_begin(_g) {
    if (_g.game_number==2) {ln2_loader_begin(_g);return;}
    _g.loader={active:true,released:false,fire_blocked:false};
    if (_g.game_number==1) {if (is_struct(_g.controls)) _g.controls.pause=0;}
    else _g.paused=false;
    ln_frontend_music(_g,true);
}
function ln_frontend_tick(_g,_joy) {
    if (!ln2_loader_active(_g)) return false;
    if (!(_joy&16)) _g.loader.released=true;
    else if (_g.loader.released) {
        _g.loader.active=false;_g.loader.fire_blocked=true;
        // LN3 uses the same track on both sides, so keep it playing seamlessly.
        if (_g.game_number!=3) ln_frontend_music(_g,false);
    }
    return true;
}
function ln_frontend_filter(_g,_joy) {
    if (is_struct(_g.loader) && _g.loader.fire_blocked) {
        if (!(_joy&16)) _g.loader.fire_blocked=false;
        return _joy&15;
    }
    return _joy;
}
function ln_frontend_selected(_g,_entered,_intro,_was_loader) {
    if (_entered && _intro) ln_frontend_begin(_g);
    else if (_entered && _was_loader) ln_frontend_music(_g,false);
    return _entered;
}
function ln_frontend_draw(_g) {
    draw_clear(c_black);draw_set_colour(c_white);
    if (_g.game_number==1) ln1_frontend_bitmap(_g);
    else {
        // Named Included Files are replaceable artwork, loaded once per run.
        static _bitmaps=array_create(5,-1);
        var _index=clamp(_g.level-1,0,4);
        if (!sprite_exists(_bitmaps[_index])) {
            var _names=["EARTH","WIND","WATER","FIRE","VOID"];
            _bitmaps[_index]=sprite_add("play/ln3/frontends/"+_names[_index]+".png",1,false,false,0,0);
        }
        if (sprite_exists(_bitmaps[_index])) draw_sprite_ext(_bitmaps[_index],0,160,84,3,3,0,c_white,1);
    }
    draw_text(160,36,"LAST NINJA "+string(_g.game_number)+" — "+string_upper(_g.title));
    draw_text(1000,36,"Scene 0");draw_text(160,700,"Press # or Xbox A to begin");
}

function ln_trilogy_frontend_checks() {
    var _picker=new LNSceneTest(ln3_data_read("catalog.json"));
    for(var _i=0;_i<array_length(_picker.levels);_i++) {
        var _level=_picker.levels[_i];if (_level.game==2) continue;
        _picker.level_index=_i;
        var _g=_level.game==1?new LN1Play(_level.number):new LN3Play(_level.number);
        ln_check(ln_scene_test_open(_picker,_g,-1) && ln2_loader_active(_g),"LN1/LN3 selectable Scene 0");
        var _before=json_stringify(_g.game_number==1?[_g.player.tick,_g.player.x,_g.player.y,_g.player_health]:_g.state),_room=_g.room_id;
        repeat(3) {if (_g.game_number==1) ln1_play_tick(_g,16);else ln3_play_tick(_g,16);}
        ln_check(json_stringify(_g.game_number==1?[_g.player.tick,_g.player.x,_g.player.y,_g.player_health]:_g.state)==_before && ln2_loader_active(_g),"intro freezes gameplay and held fire");
        var _s=surface_create(1280,800);surface_set_target(_s);ln_frontend_draw(_g);surface_reset_target();surface_save(_s,"ln"+string(_g.game_number)+"-frontend-"+string(_g.level)+".png");surface_free(_s);
        _g=ln_save_restore(json_parse(json_stringify(ln_save_capture(_g))));
        ln_frontend_tick(_g,16);ln_check(ln2_loader_active(_g),"saved title requires a released fire button");
        ln_frontend_tick(_g,0);var _voice=global.ln_music_voice;ln_frontend_tick(_g,16);
        ln_check(!ln2_loader_active(_g) && _g.room_id==_room,"fresh fire starts prepared room");
        if (_g.game_number==3) ln_check(global.ln_music_voice==_voice,"LN3 music continues seamlessly");
        ln_check(ln_frontend_filter(_g,16)==0 && ln_frontend_filter(_g,0)==0 && ln_frontend_filter(_g,16)==16,"dismissal press cannot become an attack");
        ln_scene_test_open(_picker,_g,-1);ln_scene_test_open(_picker,_g,0);
        ln_check(!ln2_loader_active(_g),"direct gameplay selection bypasses title");
    }
    show_debug_message("LN_TRILOGY_FRONTEND_PASS: eleven LN1/LN3 title entries, frozen gameplay, fresh fire, saves and music");
}

// Temporary LN1 title treatment: source eyes, paired horizontal pixels, C64 colours.
function ln1_frontend_label(_text,_cy,_colour) {
    static _glyphs = {"A":["0110", "1001", "1001", "1111", "1001", "1001", "1001"],"C":["0111", "1000", "1000", "1000", "1000", "1000", "0111"],"D":["1110", "1001", "1001", "1001", "1001", "1001", "1110"],"E":["1111", "1000", "1000", "1110", "1000", "1000", "1111"],"G":["0111", "1000", "1000", "1011", "1001", "1001", "0111"],"H":["1001", "1001", "1001", "1111", "1001", "1001", "1001"],"I":["111", "010", "010", "010", "010", "010", "111"],"L":["1000", "1000", "1000", "1000", "1000", "1000", "1111"],"M":["10001", "11011", "10101", "10001", "10001", "10001", "10001"],"N":["1001", "1101", "1101", "1011", "1011", "1001", "1001"],"O":["0110", "1001", "1001", "1001", "1001", "1001", "0110"],"P":["1110", "1001", "1001", "1110", "1000", "1000", "1000"],"R":["1110", "1001", "1001", "1110", "1010", "1001", "1001"],"S":["0111", "1000", "1000", "0110", "0001", "0001", "1110"],"T":["1111", "0110", "0110", "0110", "0110", "0110", "0110"],"U":["1001", "1001", "1001", "1001", "1001", "1001", "0110"],"W":["10001", "10001", "10001", "10101", "10101", "11011", "10001"]," ":["00", "00", "00", "00", "00", "00", "00"]};
    var _width=0;
    for(var _n=1;_n<=string_length(_text);_n++) {
        var _glyph=variable_struct_get(_glyphs,string_char_at(_text,_n));
        _width+=string_length(_glyph[0])*2+2;
    }
    var _left=160+floor((320-(_width-2))/2)*3;
    draw_set_colour(_colour);
    for(var _n=1;_n<=string_length(_text);_n++) {
        var _glyph=variable_struct_get(_glyphs,string_char_at(_text,_n));
        for(var _row=0;_row<7;_row++) for(var _col=1;_col<=string_length(_glyph[_row]);_col++) {
            if(string_char_at(_glyph[_row],_col)=="1") {
                var _px=_left+(_col-1)*6,_py=84+(_cy+_row)*3;
                draw_rectangle(_px,_py,_px+6,_py+3,false);
            }
        }
        _left+=(string_length(_glyph[0])*2+2)*3;
    }
}
function ln1_frontend_bitmap(_g) {
    // The full title canvas is 320 x 200; only the supplied eye band is displayed.
    draw_sprite_part_ext(spr_ln1_loader_reference,0,0,16,240,72,160+40*3,84+46*3,3,3,c_white,1);
    static _colours=[make_colour_rgb(184,199,111),make_colour_rgb(86,172,77),make_colour_rgb(103,182,189),make_colour_rgb(136,57,50),make_colour_rgb(139,63,150),make_colour_rgb(120,105,196)];
    var _colour=_colours[clamp(_g.level-1,0,5)];
    ln1_frontend_label("THE",132,_colour);
    ln1_frontend_label(string_upper(_g.title),148,_colour);
    draw_set_colour(c_white);
}
