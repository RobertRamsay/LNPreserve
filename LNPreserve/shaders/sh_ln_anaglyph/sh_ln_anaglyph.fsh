varying vec2 v_vTexcoord;
varying vec4 v_vColour;
uniform sampler2D u_depth;
uniform vec4 u_bounds; // stage texel centres: left, top, right, bottom
uniform float u_texel; // one native pixel across, in texture space
uniform float u_separation; // native pixels of disparity between farthest and nearest
uniform float u_mode; // glasses blend: 0 red/cyan colour .. 1 red/blue grey
uniform float u_focus; // depth that sits on the screen plane (the player's feet)
// Depth 0 is the top of the picture (far), 1 the bottom (near).
float eyeShift(float d) {return 0.5*u_separation*(d-u_focus);}
vec2 inside(vec2 uv) {return clamp(uv,u_bounds.xy,u_bounds.zw);}
// Inverse warp: find the source pixel whose shifted position lands here.
// When several land together the nearest wins, so foreground covers background.
vec3 eyeView(float side) {
    // Candidates every third of a native pixel (one screen pixel at 3x), centred on zero.
    float steps=floor((abs(u_separation)*0.5*max(u_focus,1.0-u_focus))*3.0)+1.0;
    float best=-1.0;
    vec2 bestUV=v_vTexcoord;
    // Disoccluded gaps reveal what lies behind, so they borrow the farthest
    // candidate, taking the one whose landing comes closest.
    float far=2.0,farMiss=1000.0;
    vec2 farUV=v_vTexcoord;
    for (int i=0;i<64;i++) {
        float k=(float(i)-steps)/3.0;
        if (k>steps/3.0) break;
        vec2 source=inside(v_vTexcoord+vec2(k*u_texel,0.0));
        float d=texture2D(u_depth,source).r;
        float miss=abs(k+side*eyeShift(d));
        if (miss<=0.17 && d>best) {best=d;bestUV=source;}
        if (d<far-0.003 || (d<far+0.003 && miss<farMiss)) {far=d;farMiss=miss;farUV=source;}
    }
    if (best<0.0) bestUV=farUV;
    return texture2D(gm_BaseTexture,bestUV).rgb;
}
void main() {
    vec3 left=eyeView(1.0),right=eyeView(-1.0);
    vec3 luma=vec3(0.299,0.587,0.114);
    // Blend from red/cyan colour (0) to red/blue grey (1): green fades out while
    // each eye's channel moves from its own colour towards that eye's brightness.
    vec3 col=mix(vec3(left.r,right.g,right.b),vec3(dot(left,luma),0.0,dot(right,luma)),clamp(u_mode,0.0,1.0));
    gl_FragColor=vec4(col,texture2D(gm_BaseTexture,v_vTexcoord).a)*v_vColour;
}
