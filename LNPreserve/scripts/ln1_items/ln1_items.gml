/// Source $5940: item interaction occurs at the action's input boundary.
function ln1_item_interact(_g) {
    var _p = _g.player;
    for (var _i = 0; _i < array_length(_g.world.items); _i++) {
        var _item = _g.world.items[_i];
        if (_item.room != _g.room_id || _g.inventory[_item.id] != 0) continue;
        var _x = _p.x - (_p.facing >= 4 ? 36 : 0);
        if (_x < _item.x_min || _x >= _item.x_max || _p.y < _item.y_min || _p.y >= _item.y_max) continue;
        if (_g.inventory[2] == 0 && _item.id != 2 && _item.id < 10) return;
        // The original $5940 treats these locations as mechanisms, not pickups.
        var _selected = is_struct(_g.controls) ? _g.controls.item : 10;
        if (_item.id == 1 && _selected != 6) {
            _p.input_lock = 255; _g.player_health = 0; return;
        }
        if (_item.id == 16 || _item.id == 18 || _item.id == 19) {
            if (_item.id == 16) _g.world_state.flag_b = 35;
            else {
                _g.world_state.protection = _item.id == 18 ? 5 : 2;
                if (_item.id == 19) _g.world_state.protection_tick = _p.tick;
            }
            _g.notice_item=10;_g.notice_tick=_p.tick;_g.notice_label=1;_g.notice_duration=150;
            return;
        }
        _g.inventory[_item.id] = _item.id == 14 ? 133 : (_item.id == 15 ? 3 : 1);
        if (_item.id == 9) _g.world_state.mode = 9;
        _g.notice_item = _item.id; _g.notice_tick = _p.tick;
        _g.notice_label = 1; _g.notice_duration = 150;
        if (is_struct(_g.controls)) {
            for (var _j = 0; _j < 11; _j++) _g.controls.inventory[_j] = _g.inventory[_j];
            for (var _j = 0; _j < 6; _j++) _g.controls.weapons[_j] = _g.inventory[10 + _j];
            _g.controls.action_reset = 150;
        }
        return;
    }
}
