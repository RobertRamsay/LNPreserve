/// obj_ai_restyle - Create
// Live AI restyle. Place one instance in your first room (it is persistent).
// Run gm_restyle_server.py before or after starting the game.

// ---- Settings ----
host_address = "127.0.0.1";
host_port = 5577;

// Capture size sent to the helper. Keep the same shape as the region
// and use multiples of 64 (640x384 matches LNPreserve's 5:3 playfield).
cap_w = 640;
cap_h = 384;

// Area of application_surface to restyle: returns [x, y, w, h].
// Return a width of 0 to show the normal game (menus, editors).
// Override per game, e.g. _ai.region_func = my_region_function;
region_func = function() {
    return [0, 0, surface_get_width(application_surface), surface_get_height(application_surface)];
};
region = [0, 0, 0, 0];

// Style prompts (TAB cycles, F3 types a custom one)
prompt_list = [
    "oil painting, dramatic lighting",
    "studio ghibli anime style",
    "gothic dark fantasy, moody fog",
    "neon cyberpunk city at night",
    "watercolour storybook illustration"
];

// Keys
key_toggle = vk_f2;
key_next_style = vk_tab;
key_custom_style = vk_f3;
key_hide_overlay = vk_f4;

// ---- State ----
reconnect_delay = game_get_speed(gamespeed_fps) * 2;
reconnect_timer = 0;
connected = false;
connecting = true;

prompt_index = 0;
prompt_current = prompt_list[0];
prompt_dialog_id = -1;

ai_enabled = true;
overlay_visible = true;
awaiting_reply = false;
have_result = false;
status_text = "Connecting to helper...";
helper_text = "";
fps_timer = 0;
fps_counter = 0;
fps_display = 0;

// Surfaces
cap_surf = -1;
result_surf = -1;

// Buffers: header = u8 type, u32 length, u16 w, u16 h
header_size = 9;
frame_bytes = cap_w * cap_h * 4;
send_buf = buffer_create(header_size + frame_bytes, buffer_fixed, 1);
rx_capacity = (header_size + frame_bytes) * 3;
rx_buf = buffer_create(rx_capacity, buffer_fixed, 1);
shift_buf = buffer_create(rx_capacity, buffer_fixed, 1);
rx_len = 0;

// We draw application_surface ourselves in Post Draw
application_surface_draw_enable(false);

// Socket
sock = network_create_socket(network_socket_tcp);
var _res = network_connect_raw_async(sock, host_address, host_port);
if (_res < 0) {
    connecting = false;
    reconnect_timer = reconnect_delay;
}

// ---- Methods ----

send_prompt = function(_text) {
    if (!connected) {
        return;
    }
    var _len = string_byte_length(_text);
    var _buf = buffer_create(5 + _len, buffer_fixed, 1);
    buffer_write(_buf, buffer_u8, 2);
    buffer_write(_buf, buffer_u32, _len);
    buffer_write(_buf, buffer_text, _text);
    network_send_raw(sock, _buf, 5 + _len);
    buffer_delete(_buf);
};

reset_connection = function(_message) {
    connected = false;
    connecting = false;
    awaiting_reply = false;
    rx_len = 0;
    reconnect_timer = reconnect_delay;
    status_text = _message;
};

read_status_text = function(_plen) {
    var _tmp = buffer_create(_plen + 1, buffer_fixed, 1);
    buffer_copy(rx_buf, 5, _plen, _tmp, 0);
    buffer_poke(_tmp, _plen, buffer_u8, 0);
    buffer_seek(_tmp, buffer_seek_start, 0);
    helper_text = buffer_read(_tmp, buffer_string);
    buffer_delete(_tmp);
};

handle_packet = function(_ptype, _plen) {
    if (_ptype == 1) {
        var _w = buffer_peek(rx_buf, 5, buffer_u16);
        var _h = buffer_peek(rx_buf, 7, buffer_u16);
        if (_w == cap_w && _h == cap_h) {
            if (!surface_exists(result_surf)) {
                result_surf = surface_create(cap_w, cap_h);
            }
            buffer_set_surface(rx_buf, result_surf, header_size);
            have_result = true;
            fps_counter += 1;
        }
        awaiting_reply = false;
    } else if (_ptype == 3) {
        awaiting_reply = false;
    } else if (_ptype == 4) {
        read_status_text(_plen);
    }
};

parse_packets = function() {
    var _keep_going = true;
    while (_keep_going) {
        _keep_going = false;
        if (rx_len >= 5) {
            var _ptype = buffer_peek(rx_buf, 0, buffer_u8);
            var _plen = buffer_peek(rx_buf, 1, buffer_u32);
            var _total = 5 + _plen;
            if (_total > rx_capacity) {
                rx_len = 0;
                status_text = "Bad packet from helper";
            } else if (rx_len >= _total) {
                handle_packet(_ptype, _plen);
                var _remain = rx_len - _total;
                if (_remain > 0) {
                    buffer_copy(rx_buf, _total, _remain, shift_buf, 0);
                    buffer_copy(shift_buf, 0, _remain, rx_buf, 0);
                }
                rx_len = _remain;
                _keep_going = true;
            }
        }
    }
};
