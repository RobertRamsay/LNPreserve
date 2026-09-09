varying vec2 v_vTexcoord;
varying vec4 v_vColour;
uniform vec2 u_size;
uniform float u_scale;
uniform float u_pixel_scale;
uniform float u_time;
uniform float u_blur;
uniform float u_honeycomb;
uniform float u_scanlines;
const float PI=3.14159265359;
void main() {
    vec2 p=v_vTexcoord*2.0-1.0;
    // Fixed geometry: all borders and HUD lines stay straight and stationary.
    vec2 uv=v_vTexcoord;
    vec2 edge=0.5/u_size;
    vec2 sampleUV=clamp(uv,edge,1.0-edge);
    float phase=(0.14+0.025*sin(u_time*0.8))*u_pixel_scale/u_size.x;
    vec3 col=vec3(texture2D(gm_BaseTexture,clamp(sampleUV+vec2(phase,0.0),edge,1.0-edge)).r,
                  texture2D(gm_BaseTexture,sampleUV).g,
                  texture2D(gm_BaseTexture,clamp(sampleUV-vec2(phase,0.0),edge,1.0-edge)).b);
    // Blur the underlying pixels before adding phosphors and scanlines.
    vec2 radius=vec2(2.0*u_blur*u_pixel_scale)/u_size;
    vec3 blurred=texture2D(gm_BaseTexture,sampleUV).rgb*0.25;
    blurred+=(texture2D(gm_BaseTexture,clamp(sampleUV+vec2(radius.x,0.0),edge,1.0-edge)).rgb+
              texture2D(gm_BaseTexture,clamp(sampleUV-vec2(radius.x,0.0),edge,1.0-edge)).rgb+
              texture2D(gm_BaseTexture,clamp(sampleUV+vec2(0.0,radius.y),edge,1.0-edge)).rgb+
              texture2D(gm_BaseTexture,clamp(sampleUV-vec2(0.0,radius.y),edge,1.0-edge)).rgb)*0.125;
    blurred+=(texture2D(gm_BaseTexture,clamp(sampleUV+radius,edge,1.0-edge)).rgb+
              texture2D(gm_BaseTexture,clamp(sampleUV-radius,edge,1.0-edge)).rgb+
              texture2D(gm_BaseTexture,clamp(sampleUV+vec2(radius.x,-radius.y),edge,1.0-edge)).rgb+
              texture2D(gm_BaseTexture,clamp(sampleUV+vec2(-radius.x,radius.y),edge,1.0-edge)).rgb)*0.0625;
    col=mix(col,blurred,u_blur)*vec3(0.985,1.0,1.035);
    col*=1.0-u_scanlines*0.4*(0.5-0.5*cos(2.0*PI*uv.y*u_size.y/u_pixel_scale));
    // Staggered RGB phosphor dots on a hexagonal (honeycomb) lattice.
    vec2 pixel=v_vTexcoord*u_size*u_scale;
    float row=floor(pixel.y/2.598);
    float cx=pixel.x/3.0-0.5*mod(row,2.0);
    vec2 dotpos=vec2((fract(cx)-0.5)*3.0,(fract(pixel.y/2.598)-0.5)*2.598);
    float dotlight=1.0-smoothstep(0.65,1.5,length(dotpos));
    float channel=mod(floor(cx),3.0);
    vec3 mask=channel<0.5?vec3(1.0,0.78,0.78):(channel<1.5?vec3(0.78,1.0,0.78):vec3(0.78,0.78,1.0));
    col*=mix(vec3(1.0),mix(vec3(0.84),mask*1.10,dotlight),u_honeycomb);
    col*=1.025-0.035*dot(p,p);
    gl_FragColor=vec4(clamp(col,0.0,1.0),1.0)*v_vColour;
}
