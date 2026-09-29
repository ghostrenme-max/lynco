shader_type canvas_item;
render_mode unshaded;
uniform float animation_time = 0.0;
uniform float side = 0.0;
uniform float cloth_time = 0.0;
uniform vec2 strip_state[33];
varying float compression;
varying float fold_phase;
varying float tension;

void vertex() {
 float row=UV.y*32.0;
 int lo=min(int(floor(row)),31);
 vec2 state=mix(strip_state[lo],strip_state[lo+1],fract(row));
 float p=clamp(state.x,0.0,1.12);
 float u=UV.x;
 float v=UV.y;
 float width=mix(1065.0,100.0,clamp(p,0.0,1.0));
 float anchor=-80.0-255.0*smoothstep(0.72,1.0,p);
 float grip=exp(-pow((v-0.46-side*0.035)/0.19,2.0));
 // Depth folds gather toward the hand, while the heavy lower hem lags behind.
 float phase=u*56.54867 + p*sin(v*3.14159)*3.7;
 phase+=state.y*0.10*sin(v*5.0+u*3.0);
 float amplitude=mix(5.0,14.0,clamp(p,0.0,1.0));
 float x=anchor+u*width+sin(phase)*amplitude*sin(u*3.14159);
 float y=-38.0+v*1170.0;
 y-=p*100.0*pow(u,1.3)*grip;
 y+=sin(u*3.14159)*v*(state.y*7.0+sin(phase)*7.0);
 VERTEX=vec2(side<0.5 ? x:1920.0-x,y);
 compression=clamp(p,0.0,1.0);
 fold_phase=phase;
 tension=state.y;
}
void fragment() {
 vec4 cloth=texture(TEXTURE,UV);
 // A virtual pleated surface normal gives broad lit ridges and deep occluded valleys.
 float slope=sin(fold_phase)*mix(1.3,3.8,compression);
 vec3 normal=normalize(vec3(slope,0.12*tension,1.0));
 vec3 light=normalize(vec3(-0.65,-0.35,1.0));
 float diffuse=max(dot(normal,light),0.0);
 float valley=pow(0.5+0.5*cos(fold_phase+0.7),3.0);
 float ao=1.0-valley*mix(0.22,0.5,compression);
 float lighting=(0.34+0.88*diffuse)*ao;
 // Rolled inner edge: dark seam and narrow warm rim suggest several layers of fabric.
 float seam=smoothstep(0.977,0.990,UV.x)*(1.0-smoothstep(0.992,1.0,UV.x));
 float rim=smoothstep(0.992,0.997,UV.x);
 lighting*=1.0-0.55*seam;
 vec3 color=cloth.rgb*lighting + vec3(0.16,0.045,0.018)*rim;
 float hem=smoothstep(0.968,0.980,UV.y)*(1.0-smoothstep(0.987,0.998,UV.y));
 color*=1.0-0.3*hem;
 COLOR=vec4(color,cloth.a);
}
