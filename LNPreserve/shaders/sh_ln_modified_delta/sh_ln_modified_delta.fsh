varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec2 v_world;
uniform sampler2D u_original;
uniform vec4 u_original_uv;
void main() {
    vec4 colour=texture2D(gm_BaseTexture,v_vTexcoord)*v_vColour;
    vec2 uv=mix(u_original_uv.xy,u_original_uv.zw,v_world/vec2(240.0,144.0));
    vec4 original=texture2D(u_original,uv);
    if(distance(colour.rgb,original.rgb)<0.01) discard;
    gl_FragColor=colour;
}
