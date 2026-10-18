/// obj_ai_restyle - Post Draw

if (!surface_exists(cap_surf)) {
    cap_surf = surface_create(cap_w, cap_h);
}
if (!surface_exists(result_surf)) {
    result_surf = surface_create(cap_w, cap_h);
    have_result = false;
}

// Which part of the screen to restyle this frame
region = region_func();
var _rx = region[0];
var _ry = region[1];
var _rw = region[2];
var _rh = region[3];
var _region_ok = false;
if (_rw > 0 && _rh > 0) {
    _region_ok = true;
}

gpu_set_blendenable(false);

// Grab just the region and send it, one frame in flight at a time
if (ai_enabled && connected && !awaiting_reply && _region_ok) {
    surface_set_target(cap_surf);
    draw_surface_part_ext(application_surface, _rx, _ry, _rw, _rh, 0, 0, cap_w / _rw, cap_h / _rh, c_white, 1);
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

// Normal game first, then the AI picture over the region only
var _win_w = window_get_width();
var _win_h = window_get_height();
draw_surface_stretched(application_surface, 0, 0, _win_w, _win_h);

if (ai_enabled && have_result && _region_ok) {
    var _sx = _win_w / surface_get_width(application_surface);
    var _sy = _win_h / surface_get_height(application_surface);
    gpu_set_texfilter(true);
    draw_surface_stretched(result_surf, _rx * _sx, _ry * _sy, _rw * _sx, _rh * _sy);
    gpu_set_texfilter(false);
}

gpu_set_blendenable(true);
