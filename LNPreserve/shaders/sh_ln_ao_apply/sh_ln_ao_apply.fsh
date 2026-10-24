varying vec2 v_vTexcoord;
varying vec4 v_vColour;
// gm_BaseTexture is the stage, read crisply; u_ao is read smoothly.
uniform sampler2D u_ao;
uniform vec2 u_texel; // one native pixel in texture space
// Smooth shade over crisp pixels: a small cross blur of the native-resolution
// occlusion hides its grain, then it darkens the picture at screen scale.
void main() {
    float ao=texture2D(u_ao,v_vTexcoord).r*0.4;
    ao+=texture2D(u_ao,v_vTexcoord+vec2(u_texel.x,0.0)).r*0.15;
    ao+=texture2D(u_ao,v_vTexcoord-vec2(u_texel.x,0.0)).r*0.15;
    ao+=texture2D(u_ao,v_vTexcoord+vec2(0.0,u_texel.y)).r*0.15;
    ao+=texture2D(u_ao,v_vTexcoord-vec2(0.0,u_texel.y)).r*0.15;
    vec4 colour=texture2D(gm_BaseTexture,v_vTexcoord);
    gl_FragColor=vec4(colour.rgb*ao,colour.a)*v_vColour;
}
