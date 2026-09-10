/// Original throw setup; melee/item interaction is a separate preceding call.
function ln2_projectile_spawn_rule(_s,_d,_actor) {
    var _requests=[{kind:"attack",actor:_actor,value:0}],_q=_s.projectiles[_actor];
    if (_actor==0) {
        if (_q.kind!=0) return _requests;
        if (_s.weapon==0) {
            if (_s.selected_item!=10) return _requests;
            _q.kind=_s.object_flag==0?6:7;_q.life=30;
        } else {
            if (_s.weapon!=4 || (_s.ammo&127)==0) return _requests;
            _s.ammo=(_s.ammo-1)&255;
            if ((_s.ammo&127)==0) {
                _s.weapon=0;_s.selected_weapon=0;array_push(_requests,{kind:"icon",actor:0,value:0});
            }
            _q.kind=1;_q.life=255;
        }
    } else {
        if (_q.kind!=0) return _requests;
        _q.kind=1;_q.life=255;
    }
    _q.facing=_s.facing[_actor];var _dx=_d.spawn_xy[_q.facing],_x=_s.actor_x[_actor]+(_dx>=128?_dx-256:_dx);
    if (_x<0 || _x>255) {_q.kind=0;return _requests;}
    _q.x=_x;_q.y=(_s.actor_y[_actor]+_d.spawn_xy[_q.facing+1])&255;_q.buffer=255;
    return _requests;
}

function ln2_projectile_stop(_q) {_q.kind=0;_q.enabled=0;_q.sprite_y=0;}

function ln2_projectile_update_rule(_s,_d) {
    var _elapsed=(_s.tick-_s.previous)&255,_requests=[];if (_elapsed==0) return _requests;
    _s.previous=_s.tick;
    for (var _actor=1;_actor>=0;_actor--) {
        var _q=_s.projectiles[_actor];if (_q.kind==0) continue;
        var _kind=_q.kind&7,_offset=_q.facing+_d.offsets[_kind];
        repeat(_elapsed) {
            _q.life=(_q.life-1)&255;
            if (_q.life==0) {ln2_projectile_stop(_q);break;}
            if (_q.life<8) continue;
            if (_kind<2 && _q.buffer<128 && _q.probes[_q.buffer==0?0:1]==0) {ln2_projectile_stop(_q);break;}
            var _dx=_d.motion[_offset],_x=_q.x+(_dx>=128?_dx-256:_dx);
            if (_x<0 || _x>255) {ln2_projectile_stop(_q);break;}
            _q.x=_x;if (_q.x>=253) {ln2_projectile_stop(_q);break;}
            _q.y=(_q.y+_d.motion[_offset+1])&255;
            if (_q.y<34 || _q.y>=177) {ln2_projectile_stop(_q);break;}
        }
        if (_q.kind==0) continue;
        var _target=1-_actor,_combat=_s.combat[_target]&252;
        if (_combat==36 || _combat==12 || _kind>=6) continue;
        if (_target==1 && _s.enemy_active<128) continue;
        if (abs(_s.actor_y[_target]-_q.y)>=8 || abs(_s.actor_x[_target]-_q.x)>=6) continue;
        array_push(_requests,{kind:"damage",actor:_target,value:_target==0?22:44});
        array_push(_requests,{kind:"hurt",actor:_target,value:0});ln2_projectile_stop(_q);
    }
    return _requests;
}

function ln2_projectile_checks() {
    var _o=ln3_data_read("verification/ln2_projectile_vectors.json"),_level=0,_d=undefined;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];
        if (_level!=_v.level) {_level=_v.level;_d=ln3_data_read("play/ln2/level"+string(_level)+"/projectiles.json");}
        var _s=_v.before,_requests=_v.operation==0?ln2_projectile_update_rule(_s,_d):ln2_projectile_spawn_rule(_s,_d,_v.actor);
        ln3_state_check(_s,_v.expected,"LN2 original projectile state "+string(_i));
        ln_check(array_length(_requests)==array_length(_v.requests),"LN2 original projectile request count "+string(_i));
        for (var _j=0;_j<array_length(_requests);_j++) ln3_state_check(_requests[_j],_v.requests[_j],"LN2 original projectile external request "+string(_i));
    }
    ln2_projectile_mask_checks();
    ln2_projectile_integration_checks();
    show_debug_message("LN2_PROJECTILES_PASS: "+string(array_length(_o.vectors))+" original spawn/update states; visibility probes supplied, damage/interaction/display callees recorded.");
}

/// Original $96a3 overlap and paired-bit alignment, including wrapped mask Y.
function ln2_sprite_mask_bits(_records,_x,_y,_depth) {
    var _result=array_create(63,255);
    for (var _i=0;_i<array_length(_records);_i++) {
        var _r=_records[_i];if (_r.baseline<_depth) continue;
        var _dx=_r.x-_x,_dy=_r.y-_y,_sx=max(0,-_dx),_sy=max(0,-_dy),_tx=max(0,_dx),_ty=max(0,_dy);
        if (_sx>=_r.width || _sy>=_r.height || _tx>=24 || _ty>=21) continue;
        var _endx=min(24,_r.width-_sx+_tx),_endy=min(21,_r.height-_sy+_ty);
        for (var _py=_ty;_py<_endy;_py++) {
            var _oy=_sy+_py-_ty;
            for (var _px=_tx;_px<_endx;_px+=2) {
                var _ox=_sx+_px-_tx,_cell=(_oy div 8)*_r.width+(_ox div 8)*8+(_oy&7);
                if ((_r.bitmap[_cell]>>(6-(_ox&6)))&3) _result[_py*3+(_px div 8)]&=255^(192>>(_px&6));
            }
        }
    }
    return _result;
}

/// Draw PNG regions permitted by the original mask. Equal rows share a draw.
function ln2_sprite_draw_bits(_sprite,_frame,_x,_y,_bits) {
    var _row=0;
    while (_row<21) {
        var _height=1;
        while (_row+_height<21 && _bits[_row*3]==_bits[(_row+_height)*3] &&
            _bits[_row*3+1]==_bits[(_row+_height)*3+1] && _bits[_row*3+2]==_bits[(_row+_height)*3+2]) _height++;
        var _column=0;
        while (_column<24) {
            if ((_bits[_row*3+(_column div 8)]&(128>>(_column&7)))==0) {_column++;continue;}
            var _start=_column;_column++;
            while (_column<24 && (_bits[_row*3+(_column div 8)]&(128>>(_column&7)))!=0) _column++;
            draw_sprite_part(_sprite,_frame,_start,_row,_column-_start,_height,_x+_start,_y+_row);
        }
        _row+=_height;
    }
}

function ln2_projectile_mask_checks() {
    var _o=ln3_data_read("verification/ln2_projectile_art_vectors.json"),_art=ln3_data_read("play/ln2/projectile_art.json"),_level=0,_d=undefined;
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];if (_level!=_v.level) {_level=_v.level;_d=ln3_data_read("play/ln2/level"+string(_level)+"/projectile_art.json");}
        var _records=[];for (var _j=0;_j<array_length(_d.depth);_j++) if (_d.depth[_j].room==_v.room) {_records=_d.depth[_j].masks;break;}
        var _bits=ln2_sprite_mask_bits(_records,_v.expected.x+24,_v.expected.y+50,_v.y),_raw=_art.frames[_v.frame].raw;
        for (var _j=0;_j<63;_j++) {
            ln_check(_bits[_j]==_v.visibility[_j],"LN2 original full 24x21 visibility mask "+string(_i)+":"+string(_j));
            ln_check((_raw[_j]&_bits[_j])==_v.expected.raw[_j],"LN2 original projectile sprite mask "+string(_i)+":"+string(_j));
        }
    }
    show_debug_message("LN2_PROJECTILE_MASK_PASS: "+string(array_length(_o.vectors))+" original masked projectile sprites across 93 scene records, including odd-X and offscreen masks.");
}

function ln2_projectile_gpu_checks() {
    var _o=ln3_data_read("verification/ln2_projectile_art_vectors.json"),_art=ln3_data_read("play/ln2/projectile_art.json"),_level=0,_d=undefined;
    var _surface=surface_create(24,21),_buffer=buffer_create(24*21*4,buffer_fixed,1),_pixels=0;
    var _palette=[c_black,c_white,make_colour_rgb(129,51,56),make_colour_rgb(117,206,200),make_colour_rgb(142,60,151),make_colour_rgb(86,172,77),make_colour_rgb(46,44,155)];
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];if (_level!=_v.level) {_level=_v.level;_d=ln3_data_read("play/ln2/level"+string(_level)+"/projectile_art.json");}
        var _records=[];for (var _j=0;_j<array_length(_d.depth);_j++) if (_d.depth[_j].room==_v.room) {_records=_d.depth[_j].masks;break;}
        var _bits=ln2_sprite_mask_bits(_records,_v.expected.x+24,_v.expected.y+50,_v.y);
        surface_set_target(_surface);draw_clear_alpha(c_black,0);ln2_sprite_draw_bits(asset_get_index(_art.sprite),_v.frame,0,0,_bits);surface_reset_target();buffer_get_surface(_buffer,_surface,0);
        for (var _y=0;_y<21;_y++) for (var _x=0;_x<24;_x++) {
            var _visible=(_v.expected.raw[_y*3+(_x div 8)]&(128>>(_x&7)))!=0,_actual=buffer_peek(_buffer,(_y*24+_x)*4,buffer_u32);
            ln_check(((_actual>>24)&255)==(_visible?255:0),"LN2 original masked projectile GPU alpha "+string(_i));
            if (_visible) ln_check((_actual&$ffffff)==_palette[_v.expected.colour],"LN2 original projectile GPU colour "+string(_i));_pixels++;
        }
    }
    surface_free(_surface);buffer_delete(_buffer);
    show_debug_message("LN2_PROJECTILE_GPU_PASS: "+string(_pixels)+" original masked projectile pixels in the GameMaker renderer.");
    ln2_projectile_bodies_gpu_checks();
}

function ln2_projectile_init(_g) {
    if (!variable_global_exists("ln2_knife_art")) global.ln2_knife_art=ln3_data_read("play/ln2/juggler_knives.json");
    if (!variable_global_exists("ln2_projectile_cache")) global.ln2_projectile_cache=array_create(7,undefined);
    if (!is_struct(global.ln2_projectile_cache[_g.level-1])) {
        var _folder="play/ln2/level"+string(_g.level)+"/";
        global.ln2_projectile_cache[_g.level-1]={rules:ln3_data_read(_folder+"projectiles.json"),art:ln3_data_read(_folder+"projectile_art.json"),bodies:ln3_data_read(_folder+"projectile_bodies.json")};
    }
    if (!variable_global_exists("ln2_projectile_art")) global.ln2_projectile_art=ln3_data_read("play/ln2/projectile_art.json");
    if (!variable_global_exists("ln2_projectile_bodies")) global.ln2_projectile_bodies=ln3_data_read("play/ln2/projectile_bodies.json");
    _g.projectile_data=global.ln2_projectile_cache[_g.level-1].rules;
    _g.projectile_art=global.ln2_projectile_cache[_g.level-1].art;
    _g.projectile_bodies=global.ln2_projectile_cache[_g.level-1].bodies;
    ln2_projectile_reset(_g);
}

function ln2_projectile_reset(_g) {
    _g.projectiles=[];
    repeat(2) array_push(_g.projectiles,{kind:0,facing:1,x:0,y:0,life:0,phase:0,buffer:255,enabled:0,sprite_y:0,
        probes:[0,0],frame:-1,draw_x:0,draw_y:0,mask_bits:array_create(63,255)});
    _g.projectile=_g.projectiles[0];_g.projectile_clock=_g.player.tick;_g.player_projectile_active=false;
}

function ln2_projectile_state(_g,_tick) {
    return {tick:_tick,previous:_g.projectile_clock,weapon:_g.player.weapon,selected_weapon:_g.player.selected_weapon,
        selected_item:_g.selected_item,ammo:_g.inventory[4],object_flag:_g.inventory[19],
        actor_x:[_g.player.x,_g.enemy.x],actor_y:[_g.player.y,_g.enemy.y],facing:[_g.player.facing,_g.enemy.facing],
        combat:[_g.player.combat_state,_g.enemy.combat_state],enemy_active:_g.enemy.active,projectiles:_g.projectiles};
}

function ln2_projectile_throw(_g,_enemy) {
    ln2_combat_attack(_g,_enemy,4);
    var _s=ln2_projectile_state(_g,_g.player.tick);ln2_projectile_spawn_rule(_s,_g.projectile_data,_enemy?1:0);
    _g.player.weapon=_s.weapon;_g.player.selected_weapon=_s.selected_weapon;_g.inventory[4]=_s.ammo;
    _g.player_projectile_active=_g.projectiles[0].kind!=0;_g.enemy.projectile_active=_g.projectiles[1].kind;
}

function ln2_projectile_motion(_g,_tick) {
    var _s=ln2_projectile_state(_g,_tick),_requests=ln2_projectile_update_rule(_s,_g.projectile_data);_g.projectile_clock=_s.previous;
    for (var _i=0;_i<array_length(_requests);_i++) {
        var _r=_requests[_i];if (_r.kind=="damage") {
            if (_r.actor!=0 || !ln_test_enemy_damage_disabled()) ln2_damage(_g,_r.value,_r.actor==1);
        }
        else if (_r.kind=="hurt") ln2_combat_hurt(_g,_r.actor==1);
    }
    _g.player_projectile_active=_g.projectiles[0].kind!=0;_g.enemy.projectile_active=_g.projectiles[1].kind;
    for (var _i=0;_i<2;_i++) _g.projectiles[_i].phase=_g.projectiles[_i].life;
}

function ln2_projectile_present(_g) {
    for (var _i=0;_i<2;_i++) {
        var _q=_g.projectiles[_i];if (_q.kind==0) {_q.frame=-1;continue;}
        var _knife=(_q.kind&7)>=2 && (_q.kind&7)<=5;
        var _map=_knife?global.ln2_knife_art.maps:_g.projectile_art.frames;
        _q.frame=variable_struct_get(_map,string(_q.kind))[_q.x];
        _q.kind^=8;_q.buffer=_q.buffer==255?0:(_q.buffer^1);
        _q.draw_x=((_q.x+4)&255)-24;_q.draw_y=((_q.y+12)&255)-50;_q.sprite_y=_q.draw_y+50;_q.enabled=_q.sprite_y;
        _q.mask_bits=ln2_sprite_mask_bits(_g.sprite_masks,_q.draw_x+24,_q.sprite_y,_q.y);
        var _raw=(_knife?global.ln2_knife_art:global.ln2_projectile_art).frames[_q.frame].raw;
        _q.probes[_q.buffer]=(_raw[1]&_q.mask_bits[1])|(_raw[4]&_q.mask_bits[4])|(_raw[7]&_q.mask_bits[7]);
    }
    _g.enemy.projectile_active=_g.projectiles[1].kind;
}

function ln2_projectile_draw(_g,_enemy) {
    var _q=_g.projectiles[_enemy?1:0];if (_q.kind==0 || _q.frame<0 || _q.enabled==0) return;
    ln2_sprite_draw_bits(asset_get_index(((_q.kind&7)>=2 && (_q.kind&7)<=5)?global.ln2_knife_art.sprite:global.ln2_projectile_art.sprite),_q.frame,_q.draw_x,_q.draw_y,_q.mask_bits);
}

function ln2_projectile_body_draw(_g,_a,_enemy) {
    var _costume=_enemy && !_a.custom?_a.costume:0,_key=string(_a.display_frame)+":"+string(real(_a.mirror));
    var _poses=variable_struct_get(_g.projectile_bodies.poses,string(_costume));
    if (!variable_struct_exists(_poses,_key)) throw "Missing original LN2 projectile body pose "+_key;
    var _parts=variable_struct_get(_poses,_key),_sprite=asset_get_index(global.ln2_projectile_bodies.sprite);
    for (var _i=0;_i<array_length(_parts);_i++) {
        var _part=_parts[_i],_x=_a.x+_part.x,_y=((_a.y+_part.y+50)&255)-50;
        if (_g.mask<0) {draw_sprite(_sprite,_part.frame,_x,_y);continue;}
        if (_x+24<0 || _x+24>=264 || _y+50==0) continue;
        var _bits=ln2_sprite_mask_bits(_g.sprite_masks,_x+24,_y+50,_a.depth_y);
        for (var _px=0;_px<24;_px++) if (_x+24+_px>=264)
            for (var _py=0;_py<21;_py++) _bits[_py*3+(_px div 8)]&=255^(128>>(_px&7));
        ln2_sprite_draw_bits(_sprite,_part.frame,_x,_y,_bits);
    }
}

function ln2_projectile_integration_checks() {
    var _g=new LN2Play(1);_g.player.x=120;_g.player.y=100;_g.player.facing=3;
    _g.inventory[4]=129;_g.player.weapon=4;_g.player.selected_weapon=4;_g.enemy.active=0;
    ln2_projectile_throw(_g,false);
    ln_check(_g.projectile.kind==1 && _g.inventory[4]==128 && _g.player.weapon==0 && _g.player.selected_weapon==0,"LN2 last throwing star consumes ammunition and selects empty hand");
    ln2_projectile_motion(_g,(_g.projectile_clock+1)&255);ln2_projectile_present(_g);
    ln_check(_g.projectile.kind==9 && _g.projectile.frame>=0 && _g.projectile.buffer==0,"LN2 native throw reaches original first sprite buffer/phase");
    ln2_projectile_reset(_g);_g.player.combat_state=0;_g.player_health=44;
    var _q=_g.projectiles[1];_q.kind=1;_q.x=_g.player.x;_q.y=_g.player.y;_q.life=7;
    ln2_projectile_motion(_g,(_g.projectile_clock+1)&255);
    ln_check(_g.player_health==22 && _q.kind==0,"LN2 original enemy projectile applies 22 damage and despawns");
    global.ln_test_no_enemy_damage=true;ln2_projectile_reset(_g);_g.player.combat_state=0;_g.player_health=44;
    _q=_g.projectiles[1];_q.kind=1;_q.x=_g.player.x;_q.y=_g.player.y;_q.life=7;
    ln2_projectile_motion(_g,(_g.projectile_clock+1)&255);
    ln_check(_g.player_health==44 && _q.kind==0,"F11 protection absorbs LN2 hostile projectile damage");
    global.ln_test_no_enemy_damage=false;
    ln2_test_enter(_g,0);ln_check(_g.projectiles[0].kind==0 && _g.projectiles[1].kind==0,"LN2 scene entry clears both projectiles");
    show_debug_message("LN2_PROJECTILE_INTEGRATION_PASS: original action dispatch, ammunition, graphics buffer, player hit and room reset; complete combat replay pending.");
}

function ln2_projectile_bodies_gpu_checks() {
    var _o=ln3_data_read("verification/ln2_projectile_bodies_gpu.json"),_g=undefined,_level=0,_pixels=0;
    var _surface=surface_create(96,96),_b=buffer_create(96*96*4,buffer_fixed,1);
    for (var _i=0;_i<array_length(_o.vectors);_i++) {
        var _v=_o.vectors[_i];if (_level!=_v.level) {_level=_v.level;_g=new LN2Play(_level);_g.mask=-1;}
        var _e=_g.enemy;_e.x=48;_e.y=64;_e.custom=false;_e.display_frame=_v.frame;_e.mirror=_v.mirror;_e.costume=_v.costume;
        surface_set_target(_surface);draw_clear_alpha(c_black,0);ln2_projectile_body_draw(_g,_e,true);surface_reset_target();buffer_get_surface(_b,_surface,0);
        for (var _y=0;_y<96;_y++) for (var _x=0;_x<96;_x++) {
            var _code=string_char_at(_v.rows[_y],_x+1),_actual=buffer_peek(_b,(_y*96+_x)*4,buffer_u32),_visible=_code!=".";
            ln_check(((_actual>>24)&255)==(_visible?255:0),"LN2 original body during projectile GPU alpha "+string(_i));
            if (_visible) {
                var _rgb=_o.palette[string_pos(_code,"0123456789abcdef")-1];
                ln_check((_actual&$ffffff)==make_colour_rgb(_rgb[0],_rgb[1],_rgb[2]),"LN2 original body during projectile GPU colour "+string(_i));
            }
            _pixels++;
        }
    }
    buffer_delete(_b);surface_free(_surface);
    _g=new LN2Play(1);_g.player.x=120;_g.player.y=110;_g.player.depth_y=110;_g.player.facing=3;
    _g.player.display_frame=32;_g.player.mirror=false;_g.player.weapon=4;_g.player.selected_weapon=4;_g.inventory[4]=137;_g.enemy.active=0;
    ln2_projectile_throw(_g,false);
    repeat(3) {ln2_projectile_motion(_g,(_g.projectile_clock+1)&255);ln2_projectile_present(_g);}
    ln2_play_draw(_g);surface_save(application_surface,"lnpreserve-ln2-projectile.png");surface_free(_g.stage_surface);
    show_debug_message("LN2_PROJECTILE_BODIES_GPU_PASS: "+string(_pixels)+" original body compositor pixels while the fourth sprite is a projectile.");
}
