shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform bool opponent = false;
void fragment() {
 vec2 p = abs(UV - 0.5) * vec2(1.64,2.30);
 float d;
 if (opponent) {
  // Angular shoulders distinguish ownership even without color.
  float bevel = max(p.x+p.y-1.85,0.0);
  d = max(max(p.x-0.82,p.y-1.15),bevel-0.025);
  ALBEDO = vec3(0.55,0.15,0.20);
  float side = step(0.752,p.x);
  float brace = step(0.58,p.y)*step(p.y,0.94);
  ALBEDO = mix(ALBEDO,vec3(0.95,0.76,0.71),side*brace);
 } else {
  vec2 q = p-vec2(0.735,1.065);
  d=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-0.075;
  ALBEDO=vec3(0.92,0.94,0.88);
 }
 ALPHA=1.0-smoothstep(-0.004,0.004,d);
}
