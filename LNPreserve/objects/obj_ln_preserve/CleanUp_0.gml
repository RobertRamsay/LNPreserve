if (variable_global_exists("ln_music_voice") && global.ln_music_voice >= 0) audio_stop_sound(global.ln_music_voice);
if (variable_instance_exists(id, "play") && surface_exists(play.stage_surface)) surface_free(play.stage_surface);
if (variable_instance_exists(id, "play") && play.game_number==3) ln3_ending_free(play);
if (variable_instance_exists(id, "play") && play.game_number==2) ln2_ending_free(play);

if (surface_exists(crt_surface)) surface_free(crt_surface);

if (variable_instance_exists(id,"rewind")) ln_rewind_clear(rewind);

ln_crt_preferences_flush(true);

ln_paint_free();
ln_edit_free_cache();ln_edit_free_preview();

ln_track_stop(global.ln_tracks);
ln_tool_free();

if(variable_instance_exists(id,"startup_sound") && startup_sound>=0) audio_stop_sound(startup_sound);
