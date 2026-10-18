/// obj_ai_restyle - Async Dialog

if (async_load[? "id"] == prompt_dialog_id) {
    if (async_load[? "status"]) {
        var _text = async_load[? "result"];
        if (string_length(_text) > 0) {
            prompt_current = _text;
            send_prompt(prompt_current);
        }
    }
    prompt_dialog_id = -1;
}
