function ln2_entry_checks() {
    var _b=buffer_load("verification/ln2_entry_vectors.json"),_oracle=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
    var _level=0,_d=undefined,_w=undefined;
    for (var _i=0;_i<array_length(_oracle.vectors);_i++) {
        var _v=_oracle.vectors[_i];
        if (_level!=_v.level) {
            _level=_v.level;_b=buffer_load("play/ln2/level"+string(_level)+"/gameplay.json");
            _d=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
            _b=buffer_load("play/ln2/level"+string(_level)+"/world.json");
            _w=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
        }
        _d.boundaries=json_parse(json_stringify(_v.boundaries));
        var _g={level:_level,room_id:_v.room,last_entry:_v.entry,world:_w,data:_d,inventory:_v.inventory,
                player:json_parse(json_stringify(_v.before.player)),enemy:json_parse(json_stringify(_v.before.enemy)),
                opened_passages:{}};
        ln2_entry_hook(_g);
        for (var _who=0;_who<2;_who++) {
            var _a=_who==0?_g.player:_g.enemy,_e=_who==0?_v.expected.player:_v.expected.enemy;
            var _names=variable_struct_get_names(_e);
            for (var _j=0;_j<array_length(_names);_j++) {
                var _name=_names[_j],_actual=variable_struct_get(_a,_name),_expected=variable_struct_get(_e,_name);
                ln_check(_actual==_expected,"LN2 entrance "+string(_i)+" actor "+string(_who)+" "+_name+" got "+string(_actual)+" expected "+string(_expected));
            }
        }
        ln_check(_g.special_mode==_v.expected.special_mode && _g.special_flag==_v.expected.special_flag &&
                 _g.exit_locked==_v.expected.exit_locked && _g.player.vehicle==_v.expected.vehicle,"LN2 entrance world modes "+string(_i));
        if (_g.player.vehicle!=0) ln_check(_g.player.vehicle_limit==_v.expected.vehicle_limit,"LN2 original attachment limit");
        ln_check(json_stringify(_g.data.boundaries)==json_stringify(_v.expected.boundaries),"LN2 entrance boundary gate "+string(_i));
    }
    show_debug_message("LN2_ENTRANCES_PASS: "+string(array_length(_oracle.vectors))+" original entrance effects; drawing side effects and full-game timing remain separate.");
    ln2_intro_checks();
    ln2_sequence_checks();
}

function ln2_compare_fields(_actual,_expected,_label) {
    var _keys=variable_struct_get_names(_expected);
    for (var _i=0;_i<array_length(_keys);_i++) {
        var _key=_keys[_i],_a=variable_struct_get(_actual,_key),_e=variable_struct_get(_expected,_key);
        ln_check(_a==_e,_label+" "+_key+" got "+string(_a)+" expected "+string(_e));
    }
}

function ln2_sequence_checks() {
    var _b=buffer_load("verification/ln2_sequence_vectors.json"),_o=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
    var _level=0,_g=undefined,_count=0;
    for (var _i=0;_i<array_length(_o.vehicles);_i++) {
        var _v=_o.vehicles[_i];
        if (_level!=_v.level) { _level=_v.level;_g=new LN2Play(_level); }
        var _p=_v.initial;_p.display_frame=_p.frame;_p.mirror=false;_g.data.boundaries=_v.boundaries;
        for (var _j=0;_j<array_length(_v.frames);_j++) {
            var _f=_v.frames[_j];ln2_player_update(_p,_g.data,_f.joy,_f.tick);
            ln2_compare_fields(_p,_f.expected,"LN2 entrance motion "+string(_i)+" tick "+string(_j));
            ln_check(_p.display_frame==_f.display.frame && _p.mirror==_f.display.mirror,"LN2 entrance motion original pose");_count++;
        }
    }
    show_debug_message("LN2_VEHICLES_PASS: "+string(_count)+" original entrance-motion states and poses across seven banks.");
    for (var _i=0;_i<array_length(_o.worlds);_i++) {
        var _v=_o.worlds[_i];
        if (_level!=_v.level) { _level=_v.level;_g=new LN2Play(_level); }
        _g.room_id=_v.room;
        for (var _j=0;_j<array_length(_g.world.rooms);_j++) if (_g.world.rooms[_j].id==_v.room) { _g.scene_record=_g.world.rooms[_j];break; }
        var _keys=variable_struct_get_names(_v.before);
        for (var _j=0;_j<array_length(_keys);_j++) variable_struct_set(_g,_keys[_j],variable_struct_get(_v.before,_keys[_j]));
        ln2_level_effect_tick(_g,0);
        ln2_compare_fields(_g.player,_v.expected.player,"LN2 world "+string(_i)+" player");
        ln2_compare_fields(_g.enemy,_v.expected.enemy,"LN2 world "+string(_i)+" enemy");
        for (var _j=0;_j<array_length(_keys);_j++) {
            var _key=_keys[_j];if (array_contains(["player","enemy","inventory","projectile"],_key)) continue;
            var _a=variable_struct_get(_g,_key),_e=variable_struct_get(_v.expected,_key);
            ln_check(_a==_e,"LN2 world "+string(_i)+" "+_key+" got "+string(_a)+" expected "+string(_e));
        }
        ln_check(json_stringify(_g.inventory)==json_stringify(_v.expected.inventory),"LN2 world original flags "+string(_i));
        var _draws=variable_struct_get_names(_v.draws);
        for (var _j=0;_j<array_length(_draws);_j++) {
            var _who=_draws[_j],_a=variable_struct_get(_g,_who),_e=variable_struct_get(_v.draws,_who);
            ln_check(_a.display_frame==_e.frame && _a.mirror==_e.mirror,"LN2 world original pose "+string(_i));
        }
    }
    show_debug_message("LN2_EFFECTS_PASS: "+string(array_length(_o.worlds))+" original moving-world state comparisons; scene drawing and full-game timing remain separate.");
}

function ln2_intro_checks() {
    var _b=buffer_load("verification/ln2_intro_vectors.json"),_o=json_parse(buffer_read(_b,buffer_text));buffer_delete(_b);
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i],_g=new LN2Play(6);
        _g.player=json_parse(json_stringify(_v.initial.player));_g.enemy=json_parse(json_stringify(_v.initial.enemy));
        _g.player.display_frame=_g.player.frame;_g.player.mirror=false;_g.enemy.display_frame=_g.enemy.frame;_g.enemy.mirror=false;
        _g.special_mode=_v.initial.special_mode;_g.special_flag=_v.initial.special_flag;_g.exit_locked=_v.initial.exit_locked;
        for (var _j=0;_j<array_length(_v.frames);_j++) {
            var _f=_v.frames[_j];_g.player.enemy_x=_g.enemy.x;_g.player.enemy_y=_g.enemy.y;_g.player.enemy_active=_g.enemy.active;
            ln2_player_update(_g.player,_g.data,_f.joy,_f.tick);ln2_enemy_action(_g);ln2_level_effect_tick(_g,_f.joy);
            for (var _who=0;_who<2;_who++) {
                var _a=_who==0?_g.player:_g.enemy,_e=_who==0?_f.player:_f.enemy,_names=variable_struct_get_names(_e);
                for (var _k=0;_k<array_length(_names);_k++) {
                    var _key=_names[_k];
                    ln_check(variable_struct_get(_a,_key)==variable_struct_get(_e,_key),"LN2 helicopter "+string(_i)+" tick "+string(_j)+" actor "+string(_who)+" "+_key);
                }
                var _pose=_who==0?_f.display.player:_f.display.enemy;
                ln_check(_a.display_frame==_pose.frame && _a.mirror==_pose.mirror,"LN2 helicopter original pose");
            }
            ln_check(_g.special_mode==_f.special_mode && _g.special_flag==_f.special_flag && _g.exit_locked==_f.exit_locked,"LN2 helicopter original attachment mode");
        }
    }
    show_debug_message("LN2_HELICOPTER_PASS: 256 original attachment/drop states and pose requests; world event dispatch excluded.");
}
