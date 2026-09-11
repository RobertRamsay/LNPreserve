function ln2_score_digits_add(_digits,_amount,_low=false) {
    var _index=_low?4:3,_carry=0;
    for (var _i=_index;_i>=0;_i--) {
        var _add=_i==_index?(_amount&15):(_i==_index-1?(_amount>>4):0);
        var _value=_digits[_i]-27+_add+_carry;_carry=_value>=10;
        _digits[_i]=27+(_value>=10?_value-10:_value);
    }
    return _digits;
}

function ln2_score_add(_g,_amount,_low=false) {_g.status.score=ln2_score_digits_add(_g.status.score,_amount,_low);}

function ln2_status_clock(_s,_limits) {
    if (_s.running==0 || _s.blocked!=0) return;
    _s.fraction++;if (_s.fraction<50) return;_s.fraction=0;
    for (var _i=5;_i>=0;_i--) {
        _s.digits[_i]++;if (_s.digits[_i]<_limits[_i]) break;
        _s.digits[_i]=27;
    }
    _s.dirty=255;
}

function ln2_status_health(_s) {
    if (_s.blocked!=0 || (_s.tick&1)) return;
    for (var _i=0;_i<2;_i++) _s.display[_i]+=sign(_s.target[_i]-_s.display[_i]);
}

function ln2_status_tick(_g,_tick) {
    ln2_status_clock(_g.status.clock,_g.status_data.clock_limits);
    var _s={tick:_tick,blocked:0,target:[_g.player_health,_g.enemy.health],display:_g.status.health};
    ln2_status_health(_s);_g.status.health=_s.display;
}

function ln2_status_digits(_digits) {
    var _text="";for (var _i=0;_i<array_length(_digits);_i++) _text+=string(_digits[_i]-27);return _text;
}

function ln2_status_checks() {
    var _o=ln3_data_read("verification/ln2_status_vectors.json"),_d=ln3_data_read("play/ln2/status.json");
    for (var _i=0;_i<array_length(_o.score);_i++) {
        var _v=_o.score[_i],_digits=ln2_score_digits_add(_v.digits,_v.amount,_v.low);
        for (var _j=0;_j<6;_j++) ln_check(_digits[_j]==_v.expected[_j],"LN2 original score digit "+string(_i));
    }
    for (var _i=0;_i<array_length(_o.clock);_i++) {
        var _v=_o.clock[_i],_s=_v.before;ln2_status_clock(_s,_d.clock_limits);ln3_state_check(_s,_v.expected,"LN2 original elapsed clock "+string(_i));
    }
    for (var _i=0;_i<array_length(_o.health);_i++) {
        var _v=_o.health[_i],_s=_v.before;ln2_status_health(_s);
        for (var _j=0;_j<2;_j++) ln_check(_s.display[_j]==_v.expected[_j],"LN2 original health-display state "+string(_i));
    }
    show_debug_message("LN2_STATUS_PASS: 6144 original score, clock and health-display states; raster and complete score-event dispatch excluded.");
}

/// Original C64 dashboard, drawn around the 240x144 playfield at integer scale.
function ln2_status_draw(_g,_x,_y,_scale) {
    draw_set_colour(c_white);
    draw_sprite_ext(spr_ln2_dashboard,0,_x,_y,_scale,_scale,0,c_white,1);
    draw_sprite_ext(spr_ln2_player_health,clamp(round(_g.status.health[0]),0,44),_x+64*_scale,_y+152*_scale,_scale,_scale,0,c_white,1);
    draw_sprite_ext(spr_ln2_enemy_health,clamp(round(_g.status.health[1]),0,44),_x+16*_scale,_y+152*_scale,_scale,_scale,0,c_white,1);
    var _icons=asset_get_index("spr_ln2_level"+string(_g.level)+"_status_icons");
    draw_sprite_ext(_icons,clamp(_g.player.selected_weapon,0,4),_x+264*_scale,_y+24*_scale,_scale,_scale,0,c_white,1);
    var _found=_g.notice_item>=0,_item=_found?_g.notice_item:_g.selected_item;
    draw_sprite_ext(spr_ln2_status_labels,real(_found),_x+248*_scale,_y+56*_scale,_scale,_scale,0,c_white,1);
    if (_item==10) draw_sprite_ext(spr_ln2_molotov_states,ln2_molotov_frame(_g),_x+264*_scale,_y+72*_scale,_scale,_scale,0,c_white,1);
    else if (_item==16) draw_sprite_ext(spr_ln2_orb_icon,0,_x+264*_scale,_y+72*_scale,_scale,_scale,0,c_white,1);
    else draw_sprite_ext(_icons,clamp(_item,0,16),_x+264*_scale,_y+72*_scale,_scale,_scale,0,c_white,1);
    for (var _i=0;_i<6;_i++) {
        draw_sprite_ext(spr_ln2_status_digits,clamp(_g.status.score[_i]-27,0,9),_x+(136+8*_i)*_scale,_y+160*_scale,_scale,_scale,0,c_white,1);
        draw_sprite_ext(spr_ln2_status_digits,clamp(_g.status.clock.digits[_i]-27,0,9),_x+(128+8*(_i+(_i div 2)))*_scale,_y+176*_scale,_scale,_scale,0,c_white,1);
    }
}

function ln2_hud_hash(_g,_surface,_rect) {
    surface_set_target(_surface);draw_clear(c_black);ln2_status_draw(_g,0,0,1);surface_reset_target();
    var _sum=0.0;
    for (var _y=_rect[1];_y<_rect[3];_y++) for (var _x=_rect[0];_x<_rect[2];_x++) _sum+=surface_getpixel(_surface,_x,_y)*(_x+3*_y+1);
    return _sum;
}

function ln2_hud_checks() {
    ln2_status_checks();
    var _g=new LN2Play(1),_s=surface_create(320,200);
    var _rects=[[64,152,104,192],[16,152,56,192],[264,24,304,56],[264,72,304,104],[248,56,312,64],[136,160,184,168],[128,176,192,184]];
    for (var _i=0;_i<7;_i++) {
        var _before=ln2_hud_hash(_g,_s,_rects[_i]);
        switch (_i) {
            case 0:_g.status.health[0]=0;break;
            case 1:_g.status.health[1]=0;break;
            case 2:_g.inventory[1]=255;ln2_controls_update(_g,255,239);break;
            case 3:_g.inventory[7]=255;ln2_controls_update(_g,223,255);break;
            case 4:_g.notice_item=7;break;
            case 5:ln2_score_add(_g,$50);break;
            case 6:repeat(50) ln2_status_clock(_g.status.clock,_g.status_data.clock_limits);break;
        }
        ln_check(ln2_hud_hash(_g,_s,_rects[_i])!=_before,"each original HUD field responds to live game state: "+string(_i));
    }
    surface_free(_s);
    _g.status.health=[31,17];_g.status.score=[28,29,30,31,32,33];_g.status.clock.digits=[27,28,29,30,31,32];
    _g.notice_item=-1;ln2_play_draw(_g);surface_save(application_surface,"lnpreserve-ln2-hud.png");
    show_debug_message("LN2_HUD_PASS: original dashboard, health spirals, weapon/item controls, found notice, score and clock");
}
