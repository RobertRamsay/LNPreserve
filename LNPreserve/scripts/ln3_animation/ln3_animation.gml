function ln3_signed_offset(_value) {return (_value&128)?-(_value&127):_value;}

function ln3_animation_head(_s,_data,_i) {
    if (_i!=0 && _i!=4) return;
    var _p=_s.parts[_i],_enemy=_i==4;
    if (_p.animation==0 || (!_enemy && _p.animation==115) || (_enemy && _data.hazard_actor_exempt && _p.animation==138)) return;
    var _mask=1<<_i;_s.mirror&=255^_mask;_s.mirror|=(_s.mirror>>1)&_mask;
    var _action=_enemy?_s.enemy_action:_s.player_action;
    var _lying=(_action==(_enemy?59:20) && _p.cursor>=1) || (_action==(_enemy?60:21) && _p.cursor<2);
    var _anchor=_s.parts[_i+(_lying?2:1)];_p.x=_anchor.x;_p.y=_anchor.y;
}

function ln3_animation_offset(_s,_data,_i) {
    if (_i==3 || _i==7) return;
    var _p=_s.parts[_i],_offsets=_data.sequences[_p.animation].offsets;
    if (array_length(_offsets)>0) {
        var _o=_offsets[_p.cursor],_x=_o[0];
        if (_s.mirror&_data.masks[_i]) _x^=128;
        _p.x=(_p.x+ln3_signed_offset(_x))&255;_p.y=(_p.y+ln3_signed_offset(_o[1]))&255;
    } else if (_i==6 && _s.enemy_action_flags<128 && _p.animation<138) _s.parts[5].x=_p.x;
}

function ln3_animation_visibility(_s,_i) {
    if (_i!=2 && _i!=6) return;
    var _enemy=_i==6,_action=_enemy?_s.enemy_action:_s.player_action,_cursor=_s.parts[_i].cursor;
    if (_action==(_enemy?59:20)) {
        _s.enabled|=_enemy?112:7;
        if (_cursor>=1) _s.enabled&=_enemy?95:245;
    } else if (_action==(_enemy?60:21)) {
        _s.enabled|=_enemy?96:7;
        if (_cursor<2) _s.enabled&=_enemy?95:245;
    }
}

function ln3_animation_weapon(_s,_data,_enemy) {
    var _body=_enemy?5:1,_part=_enemy?7:3,_p=_s.parts[_part],_torso=_s.parts[_body],_mask=1<<_part;
    if ((!_enemy && _torso.animation==115) || _p.animation==114) return;
    _s.enabled&=255^_mask;
    var _action=_enemy?_s.enemy_action:_s.player_action;
    var _change=_action-(_enemy?57:18);
    if (_change>=0 && _change<2) {
        if (_enemy) {if (_torso.cursor<_data.weapon_change_cursors[_change]) return;}
        else if (_torso.cursor==_data.weapon_change_cursors[_change]) _s.player_weapon=_s.pending_weapon;
    }
    var _weapon=_enemy?_s.enemy_weapon:_s.player_weapon;
    if (_weapon==0 || _weapon>=4 || (!_enemy && _s.inventory[_weapon-1]==0)) return;
    var _index=-1;
    for (var _i=54;_i>=0;_i--) if (_data.weapon_frames[_i]==_torso.frame) {_index=_i;break;}
    if (_index<0) return;
    var _pose=_data.weapon_poses[_index+_data.weapon_offsets[_weapon]];
    for (var _i=11;_i>=0;_i--) {
        var _over=_data.weapon_overrides[_i];
        if (_over.action==_action-(_enemy?39:0) && _over.cursor==_torso.cursor) {_pose=_over.poses[_weapon-1];break;}
    }
    _p.animation=_pose.animation;_p.colour=0;_p.move_mode=0;
    if (!_enemy) _p.cursor=0;
    _s.enabled|=_mask;_s.mirror&=255^_mask;_s.mirror|=(_s.mirror<<1)&_mask;
    var _x=_pose.offset[0];if (_s.mirror&(1<<_body)) _x^=128;
    _p.x=(_torso.x+ln3_signed_offset(_x))&255;_p.y=(_torso.y+ln3_signed_offset(_pose.offset[1]))&255;
}

function ln3_animation_throw(_s,_data,_enemy) {
    var _body=_enemy?5:1,_part=_enemy?7:3,_p=_s.parts[_part],_torso=_s.parts[_body],_mask=1<<_part;
    if (_p.animation==114 || (_enemy?_s.enemy_weapon:_s.player_weapon)!=4 || (_enemy && _s.near_enemy!=0)) return;
    var _action=_enemy?_s.enemy_action:_s.player_action,_choices=_enemy?_data.throw_enemy_actions:_data.throw_player_actions;
    for (var _i=1;_i>=0;_i--) {
        if (_action!=_choices[_i]) continue;
        if (_torso.frame!=_data.throw_frames[_i]) return;
        if (!_enemy) {
            _s.ammo=(_s.ammo-1)&255;_s.inventory[28]=_s.ammo;
            if (_s.ammo>=128) {_s.player_weapon=0;_s.inventory[3]=0;return;}
        }
        var _facing=(_s.mirror>>(_enemy?5:1))&1;
        _p.move_mode=128|(9+2*_i+_facing);_p.animation=114;_p.cursor=0;_p.colour=1;
        _s.enabled|=_mask;_s.mirror&=255^_mask;_s.mirror|=(_s.mirror<<1)&_mask;
        _p.x=_torso.x;_p.y=_torso.y;return;
    }
}

function ln3_animation_update(_s,_data) {
    _s.draw_frames=array_create(8,-1);_s.draw_x=array_create(8,-1);_s.draw_y=array_create(8,-1);
    _s.draw_colours=array_create(8,-1);_s.draw_mirror=array_create(8,-1);
    for (var _order=0;_order<8;_order++) {
        var _i=_data.order[_order],_mask=_data.masks[_i],_p=_s.parts[_i];
        _s.drawn_mask&=255^_mask;
        if (!(_s.enabled&_mask)) continue;
        var _seq=_data.sequences[_p.animation],_length=array_length(_seq.frames);
        if (_p.cursor>=_length) _p.cursor=_seq.loop?0:_length-1;
        _p.frame=_seq.frames[_p.cursor];
        if (_p.cursor+1>=_length) {
            if (_i==1) _s.player_action_flags=1;
            if (_i==5) _s.enemy_action_flags=5;
        }
        ln3_animation_head(_s,_data,_i);ln3_animation_offset(_s,_data,_i);ln3_animation_visibility(_s,_i);
        if (_i==1) {ln3_animation_weapon(_s,_data,false);ln3_animation_throw(_s,_data,false);}
        if (_i==5 && !(_data.hazard_actor_exempt && _s.parts[4].animation==138)) {
            ln3_animation_weapon(_s,_data,true);ln3_animation_throw(_s,_data,true);
        }
        _s.draw_frames[_i]=_p.frame;_s.draw_x[_i]=_p.x;_s.draw_y[_i]=_p.y;
        _s.draw_colours[_i]=_p.colour;_s.draw_mirror[_i]=(_s.mirror&_mask)!=0;
        _s.drawn_mask|=_mask;
        if (_p.animation==115 || (_i!=3 && _i!=7)) _p.cursor=(_p.cursor+1)&255;
    }
    _s.draw_buffer^=1;
}
