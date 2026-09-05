function ln2_environment_action(_g,_address) {
    _g.enemy.custom=true;_g.enemy.depth_y=1;ln2_enemy_special(_g,_address);
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
    var _p=_g.player;_p.depth_y=_depth;_p.height_fixed=255;
    _g.fall_remaining=_distance;_g.fall_clock=_p.tick;_g.exit_locked=true;
}

function ln2_fall_tick(_g,_tick) {
    var _p=_g.player;_p.tick=_tick;var _elapsed=(_tick-_g.fall_clock)&255;
    if (_elapsed>=2) {
        var _step=(_elapsed<<2)&255;_p.y=(_p.y+_step)&255;_g.fall_clock=_tick;
        _p.display_frame=((_p.facing+2)&4)?83:78;_p.mirror=(_p.facing&2)!=0;
        _g.fall_remaining-=_step;
        if (_g.fall_remaining<0 || _p.y>=189) { _g.fall_remaining=-1;_p.input_lock=255;return; }
    }
    ln2_enemy_action(_g);
}
