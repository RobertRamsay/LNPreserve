varying vec2 v_vTexcoord;
varying vec4 v_vColour;
uniform sampler2D u_depth; // green: true silhouette depth (red has sprite holes filled for 3D)
uniform vec2 u_texel; // one native pixel in texture space
#define SORT(a,b) {float lo=min(a,b);b=max(a,b);a=lo;}
// Median of nine (Paeth's 19-step network).
float median9(float p0,float p1,float p2,float p3,float p4,float p5,float p6,float p7,float p8) {
    SORT(p1,p2) SORT(p4,p5) SORT(p7,p8) SORT(p0,p1) SORT(p3,p4) SORT(p6,p7)
    SORT(p1,p2) SORT(p4,p5) SORT(p7,p8) SORT(p0,p3) SORT(p5,p8) SORT(p4,p7)
    SORT(p3,p6) SORT(p1,p4) SORT(p2,p5) SORT(p4,p7) SORT(p4,p2) SORT(p6,p4)
    SORT(p4,p2)
    return p4;
}
float depthAt(float x,float y) {return texture2D(u_depth,v_vTexcoord+vec2(x,y)*u_texel).g;}
// De-dither at native resolution: C64 multicolour pixels are two wide, so a
// four-pixel-wide box (weights .5 1 1 1 .5) across three rows merges checker
// and stripe dithers into flat tones. Neighbours at another depth are left out,
// so the edges between characters, props and ground stay sharp.
// Alpha carries a cleaned depth for outlines: a median over whole C64 pixels
// drops dotted mask speckle (foliage) but keeps solid silhouettes sharp.
void main() {
    float centre=texture2D(u_depth,v_vTexcoord).g;
    vec3 sum=vec3(0.0);
    float total=0.0;
    for (int y=-1;y<=1;y++) for (int x=-2;x<=2;x++) {
        vec2 uv=v_vTexcoord+vec2(float(x),float(y))*u_texel;
        float wx=(x==-2 || x==2)?0.5:1.0;
        float wy=y==0?2.0:1.0;
        float w=wx*wy*step(abs(texture2D(u_depth,uv).g-centre),0.02);
        sum+=texture2D(gm_BaseTexture,uv).rgb*w;
        total+=w;
    }
    float cleaned=median9(depthAt(-2.0,-1.0),depthAt(0.0,-1.0),depthAt(2.0,-1.0),
                          depthAt(-2.0,0.0),centre,depthAt(2.0,0.0),
                          depthAt(-2.0,1.0),depthAt(0.0,1.0),depthAt(2.0,1.0));
    gl_FragColor=vec4(sum/max(total,0.0001),cleaned);
}
