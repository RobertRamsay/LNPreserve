function ln3_item_proximity(_s,_record) {
    var _item=_record[0];if (_s.weapon_fx_request!=0 || _item==25) return;
    var _dx=abs(_record[1]-_s.parts[2].x),_dy=abs(_record[3]-_s.parts[2].y);
    if (_dx<24 && _dy<24) {
        if (_s.weapon_fx_state==5) return;
        _s.weapon_fx_request=(_s.weapon_fx_request+1)&255;_s.enemy_pending_weapon=_item;
        return;
    }
    if (_s.weapon_fx_state==5 && _s.enemy_pending_weapon==_item) _s.weapon_fx_request=(_s.weapon_fx_request+1)&255;
}

function ln3_item_notice(_s,_data,_item) {
    _s.portrait_visible=1;_s.weapon_notice_timer=200;_s.notice_icon=255;
    ln3_score_add(_s,_data,0);return _item;
}

function ln3_items_update(_s,_data,_records) {
    for (var _i=0;_i<array_length(_records);_i++) {
        var _r=_records[_i],_item=_r[0];
        if (_data.level==1 && _item==25) { }
        else {
            if (_s.inventory[_item]!=0) continue;
            if (_data.level==1 && _item==6 && _s.special_scene_phase<2) {ln3_item_proximity(_s,_r);continue;}
            if (_data.level==1 && _item==3 && _s.room_id==2 && _s.ammo_pile>=128) continue;
        }
        var _p=_s.parts[2];
        if (_p.x<_r[1] || _p.x>_r[2] || _p.y<_r[3] || _p.y>_r[4]) {ln3_item_proximity(_s,_r);continue;}
        if (_s.player_action<26 || _s.player_action>=28 || _s.parts[1].cursor!=3) continue;
        if (_data.level==1 && _item==25) {
            if (_s.special_scene_phase!=0 || _s.selected_item!=13) continue;
            _s.inventory[13]=128;_s.special_wait=50;_s.special_scene_phase=(_s.special_scene_phase+1)&255;return -1;
        }
        if (_item==21) {
            _s.lives=(_s.lives+1)&255;_s.inventory[27]=_s.lives;
            _s.inventory[21]=128;_s.player_health=44;_s.inventory[26]=44;
        } else if (_data.level==1) {
            if (_item==9 || _item==10) {
                _s.inventory[_item]=(_s.inventory[_item]+1)&255;
                if ((_s.inventory[9]^_s.inventory[10])!=0) return ln3_item_notice(_s,_data,_item);
                _s.inventory[9]=128;_s.inventory[10]=128;_item=2;
            } else if (_item==3) {
                _s.ammo=4;_s.inventory[28]=4;
                if (_s.room_id==2) _s.ammo_pile=(_s.ammo_pile-1)&255;
            } else if (_item==12) {
                if (_s.inventory[4]==0) continue;
                _s.inventory[12]=(_s.inventory[12]+1)&255;_s.inventory[12]=128;_s.inventory[4]=128;_item=13;
            } else if (_item==7 || _item==8) {
                _s.inventory[_item]=(_s.inventory[_item]+1)&255;
                if ((_s.inventory[7]^_s.inventory[8])!=0) return ln3_item_notice(_s,_data,_item);
                _s.inventory[7]=128;_s.inventory[8]=128;_item=17;
            }
        } else if (_data.level==3 && _item==14) {
            _s.inventory[14]=128;_s.ammo=4;_s.inventory[28]=4;_item=3;
        }
        _s.inventory[_item]=(_s.inventory[_item]+1)&255;
        return ln3_item_notice(_s,_data,_item);
    }
    return -1;
}
