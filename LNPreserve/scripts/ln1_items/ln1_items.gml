// Apples are counted in inventory; each world location can be harvested once.
function ln1_apple_key(_g,_item) {
    return string(_g.level)+":"+string(_item.room)+":"+string(_item.x_min)+":"+string(_item.y_min);
}
function ln1_item_available(_g,_item) {
    if (_item.id!=8) return _g.inventory[_item.id]==0;
    return !variable_struct_exists(_g.apple_pickups,ln1_apple_key(_g,_item));
}

/// Source $5940: item interaction occurs at the action's input boundary.
function ln1_item_interact(_g, _only_id=-1) {
    var _p = _g.player;
    for (var _i = 0; _i < array_length(_g.world.items); _i++) {
        var _item = _g.world.items[_i];
        if (_only_id>=0 && _item.id!=_only_id) continue;
        if (_item.room != _g.room_id || !ln1_item_available(_g,_item)) continue;
        var _x = _p.x - (_p.facing >= 4 ? 36 : 0);
        if (_x < _item.x_min || _x >= _item.x_max || _p.y < _item.y_min || _p.y >= _item.y_max) continue;
        if (_g.inventory[2] == 0 && _item.id != 2 && _item.id < 10) return;
        // The original $5940 treats these locations as mechanisms, not pickups.
        var _selected = is_struct(_g.controls) ? _g.controls.item : 10;
        if (_item.id == 1 && _selected != 6) {
            _p.input_lock = 255; _g.player_health = 0; return;
        }
        if (_item.id == 16 || _item.id == 18 || _item.id == 19) {
            if (_item.id == 16) _g.world_state.flag_b = 35;
            else {
                _g.world_state.protection = _item.id == 18 ? 5 : 2;
                if (_item.id == 19) _g.world_state.protection_tick = _p.tick;
            }
            _g.notice_item=10;_g.notice_tick=_p.tick;_g.notice_label=1;_g.notice_duration=150;
            return;
        }
        if (_item.id==8) {
            variable_struct_set(_g.apple_pickups,ln1_apple_key(_g,_item),true);
            _g.inventory[8]=(_g.inventory[8]&127)+1;
        } else _g.inventory[_item.id] = _item.id == 14 ? 133 : (_item.id == 15 ? 3 : 1);
        if (_item.id == 9) _g.world_state.mode = 9;
        _g.notice_item = _item.id; _g.notice_tick = _p.tick;
        _g.notice_label = 1; _g.notice_duration = 150;
        if (is_struct(_g.controls)) {
            for (var _j = 0; _j < 11; _j++) _g.controls.inventory[_j] = _g.inventory[_j];
            for (var _j = 0; _j < 6; _j++) _g.controls.weapons[_j] = _g.inventory[10 + _j];
            if (_g.inventory[8] == 128) _g.controls.inventory[8] = 0;
            _g.controls.action_reset = 150;
        }
        return;
    }
}

/// Optional fire-only assistance: use source pickup rectangles and original crouch.
function ln1_pickup_assist_start(_g) {
    var _p=_g.player;
    if (_p.action>=256 || _p.input_lock!=0 || _g.player_health<=0 || _g.water_active || _g.sequence_kind!=0 || _g.prayer_phase!=0) return false;
    var _best=undefined,_distance=100000;
    for (var _i=0;_i<array_length(_g.world.items);_i++) {
        var _item=_g.world.items[_i];
        // Scripted mechanisms/scroll progression retain their original controls.
        if (_item.room!=_g.room_id || _item.sprite=="" || !ln1_item_available(_g,_item) ||
            _item.id>=16 || _item.id==1 || _item.id==9 || _item.id==10) continue;
        if (_g.inventory[2]==0 && _item.id!=2 && _item.id<10) continue;
        for (var _side=0;_side<2;_side++) {
            // Find the nearest reachable point, including sloping boundary edges.
            // Testing only the centre or clamped point can miss a clear approach.
            var _offset=_side?36:0;
            for (var _x=max(0,_item.x_min+_offset);_x<min(256,_item.x_max+_offset);_x++)
            for (var _y=_item.y_min;_y<_item.y_max;_y++) {
                var _dx=_x-_p.x,_dy=_y-_p.y,_dist=_dx*_dx+_dy*_dy;
                if (abs(_dx)>20 || abs(_dy)>16 || _dist>=_distance) continue;
                var _probe={x:_p.x,y:_p.y,boundary_mode:128,boundary_crossings:0},_clear=true;
                var _steps=max(1,ceil(max(abs(_dx),abs(_dy))));
                for (var _step=1;_step<=_steps;_step++) {
                    var _nx=round(_p.x+_dx*_step/_steps),_ny=round(_p.y+_dy*_step/_steps);
                    if (ln1_player_boundary(_probe,_g.data,_nx,_ny)!=0 || _probe.boundary_crossings!=0) {_clear=false;break;}
                    _probe.x=_nx;_probe.y=_ny;
                }
                if (_clear) {_best={id:_item.id,room:_g.room_id,x:_x,y:_y,facing:_side?7:1};_distance=_dist;}
            }
        }
    }
    if (!is_struct(_best)) return false;
    _best.weapon=_p.weapon;_best.health=_g.player_health;_best.elapsed=0;_best.collected=false;
    _best.control_lock=is_struct(_g.controls)?_g.controls.weapon_locked:0;
    _g.pickup_assist=_best;
    _p.x=_best.x;_p.y=_best.y;_p.facing=_best.facing;_p.heading=_p.facing;
    _p.weapon=0;_p.stopped=255;_p.fraction_x=0;_p.fraction_y=0;_p.input_lock=255;
    if (is_struct(_g.controls)) _g.controls.weapon_locked=255;
    ln1_player_begin_action(_p,_g.data,0);
    return true;
}

function ln1_pickup_assist_tick(_g) {
    if (!variable_struct_exists(_g,"pickup_assist") || !is_struct(_g.pickup_assist)) return;
    var _a=_g.pickup_assist,_p=_g.player;
    _a.elapsed++;
    var _cancel=_a.room!=_g.room_id || _g.player_health<_a.health || (_p.combat_state&252)==36;
    // The second crouch hold begins after four ticks. The source hit rectangle
    // aligns the reaching pose with the object; collect only once that pose is held.
    if (!_cancel && !_a.collected && _a.elapsed>=5 && (_p.display_frame==18 || _p.display_frame==19)) {
        ln1_item_interact(_g,_a.id);_a.collected=_g.inventory[_a.id]!=0;
    }
    if (_cancel || _p.action<256) {
        _p.weapon=_a.weapon;
        if (_g.player_health>0 && (_p.combat_state&252)!=36) _p.input_lock=0;
        if (is_struct(_g.controls)) _g.controls.weapon_locked=_a.control_lock;
        _g.pickup_assist=undefined;
    }
}

function ln1_pickup_assist_checks() {
    for (var _id_index=0;_id_index<2;_id_index++) for (var _side=0;_side<2;_side++) {
        var _test=new LN1Play(),_id=_id_index==0?2:4;
        var _item=_test.world.items[_id_index];
        ln1_play_enter(_test,_item.room);
        _test.inventory[2]=_id==2?0:1;_test.inventory[_id]=0;
        var _n=_test.player;
        _n.x=clamp((_side?_item.x_max-1+36:_item.x_min)+(_side?19:-19),0,255);
        _n.y=floor((_item.y_min+_item.y_max-1)/2);
        _n.action=0;_n.input_lock=0;_n.fire_previous=0;_n.weapon=2;_n.selected_weapon=2;
        ln1_player_update(_n,_test.data,16,(_n.tick+1)&255);
        ln_check(is_struct(_test.pickup_assist),"fire near sack/key edge starts assistance: item="+string(_id)+" side="+string(_side)+" x="+string(_n.x)+" y="+string(_n.y));
        ln_check(_test.inventory[_id]==0,"sack/key is not collected before crouching");
        repeat(20) {
            ln1_pickup_assist_tick(_test);
            ln1_player_update(_n,_test.data,16,(_n.tick+1)&255);
        }
        ln_check(_test.inventory[_id]==1 && !is_struct(_test.pickup_assist) && _n.input_lock==0 && _n.weapon==2,
            "fire-only sack/key pickup completes and restores input/weapon on both sides");
    }

    var _g=new LN1Play();_g.room_id=5;_g.data.boundaries=[];
    var _p=_g.player;_p.x=185;_p.y=60;_p.action=0;_p.input_lock=0;_p.weapon=2;_p.selected_weapon=2;
    ln_check(ln1_pickup_assist_start(_g),"nearby sack starts assisted pickup");
    ln_check(_g.inventory[2]==0,"assisted pickup waits for the reaching pose");
    repeat(20) {
        ln1_player_update(_p,_g.data,0,(_p.tick+1)&255);
        ln1_pickup_assist_tick(_g);
    }
    ln_check(_g.inventory[2]==1 && !is_struct(_g.pickup_assist) && _p.input_lock==0 && _p.weapon==2,
        "assisted pickup collects sack and restores weapon/input");
    _g.inventory[2]=0;_p.action=0;_p.x=20;_p.y=60;
    ln_check(!ln1_pickup_assist_start(_g),"distant pickup is not assisted");
    _p.x=202;_p.y=50;_g.data.boundaries=[[0,53,255,53,0]];
    ln_check(!ln1_pickup_assist_start(_g),"pickup assistance does not cross a blocking boundary");
    _g=new LN1Play(2);ln1_test_wilderness_kit(_g);
    ln_check(_g.inventory[2]==1 && _g.inventory[11]==1 && _g.inventory[13]==1 &&
        _g.inventory[14]==5 && _g.inventory[15]==3 && _g.lives_left==4 && _g.player_health==32,
        "F11 Wilderness starter equipment, ammunition, lives and health");
}

// Track real press edges at PAL frequency. Holding fire never consumes an item.
function ln_consumable_tap(_g,_joy,_eligible) {
    if (!variable_struct_exists(_g,"food_taps")) _g.food_taps={remaining:0,previous:0};
    var _t=_g.food_taps,_edge=(_joy&16)!=0 && _t.previous==0;
    _t.previous=_joy&16;_t.remaining=max(0,_t.remaining-1);
    if (!_eligible || (_joy&15)!=0) {_t.remaining=0;return false;}
    if (!_edge) return false;
    if (_t.remaining==0) {_t.remaining=18;return false;}
    _t.remaining=0;return true;
}

function ln1_apple_input(_g,_joy) {
    var _ready=is_struct(_g.controls) && _g.controls.item==8 && (_g.inventory[8]&127)!=0 &&
        _g.player_health>0 && _g.player.input_lock==0 && _g.controls.weapon_locked==0 && !ln1_weapon_changing(_g.player,_g.data);
    if (ln_consumable_tap(_g,_joy,_ready)) {
        var _remaining=(_g.inventory[8]&127)-1;
        _g.inventory[8]=_remaining>0?_remaining:128;
        _g.controls.inventory[8]=max(0,_remaining);
        if (_remaining==0) _g.controls.item=10;
        _g.notice_item=10;_g.notice_duration=0;_g.player_health=32;_g.lives_left++;
    }
    return _ready && (_joy&15)==0 ? 0 : _joy;
}
