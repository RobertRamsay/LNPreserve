varying vec2 v_vTexcoord;
varying vec4 v_vColour;
uniform vec2 u_size;
uniform float u_scale;
uniform float u_time;
const float PI=3.14159265359;
void main() {
    vec2 p=v_vTexcoord*2.0-1.0;
    vec2 uv=(p*(1.0+0.006*dot(p,p))+1.0)*0.5;
    // Sub-pixel drift, no large rolling bar or hard flicker.
    uv.x+=(0.10*sin(uv.y*31.0+u_time*1.7)+0.035*sin(uv.y*111.0-u_time*2.1))/u_size.x;
    uv.y+=0.07*sin(u_time*1.3)/u_size.y;
    vec2 edge=0.5/u_size;
    vec2 sampleUV=clamp(uv,edge,1.0-edge);
    float phase=(0.14+0.025*sin(u_time*0.8))/u_size.x;
    vec3 col=vec3(texture2D(gm_BaseTexture,clamp(sampleUV+vec2(phase,0.0),edge,1.0-edge)).r,
                  texture2D(gm_BaseTexture,sampleUV).g,
                  texture2D(gm_BaseTexture,clamp(sampleUV-vec2(phase,0.0),edge,1.0-edge)).b);
    // Restrained phosphor glow and cool white balance.
    vec3 glow=(texture2D(gm_BaseTexture,clamp(sampleUV+vec2(1.0/u_size.x,0.0),edge,1.0-edge)).rgb+
               texture2D(gm_BaseTexture,clamp(sampleUV-vec2(1.0/u_size.x,0.0),edge,1.0-edge)).rgb)*0.5;
    col=mix(col,glow,0.045)*vec3(0.985,1.0,1.035);
    col*=0.96+0.04*cos(2.0*PI*uv.y*u_size.y);
    // Staggered RGB phosphor dots on a hexagonal (honeycomb) lattice.
    vec2 pixel=v_vTexcoord*u_size*u_scale;
    float row=floor(pixel.y/2.598);
    float cx=pixel.x/3.0-0.5*mod(row,2.0);
    vec2 dotpos=vec2((fract(cx)-0.5)*3.0,(fract(pixel.y/2.598)-0.5)*2.598);
    float dotlight=1.0-smoothstep(0.65,1.5,length(dotpos));
    float channel=mod(floor(cx),3.0);
    vec3 mask=channel<0.5?vec3(1.0,0.78,0.78):(channel<1.5?vec3(0.78,1.0,0.78):vec3(0.78,0.78,1.0));
    col*=mix(vec3(0.94),mask*1.08,dotlight*0.35);
    col*=1.025-0.035*dot(p,p);
    float inside=step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0);
    gl_FragColor=vec4(clamp(col,0.0,1.0)*inside,1.0)*v_vColour;
}
