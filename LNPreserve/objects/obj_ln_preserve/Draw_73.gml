if (!presentation_test) {
    ln_crt_present(self);
    if (ln_crt_controls_visible(self)) {
        ln_crt_sliders_draw(!scene_test.menu);ln_window_buttons(!scene_test.menu);
        if (scene_test.menu) ln_crt_button();
    }
}
