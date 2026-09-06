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
