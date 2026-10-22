varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec2 v_world;
uniform sampler2D u_mask;
uniform vec4 u_mask_uv;
uniform float u_has_mask;
uniform sampler2D u_editor;
uniform float u_has_editor;
uniform float u_offset; // foot units below the stage row: 8 for LN1/LN2 actors, 29 for LN3 sprites
const float FRONT=254.5/255.0;
float maskAlpha(vec2 stage) {
    vec2 p=stage/vec2(240.0,144.0);
    float a=0.0;
    if (u_has_mask>0.5) a=texture2D(u_mask,mix(u_mask_uv.xy,u_mask_uv.zw,p)).a;
    if (u_has_editor>0.5) {
        vec4 authored=texture2D(u_editor,p);
        if (authored.r>0.5) a=authored.a;
    }
    return a;
}
// Scene depth in stage rows: open ground recedes up the screen, while occluder
// pixels stand upright at their baseline (mask alpha, in the game's foot units).
void main() {
    float row=v_world.y;
    float a=maskAlpha(v_world);
    if (a>FRONT) {
        // Always-in-front props carry no baseline: stand them on the bottom edge
        // of their own region in this column.
        for (int i=1;i<144;i++) {
            row=v_world.y+float(i);
            if (row>=144.0 || maskAlpha(vec2(v_world.x,row))<=FRONT) break;
        }
    } else if (a>0.5/255.0) row=a*255.0-u_offset;
    float d=clamp(row/144.0,0.0,1.0);
    gl_FragColor=vec4(d,d,d,1.0);
}
