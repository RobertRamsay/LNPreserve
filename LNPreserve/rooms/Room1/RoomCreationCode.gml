instance_create_depth(0, 0, 0, obj_ln_preserve);
// AI restyle is switched off for now; set true to bring back its overlay and F2/F4 keys.
var _ai_restyle_enabled = false;
if (_ai_restyle_enabled) {
    var _ai = instance_create_depth(0, 0, 0, obj_ai_restyle);
    _ai.region_func = ln_ai_region;
}
