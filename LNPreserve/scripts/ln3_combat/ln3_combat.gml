function ln3_combat_reaction(_data,_action,_attack) {
    for (var _i=6;_i>=0;_i--) if (_data.reaction_stances[_i]==_action) return _data.reactions_low[_attack];
    return _data.reactions_high[_attack];
}

function ln3_score_add(_s,_data,_weapon) {
    var _points=_data.score_awards[_weapon],_carry=0;
    for (var _i=5;_i>=0;_i--) {
        var _value=(_s.score_digits[_i]&15)+_points[_i]+_carry;_carry=_value>=10;
        if (_carry) _value-=10;
        _s.score_digits[_i]=_value|48;
    }
}

function ln3_combat_damage_player(_s,_actions,_data) {
    var _weapon=_s.enemy_weapon==4?0:_s.enemy_weapon;
    _s.player_health=max(0,_s.player_health-_data.enemy_damage[_weapon]);_s.inventory[26]=_s.player_health;
    if (_s.player_health!=0) return;
    _s.player_dead=(_s.player_dead-1)&255;_s.joy=0;_s.death_wait=50;
    var _action=39;
    for (var _i=8;_i>=0;_i--) if (_s.enemy_action==_data.enemy_kneel_actions[_i]) {_action=40;break;}
    ln3_action_set(_s,_actions,_action,true);
}

function ln3_combat_damage_enemy(_s,_data) {
    var _weapon=_s.player_weapon,_damage=_data.player_damage[_weapon];
    if (_s.room_id==13) {
        var _sum=(_s.boss_honour+_damage)&255;
        _s.boss_honour=_sum<26?_sum:_s.honour;
        if (_sum<26) {ln3_score_add(_s,_data,_weapon);return;}
    }
    _s.enemy_health=max(0,_s.enemy_health-_damage);
    if (_s.enemy_health==0) {
        _s.enemy_dead=(_s.enemy_dead-1)&255;_s.enemy_flash_mode^=3;_s.enemy_flash=_s.enemy_flash_mode;
        if (_s.room_id==13) {_s.level_sequence=3;_s.level_requested=true;return;}
    }
    var _lose=true;
    if ((_weapon==0 || _weapon==_s.enemy_weapon) && _s.honour<40) {
        _s.honour_fraction=(_s.honour_fraction+1)&3;
        if (_s.honour_fraction==0) _s.honour=(_s.honour+1)&255;
        _lose=false;
    }
    if (_lose && _s.honour!=0) {
        _s.honour_fraction=(_s.honour_fraction-1)&3;
        if (_s.honour_fraction==0) _s.honour=(_s.honour-1)&255;
    }
    _s.inventory[25]=_s.honour;ln3_score_add(_s,_data,_weapon);
}

function ln3_combat_update(_s,_actions,_data) {
    if (_s.enemy_behavior>=128 || _s.near_enemy==0) return;
    _s.joy=0;
    if (_s.player_dead==0) {
        for (var _i=7;_i>=0;_i--) {
            if (_s.enemy_action-39!=_data.attack_actions[_i]) continue;
            if (_s.parts[5].cursor==_data.attack_cursors[_i]) {
                if (_s.player_action_flags>=128) ln3_combat_damage_player(_s,_actions,_data);
                else if (_s.player_action<14) {
                    ln3_action_set(_s,_actions,ln3_combat_reaction(_data,_s.player_action,_i));
                    ln3_combat_damage_player(_s,_actions,_data);
                }
            }
            break;
        }
    }
    if ((_s.enemy_dead|_s.player_dead)!=0) return;
    for (var _i=7;_i>=0;_i--) {
        if (_s.player_action!=_data.attack_actions[_i]) continue;
        if (_s.parts[1].cursor!=_data.attack_cursors[_i] || (((_s.mirror<<4)^_s.mirror)&96)==0) return;
        if (_s.enemy_action_flags<128) {
            if (_s.enemy_action>=53) return;
            ln3_action_set(_s,_actions,39+ln3_combat_reaction(_data,_s.enemy_action-39,_i),true);
        }
        ln3_combat_damage_enemy(_s,_data);return;
    }
}

function ln3_projectile_hits(_s,_data) {
    var _p=_s.parts[3],_target=_s.parts[5];
    if (!(_data.projectile_hazard_exempt && _s.parts[4].animation==138) && _p.animation==114 && _s.enemy_dead==0 && (_s.enabled&96)!=0) {
        var _dx=_p.x-_target.x,_dy=_p.y-_target.y;
        if (_dx>=0 && _dx<24 && _dy>=0 && _dy<21) {
            _p.animation=0;_p.move_mode=0;_s.enemy_health=0;_s.enabled&=247;_s.enemy_dead=(_s.enemy_dead-1)&255;
        }
    }
    _p=_s.parts[7];_target=_s.parts[1];
    if (_p.animation!=114 || _s.player_action==28 || _s.player_action==29) return;
    var _dx=_target.x-_p.x,_dy=_p.y-_target.y;
    if (_dx>=0 && _dx<24 && _dy>=0 && _dy<21) {
        _p.animation=0;_p.move_mode=0;_s.player_health=0;_s.inventory[26]=0;_s.enabled&=127;_s.player_dead=(_s.player_dead+1)&255;
    }
}
