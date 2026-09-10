/// Native level lifecycle and the recovered level-specific boundary handlers.
function ln1_level_load(_g, _level, _ordinary_exit = false) {
    if (_level > 6) { _g.level_complete = true; return false; }
    if (_level < 1) return false;
    if (_level == _g.level) return true;
    _g.level_states[_g.level-1] = {wounds:_g.room_wounds, state:_g.world_state};
    var _inventory = _g.inventory, _lives = _g.lives_left, _health = _g.player_health;
    if (_ordinary_exit) {
        // $6e36 carries the inventory, converts the extra-life pickup and clears
        // the shuriken high bit before $6df8 restores the next level's state.
        if (_inventory[8] != 0 && _inventory[8] != 128) _lives++;
        _inventory[8] = 0; _inventory[14] &= 127;
        if (_g.level == 1 && _lives == 1) _lives++;
    }
    var _fresh = new LN1Play(_level), _names = variable_struct_get_names(_fresh);
    for (var _i=0;_i<array_length(_names);_i++) {
        var _name = _names[_i];
        if (_name == "level_states" || _name == "stage_surface" || _name == "timer" ||
            _name == "controls" || _name == "inventory" || _name == "lives_left") continue;
        variable_struct_set(_g,_name,variable_struct_get(_fresh,_name));
    }
    _g.player.world_game = _g; _g.inventory = _inventory; _g.lives_left = max(1,_lives);
    _g.player_health = _ordinary_exit ? 32 : max(1,_health);
    var _saved = _g.level_states[_level-1];
    if (is_struct(_saved)) { _g.room_wounds = _saved.wounds; _g.world_state = _saved.state; }
    ln1_play_enter(_g,_g.last_entry>>2);
    ln1_level_sync_controls(_g);
    if (_ordinary_exit && is_struct(_g.controls)) _g.controls.item = 10;
    ln_music_play(1,["wastelands","wilderness","palace_gardens","dungeons","palace","inner_sanctum"][_level-1],false);
    return true;
}

function ln1_level_sync_controls(_g) {
    if (!is_struct(_g.controls)) return;
    for (var _i=0;_i<11;_i++) _g.controls.inventory[_i] = _g.inventory[_i];
    for (var _i=0;_i<6;_i++) _g.controls.weapons[_i] = _g.inventory[_i+10];
    if (_g.inventory[8] == 128) _g.controls.inventory[8] = 0;
    _g.controls.weapon = _g.player.selected_weapon;
    _g.controls.weapon_locked = 0;
}

function ln1_level_enemy_action(_g,_address) {
    _g.enemy.action = _address; _g.enemy.countdown = 0;
    _g.enemy.action_tick = _g.player.tick;
}

function ln1_level_sequence(_g,_kind,_address) {
    _g.sequence_kind = _kind; _g.sequence_phase = 0; _g.sequence_wait = 0;
    _g.player.input_lock = 255; _g.player.stopped = 255;
    if (_address >= 256) ln1_special_action(_g,_address);
}

function ln1_level_sink(_g,_offset=0,_travel=false) {
    var _p = _g.player;
    if (!_travel) _g.player_health = 0;
    _p.input_lock = 255; _p.action = 0; _p.action_state = 0; _p.flags = 0;
    _g.water_active = true; _g.water_ticks = 0; _g.water_travel = _travel;
    _g.water_cutoff = min(_p.y + 24 + _offset,173);
    ln1_water_advance(_g);
}

/// These cases follow each bank's original $bdxx/$bexx boundary dispatcher.
function ln1_level_hazard(_g,_kind) {
    if (_g.level == 1) return false;
    var _p = _g.player, _selected = is_struct(_g.controls) ? _g.controls.item : 10;
    switch (_kind) {
        case 2:
            if (_selected == 5 && _p.weapon == 0 && _p.facing == 1) ln1_level_sequence(_g,2,$aa1e);
            return true;
        case 3:
            if (_p.boundary_crossings & 1) { _g.player_health=0; ln1_level_sequence(_g,3,0); }
            return true;
        case 4:
            if (_selected == 5 && _p.weapon == 0 && _p.facing == 7) ln1_level_sequence(_g,4,$aa4d);
            else { _g.player_health=0; ln1_level_sequence(_g,3,0); }
            return true;
        case 5: ln1_level_sink(_g); return true;
        case 6:
            if (_selected == 7 && (_p.weapon | _p.selected_weapon) == 0 && _p.facing == 1)
                ln1_level_sequence(_g,6,$50d4);
            else { _p.input_lock=255; _g.player_health=0; }
            return true;
        case 7: ln1_level_sink(_g,16); return true;
        case 8:
            _g.world_state.flag_b = (_g.world_state.flag_b+1)&255;
            ln1_level_sink(_g,0,true); return true;
        case 9:
            if (_selected == 0 && _p.weapon == 0 && _p.facing == 1) ln1_level_sequence(_g,9,$5054);
            return true;
        case 10:
            var _crossings = _p.boundary_crossings; _p.boundary_crossings = 128;
            if (_crossings < 128) ln1_level_enemy_action(_g,$5157);
            return true;
        case 11:
            if (_selected == 4) { _p.y=0; ln1_play_exit(_g); }
            return true;
        case 12:
            if (_selected == 1 && _g.inventory[1] != 0) {
                _g.inventory[1] = 0; _g.world_state.statue_open = true;
                ln1_level_enemy_action(_g,$4e4f);
                if (array_length(_g.data.boundaries)>0) {
                    _g.data.boundaries[0][2]=_g.data.boundaries[0][0];
                    _g.data.boundaries[0][3]=_g.data.boundaries[0][1];
                }
                if (is_struct(_g.controls)) _g.controls.item=10;
                ln1_level_sync_controls(_g);
            }
            return true;
        case 13:
            var _crossings = _p.boundary_crossings; _p.boundary_crossings = 128;
            if (_crossings < 128 && _g.enemy.active == 134) {
                ln1_level_enemy_action(_g,$4e0c); _g.enemy.speed = 3;
            }
            return true;
        case 14:
            if (_g.world_state.protection != 2) {
                ln1_level_enemy_action(_g,$4e3e); _g.world_state.mode = 1;
            }
            return true;
        case 20:
            _g.player_health=0; ln1_level_sequence(_g,20,0); return true;
        case 21:
            if (_p.boundary_crossings & 1) { _g.world_state.flag_a=160; ln1_level_sink(_g); }
            return true;
        case 22:
            if (_g.world_state.protection == 0) {
                _g.world_state.flag_b = (_g.world_state.flag_b+1)&255;
                _g.player_health=0; _p.input_lock=255; _g.death_wait=20;
            }
            return true;
        case 23:
            _g.sequence_scene = _g.scene; _g.sequence_enemy = _g.enemy;
            _g.scene = asset_get_index(_g.world.vision_sprite);
            _g.enemy = new LN1Enemy(); _g.enemy.action = _g.world.vision_enemy;
            ln1_level_sequence(_g,23,0); return true;
    }
    return false;
}

function ln1_level_sequence_tick(_g,_joy) {
    var _p=_g.player, _kind=_g.sequence_kind;
    _p.tick=(_p.tick+1)&255; _p.last_tick=_p.tick;
    if (_kind==23) {
        ln1_enemy_action(_g);
        if ((_joy&10)==10) {
            _g.scene=_g.sequence_scene;_g.enemy=_g.sequence_enemy;
            _g.sequence_kind=0;_p.input_lock=0;
        }
        return;
    }
    if (_kind==3 || _kind==20) {
        if (((_p.tick-_g.water_clock)&255)<2) return;
        _g.water_clock=_p.tick;
        if (_kind==3) { _p.y+=4; _p.frame=20+((_p.facing+2)&4); }
        else { _p.x=max(0,_p.x-8); _p.y=(_p.y-4)&255; _p.frame=18+(((_p.facing+2)&4)>>2); }
        ln1_player_render(_p,_g.data.mirror[_p.facing>>1]&(1<<_p.heading));
        if ((_kind==3 && _p.y>=192) || (_kind==20 && _p.x==0)) {
            _p.display_frame=255;_g.sequence_kind=0;_g.death_wait=20;
        }
        return;
    }
    if (_g.sequence_wait>0) {
        _g.sequence_wait--;
        if (_g.sequence_wait==0) { _g.sequence_kind=0;_p.input_lock=0;_p.x=255;ln1_play_exit(_g); }
        return;
    }
    ln1_player_action(_p,_g.data,1); ln1_enemy_action(_g);
    if (_p.action>=256) return;
    switch (_kind) {
        case 2:
            if (_p.y>=84) { ln1_special_action(_g,$aa21);return; }
            if (_g.sequence_phase==0) { _g.sequence_phase=1;ln1_special_action(_g,$aa32);return; }
            break;
        case 4:
            if (_p.x<156 && _p.y>=124) { _g.sequence_kind=3;_g.player_health=0;return; }
            if (_p.x<156 || _p.y<136) { ln1_special_action(_g,$aa5e);return; }
            if (_g.sequence_phase==0) { _g.sequence_phase=1;ln1_special_action(_g,$aa6f);return; }
            break;
        case 6:
            _g.world_state.flag_b=(_g.world_state.flag_b+1)&255;_g.sequence_wait=100;return;
        case 9:
            if (_p.y>=20) { ln1_special_action(_g,$5057);return; }
            _g.sequence_kind=0;_p.input_lock=0;_p.x=255;ln1_play_exit(_g);return;
    }
    _g.sequence_kind=0;_p.input_lock=0;
}

function ln1_level_events(_g) {
    var _p=_g.player,_e=_g.enemy,_state=_g.world_state;
    if (_state.mode!=5 && _state.mode!=3 && _e.action<256 &&
        ((_g.level==1 && _g.room_id==20 && _p.y<88) ||
         (_g.level==2 && _g.room_id==24 && _p.y<114 && _p.x>=134))) {
        ln1_level_enemy_action(_g,_g.level==1?$4f76:$abaa);
    }
    if (_state.mode==1 && _e.x<40) {
        _p.input_lock=255;_g.player_health=0;
        if (_e.x<8) { _e.active=0;_e.action=0;_e.display_frame=255;_state.mode=0; }
    } else if (_state.mode==2 && (_e.x<4 || _e.x==255)) {
        _e.active=0;_e.action=0;_e.display_frame=255;_state.mode=0;
    }
    if (_g.level==4 && _state.mode==4) {
        if (_e.y<120) { _e.facing=5;_e.heading=4; }
        else { _state.mode=6;ln1_level_enemy_action(_g,$5145);_e.speed=2; }
        return;
    }
    if ((_g.level==4 && _state.mode==6) || (_g.level==6 && _state.mode==7 && _e.active==134)) {
        _e.facing=ln1_enemy_face(_e,_p.x,_p.y);
        if (min(255,abs(_p.x-_e.x)+abs(_p.y-_e.y))<(_g.level==4?8:18)) {
            _p.input_lock=255;_state.mode=0;
            // Source $bf92 tail-calls the contact animation at $4e20.
            ln1_level_enemy_action(_g,_g.level==4?$514f:$4e20);
        } else {
            // The special actor keeps its current animation while pursuit
            // steering changes direction. Starting an ordinary guard stance
            // here replaces the spider or dog with humanoid combat frames.
            var _dx=abs(_p.x-_e.x),_dy=abs(_p.y-_e.y);
            var _headings=[0,2,4,2,4,6,0,6];
            _e.heading=(_dx>>2)<_dy ? _headings[_e.facing-1] :
                (_dy<4 ? _headings[_e.facing] : _e.facing);
        }
    }
    if (_g.level==6 && _state.mode==9 && _p.action<256) ln1_special_action(_g,$5113);
}

/// Source $561f: protection and colour effects use wrapping native tick clocks.
function ln1_level_effect_tick(_g, _cycles=19656) {
    var _s=_g.world_state;
    if ((_s.flag_a|_s.flag_b)!=0) {
        // $555b selects VIC raster IRQs, not the faster CIA gameplay timer.
        if (!variable_struct_exists(_s,"magic_clock")) _s.magic_clock=0;
        _s.magic_clock+=_cycles;
        while (_s.magic_clock>=19656 && (_s.flag_a|_s.flag_b)!=0) {
            _s.magic_clock-=19656;
            if (_s.flag_a==0) _s.flag_b=(_s.flag_b-1)&255;
            _s.flag_a=(_s.flag_a-1)&255;
        }
    } else if (_s.protection==2 && ((_g.player.tick-_s.protection_tick)&255)>=250) _s.protection=0;
}

/// Original $5649/$6fc1 palette cycle; the two bytes are the native magic timer.
function ln1_magic_colour(_g) {
    if ((_g.world_state.flag_a|_g.world_state.flag_b)==0) return -1;
    static _cycle=[0, 6, 9, 2, 11, 4, 8, 12, 14, 5, 10, 3, 15, 7, 13, 1, 13, 7, 15, 3, 10, 5, 14, 12, 8, 4, 11, 2, 9, 6, 0, 0];
    static _colours=[make_colour_rgb(0,0,0),make_colour_rgb(255,255,255),make_colour_rgb(129,51,56),make_colour_rgb(117,206,200),make_colour_rgb(142,60,151),make_colour_rgb(86,172,77),make_colour_rgb(46,44,155),make_colour_rgb(237,241,113),make_colour_rgb(142,80,41),make_colour_rgb(85,56,0),make_colour_rgb(196,108,113),make_colour_rgb(74,74,74),make_colour_rgb(123,123,123),make_colour_rgb(169,255,159),make_colour_rgb(112,109,235),make_colour_rgb(178,178,178)];
    return _colours[_cycle[_g.world_state.flag_a&31]];
}

function ln1_magic_checks() {
    var _g=new LN1Play(2);ln1_play_enter(_g,17);
    var _item=undefined;
    for(var _i=0;_i<array_length(_g.world.items);_i++)
        if (_g.world.items[_i].id==16 && _g.world.items[_i].room==17) _item=_g.world.items[_i];
    ln_check(is_struct(_item),"magic source exists");
    _g.player.x=_item.x_min;_g.player.y=_item.y_min;_g.player.facing=1;
    _g.player.action=0;_g.player.input_lock=0;
    ln1_play_tick(_g,0);
    ln_check(_g.world_state.flag_b==35 && _g.inventory[16]==0,"touch activates renewable magic without fire");
    _g.world_state.flag_a=0;_g.world_state.flag_b=35;
    var _colours=[];
    repeat(8960) {
        var _before=_g.world_state.flag_a+256*_g.world_state.flag_b;
        ln1_level_effect_tick(_g);
        ln_check(_g.world_state.flag_a+256*_g.world_state.flag_b==_before-1,"original 16-bit magic countdown");
        if (array_length(_colours)<32) array_push(_colours,ln1_magic_colour(_g));
    }
    ln_check(ln1_magic_colour(_g)==-1 && _colours[0]!=_colours[2],"magic flashes and stops exactly at expiry");
    _g.world_state.flag_a=0;_g.world_state.flag_b=35;_g.world_state.magic_clock=0;
    var _ticks=ceil(8960*19656/_g.data.timer_period_cycles);
    repeat(_ticks-1) ln1_level_effect_tick(_g,_g.data.timer_period_cycles);
    ln_check((_g.world_state.flag_a|_g.world_state.flag_b)!=0,"magic uses VIC duration, not CIA duration");
    ln1_level_effect_tick(_g,_g.data.timer_period_cycles);
    ln_check((_g.world_state.flag_a|_g.world_state.flag_b)==0,"magic expires on the correct elapsed cycle");
    // Run the room's flame animation through its actual event dispatcher.
    for(var _protected=0;_protected<2;_protected++) {
        var _dragon=new LN1Play(2);ln1_play_enter(_dragon,24);
        _dragon.player.x=140;_dragon.player.y=106;
        _dragon.world_state.flag_b=_protected?35:0;
        _dragon.enemy.action=0;ln1_level_events(_dragon);
        ln_check(_dragon.enemy.action==$abaa,"approaching dragon starts original flame sequence");
        var _flame=false;
        repeat(200) {
            _dragon.player.tick=(_dragon.player.tick+1)&255;ln1_enemy_action(_dragon);
            if (_dragon.enemy.action_state==2) _flame=true;
            ln1_combat_event(_dragon,_dragon.enemy.action_state,true);_dragon.enemy.action_state=0;
        }
        ln_check(_flame && (_dragon.player_health>0)==bool(_protected),"animated dragon fire kills only without magic");
    }
    // Boundary checks exercise the real flame event, with each timer byte alone.
    for(var _state=0;_state<3;_state++) for(var _x=128;_x<133;_x++) for(var _y=98;_y<116;_y++) {
        _g.player.x=_x;_g.player.y=_y;_g.player_health=32;_g.world_state.mode=0;
        _g.world_state.flag_a=_state==1?1:0;_g.world_state.flag_b=_state==2?35:0;
        ln1_combat_event(_g,2,true);
        var _fatal=_state==0 && _x>=130 && _y>=100 && _y<114;
        ln_check((_g.player_health==0)==_fatal,"dragon fire respects source rectangle and magic");
    }
    ln_check(shader_is_compiled(sh_ln_occlusion),"magic shader compiles");
    var _surface=surface_create(16,16);surface_set_target(_surface);
    draw_clear_alpha(c_black,0);draw_set_colour(c_black);draw_rectangle(0,0,7,7,false);
    draw_set_colour(c_yellow);draw_rectangle(8,0,15,7,false);draw_set_colour(c_white);
    var _sprite=sprite_create_from_surface(_surface,0,0,16,16,false,false,0,0);
    draw_clear_alpha(c_black,0);
    ln_draw_masked_actor(_sprite,0,0,0,1,1,-1,0,0,16,16,0.5,1000,false,c_fuchsia);
    ln_check(surface_getpixel(_surface,3,3)==c_fuchsia && surface_getpixel(_surface,11,3)==c_yellow,
        "magic shader recolours body but preserves face/shared colours");
    draw_clear_alpha(c_black,0);
    ln_draw_masked_actor(_sprite,0,0,0,1,1,-1,0,0,16,16);
    ln_check(surface_getpixel(_surface,3,3)==c_black,"magic colour resets for other actors");
    surface_reset_target();sprite_delete(_sprite);surface_free(_surface);
    show_debug_message("LN1_MAGIC_PASS: touch activation, 8960 ticks, colour cycle, expiry and 270 dragon flame cases.");
}
