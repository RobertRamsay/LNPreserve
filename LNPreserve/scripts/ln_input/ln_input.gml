enum LNKey { Up, Down, Left, Right, Fire, F1, F3, F5, F7, Weapon, Count }

function LNInput() constructor {
    bindings = [ord("W"), ord("S"), ord("A"), ord("D"), ord("J"),
                ord("1"), ord("2"), ord("3"), ord("4"), vk_space];
    sampled = array_create(LNKey.Count, false);
    held = array_create(LNKey.Count, false);
    pressed = array_create(LNKey.Count, false);
    released = array_create(LNKey.Count, false);
    queue = [];
    head = 0;
    enqueue = function(_cycle, _action, _down) {
        array_push(queue, {cycle: int64(_cycle), action: _action, down: _down});
    };
    sample = function(_cycle) {
        for (var _i = 0; _i < LNKey.Count; _i++) {
            var _down = keyboard_check(bindings[_i]);
            if (_down != sampled[_i]) {
                enqueue(_cycle, _i, _down);
                sampled[_i] = _down;
            }
        }
    };
    consume = function(_through_cycle) {
        for (var _i = 0; _i < LNKey.Count; _i++) {
            pressed[_i] = false;
            released[_i] = false;
        }
        while (head < array_length(queue) && queue[head].cycle <= _through_cycle) {
            var _e = queue[head++];
            held[_e.action] = _e.down;
            if (_e.down) pressed[_e.action] = true;
            else released[_e.action] = true;
        }
        if (head == array_length(queue)) { queue = []; head = 0; }
    };
    joystick = function() {
        // Active-low CIA joystick bits. Opposites cancel; diagonals are preserved.
        var _value = 255;
        if (held[LNKey.Up] && !held[LNKey.Down]) _value &= ~1;
        if (held[LNKey.Down] && !held[LNKey.Up]) _value &= ~2;
        if (held[LNKey.Left] && !held[LNKey.Right]) _value &= ~4;
        if (held[LNKey.Right] && !held[LNKey.Left]) _value &= ~8;
        if (held[LNKey.Fire]) _value &= ~16;
        return _value;
    };
}
