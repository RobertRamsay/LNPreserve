function ln_music_play(_game, _level, _loader) {
    var _role = _loader ? "loader" : "game";
    var _name = "snd_ln" + string(_game) + "_" + _level + "_" + _role;
    var _asset = asset_get_index(_name);
    if (_asset < 0) return -1;
    if (variable_global_exists("ln_music_voice") && global.ln_music_voice >= 0) {
        audio_stop_sound(global.ln_music_voice);
    }
    global.ln_music_voice = audio_play_sound(_asset, 0, true);
    return global.ln_music_voice;
}
