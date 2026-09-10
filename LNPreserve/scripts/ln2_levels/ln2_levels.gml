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
            _p.input_lock=255;return;
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
    for (var _flags=0;_flags<4;_flags++) for (var _busy=0;_busy<2;_busy++)
    for (var _interrupt=0;_interrupt<2;_interrupt++) for (var _lock=0;_lock<2;_lock++) {
        var _g=new LN2Play(1),_p=_g.player;
        _p.boundary_crossings=(_flags&1)|((_flags&2)?128:0);
        _p.boundary_mode=2|(_interrupt?64:0);_p.action=_busy?$c300:0;_g.exit_locked=_lock;
        var _expected=(_flags&2)!=0 && (!_busy || _interrupt) && !_lock;
        ln_check(ln2_boundary_exit(_g)==_expected,"curtain crossing obeys original new-crossing/action/exit locks");
        ln_check(_g.room_id==(_expected?2:1),"curtain uses original scene 2 entrance");
    }
    var _g=new LN2Play(1),_p=_g.player;
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
