/// obj_ai_restyle - Post Draw

if (!surface_exists(cap_surf)) {
    cap_surf = surface_create(cap_w, cap_h);
}
if (!surface_exists(result_surf)) {
    result_surf = surface_create(cap_w, cap_h);
    have_result = false;
}

gpu_set_blendenable(false);

// Grab this frame and send it, one frame in flight at a time
if (ai_enabled && connected && !awaiting_reply) {
    surface_set_target(cap_surf);
    draw_surface_stretched(application_surface, 0, 0, cap_w, cap_h);
    surface_reset_target();

    buffer_seek(send_buf, buffer_seek_start, 0);
    buffer_write(send_buf, buffer_u8, 1);
    buffer_write(send_buf, buffer_u32, 4 + frame_bytes);
    buffer_write(send_buf, buffer_u16, cap_w);
    buffer_write(send_buf, buffer_u16, cap_h);
    buffer_get_surface(send_buf, cap_surf, header_size);
    network_send_raw(sock, send_buf, buffer_get_size(send_buf));
    awaiting_reply = true;
}

// Show the AI frame, or the normal game if there isn't one
var _win_w = window_get_width();
var _win_h = window_get_height();
if (ai_enabled && have_result) {
    draw_surface_stretched(result_surf, 0, 0, _win_w, _win_h);
} else {
    draw_surface_stretched(application_surface, 0, 0, _win_w, _win_h);
}

gpu_set_blendenable(true);
