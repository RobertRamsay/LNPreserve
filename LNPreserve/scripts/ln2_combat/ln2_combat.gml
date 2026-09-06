function ln2_player_special(_g,_address) {
    ln2_player_special_state(_g.player,_g.data,_address);
}

function ln2_enemy_special(_g,_address) {
    var _e=_g.enemy;_e.action=_address;_e.flags=0;_e.countdown=0;
}

/// $ab70: attack range, directional vertical window, and defending pose.
function ln2_combat_hit(_a,_b,_active,_attack_count,_d) {
    if (_active<128 || (_b.combat_state&252)==12) return -1;
    var _facing=_a.combat_state&3,_dx=_facing<2?_b.x-_a.x-2:_a.x-_b.x;
    if (_dx<0) return -1;
    var _attack=((_a.combat_state-20)&255)>>2;
    var _index=((_a.weapon>=4?0:_a.weapon)<<2)|_attack;
    if (_index>=array_length(_d.hit_x_min)) return -1;
    if (_dx<_d.hit_x_min[_index] || _dx>=_d.hit_x_max[_index]) return -1;
    var _dy=((_facing==0 || _facing==3)?_a.y-_b.y:_b.y-_a.y)+8;
    if (_dy<0 || _dy>255 || _dy<_d.hit_y_min[_index] || _dy>=_d.hit_y_max[_index]) return -1;
    if ((_b.combat_state&252)==16 && ((_b.combat_state^_a.combat_state)&2) && _attack_count<4) return -1;
    return _index;
}

function ln2_damage(_g,_amount,_enemy) {
    if (!_enemy) {
        _g.player_health=max(0,_g.player_health-_amount);
        if (_g.player_health==0) { _g.player.combat_state=36+(_g.player.facing>>1);_g.player.input_lock=255; }
        return;
    }
    var _e=_g.enemy;
    if (_e.health==0) return;
    _e.health=max(0,_e.health-_amount);
    if (_e.health==0) {
        ln2_score_add(_g,$25,true);
        _e.recovery_time=_g.tick_epoch*256+_g.player.tick;
        var _count=(_e.knockouts+1)&127;
        if (_count>=_e.retreat_trait && _e.retreat_trait!=15) {_count=255;ln2_score_add(_g,$25,true);}
        _e.knockouts=_count|128;ln2_enemy_combat(_e,36);
    }
    ln2_enemy_remember(_g);
}

function ln2_combat_hurt(_g,_enemy) {
    var _victim=_enemy?_g.enemy:_g.player,_attacker=_enemy?_g.player:_g.enemy;
    if ((_victim.combat_state&252)!=36) {
        _victim.previous_combat=_victim.combat_state;_victim.combat_state=36+(_victim.facing>>1);
    }
    var _health=_enemy?_victim.health:_g.player_health;
    if (_health!=0) {
        var _index=(((_attacker.combat_state-20)&14)<<1)|(_victim.combat_state&3);
        if (_enemy) ln2_enemy_special(_g,_g.data.reactions[_index]);
        else { ln2_player_special(_g,_g.data.reactions[_index]);_g.enemy.attack_count=0; }
    } else if (_enemy) {
        if (_g.level==7) {ln2_final_enemy_hurt(_g);return;}
        ln2_enemy_special(_g,_g.data.enemy_falls[(_victim.facing&4)?1:0]);
        _victim.mode=7;_victim.separation_y=0;
    } else _g.enemy.attack_count=0;
}

function ln2_combat_attack(_g,_enemy,_interaction) {
    if (!_enemy && _interaction>=0) ln2_item_interact(_g,_interaction);
    var _a=_enemy?_g.enemy:_g.player,_b=_enemy?_g.player:_g.enemy;
    var _index=ln2_combat_hit(_a,_b,_g.enemy.active,_g.enemy.attack_count,_g.data);
    if (_index<0 || (_b.combat_state&252)==36) return;
    var _damage=_enemy?_g.data.enemy_damage:_g.data.player_damage;
    ln2_damage(_g,_damage[_index],!_enemy);
    ln2_combat_hurt(_g,!_enemy);
}

function ln2_combat_event(_g,_event,_enemy) {
    var _a=_enemy?_g.enemy:_g.player;
    switch (_event) {
        case 0:return;
        case 1:case 12:_g.player.weapon=_g.player.selected_weapon;return;
        case 2:
            _a.action_mirror=_a.facing&2;_a.combat_state=_a.previous_combat;
            _a.frame=(_a.combat_state&252)==0?16+(((_a.facing+2)&4)>>2):(((_a.facing+2)&4)<<1);
            if (_enemy) { ln2_enemy_select(_a,_g.data,4);ln2_enemy_react(_g);_a.mode=8; }
            else _a.redraw=255;
            return;
        case 3:
            if (_enemy) { _a.mode=11;ln2_enemy_remember(_g); }
            else _g.respawn_wait=20;
            return;
        case 4:ln2_combat_attack(_g,_enemy,3);return;
        case 5:ln2_combat_attack(_g,_enemy,4);return;
        case 7:ln2_combat_attack(_g,_enemy,5);return;
        case 8:ln2_combat_attack(_g,_enemy,6);return;
        case 9:if (!_enemy) ln2_item_interact(_g,0);return;
        case 10:if (!_enemy) ln2_item_interact(_g,1);return;
        case 11:if (!_enemy) ln2_item_interact(_g,2);return;
        case 13:ln2_damage(_g,44,false);return;
        case 14:ln2_combat_attack(_g,_enemy,-1);return;
        case 22:ln2_force_exit(_g,1);return;
        case 15:case 17:case 18:case 19:case 20:case 21:case 23:
            if (_g.level==2) {
                if (_event==17 || _event==18) _g.player.weapon=_g.player.selected_weapon;
                else if (abs(_g.player.x-(_event==20?219:124))<11 && abs(_g.player.y-(_event==20?143:115))<7)
                    ln2_damage(_g,44,false);
                return;
            }
            if (_g.level==5) {
                if (_event==15 || _event==21 || _event==23) {
                    if (_g.special_flag==0) { _g.special_count=(_g.special_count+1)&255;if (_g.special_count<4) return; }
                    ln2_enemy_special(_g,$c5b2);_g.inventory[21]=255;
                } else _g.player.weapon=_g.player.selected_weapon;
                return;
            }
            if (_g.level==6) {
                if (_event==15 || _event==23) {
                    if (_g.special_flag<128) return;
                    _g.special_flag=0;_g.player.action&=255;_g.exit_locked=false;ln2_fall_begin(_g,80,2);
                } else _g.player.weapon=_g.player.selected_weapon;
                return;
            }
            if (_g.level==7) {
                if (_event!=23) { _g.player.weapon=_g.player.selected_weapon;return; }
                ln2_spirit_motion(_g.enemy);return;
            }
            if ((_g.player.boundary_crossings&1) && (_g.player.combat_state&252)!=12) {
                _g.player.x=(_g.player.x+(_event==17?4:-4))&255;
                _g.player.y=(_g.player.y+1)&255;ln2_player_depth(_g.player,1);_g.player.redraw=255;
            }
            return;
    }
    var _key="action:"+string(_event);
    if (!array_contains(_g.pending_events,_key)) array_push(_g.pending_events,_key);
}
