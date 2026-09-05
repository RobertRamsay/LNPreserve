/// The original two projectile slots, translated from $50ec/$5130/$76fc.
function LN1Projectile() constructor {
    active=0;life=0;x=0;y=0;facing=1;animation_tick=0;
}

function ln1_projectile_launch(_g,_enemy,_kind,_life) {
    var _slot=_enemy?1:0,_a=_enemy?_g.enemy:_g.player,_shot=_g.projectiles[_slot],_d=_g.projectile_data;
    if (_shot.active!=0) return false;
    var _dx=_d.launch[_a.facing];if (_dx>=128) _dx-=256;
    var _x=_a.x+_dx;if (_x<0 || _x>255) return false;
    _shot.active=_kind;_shot.life=_life;_shot.facing=_a.facing;_shot.x=_x;
    _shot.y=(_a.y+_d.launch[_a.facing+1])&255;
    if (_enemy) _g.enemy.projectile_active=_kind;
    return true;
}

function ln1_projectile_player_request(_g) {
    if (_g.projectiles[0].active!=0) return;
    var _p=_g.player,_kind=0;
    if (_p.weapon==0 && is_struct(_g.controls) && _g.controls.item==3) _kind=3;
    else if (_p.weapon==4 || _p.weapon==5) {
        var _item=_p.weapon+10;
        if ((_g.inventory[_item]&127)==0) return;
        _g.inventory[_item]--;
        _kind=_p.weapon==4?1:2;
        if ((_g.inventory[_item]&127)==0) { _p.weapon=0;_p.selected_weapon=0; }
        ln1_level_sync_controls(_g);
    }
    if (_kind!=0) ln1_projectile_launch(_g,false,_kind,_kind==1?255:86);
}

function ln1_projectile_tick(_g) {
    var _d=_g.projectile_data;
    for (var _slot=1;_slot>=0;_slot--) {
        var _s=_g.projectiles[_slot];
        if (_s.active==0) continue;
        _s.life=(_s.life-1)&255;
        if (_s.life==0) { _s.active=0;continue; }
        var _kind=_s.active&3;
        if (_s.life>=64) {
            var _index=_s.facing+(_kind==1?0:8),_dx=_d.step[_index];
            if (_dx>=128) _dx-=256;
            var _nx=_s.x+_dx;
            if (_nx<0 || _nx>255) { _s.active=0;continue; }
            _s.x=_nx;
            if (_s.x<8 || _s.x>=245) { _s.active=0;continue; }
            _s.y=(_s.y+_d.step[_index+1])&255;
            if (_s.y<34 || _s.y>=177) { _s.active=0;continue; }
        }
        var _target=_slot==1?_g.player:_g.enemy;
        if (_g.enemy.active>=128 && (_target.combat_state&252)!=36 && (_target.combat_state&252)!=12) {
            if (_kind==1 && (_slot==1 || _g.enemy.active<133)) {
                if (abs(_target.y-_s.y)<8 && abs(_target.x-_s.x)<6) {
                    if (_slot==1) { _g.player_health=max(0,_g.player_health-16);ln1_combat_hurt(_g,false); }
                    else { _g.enemy.wounds=32;_g.room_wounds[_g.room_id]=32;ln1_combat_hurt(_g,true); }
                    _s.active=0;
                }
            } else if (_kind!=1 && _s.life<64) {
                if (_g.enemy.active<133) {
                    if (abs(((_target.y+16)&255)-_s.y)<16 && abs(_target.x-_s.x)<12 && (_g.enemy.combat_state&252)!=36) {
                        ln1_level_enemy_action(_g,_g.data.reactions[10+((_g.enemy.facing&4)>>2)]);
                        _g.enemy.mode=7;_g.enemy.separation_y=4;
                    }
                } else if (_g.enemy.active==137 && abs(((_target.y+16)&255)-_s.y)<8 && abs(_target.x-_s.x)<6) {
                    if (_g.world_state.mode!=5 && variable_struct_exists(_g.data,"dragon_smoke_action")) {
                        _g.world_state.mode=5;_g.enemy.separation_y=2;
                        ln1_level_enemy_action(_g,_g.data.dragon_smoke_action);
                    }
                    _s.active=0;
                }
            }
        }
        if (_s.active && ((_g.player.tick-_s.animation_tick)&255)>=_d.animation_periods[_slot]) {
            _s.active=_s.life>=64?(_s.active^4):((_s.active+4)&31);
            _s.animation_tick=_g.player.tick;
        }
    }
    _g.enemy.projectile_active=_g.projectiles[1].active;
}

function ln1_projectile_draw(_g) {
    for (var _slot=0;_slot<2;_slot++) {
        var _s=_g.projectiles[_slot];if (!_s.active) continue;
        var _d=_g.projectile_data,_kind=_s.active&3;
        var _sprite=asset_get_index(_s.life>=64?_d.flight_sprite:_d.cloud_sprite);
        var _frame=_s.life>=64?(_s.active-1):(_s.active>>2);
        draw_sprite(_sprite,_frame,_s.x+_d.draw_x[_kind]-24,_s.y+_d.draw_y[_kind]-50);
    }
}
