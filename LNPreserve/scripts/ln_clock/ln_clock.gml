/// PAL clock transport. This alone does NOT establish cycle-accurate gameplay.
/// Integer timing matches the PAL machine constants used by VICE.
function LNClock() constructor {
    hz = 985248;
    cycles_per_frame = 19656;
    credit = int64(0);
    cycle = int64(0);
    frame = 0;
    paused = false;
    advance = function(_microseconds, _tick, _limit = 8) {
        if (paused) return 0;
        credit += int64(max(0, floor(_microseconds))) * int64(hz);
        var _cost = int64(cycles_per_frame) * int64(1000000);
        var _count = 0;
        while (credit >= _cost && _count < _limit) {
            var _end = cycle + cycles_per_frame;
            _tick(cycle, _end, frame);
            cycle = _end;
            frame++;
            credit -= _cost;
            _count++;
        }
        // Keep all debt: a slow host must never silently skip original updates.
        return _count;
    };
    reset = function() { credit = int64(0); cycle = int64(0); frame = 0; };
}
