varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec2 v_world;
uniform sampler2D u_mask;
uniform vec4 u_mask_uv;
uniform vec4 u_scene;
uniform float u_mask_threshold;
uniform float u_clip_bottom;
void main() {
    vec4 colour = v_vColour * texture2D(gm_BaseTexture, v_vTexcoord);
    if (v_world.y >= u_clip_bottom) discard;
    vec2 p = (v_world - u_scene.xy) / u_scene.zw;
    if (p.x >= 0.0 && p.y >= 0.0 && p.x < 1.0 && p.y < 1.0) {
        vec2 uv = mix(u_mask_uv.xy, u_mask_uv.zw, p);
        colour.a *= 1.0 - step(u_mask_threshold, texture2D(u_mask, uv).a);
    }
    gl_FragColor = colour;
}
