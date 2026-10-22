varying vec2 v_vTexcoord;
varying vec4 v_vColour;
uniform float u_value;
uniform sampler2D u_raw; // the sprite before masking
uniform vec3 u_gap; // enabled, one texel across, right edge of the sprite in texture space
// A transparent sprite pixel is enclosed when the nearest sprite pixel along the
// row, within seven pixels, is opaque and survived the mask.
float enclosedSide(float side) {
    for (int i=1;i<=7;i++) {
        vec2 uv=v_vTexcoord+vec2(side*float(i)*u_gap.y,0.0);
        if (uv.x<0.0 || uv.x>u_gap.z) return 0.0;
        if (texture2D(u_raw,uv).a>=0.5) return step(0.5,texture2D(gm_BaseTexture,uv).a);
    }
    return 0.0;
}
// Writes one depth across the visible pixels of an already-masked sprite.
// Holes and notches inside the sprite move with it, not with the ground behind.
void main() {
    float solid=step(0.5,texture2D(gm_BaseTexture,v_vTexcoord).a);
    if (solid<0.5 && u_gap.x>0.5 && texture2D(u_raw,v_vTexcoord).a<0.5)
        solid=enclosedSide(-1.0)*enclosedSide(1.0);
    if (solid<0.5) discard;
    gl_FragColor=vec4(u_value,u_value,u_value,1.0);
}
