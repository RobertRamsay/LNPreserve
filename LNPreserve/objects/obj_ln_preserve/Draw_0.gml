try {
if (!workbench) {
    if (scene_test.menu || scene_test.preview) { ln_scene_test_draw(scene_test); exit; }
    if (play.game_number==1) ln1_play_draw(play, control_state_ln1.pause != 0);else ln2_play_draw(play);
    if (scene_test.message_us > 0) {
        draw_set_colour(make_colour_rgb(125,210,171)); draw_text(160,12,scene_test.message); draw_set_colour(c_white);
    }
    if (selftest && host_frames == 2) {
        ln_run_mask_checks(); ln1_feedback_capture(); ln_scene_test_capture(catalog); ln1_level_capture();
        ln2_world_capture();
        ln1_play_draw(play, control_state_ln1.pause != 0);
    }
    if (selftest && host_frames == 3) {
        screen_save("lnpreserve-player.png");
        show_debug_message("LN_CAPTURE_DIRECTORY:" + game_save_id);
    }
    if (selftest && host_frames == 6) screen_save("lnpreserve-encounter.png");
    exit;
}
draw_clear(make_colour_rgb(20,23,28));
draw_set_colour(make_colour_rgb(125,210,171));
draw_text(32,24,"LN PRESERVE");
draw_set_colour(c_white);
draw_text(32,48,"Native GameMaker conversion workbench | Gameplay port incomplete");
var _dataset = catalog.datasets[dataset_index];
var _assets = view_mode == 0 ? _dataset.locations : _dataset.objects;
var _count = array_length(_assets);
draw_text(32,86,_dataset.id + "  |  " + string(dataset_index+1) + "/" + string(array_length(catalog.datasets)));
draw_set_colour(make_colour_rgb(165,173,184));
draw_text(32,110,"Source: " + _dataset.provenance);
draw_set_colour(c_white);
var _sx = 32, _sy = 160, _scale = 3;
draw_set_colour(make_colour_rgb(35,39,45));
draw_rectangle(_sx,_sy,_sx+768,_sy+480,false);
draw_set_colour(c_white);
if (_count > 0) {
    var _asset = _assets[asset_index];
    var _sprite = asset_get_index(_asset.sprite_name);
    draw_text(32,138,_asset.name + "  (" + string(asset_index+1) + "/" + string(_count) + ")");
    if (_sprite >= 0) draw_sprite_ext(_sprite,0,_sx,_sy,_scale,_scale,0,c_white,1);
    var _mask = -1;
    if (view_mode == 0) _mask = asset_get_index(_asset.mask_name);
    if (test_fixture) {
        _mask = spr_depth_fixture;
        draw_sprite_ext(spr_depth_fixture,0,_sx,_sy,_scale,_scale,0,make_colour_rgb(70,180,200),1);
    }
    if (view_mode == 0 || test_fixture) {
        if (!mask_enabled || (test_fixture && !ln_occluder_active(probe_y,120))) _mask = -1;
        var _mw = _mask >= 0 ? sprite_get_width(_mask)*_scale : 720;
        var _mh = _mask >= 0 ? sprite_get_height(_mask)*_scale : 432;
        ln_draw_masked_actor(spr_depth_probe,0,_sx+probe_x*_scale,_sy+(probe_y-40-probe_jump)*_scale,
                            _scale,_scale,_mask,_sx,_sy,_mw,_mh);
    }
}
draw_set_colour(make_colour_rgb(125,210,171));
draw_text(838,160,"INSPECT THE CONVERSION");
draw_set_colour(c_white);
if (selftest && host_frames == 2) ln_run_mask_checks();
draw_text(838,194,"Q / E   Previous / next dataset");
draw_text(838,222,"Left / Right   Previous / next asset");
draw_text(838,250,"Tab   Scene / object view");
draw_text(838,292,"WASD   Move the mask probe");
draw_text(838,320,"J   Fire input / lift probe");
draw_text(838,348,"Space   Weapon input");
draw_text(838,376,"1 2 3 4   F1 F3 F5 F7 input");
draw_text(838,418,"M   Mask " + (mask_enabled ? "on" : "off"));
draw_text(838,446,"T   Synthetic mask fixture " + (test_fixture ? "on" : "off"));
draw_text(838,496,"PAL frames: " + string(clock.frame));
draw_text(838,522,"Cycles: " + string(clock.cycle));
draw_text(838,548,"Weapon presses: " + string(weapon_presses));
draw_text(838,574,"F-key presses: " + string(function_presses));
draw_text(838,604,"LN1 selected weapon: " + string(control_state_ln1.weapon));
draw_text(838,630,"LN1 music / pause: " + string(control_state_ln1.music) + " / " + string(control_state_ln1.pause));
draw_set_colour(make_colour_rgb(245,190,100));
draw_text(32,666,"Scene previews and masks are diagnostic. Original gameplay parity has not passed.");
draw_set_colour(make_colour_rgb(165,173,184));
draw_text(32,696,"Scenery objects are editable PNG sprite resources. Yellow rectangle = synthetic depth probe.");
draw_text(32,724,"Silent level/loader sound assets are in Music placeholders. Replace their WAVs in GameMaker.");
draw_text(32,752,"See README and evidence/STATUS.json for verified extraction and remaining work.");
draw_set_colour(c_white);
if (selftest && host_frames == 3) {
    surface_save(application_surface,"lnpreserve-workbench.png");
    show_debug_message("LN_CAPTURE_DIRECTORY:" + game_save_id);
}

} catch (_runtime_failure) {
    if (!selftest) throw _runtime_failure;
    shader_reset();
    show_debug_message("LN_RUNTIME_FAILURE: " + string(_runtime_failure));
    game_end();
}
