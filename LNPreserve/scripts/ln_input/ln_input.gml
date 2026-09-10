enum LNKey { Up, Down, Left, Right, Fire, F1, F3, F5, F7, Weapon, WeaponPrev, CRT, Count }

function LNInput() constructor {
    // Windows UK keyboard: dedicated # key (OEM 7), not character code 35 (End).
    bindings = [ord("W"), ord("S"), ord("A"), ord("D"), 222,
                ord("1"), ord("2"), ord("3"), ord("4"), vk_space, -1, -1];
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
