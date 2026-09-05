/// A scene may combine sorted props with full-resolution, per-pixel masks.
/// Foot depth is independent of visual jumping height.
function ln_actor_depth(_foot_y, _layer_bias = 0) {
    return -floor(_foot_y * 256) + _layer_bias;
}

function ln_draw_masked_actor(_sprite, _frame, _x, _y, _xscale, _yscale,
                              _mask_sprite, _scene_x, _scene_y, _scene_width, _scene_height) {
    if (_mask_sprite < 0 || !shader_is_compiled(sh_ln_occlusion)) {
        draw_sprite_ext(_sprite, _frame, _x, _y, _xscale, _yscale, 0, c_white, 1);
        return;
    }
    var _uv = sprite_get_uvs(_mask_sprite, 0);
    shader_set(sh_ln_occlusion);
    texture_set_stage(shader_get_sampler_index(sh_ln_occlusion, "u_mask"), sprite_get_texture(_mask_sprite, 0));
    shader_set_uniform_f(shader_get_uniform(sh_ln_occlusion, "u_mask_uv"), _uv[0], _uv[1], _uv[2], _uv[3]);
    shader_set_uniform_f(shader_get_uniform(sh_ln_occlusion, "u_scene"), _scene_x, _scene_y, _scene_width, _scene_height);
    draw_sprite_ext(_sprite, _frame, _x, _y, _xscale, _yscale, 0, c_white, 1);
    shader_reset();
}

/// A foreground overlay can be enabled only when the actor stands behind it.
/// Use one mask per depth band for stairs, platforms, arches and movable props.
function ln_occluder_active(_actor_foot_y, _occluder_baseline, _enabled = true) {
    return _enabled && _actor_foot_y < _occluder_baseline;
}
