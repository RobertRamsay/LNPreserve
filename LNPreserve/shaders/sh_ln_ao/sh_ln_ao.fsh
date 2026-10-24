varying vec2 v_vTexcoord;
varying vec4 v_vColour;
// gm_BaseTexture is the stage depth: 0 far (top) .. 1 near (bottom).
uniform vec2 u_texel; // one native pixel in texture space
uniform float u_radius; // reach in native pixels
uniform float u_strength;
// Ambient occlusion for 2.5D depth. Open ground rises in nearness by 1/144 per row
// down the screen, so each sample is compared with where the ground plane itself
// would be at that offset: only things standing proud of the ground and nearer
// than the pixel itself (characters, walls, props) occlude. Samples lie on an ellipse squashed to the ground's
// isometric foreshortening.
void main() {
    float d=texture2D(gm_BaseTexture,v_vTexcoord).r;
    // Interleaved gradient noise turns the sample spiral per pixel, so the 20 taps
    // read as soft grain rather than rings; it is fixed per pixel, so it never crawls.
    vec2 pixel=floor(v_vTexcoord/u_texel);
    float turn=fract(52.9829189*fract(dot(pixel,vec2(0.06711056,0.00583715))))*6.2831853;
    float occlusion=0.0;
    for (int i=0;i<20;i++) {
        float t=(float(i)+0.5)/20.0;
        float a=float(i)*2.3999632+turn;
        vec2 o=vec2(cos(a),sin(a)*0.55)*u_radius*sqrt(t);
        float n=texture2D(gm_BaseTexture,v_vTexcoord+o*u_texel).r;
        // An occluder must stand proud of the ground plane and also be nearer than
        // this pixel, so upright surfaces (constant depth) never shade themselves.
        float excess=min(n-(d+o.y/144.0),n-d);
        // Only ground just behind an object (within about a dozen rows of depth)
        // takes its shade, so it pools at bases instead of haloing heads.
        float near=smoothstep(0.004,0.02,excess)*(1.0-smoothstep(0.035,0.1,excess));
        occlusion+=near*(1.0-t*0.5);
    }
    float ao=1.0-clamp(occlusion/9.0,0.0,1.0)*u_strength;
    gl_FragColor=vec4(ao,ao,ao,1.0);
}
