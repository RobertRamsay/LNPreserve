if (variable_global_exists("ln_music_voice") && global.ln_music_voice >= 0) audio_stop_sound(global.ln_music_voice);
if (variable_instance_exists(id, "play") && surface_exists(play.stage_surface)) surface_free(play.stage_surface);
