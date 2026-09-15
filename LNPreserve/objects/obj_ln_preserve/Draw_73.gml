if(startup_active) {ln_tool_present(self);exit;}
draw_set_font(font_jansina);
if(!(global.ln_editor.open || editor_test || global.ln_tracks.open || global.ln_sprites.open)) {
if (!presentation_test) {
    ln_crt_present(self);
    if(scene_test.menu && (!global.ln_tool.active || ln_tool_ui_visible())) {ln_paint_slider();draw_set_colour(c_white);draw_text(862,648,"F6 Scene editor");}
    if (rewind.active) {draw_set_colour(c_white);draw_text(160,12,"REWIND");}
    if (ln_crt_controls_visible(self)) {
        ln_crt_sliders_draw(!scene_test.menu);ln_window_buttons(!scene_test.menu);
        if (scene_test.menu) ln_crt_button();
    }
}

}
ln_tool_present(self);
if(track_player_test) {surface_save(application_surface,"track-player.png");show_debug_message("LN_TRACK_CAPTURE:"+game_save_id);}

if(sprite_viewer_test) {surface_save(application_surface,"sprite-viewer-"+string(global.ln_sprites.game)+"-"+string(global.ln_sprites.category)+".png");show_debug_message("LN_SPRITE_CAPTURE:"+game_save_id);}
