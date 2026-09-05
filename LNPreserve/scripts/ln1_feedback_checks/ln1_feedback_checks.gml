/// Integration regressions for feedback, room state, prayer and water transitions.
function ln1_feedback_checks() {
    var _g = new LN1Play(), _p = _g.player;
    _g.last_entry = 8 * 4; ln1_play_enter(_g, 8);
    var _item = _g.world.items[2]; // Original nunchakus placement.
    _p.x = _item.x_min; _p.y = _item.y_min; _p.facing = 1; _p.tick = 250;
    ln1_item_interact(_g);
    ln_check(_g.inventory[13] == 1 && _g.notice_item == 13 && _g.notice_label == 1, "nunchakus pickup sets FOUND and inventory");
    _p.tick = 143; ln1_notice_update(_g);
    ln_check(_g.notice_item == 13, "FOUND survives 149 ticks across clock wrap");
    _p.tick = 144; ln1_notice_update(_g);
    ln_check(_g.notice_item == -1 && _g.notice_label == 0, "FOUND restores USING at original 150 ticks");
    _g.room_age = 62; ln1_play_enter(_g, 8);
    ln_check(_g.room_age == 0 && _item.flashes == 2 && sprite_get_number(asset_get_index(_item.flash_sprite)) == 31,
        "room entry restarts two complete original colour ramps, including nunchakus");
    ln_check(_g.inventory[13] == 1, "room entry does not restore a collected item");

    ln1_play_enter(_g, 2);
    var _e = _g.enemy;
    // A confirmed hit from the independent original-machine-code range vectors.
    _e.active = 128; _e.x = 89; _e.y = 103; _e.combat_state = 31;
    _p.x = 128; _p.y = 96; _p.weapon = 2; _p.combat_state = 26;
    ln1_combat_event(_g, 14, false);
    ln_check(_e.wounds > 0 && _g.room_wounds[2] == _e.wounds, "melee updates scene wounds immediately");
    var _wounds = _e.wounds;
    ln1_play_enter(_g, 1); ln1_play_enter(_g, 2);
    ln_check(_g.enemy.wounds == _wounds, "enemy damage survives leaving and returning");
    _g.enemy.wounds = 32; _g.room_wounds[2] = 32;
    ln1_combat_event(_g, 36, true);
    ln_check(_g.room_wounds[2] == 32 && _g.enemy.active == 0, "death completion cannot erase scene wounds");
    ln1_play_enter(_g, 1); ln1_play_enter(_g, 2);
    repeat (120) ln1_play_tick(_g, 0);
    ln_check(_g.enemy.wounds == 32 && _g.enemy.active == 0 && _g.enemy.display_frame == 255, "defeated enemy stays defeated on re-entry");

    _g = new LN1Play(); _p = _g.player;
    ln1_play_enter(_g, 6); _p.facing = 7; _p.action = 0; _p.boundary_crossings = 1;
    _p.weapon = 1; _p.selected_weapon = 0; ln1_play_hazards(_g);
    ln_check(_g.prayer_phase == 0, "Buddha waits until equipped weapon is put away");
    _p.weapon = 0; _p.selected_weapon = 1; _p.boundary_crossings = 1; ln1_play_hazards(_g);
    ln_check(_g.prayer_phase == 0, "Buddha rejects a selected weapon");
    _p.selected_weapon = 0; _p.facing = 3; _p.boundary_crossings = 1; ln1_play_hazards(_g);
    ln_check(_g.prayer_phase == 0, "Buddha requires approaching the statue facing northwest");
    _p.facing = 7; _p.boundary_crossings = 1; ln1_play_hazards(_g);
    ln_check(_g.prayer_phase == 1 && _p.action == $ada5, "unarmed approach starts original kneeling sequence");
    repeat (40) ln1_play_tick(_g, 0);
    ln_check(_g.prayer_phase == 2 && _p.display_frame == 66 && _g.notice_item == 11, "prayer holds kneeling pose and original first missing-item hint");
    repeat (300) ln1_play_tick(_g, 0);
    ln_check(_g.prayer_phase == 2 && _g.notice_label == 2, "prayer and its hint persist through clock wrap");
    ln1_play_tick(_g, 10); repeat (26) ln1_play_tick(_g, 0);
    ln_check(_g.prayer_phase == 0 && _p.display_frame == 0 && _p.input_lock == 0, "southeast input plays stand-up sequence and releases controls");

    _g = new LN1Play(); _p = _g.player;
    _g.last_entry = 15 * 4; ln1_play_enter(_g, 15);
    ln_check(_p.boundary_crossings == 1, "water room restores source entrance crossing state");
    _p.x = 0; _p.y = 100; _p.action = 0; _p.facing = 1; _p.heading = 1;
    ln1_play_hazards(_g);
    ln_check(_g.water_active && _g.water_cutoff == 124 && _g.player_health == 0, "unsafe water starts sinking at original cutoff");
    ln1_play_tick(_g, 0); ln_check(_p.y == 100, "sinking waits for its two-tick cadence");
    ln1_play_tick(_g, 0); ln_check(_p.y == 102, "sinking moves two pixels per two ticks");
    repeat (44) ln1_play_tick(_g, 0);
    ln_check(!_g.water_active && _p.display_frame == 255 && _g.death_wait == 20, "fully submerged sprite disappears before respawn delay");
    repeat (20) ln1_play_tick(_g, 0);
    ln_check(_g.lives_left == 2 && _g.player_health == 32 && _p.action == 0 && _p.flags == 0, "water respawn restores health and clears death commands");
    repeat (8) ln1_play_tick(_g, 0);
    ln_check(_p.display_frame < 18 && _g.death_wait == 0, "spawn does not briefly return to a death pose");
    _p.action = $5d34; _p.flags = 255; _p.action_state = 3; _p.countdown = 40; _g.death_wait = 1;
    ln1_play_tick(_g, 0); repeat (8) ln1_play_tick(_g, 0);
    ln_check(_p.action < 256 && _p.action_state == 0 && _p.display_frame < 18, "ordinary death also clears stale animation state");
    show_debug_message("LN_FEEDBACK_PASS: pickup expiry, two scene-entry flashes, persistent enemy wounds/death, prayer and water/respawn regressions.");
}

/// Deterministic visual checkpoints; these are native fixtures, not reference replays.
function ln1_feedback_capture() {
    var _g = new LN1Play(), _p = _g.player;
    ln1_play_enter(_g, 8); _p.x = 180; _p.y = 120; _p.facing = 1;
    ln1_item_interact(_g); ln1_play_draw(_g, false); surface_save(application_surface, "lnpreserve-found.png");
    ln1_play_enter(_g, 2); repeat (8) ln1_play_tick(_g, 0);
    _g.enemy.wounds = 20; _g.room_wounds[2] = 20;
    ln1_play_draw(_g, false); surface_save(application_surface, "lnpreserve-wounded.png");
    ln1_play_enter(_g, 6); _p.x = 90; _p.y = 60; _p.heading = 7; _p.facing = 7;
    _p.action = 0; _p.weapon = 0; _p.selected_weapon = 0; _p.boundary_crossings = 1;
    ln1_play_hazards(_g); repeat (40) ln1_play_tick(_g, 0);
    ln1_play_draw(_g, false); surface_save(application_surface, "lnpreserve-prayer.png");
    surface_free(_g.stage_surface);
    _g = new LN1Play(); _p = _g.player;
    _g.last_entry = 60; ln1_play_enter(_g, 15);
    _p.x = 176; _p.y = 72; _p.action = 0; _p.facing = 1; _p.heading = 1;
    ln1_play_hazards(_g); repeat (16) ln1_play_tick(_g, 0);
    ln1_play_draw(_g, false); surface_save(application_surface, "lnpreserve-water.png");
    surface_free(_g.stage_surface);
}
