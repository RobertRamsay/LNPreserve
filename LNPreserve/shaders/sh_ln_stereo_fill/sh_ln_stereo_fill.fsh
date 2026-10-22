varying vec2 v_vTexcoord;
varying vec4 v_vColour;
uniform float u_value;
// Writes one depth across the visible pixels of an already-masked sprite.
void main() {
    if (texture2D(gm_BaseTexture,v_vTexcoord).a<0.5) discard;
    gl_FragColor=vec4(u_value,u_value,u_value,1.0);
}
