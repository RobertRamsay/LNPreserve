function ln3_combat_checks() {
    var _b=buffer_load("verification/ln3_combat_vectors.json"),_o=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
    var _level=0,_data=undefined,_actions=undefined;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];
        if (_level!=_v.level) {
            _level=_v.level;var _path="play/ln3/level"+string(_level)+"/";
            _b=buffer_load(_path+"combat.json");_data=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
            _b=buffer_load(_path+"actions.json");_actions=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
        }
        var _s=_v.before;
        if (_v.operation==0) ln3_combat_update(_s,_actions,_data);else ln3_projectile_hits(_s,_data);
        ln3_state_check(_s,_v.expected,"LN3 combat "+string(_i));
    }
    var _g=new LN3Play(1);_g.state.player_health=44;_g.state.inventory[26]=44;_g.state.enemy_weapon=0;
    global.ln_test_no_enemy_damage=false;ln3_combat_damage_player(_g.state,_g.actions,_g.combat);
    ln_check(_g.state.player_health<44,"LN3 enemy attack reduces health normally");
    _g.state.player_health=44;_g.state.inventory[26]=44;global.ln_test_no_enemy_damage=true;
    ln3_combat_damage_player(_g.state,_g.actions,_g.combat);
    ln_check(_g.state.player_health==44 && _g.state.inventory[26]==44,"F11 protection absorbs LN3 enemy attack damage");
    global.ln_test_no_enemy_damage=false;
    show_debug_message("LN3_COMBAT_PASS: "+string(array_length(_o.vectors))+" original melee, honour, score and projectile states across five banks.");
}
