enum LNKey { Up, Down, Left, Right, Fire, F1, F3, F5, F7, Weapon, WeaponPrev, CRT, Count }

function LNInput() constructor {
    // Windows UK keyboard: dedicated # key (OEM 7), not character code 35 (End).
    bindings = [ord("W"), ord("S"), ord("A"), ord("D"), 222,
                vk_f1, vk_f3, vk_f5, vk_f7, vk_space, -1, -1];
    sampled = array_create(LNKey.Count, false);
    held = array_create(LNKey.Count, false);
    pressed = array_create(LNKey.Count, false);
    released = array_create(LNKey.Count, false);
    queue = [];
    head = 0;
    enqueue = function(_cycle, _action, _down) {
        array_push(queue, {cycle: int64(_cycle), action: _action, down: _down});
    };
    pad_device=-1;
    pad_lt=false;pad_rt=false;
    sample_values = function(_cycle,_values) {
        for(var _i=0;_i<LNKey.Count;_i++) if(_values[_i]!=sampled[_i]) {
            enqueue(_cycle,_i,_values[_i]);sampled[_i]=_values[_i];
        }
    };
    sample = function(_cycle) {
        if(pad_device<0 || !gamepad_is_connected(pad_device)) {
            pad_device=-1;pad_lt=false;pad_rt=false;
            for(var _j=0;_j<gamepad_get_device_count();_j++) if(gamepad_is_connected(_j)) {pad_device=_j;break;}
        }
        var _values=array_create(LNKey.Count,false);
        if(pad_device>=0) {
            var _id=pad_device;
            pad_lt=gamepad_button_value(_id,gp_shoulderlb)>(pad_lt?0.35:0.55);
            pad_rt=gamepad_button_value(_id,gp_shoulderrb)>(pad_rt?0.35:0.55);
            _values=ln_xbox_map({x:gamepad_axis_value(_id,gp_axislh),y:gamepad_axis_value(_id,gp_axislv),
                up:gamepad_button_check(_id,gp_padu),down:gamepad_button_check(_id,gp_padd),
                left:gamepad_button_check(_id,gp_padl),right:gamepad_button_check(_id,gp_padr),
                a:gamepad_button_check(_id,gp_face1),b:gamepad_button_check(_id,gp_face2),
                xbutton:gamepad_button_check(_id,gp_face3),ybutton:gamepad_button_check(_id,gp_face4),
                lb:gamepad_button_check(_id,gp_shoulderl),rb:gamepad_button_check(_id,gp_shoulderr),
                lt:pad_lt,rt:pad_rt,start:gamepad_button_check(_id,gp_start)});
        }
        for (var _i = 0; _i < LNKey.Count; _i++) {
            var _down = bindings[_i]>=0 && keyboard_check(bindings[_i]);
            if (_i == LNKey.Down && keyboard_check(vk_control)) _down = false;
            if (_i == LNKey.F7 && keyboard_check(ord("P"))) _down = true; // P pauses/unpauses every game, like F7
            _values[_i]=_values[_i] || _down;
        }
        sample_values(_cycle,_values);
    };
    consume = function(_through_cycle) {
        for (var _i = 0; _i < LNKey.Count; _i++) {
            pressed[_i] = false;
            released[_i] = false;
        }
        while (head < array_length(queue) && queue[head].cycle <= _through_cycle) {
            var _e = queue[head++];
            held[_e.action] = _e.down;
            if (_e.down) pressed[_e.action] = true;
            else released[_e.action] = true;
        }
        if (head == array_length(queue)) { queue = []; head = 0; }
    };
    joystick = function() {
        // Active-low CIA joystick bits. Opposites cancel; diagonals are preserved.
        var _value = 255;
        if (held[LNKey.Up] && !held[LNKey.Down]) _value &= ~1;
        if (held[LNKey.Down] && !held[LNKey.Up]) _value &= ~2;
        if (held[LNKey.Left] && !held[LNKey.Right]) _value &= ~4;
        if (held[LNKey.Right] && !held[LNKey.Left]) _value &= ~8;
        if (held[LNKey.Fire]) _value &= ~16;
        return _value;
    };
}

function ln_xbox_map(_p) {
    var _v=array_create(LNKey.Count,false),_x=0,_y=0;
    if(_p.up || _p.down || _p.left || _p.right) {_x=real(_p.right)-real(_p.left);_y=real(_p.down)-real(_p.up);}
    else if(sqr(_p.x)+sqr(_p.y)>0.25*0.25) {
        var _largest=max(abs(_p.x),abs(_p.y));
        if(abs(_p.x)>=_largest*0.414214) _x=sign(_p.x);
        if(abs(_p.y)>=_largest*0.414214) _y=sign(_p.y);
    }
    _v[LNKey.Up]=_y<0;_v[LNKey.Down]=_y>0;_v[LNKey.Left]=_x<0;_v[LNKey.Right]=_x>0;
    _v[LNKey.Fire]=_p.a;_v[LNKey.F7]=_p.b || _p.start;_v[LNKey.F1]=_p.ybutton;_v[LNKey.CRT]=_p.xbutton;
    _v[LNKey.F5]=_p.lb;_v[LNKey.F3]=_p.rb;
    _v[LNKey.WeaponPrev]=_p.lt && !_p.rt;_v[LNKey.Weapon]=_p.rt && !_p.lt;
    return _v;
}

function ln_controller_previous_weapon(_g,_controls) {
    if(_g.game_number==1) {
        if(_controls.weapon_locked!=0 || ln1_weapon_changing(_g.player,_g.data)) return;
        repeat(6) {_controls.weapon=(_controls.weapon+5) mod 6;if(_controls.weapons[_controls.weapon]&127) break;}
        _controls.action_reset=0;_g.notice_item=-1;_g.notice_duration=0;
    } else if(_g.game_number==2) {
        if(_g.player_projectile_active) return;
        repeat(5) {_g.player.selected_weapon=(_g.player.selected_weapon+4) mod 5;if(_g.inventory[_g.player.selected_weapon]&127) break;}
        _g.notice_item=-1;
    } else _g.weapon_switch=2;
}

function ln_xbox_checks() {
    var _p={x:0,y:0,up:false,down:false,left:false,right:false,a:false,b:false,xbutton:false,ybutton:false,lb:false,rb:false,lt:false,rt:false,start:false};
    var _input=new LNInput();
    for(var _x=-1;_x<=1;_x++) for(var _y=-1;_y<=1;_y++) {
        _p.x=_x;_p.y=_y;_input.sample_values(0,ln_xbox_map(_p));_input.consume(0);
        var _expected=(_y<0?1:0)|(_y>0?2:0)|(_x<0?4:0)|(_x>0?8:0);
        ln_check((_input.joystick()^255)==_expected,"stick eight-way direction");
    }
    _p.x=0.1;_p.y=-0.1;_input.sample_values(0,ln_xbox_map(_p));_input.consume(0);
    ln_check(_input.joystick()==255,"stick drift deadzone");
    _p.x=1;_p.left=true;_input.sample_values(0,ln_xbox_map(_p));_input.consume(0);
    ln_check((_input.joystick()^255)==4,"D-pad overrides stick");
    _p.x=0;_p.y=0;_p.left=false;_p.a=true;
    _input.sample_values(1,ln_xbox_map(_p));_input.consume(1);ln_check(_input.pressed[LNKey.Fire],"A fire edge");
    _input.sample_values(2,ln_xbox_map(_p));_input.consume(2);ln_check(!_input.pressed[LNKey.Fire] && _input.held[LNKey.Fire],"held A does not repeat");
    _input.sample_values(3,array_create(LNKey.Count,false));_input.consume(3);ln_check(_input.released[LNKey.Fire],"disconnect releases held controls");
    var _names=["b","start","xbutton","ybutton","lb","rb","lt","rt"],_keys=[LNKey.F7,LNKey.F7,LNKey.CRT,LNKey.F1,LNKey.F5,LNKey.F3,LNKey.WeaponPrev,LNKey.Weapon];
    _p.a=false;
    for(var _i=0;_i<8;_i++) {variable_struct_set(_p,_names[_i],true);var _v=ln_xbox_map(_p);ln_check(_v[_keys[_i]],"Xbox button mapping "+_names[_i]);variable_struct_set(_p,_names[_i],false);}
    var _g=new LN2Play(1);_g.inventory[0]=255;_g.inventory[1]=255;_g.inventory[2]=0;_g.inventory[3]=255;_g.inventory[4]=0;
    _g.player.selected_weapon=0;ln_controller_previous_weapon(_g,undefined);ln_check(_g.player.selected_weapon==3,"LT wraps to previous owned weapon");
    ln2_controls_update(_g,255,239);ln_check(_g.player.selected_weapon==0,"RT wraps forward to fists");
    _g.player_projectile_active=true;ln_controller_previous_weapon(_g,undefined);ln_check(_g.player.selected_weapon==0,"LT respects projectile lock");
    var _c=ln3_data_read("actors/ln1/initial_control_state.json");_g=new LN1Play();_c.weapon_locked=0;_c.weapon=0;_c.weapons=[1,0,1,0,0,1];
    ln_controller_previous_weapon(_g,_c);ln_check(_c.weapon==5,"LN1 reverse weapon wrap");
    _g=new LN3Play();_g.state.player_dead=0;_g.state.stun=0;_g.state.input_block=0;_g.state.climb_flags=0;_g.state.player_weapon=0;
    _g.state.inventory[3]=1;ln3_weapon_select(_g.state,_g.actions,_g.input,0,2);ln_check(_g.state.pending_weapon==4,"LN3 reverse weapon wrap");
    var _connected=0;for(var _i=0;_i<gamepad_get_device_count();_i++) if(gamepad_is_connected(_i)) _connected++;
    show_debug_message("LN_XBOX_PASS: movement, deadzone, button mapping, input edges, disconnect release and reverse weapons. Connected controllers: "+string(_connected));
}

/// Number-row quick starts use fresh game state and never enter C64 key rows.
function ln_quick_start(_host,_game) {
    var _old=_host.play,_transport=_old.timer;
    if (_old.game_number==2) ln2_ending_free(_old);
    if (_old.game_number==3) ln3_ending_free(_old);
    if (surface_exists(_old.stage_surface)) surface_free(_old.stage_surface);
    if (variable_struct_exists(_old,"part_surface") && surface_exists(_old.part_surface)) surface_free(_old.part_surface);
    _host.play=_game==1?new LN1Play():(_game==2?new LN2Play():new LN3Play());
    _host.play.timer=_transport;_transport.cycles_per_frame=_host.play.data.timer_period_cycles;
    _host.control_state_ln1=ln3_data_read("actors/ln1/initial_control_state.json");
    _host.play.controls=_host.control_state_ln1;_host.input_state=new LNInput();
    _host.workbench=false;_host.scene_test.menu=false;_host.scene_test.preview=false;_host.scene_test.message_us=0;
    _host.scene_test.game=_game;
    ln_frontend_begin(_host.play);
}

function ln_function_key_checks() {
    var _input=new LNInput();
    for(var _i=0;_i<4;_i++) ln_check(_input.bindings[LNKey.F1+_i]==[vk_f1,vk_f3,vk_f5,vk_f7][_i],"matching PC/C64 function key");
    for(var _i=0;_i<array_length(_input.bindings);_i++) ln_check(!array_contains([ord("1"),ord("2"),ord("3"),ord("4")],_input.bindings[_i]),"number row does not drive C64 functions");
    var _host={play:new LN1Play(),scene_test:{menu:true,preview:true,message_us:100,game:1},workbench:true};
    for(var _game=1;_game<=3;_game++) {
        ln_quick_start(_host,_game);
        ln_check(_host.play.game_number==_game && _host.play.level==1,"quick start selects first level");
        ln_check(_host.play.room_id==(_game==3?_host.play.data.initial.room_id:1),"quick start selects opening scene");
        ln_check(!_host.workbench && !_host.scene_test.menu && !_host.scene_test.preview,"quick start returns to gameplay");
    }
    show_debug_message("LN_FUNCTION_KEYS_PASS: matching F1/F3/F5/F7 and three fresh game starts");
}

/// Enhanced/Original per game. LN3's setting also covers smooth motion and slower jumps.
function ln_enhanced_enabled(_game) {
    if(_game==3) return ln3_smooth_enabled();
    var _name=_game==1?"ln_ln1_enhanced":"ln_ln2_enhanced";
    return !variable_global_exists(_name) || variable_global_get(_name);
}
function ln_enhanced_label(_game) {return "LN"+string(_game)+" mode: "+(ln_enhanced_enabled(_game)?"Enhanced":"Original");}
function ln_enhanced_toggle(_game) {
    if(_game==3) global.ln_ln3_smooth=!ln3_smooth_enabled();
    else variable_global_set(_game==1?"ln_ln1_enhanced":"ln_ln2_enhanced",!ln_enhanced_enabled(_game));
}

/// Enhanced double-tap turn: tap a direction, then press it again within about a third
/// of a second. Call once per 50 Hz tick with the joystick bits; returns the direction
/// (joystick bits) of a completed double tap, otherwise 0. Diagonals pressed one key at a
/// time count as the diagonal. Fire cancels.
function ln_tap_new() {return {pressed:0,age:0,gap:99,start_gap:99,last:0};}
function ln_tap_bits(_d) {return (_d&1)+((_d>>1)&1)+((_d>>2)&1)+((_d>>3)&1);}
function ln_tap_step(_t,_joy) {
    var _window=18,_d=_joy&15;
    if((_joy&16)!=0 || (_d&3)==3 || (_d&12)==12) {_t.pressed=0;_t.last=0;_t.gap=99;return 0;}
    if(_d!=0) {
        if(_t.pressed==0) {_t.pressed=_d;_t.age=0;_t.start_gap=_t.gap;}
        else {_t.age++;if(ln_tap_bits(_d)>=ln_tap_bits(_t.pressed)) _t.pressed=_d;}
        if(_t.last!=0 && _t.pressed==_t.last && _t.age<=_window && _t.start_gap<=_window) {_t.last=0;return _t.pressed;}
        return 0;
    }
    if(_t.pressed!=0) {_t.last=_t.age<=_window?_t.pressed:0;_t.pressed=0;_t.gap=0;}
    else if(_t.gap<99) _t.gap++;
    return 0;
}

/// Feeds a joystick script, one entry per 50 Hz tick, to a double-tap tracker.
function ln_tap_script(_joys) {
    var _t=ln_tap_new(),_hit=0;
    for(var _i=0;_i<array_length(_joys);_i++) {var _r=ln_tap_step(_t,_joys[_i]);if(_r!=0) _hit=_r;}
    return _hit;
}
function ln_double_tap_checks() {
    ln_check(ln_tap_script([8,9,9,0,0,0,9,9])==9,"double tap: a diagonal pressed one key at a time counts");
    ln_check(ln_tap_script([6,6,0,0,6])==6,"double tap: quick second press turns");
    ln_check(ln_tap_script([6,6,6,6])==0,"double tap: a single hold does not turn");
    ln_check(ln_tap_script([6,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6])==0,"double tap: a slow second press does not turn");
    ln_check(ln_tap_script([6,0,22,0,6])==0 && ln_tap_script([6,0,5])==0,"double tap: fire or another direction cancels");
    var _was1=ln_enhanced_enabled(1),_was2=ln_enhanced_enabled(2),_was3=ln_enhanced_enabled(3),_cases=0;
    // LN1 and LN2: double-tapping the opposite diagonal faces it; Original keeps walking backwards.
    for(var _game=1;_game<=2;_game++) for(var _mode=0;_mode<2;_mode++) for(var _facing=1;_facing<8;_facing+=2) {
        variable_global_set(_game==1?"ln_ln1_enhanced":"ln_ln2_enhanced",_mode==1);
        var _g=_game==1?new LN1Play():new LN2Play(1),_p=_g.player,_d=_g.data;
        _d.boundaries=[];_p.x=120;_p.y=110;_p.facing=_facing;_p.heading=_facing;_p.action=0;_p.input_lock=0;
        _p.stopped=255;_p.fire_previous=0;_p.enemy_active=0;_p.turn_lock=0;
        if(_game==2) {_p.room_id=1;_p.vehicle=0;_p.depth_y=110;_p.fraction_x=0;_p.fraction_y=0;}
        var _back=(_facing+4)&7,_joy=0;
        for(var _j=1;_j<16;_j++) if(_d.directions[_j]==_back) {_joy=_j;break;}
        if(_game==2) for(var _j=1;_j<16;_j++) if(_d.directions[_j]<128 && ((_d.directions[_j]+_p.control_rotation-1)&7)==_back) {_joy=_j;break;}
        var _taps=[_joy,_joy,0,0,_joy,_joy,_joy];
        for(var _i=0;_i<array_length(_taps);_i++) {
            if(_game==1) ln1_player_update(_p,_d,_taps[_i],(_p.tick+1)&255);else ln2_player_update(_p,_d,_taps[_i],(_p.tick+1)&255);
        }
        ln_check(_p.facing==(_mode==1?_back:_facing),"LN"+string(_game)+(_mode==1?" enhanced double tap faces the tapped way":" original double tap keeps facing"));
        _cases++;
    }
    // LN3: from each facing, double-tap each diagonal; enhanced ends facing and walking forward that way.
    var _diagonals=[10,6,9,5];
    for(var _mode=0;_mode<2;_mode++) for(var _start=0;_start<4;_start++) for(var _k=0;_k<4;_k++) {
        global.ln_ln3_smooth=_mode==1;
        var _g=new LN3Play(1),_s=_g.state;
        repeat(8) ln3_play_tick(_g,0);
        _s.mirror=(_s.mirror&249)|((_start&1)?6:0);ln3_action_set(_s,_g.actions,_start>>1);
        var _dir=_diagonals[_k],_taps=[_dir,_dir,0,0,_dir];
        for(var _i=0;_i<array_length(_taps);_i++) ln3_play_tick(_g,_taps[_i]);
        repeat(4) ln3_play_tick(_g,_dir);
        var _forward=_s.player_action==2 || _s.player_action==4;
        if(_mode==1) ln_check(_forward && ((_s.mirror&6)!=0)==((_dir&4)!=0),"LN3 enhanced double tap faces and walks the tapped way (start "+string(_start)+" dir "+string(_dir)+" action "+string(_s.player_action)+" mirror "+string(_s.mirror)+" flags "+string(_s.player_action_flags)+")");
        else if(_k==3-_start) ln_check(!_forward,"LN3 original double tap still walks backwards");
        _cases++;
    }
    global.ln_ln1_enhanced=_was1;global.ln_ln2_enhanced=_was2;global.ln_ln3_smooth=_was3;
    show_debug_message("LN_DOUBLE_TAP_PASS: "+string(_cases)+" tracker, LN1, LN2 and LN3 turn cases in both modes");
}
