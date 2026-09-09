// Read the final application surface after the real Draw/Draw End sequence.
if (crt_live_test) {
    try {
        var _pixel=surface_getpixel(application_surface,900,100);
        if (crt_live_frame==0) {
            crt_live_baseline=_pixel;
            surface_save(application_surface,"lnpreserve-crt-live-off.png");
        }
        if (crt_live_frame==1) {
            ln_check(global.ln_crt_enabled && surface_exists(crt_surface),"live toggle enables CRT output");
            ln_check(_pixel!=crt_live_baseline,"displayed HUD changes after live toggle");
            ln_check(_pixel==surface_getpixel(crt_surface,900,100),"CRT output survives normal drawing");
            surface_save(application_surface,"lnpreserve-crt-live-on.png");
        }
        if (crt_live_frame==2) {
            ln_check(!global.ln_crt_enabled && _pixel==crt_live_baseline,"live toggle off restores original HUD");
            show_debug_message("LN_CRT_LIVE_PASS: final rendered screen OFF / ON / OFF");
            game_end();
        }
    } catch (_failure) {
        show_debug_message("LN_CRT_LIVE_FAILURE: "+string(_failure));game_end();
    }
}
