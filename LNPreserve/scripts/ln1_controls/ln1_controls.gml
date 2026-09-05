/// Native LN1 selection logic from $6eac-$6f6c in the supplied CCS edition.
/// Rows have the same active-low bits as the original keyboard scan.
/// Dashboard drawing and SID writes are returned as requests to their adapters.
function ln1_controls_update(_s, _row0, _row7) {
    var _effects = [];
    var _masks = [16,32,64,8,16];
    var _press = array_create(5,false);
    for (var _k = 0; _k < 5; _k++) {
        var _value = (_k == 4 ? _row7 : _row0) & _masks[_k];
        _press[_k] = _value != _s.previous[_k] && _value == 0;
        _s.previous[_k] = _value;
    }
    // F1: toggle music and clear the 24 SID registers when turning it off.
    if (_press[0]) {
        _s.music = _s.music ^ 255;
        if (_s.music == 0) array_push(_effects,{kind:"sid_clear",a:0,x:23});
    }
    // F3/F5: skip inventory entries whose original byte is zero.
    for (var _direction = 0; _direction < 2; _direction++) {
        if (_press[1+_direction]) {
            var _found = false;
            repeat (11) {
                _s.item = (_s.item + (_direction == 0 ? 1 : 10)) mod 11;
                if (_s.inventory[_s.item] != 0) { _found = true; break; }
            }
            if (!_found) show_error("Invalid LN1 state: no selectable inventory entry",true);
            array_push(_effects,{kind:"dashboard_icon",a:_s.item,x:2});
        }
    }
    // F7: the original stores 0/$ff, not a host-frame pause timer.
    if (_press[3]) _s.pause = _s.pause ^ 255;
    // Space: select the next owned weapon, unless the original lock is set.
    if (_press[4] && _s.weapon_locked == 0) {
        var _found = false;
        repeat (6) {
            _s.weapon = (_s.weapon+1) mod 6;
            if ((_s.weapons[_s.weapon] & 127) != 0) { _found = true; break; }
        }
        if (!_found) show_error("Invalid LN1 state: no selectable weapon",true);
        _s.action_reset = 0;
        array_push(_effects,{kind:"dashboard_icon",a:_s.weapon+10,x:0});
        array_push(_effects,{kind:"weapon_panel",a:0,x:0});
    }
    return _effects;
}

function ln1_control_rows(_input) {
    var _row0 = 255, _row7 = 255;
    var _masks = [16,32,64,8];
    for (var _i = 0; _i < 4; _i++)
        if (_input.held[LNKey.F1+_i]) _row0 &= (255 ^ _masks[_i]);
    if (_input.held[LNKey.Weapon]) _row7 &= $ef;
    return [_row0,_row7];
}
