/// A scene may combine sorted props with full-resolution, per-pixel masks.
/// Foot depth is independent of visual jumping height.
function ln_actor_depth(_foot_y, _layer_bias = 0) {
    return -floor(_foot_y * 256) + _layer_bias;
}

/// Logical character banks retain the original pose indices while identical
/// pixels share editable frames. graphics/characters.json is the asset map.
function ln_character_pose(_bank, _frame, _type = "") {
    var _original=_bank;
    if (!is_string(_bank)) _bank=sprite_get_name(_bank);
    if (!variable_global_exists("ln_character_assets")) {
        var _buffer=buffer_load("graphics/characters.json");
        global.ln_character_assets=json_parse(buffer_read(_buffer,buffer_text));buffer_delete(_buffer);
        global.ln_character_sprite_ids={};
    }
    var _assets=global.ln_character_assets;
    if (_type!="" && variable_struct_exists(_assets.types,_type)) {
        var _profile=variable_struct_get(_assets.types,_type);
        if (variable_struct_exists(_profile,"overrides") && variable_struct_exists(_profile.overrides,_bank)) {
            var _replacement=variable_struct_get(_profile.overrides,_bank);
            return {sprite:asset_get_index(_replacement.sprite),frame:_replacement.frames[_frame]};
        }
    }
    if (!variable_struct_exists(_assets.banks,_bank)) return {sprite:is_string(_original)?asset_get_index(_bank):_original,frame:_frame};
    var _mapping=variable_struct_get(_assets.banks,_bank);
    var _pose=_assets.poses[_mapping.poses[_frame]],_ids=global.ln_character_sprite_ids;
    if (!variable_struct_exists(_ids,_pose.sprite)) variable_struct_set(_ids,_pose.sprite,asset_get_index(_pose.sprite));
    return {sprite:variable_struct_get(_ids,_pose.sprite),frame:_pose.frame};
}

function ln_draw_masked_actor(_sprite, _frame, _x, _y, _xscale, _yscale,
                              _mask_sprite, _scene_x, _scene_y, _scene_width, _scene_height, _threshold = 0.5, _clip_bottom = 1000000, _red_dye = false, _magic_colour = -1) {
    if (!shader_is_compiled(sh_ln_occlusion)) {
        draw_sprite_ext(_sprite, _frame, _x, _y, _xscale, _yscale, 0, c_white, 1);
        return;
    }
    // An unmasked room must still display palette effects. Alpha cannot reach 2.
    if (_mask_sprite < 0) { _mask_sprite=_sprite; _threshold=2; }
    var _uv = sprite_get_uvs(_mask_sprite, 0);
    shader_set(sh_ln_occlusion);
    // Reset per draw so a dyed player cannot recolour enemies or other games.
    shader_set_uniform_f(shader_get_uniform(sh_ln_occlusion, "u_red_dye"), real(_red_dye));
    shader_set_uniform_f(shader_get_uniform(sh_ln_occlusion,"u_magic_colour"),
        _magic_colour<0?-1:colour_get_red(_magic_colour)/255,
        _magic_colour<0?0:colour_get_green(_magic_colour)/255,
        _magic_colour<0?0:colour_get_blue(_magic_colour)/255);
    texture_set_stage(shader_get_sampler_index(sh_ln_occlusion, "u_mask"), sprite_get_texture(_mask_sprite, 0));
    shader_set_uniform_f(shader_get_uniform(sh_ln_occlusion, "u_mask_uv"), _uv[0], _uv[1], _uv[2], _uv[3]);
    shader_set_uniform_f(shader_get_uniform(sh_ln_occlusion, "u_scene"), _scene_x, _scene_y, _scene_width, _scene_height);
    shader_set_uniform_f(shader_get_uniform(sh_ln_occlusion, "u_mask_threshold"), _threshold);
    shader_set_uniform_f(shader_get_uniform(sh_ln_occlusion, "u_clip_bottom"), _clip_bottom);
    draw_sprite_ext(_sprite, _frame, _x, _y, _xscale, _yscale, 0, c_white, 1);
    shader_reset();
}

/// A foreground overlay can be enabled only when the actor stands behind it.
/// Use one mask per depth band for stairs, platforms, arches and movable props.
function ln_occluder_active(_actor_foot_y, _occluder_baseline, _enabled = true) {
    return _enabled && _actor_foot_y < _occluder_baseline;
}
