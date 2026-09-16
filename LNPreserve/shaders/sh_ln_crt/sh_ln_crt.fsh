varying vec2 v_vTexcoord;
varying vec4 v_vColour;
uniform vec2 u_size;
uniform vec4 u_region;
uniform float u_scale;
uniform float u_pixel_scale;
uniform float u_time;
uniform vec2 u_tone; // exposure stops, contrast (1 is neutral)
uniform float u_blur;
uniform float u_honeycomb;
uniform float u_scanlines;
uniform vec3 u_scan_shape; // width, edge offset, soft profile
uniform vec2 u_phosphor; // treatment (0 classic / 1 phosphor), spacing in native rows
// Independent Gaussian RGB phosphor reconstruction, inspired by Cathode's
// shadow-mask appearance (nimitz, Shadertoy 4lXcDH). No source code copied.
vec3 phosphorLight(vec2 q) {
    vec2 cell=floor(q);
    vec3 light=vec3(0.0);
    for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
        vec2 centre=cell+vec2(float(x),float(y))+0.5;
        centre.x+=mod(centre.y-0.5,2.0)*0.5;
        vec2 delta=q-centre;
        vec3 dx=vec3(delta.x+0.24,delta.x,delta.x-0.24);
        vec3 dy=vec3(delta.y-0.10,delta.y+0.10,delta.y-0.10);
        light+=exp(-(dx*dx/0.115+dy*dy/0.065))*1.20;
    }
    return light;
}
const float PI=3.14159265359;
void main() {
    if (v_vTexcoord.x<u_region.x || v_vTexcoord.y<u_region.y ||
        v_vTexcoord.x>=u_region.z || v_vTexcoord.y>=u_region.w) {
        gl_FragColor=texture2D(gm_BaseTexture,v_vTexcoord)*v_vColour;return;
    }
    vec2 p=(v_vTexcoord-u_region.xy)/(u_region.zw-u_region.xy)*2.0-1.0;
    // Fixed geometry: all borders and HUD lines stay straight and stationary.
    vec2 uv=v_vTexcoord;
    vec2 edge=0.5/u_size;
    vec2 lo=u_region.xy+edge,hi=u_region.zw-edge;
    vec2 sampleUV=clamp(uv,lo,hi);
    float phase=(0.14+0.025*sin(u_time*0.8))*u_pixel_scale/u_size.x;
    vec3 col=vec3(texture2D(gm_BaseTexture,clamp(sampleUV+vec2(phase,0.0),lo,hi)).r,
                  texture2D(gm_BaseTexture,sampleUV).g,
                  texture2D(gm_BaseTexture,clamp(sampleUV-vec2(phase,0.0),lo,hi)).b);
    // Normalized 7x7 Gaussian kernel, sampled to three standard deviations.
    // Blur radius grows continuously with the slider; zero bypasses the filter.
    if (u_blur>0.0001) {
        vec2 sigma=vec2(1.25*u_blur*u_pixel_scale)/u_size;
        vec3 blurred=vec3(0.0);
        float total=0.0;
        for (int y=-3;y<=3;y++) {
            for (int x=-3;x<=3;x++) {
                vec2 offset=vec2(float(x),float(y));
                float weight=exp(-0.5*dot(offset,offset));
                blurred+=texture2D(gm_BaseTexture,clamp(sampleUV+offset*sigma,lo,hi)).rgb*weight;
                total+=weight;
            }
        }
        // Retain gentle colour phasing at low blur without a sharp overlay at high blur.
        col=mix(blurred/total,col,0.08*(1.0-u_blur));
    }
    col*=vec3(0.985,1.0,1.035);
    // One scanline per native row, with a full-strength centre pixel
    // and one 40%-strength pixel on either side in the rendered picture.
    float scanPeriod=u_pixel_scale*u_scale;
    float scanRow=floor((uv.y-u_region.y)*u_size.y*u_scale);
    float scanCentre=mix(floor(0.5*u_pixel_scale*u_scale),u_pixel_scale*u_scale-1.0,u_scan_shape.z);
    scanCentre+=(u_scan_shape.y-0.5)*u_pixel_scale*u_scale;
    float scanDistance=abs(mod(scanRow-scanCentre+0.5*scanPeriod,scanPeriod)-0.5*scanPeriod);
    float oldWeight=scanDistance<0.5?1.0:(scanDistance<1.5?0.4:0.0);
    float radius=max(0.5,u_scan_shape.x*0.5);
    float sigma=max(0.25,(u_scan_shape.x-1.0)*0.30);
    float softWeight=exp(-0.5*scanDistance*scanDistance/(sigma*sigma));
    softWeight*=1.0-smoothstep(max(0.0,radius-0.5),radius,scanDistance);
    col*=1.0-u_scanlines*0.4*mix(oldWeight,softWeight,u_scan_shape.z);
    // Staggered RGB phosphor dots on a hexagonal (honeycomb) lattice.
    vec2 pixel=(v_vTexcoord-u_region.xy)*u_size*u_scale;
    float row=floor(pixel.y/2.598);
    float cx=pixel.x/3.0-0.5*mod(row,2.0);
    vec2 dotpos=vec2((fract(cx)-0.5)*3.0,(fract(pixel.y/2.598)-0.5)*2.598);
    float dotlight=1.0-smoothstep(0.65,1.5,length(dotpos));
    float channel=mod(floor(cx),3.0);
    vec3 mask=channel<0.5?vec3(1.0,0.78,0.78):(channel<1.5?vec3(0.78,1.0,0.78):vec3(0.78,0.78,1.0));
    if(u_phosphor.x>0.5) {
        vec2 q=pixel/max(1.0,u_phosphor.y*u_pixel_scale*u_scale);
        col*=mix(vec3(1.0),phosphorLight(q),u_honeycomb);
    } else col*=mix(vec3(1.0),mix(vec3(0.84),mask*1.10,dotlight),u_honeycomb);
    col*=1.025-0.035*dot(p,p);
    col=clamp(col*exp2(u_tone.x),0.0,1.0);
    // Symmetric contrast around mid-grey, retaining black and white endpoints.
    if(abs(u_tone.y-1.0)>0.00001) {
        vec3 a=pow(col,vec3(u_tone.y));
        vec3 b=pow(vec3(1.0)-col,vec3(u_tone.y));
        col=a/max(a+b,vec3(0.00001));
    }
    gl_FragColor=vec4(col,texture2D(gm_BaseTexture,v_vTexcoord).a)*v_vColour;
}
