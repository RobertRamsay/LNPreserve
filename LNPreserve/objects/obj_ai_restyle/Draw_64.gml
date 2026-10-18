/// obj_ai_restyle - Draw GUI

if (!overlay_visible) {
    exit;
}

var _ai_word = "OFF";
if (ai_enabled) {
    _ai_word = "ON";
}

var _line1 = "AI: " + _ai_word + "  |  " + status_text + "  |  " + string(fps_display) + " AI fps";
var _line2 = "Style: " + prompt_current;
var _line3 = "F2 toggle   TAB next style   F3 custom style   F4 hide";

draw_set_alpha(0.6);
draw_set_colour(c_black);
draw_rectangle(4, 4, 560, 70, false);
draw_set_alpha(1);
draw_set_colour(c_white);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_text(10, 8, _line1);
draw_text(10, 28, _line2);
draw_text(10, 48, _line3);
