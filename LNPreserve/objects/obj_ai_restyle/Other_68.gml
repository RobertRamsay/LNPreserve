/// obj_ai_restyle - Async Networking

if (async_load[? "id"] != sock) {
    exit;
}

var _type = async_load[? "type"];

switch (_type) {
    case network_type_non_blocking_connect:
        if (async_load[? "succeeded"]) {
            connected = true;
            connecting = false;
            awaiting_reply = false;
            rx_len = 0;
            status_text = "Connected";
            send_prompt(prompt_current);
        } else {
            reset_connection("Helper not running - retrying");
        }
    break;

    case network_type_disconnect:
        reset_connection("Helper disconnected - retrying");
    break;

    case network_type_data:
        var _in = async_load[? "buffer"];
        var _size = async_load[? "size"];
        if (rx_len + _size > rx_capacity) {
            rx_len = 0;
            awaiting_reply = false;
        } else {
            buffer_copy(_in, 0, _size, rx_buf, rx_len);
            rx_len += _size;
            parse_packets();
        }
    break;
}
