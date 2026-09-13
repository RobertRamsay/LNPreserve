if(global.ln_editor.open || editor_test) exit;
if (!presentation_test) {
    ln_crt_present(self);
    if(scene_test.menu) {ln_paint_slider();draw_set_colour(c_white);draw_text(862,648,"F6 Scene editor");}
    if (rewind.active) {draw_set_colour(c_white);draw_text(160,12,"REWIND");}
    if (ln_crt_controls_visible(self)) {
        ln_crt_sliders_draw(!scene_test.menu);ln_window_buttons(!scene_test.menu);
        if (scene_test.menu) ln_crt_button();
    }
}
