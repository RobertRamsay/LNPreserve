/// Original $8cad/$8f58/$8cd2 victory-loop state, independently checked.
function ln2_victory_rule(_s,_operation) {
    var _result={event:0,requests:[]};
    switch (_operation) {
        case 0:_s.target=[0,0];_s.knockouts=0;break;
        case 1:
            if (_s.target[0]==_s.display[0] && _s.target[1]==_s.display[1]) _s.target=[44-_s.target[1],44-_s.target[1]];
            if (_s.eye_timer!=0) {_s.eye_timer=1;_s.eye_phase=0;}
            break;
        case 2:
            if (_s.enemy_action>=256) break;
            if (_s.reward==0) array_push(_result.requests,$c20b);
            else {_s.target=[_s.display[0],_s.display[1]];_result.event=1;}
            break;
        case 3:if (_s.eye_timer!=0) {_s.eye_timer=1;_s.eye_phase=0;}break;
    }
    return _result;
}

function ln2_victory_palette(_s,_period) {
    if (((_s.tick-_s.previous)&255)<_period) return;
    _s.previous=_s.tick;_s.phase=(_s.phase+1)&7;
}

/// The asymmetric X step is present in the original $9b84 instruction flow.
function ln2_spirit_motion(_e) {
    if (_e.y!=114) {var _dy=_e.y<114?1:-1;_e.y=(_e.y+_dy)&255;_e.depth_y=(_e.depth_y+_dy)&255;}
    if (!(_e.facing&4)) {
        if (_e.x==118) return;
        if (_e.x>118) {_e.x--;return;}
        _e.x++;
    }
    if (_e.x!=134) _e.x+=_e.x<134?1:-1;
}

function ln2_victory_start(_g) {
    _g.victory=1;repeat(10) ln2_score_add(_g,$50);
    _g.victory_palette_index=0;
    _g.ending_score=array_create(6,27);array_copy(_g.ending_score,0,_g.status.score,0,6);
    _g.ending_time=array_create(6,27);array_copy(_g.ending_time,0,_g.status.clock.digits,0,6);
    _g.player_health=0;_g.enemy.health=0;_g.enemy.knockouts=0;
}

function ln2_victory_tick(_g,_joy,_tick) {
    var _p=_g.player,_e=_g.enemy;
    if (_g.victory==1) {
        if (_g.player_health==_g.status.health[0] && _e.health==_g.status.health[1]) {
            _e.health=44-_e.health;_g.player_health=_e.health;
        }
        _p.enemy_active=_e.active;_p.enemy_x=_e.x;_p.enemy_y=_e.y;_p.separation_y=_e.separation_y;
        _p.gate_open=_g.inventory[18];_p.gate_mode=_g.inventory[20];ln2_player_update(_p,_g.data,_joy,_tick);
    } else {_p.tick=_tick;_p.last_tick=_tick;}
    ln2_enemy_action(_g);
    if (_g.victory==1) {
        ln2_combat_event(_g,_p.action_state,false);_p.action_state=0;
        ln2_combat_event(_g,_e.action_state,true);_e.action_state=0;
    }
    var _palette={phase:_g.world_state.final_palette_phase,tick:_tick,previous:_g.final_palette_tick};
    ln2_victory_palette(_palette,_g.ending_data.palette_period);
    if (_palette.previous!=_g.final_palette_tick) _g.victory_palette_index=_g.ending_data.palette_next[_g.victory_palette_index];
    _g.world_state.final_palette_phase=_palette.phase;_g.final_palette_tick=_palette.previous;
    ln2_final_candles_tick(_g,_tick);
    if (_g.victory==1 && _e.action<256) {
        if (_g.inventory[23]==0) ln2_enemy_special(_g,$c20b);
        else {_g.victory=2;_g.player_health=_g.status.health[0];_e.health=_g.status.health[1];}
    }
}

function ln2_victory_palette_draw(_g) {
    if (_g.victory==0) return;
    var _d=_g.ending_data;draw_sprite(asset_get_index(_d.palette_sprite),_d.palette_frames[_g.victory_palette_index],0,0);
}

function ln2_ending_draw(_g) {
    var _d=_g.ending_data;
    if (!surface_exists(_g.ending_surface)) _g.ending_surface=surface_create(320,200);
    surface_set_target(_g.ending_surface);draw_clear(c_black);
    draw_sprite(asset_get_index(_d.picture_sprite),_d.picture_frames[_g.victory_palette_index],0,0);
    for (var _i=0;_i<5;_i++) {
        var _value=_g.world_state.candles[_i],_phase=_value>=128?(_value&1):2;
        draw_sprite(asset_get_index(_d.candle_sprite),_i*3+_phase,0,0);
    }
    ln2_play_actor(_g,_g.enemy,true);
    for (var _i=0;_i<6;_i++) {
        draw_sprite(asset_get_index(_d.font_sprite),_g.ending_score[_i]-27,_d.score_xy[0]+_i*8,_d.score_xy[1]);
        draw_sprite(asset_get_index(_d.font_sprite),_g.ending_time[_i]-27,_d.time_xy[0]+(_i+(_i div 2))*8,_d.time_xy[1]);
    }
    surface_reset_target();draw_surface_ext(_g.ending_surface,0,0,4,4,0,c_white,1);
}

function ln2_ending_free(_g) {if (is_struct(_g) && variable_struct_exists(_g,"ending_surface") && surface_exists(_g.ending_surface)) surface_free(_g.ending_surface);}

function ln2_ending_checks() {
    var _o=ln3_data_read("verification/ln2_ending_vectors.json"),_d=ln3_data_read("play/ln2/ending.json");
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i],_s=_v.before,_r=ln2_victory_rule(_s,_v.operation);
        ln3_state_check(_s,_v.expected,"LN2 original victory state "+string(_i));
        ln_check(_r.event==_v.event && array_length(_r.requests)==array_length(_v.requests),"LN2 original victory continuation");
        for (var _j=0;_j<array_length(_r.requests);_j++) ln_check(_r.requests[_j]==_v.requests[_j],"LN2 original spirit animation request");
    }
    for (var _i=0;_i<array_length(_o.palette);_i++) {
        var _v=_o.palette[_i],_s=_v.before;ln2_victory_palette(_s,_d.palette_period);
        ln_check(_s.phase==_v.phase && _s.previous==_v.previous,"LN2 original victory palette state");
    }
    for (var _i=0;_i<array_length(_o.motion);_i++) {
        var _v=_o.motion[_i],_s=_v.before;ln2_spirit_motion(_s);ln3_state_check(_s,_v.expected,"LN2 original spirit centring motion");
    }
    var _g=new LN2Play(7);ln2_test_enter(_g,_g.world.rooms[1].spawn_entry);_g.world_state.boss_defeated=true;
    _g.world_state.candles=array_create(5,128);_g.enemy.x=118;_g.enemy.y=114;_g.enemy.active=0;_g.enemy.costume=2;_g.enemy.weapon=1;
    ln2_enemy_special(_g,$c1b9);ln2_victory_start(_g);
    repeat(1200) {
        ln2_play_tick(_g,0);
        ln_check(_g.ending_data.palette_phases[_g.victory_palette_index]==_g.world_state.final_palette_phase,"LN2 first/repeated palette drawing follows original phase");
    }
    ln_check(_g.victory==1,"LN2 spirit waits for original final item interaction");
    _g.inventory[23]=255;repeat(1200) ln2_play_tick(_g,0);
    ln_check(_g.victory==2,"LN2 final reward and finished spirit animation reach original congratulations loop");
    ln2_status_checks();
    show_debug_message("LN2_ENDING_PASS: 3072 victory, 2048 palette and 2048 spirit-motion states, plus native reward-to-ending completion; whole-game/raster parity excluded.");
}

function ln2_ending_gpu_checks() {
    var _d=ln3_data_read("play/ln2/ending.json"),_o=ln3_data_read("verification/ln2_ending_gpu.json");
    var _surface=surface_create(320,200),_b=buffer_create(320*200*4,buffer_fixed,1),_count=0;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];surface_set_target(_surface);draw_clear(c_black);
        draw_sprite(asset_get_index(_d.picture_sprite),_d.picture_frames[_v.phase],0,0);surface_reset_target();buffer_get_surface(_b,_surface,0);
        for (var _j=0;_j<array_length(_v.samples);_j++) {
            var _p=_v.samples[_j],_actual=buffer_peek(_b,(_p[1]*320+_p[0])*4,buffer_u32)&$ffffff;
            ln_check(_actual==make_colour_rgb(_p[2],_p[3],_p[4]),"LN2 original ending bitmap pixel");_count++;
        }
    }
    var _g=new LN2Play(7);ln2_test_enter(_g,_g.world.rooms[1].spawn_entry);_g.victory=1;
    for (var _i=0;_i<array_length(_o.game);_i++) {
        var _v=_o.game[_i];_g.victory_palette_index=_v.phase;
        surface_set_target(_surface);draw_clear(c_black);draw_sprite(_g.scene,0,0,0);ln2_victory_palette_draw(_g);surface_reset_target();buffer_get_surface(_b,_surface,0);
        for (var _j=0;_j<array_length(_v.samples);_j++) {
            var _p=_v.samples[_j],_actual=buffer_peek(_b,(_p[1]*320+_p[0])*4,buffer_u32)&$ffffff;
            ln_check(_actual==make_colour_rgb(_p[2],_p[3],_p[4]),"LN2 original first/repeated victory palette pixel");_count++;
        }
    }
    surface_free(_surface);buffer_delete(_b);
    _g.victory=2;_g.ending_score=[27,28,29,30,31,32];_g.ending_time=[27,27,28,29,30,31];
    _g.enemy.display_frame=116;_g.enemy.mirror=false;_g.enemy.active=0;_g.enemy.weapon=1;_g.enemy.costume=2;
    _g.enemy.x=118;_g.enemy.y=114;_g.enemy.depth_y=114;_g.world_state.boss_defeated=true;_g.world_state.candles=array_create(5,128);
    ln2_ending_draw(_g);surface_save(_g.ending_surface,"lnpreserve-ln2-ending.png");ln2_ending_free(_g);
    show_debug_message("LN2_ENDING_GPU_PASS: "+string(_count)+" original game/ending bitmap samples across first and repeated palette traversals.");
}
