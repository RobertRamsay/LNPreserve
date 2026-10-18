/// obj_ai_restyle - Step

// Toggle AI view
if (keyboard_check_pressed(key_toggle)) {
    ai_enabled = !ai_enabled;
}

// Show / hide the status overlay
if (keyboard_check_pressed(key_hide_overlay)) {
    overlay_visible = !overlay_visible;
}

// Cycle preset styles
if (keyboard_check_pressed(key_next_style)) {
    prompt_index += 1;
    if (prompt_index >= array_length(prompt_list)) {
        prompt_index = 0;
    }
    prompt_current = prompt_list[prompt_index];
    send_prompt(prompt_current);
}

// Type a custom style
if (keyboard_check_pressed(key_custom_style)) {
    if (prompt_dialog_id == -1) {
        prompt_dialog_id = get_string_async("Describe the style:", prompt_current);
    }
}

// AI frames-per-second counter
fps_timer += delta_time;
if (fps_timer >= 1000000) {
    fps_display = fps_counter;
    fps_counter = 0;
    fps_timer -= 1000000;
}

// Reconnect if the helper isn't running yet
if (!connected) {
    if (!connecting) {
        reconnect_timer -= 1;
        if (reconnect_timer <= 0) {
            network_destroy(sock);
            sock = network_create_socket(network_socket_tcp);
            connecting = true;
            status_text = "Connecting to helper...";
            var _res = network_connect_raw_async(sock, host_address, host_port);
            if (_res < 0) {
                connecting = false;
                reconnect_timer = reconnect_delay;
            }
        }
    }
}
