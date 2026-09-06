function ln3_enemy_checks() {
    var _b=buffer_load("verification/ln3_enemy_vectors.json"),_o=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
    var _level=0,_data=undefined,_input=undefined,_actions=undefined;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];
        if (_level!=_v.level) {
            _level=_v.level;var _path="play/ln3/level"+string(_level)+"/";
            _b=buffer_load(_path+"enemy.json");_data=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
            _b=buffer_load(_path+"input.json");_input=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
            _b=buffer_load(_path+"actions.json");_actions=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
        }
        var _s=_v.before;
        switch (_v.operation) {
            case 0:ln3_enemy_decide(_s,_actions,_input,_data);break;
            case 1:ln3_enemy_attack(_s,_actions,_data,_v.random);break;
            case 2:ln3_enemy_patrol(_s,_actions,_input,_data);break;
            case 3:ln3_enemy_recover_action(_s,_actions);break;
        }
        ln3_state_check(_s,_v.expected,"LN3 enemy "+string(_i));
    }
    show_debug_message("LN3_ENEMY_PASS: "+string(array_length(_o.vectors))+" original enemy decisions across five banks.");
}
