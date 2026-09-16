varying vec2 v_vTexcoord;
varying vec4 v_vColour;
uniform vec2 u_texel;
uniform float u_radius;
void main() {
    float halo=texture2D(gm_BaseTexture,v_vTexcoord).a;
    // Smooth silhouette dilation: five native pixels, fading fully at the edge.
    for(int ring=1;ring<=5;ring++) {
        float r=float(ring)/5.0;
        float weight=1.0-smoothstep(0.0,1.0,r);
        for(int ray=0;ray<12;ray++) {
            float angle=float(ray)*0.523598776;
            vec2 offset=vec2(cos(angle),sin(angle))*r*u_radius*u_texel;
            halo=max(halo,texture2D(gm_BaseTexture,v_vTexcoord+offset).a*weight);
        }
    }
    gl_FragColor=vec4(vec3(0.55),halo*0.8)*v_vColour;
}
