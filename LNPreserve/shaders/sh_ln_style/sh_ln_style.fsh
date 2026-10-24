varying vec2 v_vTexcoord;
varying vec4 v_vColour;
// gm_BaseTexture is the de-dithered stage, sampled smoothly; its alpha is the
// cleaned stage depth (0 far .. 1 near).
uniform sampler2D u_orig; // the untouched stage, for the strength blend
uniform sampler2D u_ao; // ambient shading, 1 open .. 0 shaded
uniform float u_has_ao;
uniform vec2 u_native; // one native pixel in texture space
uniform vec2 u_out; // output size in screen pixels
uniform float u_style; // 1 ink, 2 painterly, 3 pencil, 4 coloured pencil
uniform float u_strength;
uniform float u_line; // outline thickness 0 (none) .. 1 (bold)
uniform float u_saturation; // 1 leaves colour as it is; 0 grey, 2 doubled
uniform float u_brush; // Painterly blob size 0 (fine) .. 1 (broad)
uniform float u_hatch; // Pencil hatching strength 0 (none, shaded) .. 1 (heavy); 0.5 is standard
const vec3 LUMA=vec3(0.299,0.587,0.114);

float hash(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p) {
    vec2 i=floor(p),f=fract(p);
    f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0,1.0)),f.x),f.y);
}
float depthAt(vec2 uv) {return texture2D(gm_BaseTexture,uv).a;}
float lumaAt(vec2 uv) {return dot(texture2D(gm_BaseTexture,uv).rgb,LUMA);}

// Softened fields: four bilinear taps on a rotated square. The native pixel steps
// of the depth and tone round off into smooth contours, so lines follow the shape
// rather than tracing squares around single pixels.
float softDepth(vec2 uv,float b) {
    vec2 o=u_native*b;
    return 0.25*(depthAt(uv+vec2(o.x,o.y*0.5))+depthAt(uv+vec2(-o.x*0.5,o.y))+
                 depthAt(uv+vec2(-o.x,-o.y*0.5))+depthAt(uv+vec2(o.x*0.5,-o.y)));
}
float softLuma(vec2 uv,float b) {
    vec2 o=u_native*b;
    return 0.25*(lumaAt(uv+vec2(o.x,o.y*0.5))+lumaAt(uv+vec2(-o.x*0.5,o.y))+
                 lumaAt(uv+vec2(-o.x,-o.y*0.5))+lumaAt(uv+vec2(o.x*0.5,-o.y)));
}

// Edge slopes of the softened fields, in units per native pixel. The ground rises
// 1/144 per row down the screen, so that slope is taken away from depth and open
// ground never reads as an edge.
vec2 depthSlope(vec2 uv,float b) {
    vec2 h=u_native*0.5;
    return vec2(softDepth(uv+vec2(h.x,0.0),b)-softDepth(uv-vec2(h.x,0.0),b),
                softDepth(uv+vec2(0.0,h.y),b)-softDepth(uv-vec2(0.0,h.y),b))-vec2(0.0,1.0/144.0);
}
vec2 lumaSlope(vec2 uv,float b) {
    vec2 h=u_native*0.5;
    return vec2(softLuma(uv+vec2(h.x,0.0),b)-softLuma(uv-vec2(h.x,0.0),b),
                softLuma(uv+vec2(0.0,h.y),b)-softLuma(uv-vec2(0.0,h.y),b));
}
// Keeps only the crest of an edge: a pixel inks only if the edge is at least as
// strong here as a short step either side across it. The step sets the stroke
// width, so thin settings give a hairline that follows the contour smoothly.
float crest(float here,float a,float b) {
    return smoothstep(-0.2*here,0.0,here-max(a,b));
}

// Outlines. Depth jumps mark real silhouettes (characters, props against ground)
// and cannot be fooled by dithering; tone edges add lighter interior lines.
// Thickness sets both how much the fields are softened and the stroke width:
// a light touch gives a fine pen line, the top of the range a broad brush.
float inkLines(vec2 uv,vec2 px,float detail) {
    float b=mix(0.35,1.0,u_line);
    float width=mix(0.12,0.9,u_line);
    vec2 sd=depthSlope(uv,b),sl=lumaSlope(uv,b);
    float ed=length(sd),el=length(sl);
    vec2 nd=sd/max(ed,1e-5)*u_native*width,nl=sl/max(el,1e-5)*u_native*width;
    float bold=smoothstep(0.65,1.0,u_line);
    float ridgeD=mix(crest(ed,length(depthSlope(uv+nd,b)),length(depthSlope(uv-nd,b))),1.0,bold);
    float ridgeL=mix(crest(el,length(lumaSlope(uv+nl,b)),length(lumaSlope(uv-nl,b))),1.0,bold);
    // Slowly varying wobble so line weight swells and thins like a pen nib.
    float wobble=noise(px*0.08)*0.5+0.75;
    float silhouette=smoothstep(0.014,0.034,ed*wobble)*ridgeD;
    float tone=smoothstep(0.14,0.32,el*wobble)*ridgeL*detail;
    return clamp(max(silhouette,tone),0.0,1.0)*smoothstep(0.0,0.08,u_line);
}

// Kuwahara: of four overlapping quadrants, keep the mean of the calmest one.
// Brush size spreads the samples, from under half a native pixel to almost two.
vec3 painterly(vec2 uv) {
    float spread=mix(0.3,1.8,u_brush);
    vec3 bestMean=vec3(0.0);
    float bestVar=1e9;
    for (int q=0;q<4;q++) {
        vec2 dir=vec2(q==1 || q==3?1.0:-1.0,q>=2?1.0:-1.0);
        vec3 sum=vec3(0.0),sq=vec3(0.0);
        for (int y=0;y<3;y++) for (int x=0;x<3;x++) {
            vec3 c=texture2D(gm_BaseTexture,uv+dir*vec2(float(x),float(y))*u_native*spread).rgb;
            sum+=c;sq+=c*c;
        }
        vec3 mean=sum/9.0,variance=sq/9.0-mean*mean;
        float v=variance.r+variance.g+variance.b;
        if (v<bestVar) {bestVar=v;bestMean=mean;}
    }
    return bestMean;
}

// Hatching coverage 0..1 at screen position px for a darkness 0..1: one diagonal
// layer, a cross layer in mid tones and an upright layer in the deepest shadows.
float hatchLayer(float s,float period,float cover) {
    float f=abs(fract(s/period)-0.5)*2.0;
    return 1.0-smoothstep(cover-0.12,cover+0.08,1.0-f);
}
float hatching(vec2 px,float dark) {
    float jitter=(noise(px*0.35)-0.5)*1.6;
    float h=hatchLayer(px.x+px.y+jitter,5.0,clamp(dark*1.15,0.0,0.9));
    h=max(h,hatchLayer(px.x-px.y+jitter,5.0,clamp((dark-0.4)*1.5,0.0,0.85)));
    h=max(h,hatchLayer(px.x+jitter*0.5,4.0,clamp((dark-0.72)*2.2,0.0,0.8)));
    return h*(0.75+0.25*noise(px*0.9));
}

void main() {
    vec2 uv=v_vTexcoord;
    vec2 px=uv*u_out;
    vec3 soft=texture2D(gm_BaseTexture,uv).rgb;
    vec3 original=texture2D(u_orig,uv).rgb;
    // Ambient shade goes in before styling, so pencil hatches it and paint carries it.
    if (u_has_ao>0.5) {float ao=texture2D(u_ao,uv).r;soft*=ao;original*=ao;}
    vec3 col=soft;
    if (u_style<1.5) {
        // Ink: flat de-dithered colour, a little richer, under brush-pen outlines.
        float grey=dot(soft,LUMA);
        col=clamp(mix(vec3(grey),soft,1.25),0.0,1.0);
        col=mix(col,vec3(0.07,0.05,0.09),inkLines(uv,px,0.8));
    } else if (u_style<2.5) {
        // Painterly: brush patches on a faint canvas weave, with soft dark edges.
        col=painterly(uv);
        float weave=noise(px*vec2(0.9,0.3))*0.5+noise(px*vec2(0.3,0.9))*0.5;
        col*=0.93+0.1*weave;
        col=mix(col,col*0.35,inkLines(uv,px,0.35)*0.7);
    } else {
        // Pencil on paper: darkness becomes hatching, silhouettes become firm lines.
        vec3 paper=vec3(0.96,0.94,0.89)*(0.96+0.04*noise(px*1.7));
        // Gentle tone curve: mid greys stay mostly paper, shadows fill with strokes.
        float dark=pow(1.0-dot(soft,LUMA),1.5)*0.95;
        float lines=inkLines(uv,px,0.9);
        // Hatching strength: weaker strokes hand the tone over to smooth shading.
        float etch=u_hatch*2.0,shade=mix(0.5,0.12,min(etch,1.0));
        float h=hatching(px,dark);
        if (u_style<3.5) {
            vec3 graphite=vec3(0.22,0.22,0.25);
            col=mix(paper,graphite,clamp(h*0.8*etch+dark*shade,0.0,1.0));
            col=mix(col,graphite*0.7,lines*0.9);
        } else {
            // Coloured pencil: pigment from the scene, laid on in strokes; white paper shows through.
            float grey=dot(soft,LUMA);
            vec3 pigment=clamp(mix(vec3(grey),soft,1.35),0.0,1.0);
            float cover=clamp(h*0.9*etch+0.12+dark*0.15+(1.0-min(etch,1.0))*0.45,0.0,1.0);
            col=mix(paper,pigment*paper,cover);
            col=mix(col,pigment*0.3,lines*0.85);
        }
    }
    col=clamp(mix(vec3(dot(col,LUMA)),col,u_saturation),0.0,1.0);
    gl_FragColor=vec4(mix(original,col,u_strength),1.0)*v_vColour;
}
