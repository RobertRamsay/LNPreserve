varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec2 v_world;
uniform sampler2D u_mask;
uniform vec4 u_mask_uv;
uniform vec4 u_scene;
uniform float u_mask_threshold;
uniform float u_clip_bottom;
uniform float u_red_dye;
uniform vec3 u_magic_colour;
void main() {
    vec4 colour = v_vColour * texture2D(gm_BaseTexture, v_vTexcoord);
    // LN1 $561f: red body/weapon pixels; retain the face colour and alpha.
    // Original $561f changes body/weapon sprite colours, preserving the face.
    if (u_magic_colour.r >= 0.0 && max(colour.r, max(colour.g, colour.b)) < 0.001)
        colour.rgb = u_magic_colour;
    else if (u_red_dye > 0.5 && max(colour.r, max(colour.g, colour.b)) < 0.001)
        colour.rgb = vec3(129.0, 51.0, 56.0) / 255.0;
    if (v_world.y >= u_clip_bottom) discard;
    vec2 p = (v_world - u_scene.xy) / u_scene.zw;
    if (p.x >= 0.0 && p.y >= 0.0 && p.x < 1.0 && p.y < 1.0) {
        vec2 uv = mix(u_mask_uv.xy, u_mask_uv.zw, p);
        colour.a *= 1.0 - step(u_mask_threshold, texture2D(u_mask, uv).a);
    }
    gl_FragColor = colour;
}
