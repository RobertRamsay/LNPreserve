/// Where LNPreserve's playfield (the land) sits on the 1920x1080 canvas: [x, y, w, h].
/// Used by obj_ai_restyle so only the scenery is restyled; the C64 dashboard/HUD,
/// panels and text stay untouched.
/// A width of 0 means "show the normal game" (startup, workbench, menus, editors, viewers).
function ln_ai_region() {
    var _none = [0, 0, 0, 0];
    var _host = instance_find(obj_ln_preserve, 0);
    if (_host == noone) {
        return _none;
    }
    if (!global.ln_tool.active) {
        return _none;
    }
    if (_host.startup_active) {
        return _none;
    }
    if (global.ln_editor.open || global.ln_sprites.open || global.ln_tracks.open) {
        return _none;
    }
    var _region = ln_crt_game_region(_host);
    if (!is_array(_region)) {
        return _none;
    }
    var _rect = [_region[0], _region[1], _region[2] - _region[0], _region[3] - _region[1]];

    // In play, all three games draw the 240x144 stage at 160,84 at 3x (720x432),
    // with the dashboard around it. Full-screen scenes (intro, ending, victory) keep the whole picture.
    if (_region[0] == 160 && _region[1] == 84) {
        _rect = [160, 84, 720, 432];
    }

    // UI visible: the 1280x800 tool surface is drawn at 320,140
    if (ln_tool_ui_visible()) {
        return [320 + _rect[0], 140 + _rect[1], _rect[2], _rect[3]];
    }

    // UI hidden: the whole game region is scaled and centred (see ln_game_view),
    // so place the stage inside that view at the same scale
    var _full = [_region[0], _region[1], _region[2] - _region[0], _region[3] - _region[1]];
    var _view = ln_game_view(_host, _full);
    var _scale = _view[4];
    return [_view[0] + (_rect[0] - _full[0]) * _scale, _view[1] + (_rect[1] - _full[1]) * _scale, _rect[2] * _scale, _rect[3] * _scale];
}
