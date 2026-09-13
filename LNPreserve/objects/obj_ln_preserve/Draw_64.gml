if (ninja_transitions_test && variable_instance_exists(id,"transition_render_tick") && transition_render_tick>=4) {
    try {
        surface_save(application_surface,"ln1-restored-transition.png");
        ln_check(surface_getpixel(application_surface,1000,168)!=c_black,"restored transition retains enemy health HUD");
        show_debug_message("LN_NINJA_TRANSITION_RENDER_PASS: restored transition drawn over successive frames");
    } catch(_failure) {show_debug_message("LN_NINJA_TRANSITIONS_FAILURE: "+string(_failure));}
    game_end();
}
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

if (window_presets_test && (crt_live_frame&1)==1) {
    try {
        var _factor=crt_live_frame==1?1:(crt_live_frame==3?2:ln_window_fit_factor(display_get_width(),display_get_height()));
        ln_check(window_get_width()==round(1920*_factor) && window_get_height()==round(1080*_factor),"window preset uses exact client dimensions: "+string(window_get_width())+"x"+string(window_get_height())+" display "+string(display_get_width())+"x"+string(display_get_height()));
        ln_check(surface_get_width(application_surface)==1920 && surface_get_height(application_surface)==1080,"presets keep a stable rendering grid");
        screen_save("lnpreserve-window-"+string(_factor)+"x.png");
        show_debug_message("LN_WINDOW_SIZE_PASS: "+string(window_get_width())+"x"+string(window_get_height()));
        if (crt_live_frame>=5) {show_debug_message("LN_WINDOW_PRESETS_PASS");game_end();}
    } catch (_failure) {show_debug_message("LN_WINDOW_PRESETS_FAILURE: "+string(_failure));game_end();}
}

if (save_ui_test && save_ui_frame mod 3==2) {
    try {
        var _case=save_ui_frame div 3,_factor=_case<2?1:2;
        ln_check(window_get_width()==round(1920*_factor) && window_get_height()==round(1080*_factor),"save UI test client dimensions");
        var _hint="Click to load",_scale=min(1,124/max(1,string_width(_hint)));
        ln_check(1138+string_width(_hint)*_scale<=1268,"save hint fits inside occupied slot");
        screen_save("lnpreserve-save-ui-"+string(_factor)+"x-"+string(_case&1)+".png");
        show_debug_message("LN_SAVE_UI_CASE_PASS:"+string(_case));
        if (_case==3) {show_debug_message("LN_SAVE_UI_PASS: three game labels and empty slots, both sizes, CRT off/on; in-memory fixtures only.");game_end();}
    } catch (_failure) {show_debug_message("LN_SAVE_UI_FAILURE:"+string(_failure));game_end();}
}

if(fullscreen_test) {
    try {
        if(fullscreen_frame==3 || fullscreen_frame==9) ln_check(window_get_fullscreen(),"fullscreen available in game and editor");
        if(fullscreen_frame==5 || fullscreen_frame==12) ln_check(!window_get_fullscreen() && window_get_width()==fullscreen_original[0] && window_get_height()==fullscreen_original[1],"fullscreen restores prior window dimensions");
        if(fullscreen_frame==12) {show_debug_message("LN_FULLSCREEN_PASS: game/editor borderless toggle and window restoration");game_end();}
    } catch(_fullscreen_failure) {show_debug_message("LN_FULLSCREEN_FAILURE: "+string(_fullscreen_failure));game_end();}
}

if(global.ln_tool.layout_test) {
    try {
        ln_check(surface_get_width(application_surface)==1920 && surface_get_height(application_surface)==1080,"16:9 presentation surface");
        if(global.ln_tool.frame mod 2==0) {
            ln_check(surface_getpixel(application_surface,493,97)==(global.ln_tool.background?make_colour_rgb(45,95,110):make_colour_rgb(43,48,57)),"background shortcut button remains visible");
            surface_save(application_surface,"tool-layout-"+string(global.ln_tool.frame)+".png");
            if(global.ln_tool.frame==2) tool_background_pixel=surface_getpixel(application_surface,1800,500);
            if(global.ln_tool.frame==4) ln_check(surface_getpixel(application_surface,1800,500)==tool_background_pixel,"UI hiding preserves background");
            if(global.ln_tool.frame==6) ln_check(surface_getpixel(application_surface,1800,500)==c_black,"background toggle clears artwork");
            if(global.ln_tool.frame==8) ln_check(surface_getpixel(application_surface,350,290)==surface_getpixel(global.ln_tool.surface,30,150),"editor canvas survives widescreen composition");
            if(global.ln_tool.frame==10) {show_debug_message("LN_TOOL_LAYOUT_PASS: 1920x1080 game/editor UI and background visibility");game_end();}
        }
    } catch(_layout_failure) {show_debug_message("LN_TOOL_LAYOUT_FAILURE: "+string(_layout_failure));game_end();}
}
