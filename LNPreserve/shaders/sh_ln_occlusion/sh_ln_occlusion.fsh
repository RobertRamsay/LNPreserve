varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec2 v_world;
uniform sampler2D u_mask;
uniform sampler2D u_editor_depth;
uniform float u_editor_threshold;
uniform vec4 u_mask_uv;
uniform vec4 u_scene;
uniform float u_mask_threshold;
uniform float u_clip_bottom;
uniform float u_red_dye;
uniform vec3 u_magic_colour;
uniform vec2 u_depth_fill; // 1 visible pixels only, 2 also enclosed sprite holes; stereo depth to write
uniform vec4 u_frame_uv; // depth fill: this frame's texture rectangle
uniform vec2 u_gap_step; // depth fill: one texel across in texture space, and in world space
float hiddenAt(vec2 world) {
    vec2 p = (world - u_scene.xy) / u_scene.zw;
    if (p.x < 0.0 || p.y < 0.0 || p.x >= 1.0 || p.y >= 1.0) return 0.0;
    vec2 uv = mix(u_mask_uv.xy, u_mask_uv.zw, p);
    float hidden = step(u_mask_threshold, texture2D(u_mask, uv).a);
    if(u_editor_threshold<1.1) {
        vec4 authored=texture2D(u_editor_depth,p);
        if(authored.r>0.5) hidden=step(u_editor_threshold,authored.a);
    }
    return hidden;
}
// A transparent pixel is enclosed when the nearest sprite pixel along the row,
// within seven pixels, is opaque and itself visible.
float enclosedSide(float side) {
    for (int i = 1; i <= 7; i++) {
        vec2 uv = v_vTexcoord + vec2(side * float(i) * u_gap_step.x, 0.0);
        if (uv.x < u_frame_uv.x || uv.x > u_frame_uv.z) return 0.0;
        if (texture2D(gm_BaseTexture, uv).a >= 0.5) {
            vec2 world = v_world + vec2(side * float(i) * u_gap_step.y, 0.0);
            return world.y >= u_clip_bottom ? 0.0 : 1.0 - hiddenAt(world);
        }
    }
    return 0.0;
}
void main() {
    vec4 colour = v_vColour * texture2D(gm_BaseTexture, v_vTexcoord);
    // LN1 $561f: red body/weapon pixels; retain the face colour and alpha.
    // Original $561f changes body/weapon sprite colours, preserving the face.
    if (u_magic_colour.r >= 0.0 && max(colour.r, max(colour.g, colour.b)) < 0.001)
        colour.rgb = u_magic_colour;
    else if (u_red_dye > 0.5 && max(colour.r, max(colour.g, colour.b)) < 0.001)
        colour.rgb = vec3(129.0, 51.0, 56.0) / 255.0;
    if (v_world.y >= u_clip_bottom) discard;
    float hidden = hiddenAt(v_world);
    float opaque = colour.a;
    colour.a *= 1.0-hidden;
    if (u_depth_fill.x > 0.5) {
        // Holes and notches inside the sprite move with it, not with the ground behind.
        float solid = step(0.5, colour.a);
        if (solid < 0.5 && u_depth_fill.x > 1.5 && hidden < 0.5 && opaque < 0.5) solid = enclosedSide(-1.0) * enclosedSide(1.0);
        if (solid < 0.5) discard;
        colour = vec4(vec3(u_depth_fill.y), 1.0);
    }
    gl_FragColor = colour;
}
