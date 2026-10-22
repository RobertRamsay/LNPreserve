varying vec2 v_vTexcoord;
varying vec4 v_vColour;
uniform sampler2D u_depth;
uniform vec4 u_bounds; // stage texel centres: left, top, right, bottom
uniform float u_texel; // one native pixel across, in texture space
uniform float u_separation; // native pixels of disparity between farthest and nearest
uniform float u_mode; // 0 red/cyan colour, 1 red/blue grey
// Depth 0 is the top of the picture (far), 1 the bottom (near); 0.5 sits on the screen.
float eyeShift(float d) {return 0.5*u_separation*(d-0.5);}
vec2 inside(vec2 uv) {return clamp(uv,u_bounds.xy,u_bounds.zw);}
// Inverse warp: find the source pixel whose shifted position lands here.
// When several land together the nearest wins, so foreground covers background.
vec3 eyeView(float side) {
    // Candidates every third of a native pixel (one screen pixel at 3x), centred on zero.
    float steps=floor((abs(u_separation)*0.25)*3.0)+1.0;
    float best=-1.0;
    vec2 bestUV=v_vTexcoord;
    for (int i=0;i<64;i++) {
        float k=(float(i)-steps)/3.0;
        if (k>steps/3.0) break;
        vec2 source=inside(v_vTexcoord+vec2(k*u_texel,0.0));
        float d=texture2D(u_depth,source).r;
        if (abs(k+side*eyeShift(d))<=0.17 && d>best) {best=d;bestUV=source;}
    }
    // Disoccluded gap: borrow the pixel the local depth points at.
    if (best<0.0) bestUV=inside(v_vTexcoord-vec2(side*eyeShift(texture2D(u_depth,inside(v_vTexcoord)).r)*u_texel,0.0));
    return texture2D(gm_BaseTexture,bestUV).rgb;
}
void main() {
    vec3 left=eyeView(1.0),right=eyeView(-1.0);
    vec3 luma=vec3(0.299,0.587,0.114);
    vec3 col=u_mode<0.5?vec3(left.r,right.g,right.b):vec3(dot(left,luma),0.0,dot(right,luma));
    gl_FragColor=vec4(col,texture2D(gm_BaseTexture,v_vTexcoord).a)*v_vColour;
}
