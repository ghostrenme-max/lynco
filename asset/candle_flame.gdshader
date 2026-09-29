shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform float flame_time = 0.0;
uniform float phase = 0.0;
void vertex() {
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
// Rounded foot, broad body, curling tip, and upward-travelling scalloped bites.
float fire_field(vec2 p, float t) {
 float tip=0.84+0.075*sin(t*4.1)+0.025*sin(t*8.3);
 float h=(p.y-0.055)/(tip-0.055);
 float belly=0.235*(1.0+0.045*sin(t*5.2));
 float width;
 if(h<0.29) {
  float q=(h-0.29)/0.29;
  width=belly*sqrt(max(0.0,1.0-q*q));
 } else {
  width=belly*pow(max(0.0,(1.0-h)/0.71),0.70);
 }
 float curl=(0.13*sin(t*3.7-h*4.3)+0.04*sin(t*7.9-h*7.0))*h*h;
 curl-=0.13*smoothstep(0.67,1.0,h);
 float d=max(abs(p.x-curl)-width,max(0.055-p.y,p.y-tip));
 // Moving concavities create hooked flame tongues rather than a waving teardrop.
 float travel=fract(t*0.60);
 float ly=0.38+travel*0.47;
 float lx=-0.24+0.025*sin(t*3.7);
 float bite_left=(length((p-vec2(lx,ly))/vec2(0.15,0.18))-1.0)*0.115;
 d=max(d,-bite_left-(1.0-smoothstep(0.29,0.45,p.y)));
 float ry=0.34+fract(t*0.60+0.48)*0.43;
 float bite_right=(length((p-vec2(0.245,ry))/vec2(0.13,0.135))-1.0)*0.105;
 d=max(d,-bite_right-(1.0-smoothstep(0.27,0.42,p.y)));
 return d;
}
void fragment() {
 float t=flame_time+phase;
 vec2 p=vec2(UV.x-0.5,1.0-UV.y);
 float d=fire_field(p,t);
 float aa=max(fwidth(d),0.0015);
 float body=1.0-smoothstep(-aa,aa,d);
 // A wide, organically shaped pale core follows the same curling contour.
 vec2 inner=vec2((p.x+0.006)/0.73,(p.y-0.074)/0.80+0.055);
 float core_d=fire_field(inner,t+0.12);
 float core=(1.0-smoothstep(-0.012,0.012,core_d))*body;
 vec3 orange=mix(vec3(1.0,0.27,0.025),vec3(1.0,0.46,0.07),smoothstep(0.07,0.55,p.y));
 vec3 color=mix(orange,vec3(1.0,0.91,0.42),core);
 // Two small rising detached tongues, disappearing before the quad boundary.
 float sparks=0.0;
 for(int i=0;i<2;i++) {
  float life=fract(t*0.68+float(i)*0.51);
  vec2 pos=vec2(-0.16-0.09*life+0.035*sin(t*4.0+float(i)),0.66+life*0.31);
  vec2 q=p-pos;
  q.x+=q.y*0.65;
  float radius=(1.0-life)*0.024+0.006;
  float sd=(length(q/vec2(radius,radius*2.0))-1.0)*radius;
  sparks=max(sparks,(1.0-smoothstep(-0.003,0.003,sd))*smoothstep(0.0,0.15,life)*(1.0-smoothstep(0.75,1.0,life)));
 }
 color=mix(color,vec3(1.0,0.64,0.15),sparks);
 float halo=exp(-max(d,0.0)*38.0)*0.18;
 float alpha=max(body,sparks);
 color=mix(vec3(1.0,0.25,0.015),color,alpha);
 ALBEDO=color;
 ALPHA=max(alpha,halo)*smoothstep(0.0,0.04,p.y);
}