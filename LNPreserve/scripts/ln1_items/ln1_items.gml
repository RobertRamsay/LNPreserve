/// Source $5940: item interaction occurs at the action's input boundary.
function ln1_item_interact(_g) {
    var _p = _g.player;
    for (var _i = 0; _i < array_length(_g.world.items); _i++) {
        var _item = _g.world.items[_i];
        if (_item.room != _g.room_id || _g.inventory[_item.id] != 0) continue;
        var _x = _p.x - (_p.facing >= 4 ? 36 : 0);
        if (_x < _item.x_min || _x >= _item.x_max || _p.y < _item.y_min || _p.y >= _item.y_max) continue;
        if (_g.inventory[2] == 0 && _item.id != 2 && _item.id < 10) return;
        _g.inventory[_item.id] = _item.id == 14 ? 133 : (_item.id == 15 ? 3 : 1);
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
