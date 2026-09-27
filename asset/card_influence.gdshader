shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform bool glowing = false;
void fragment() {
 vec2 p = abs((UV - 0.5) * vec2(1.92, 2.58)) - vec2(0.70, 1.03);
 float d = length(max(p, vec2(0.0))) + min(max(p.x, p.y), 0.0) - 0.035;
 if (glowing) {
  float halo = exp(-max(d, 0.0) * 18.0) * smoothstep(-0.025, 0.01, d);
  ALBEDO = vec3(1.0, 0.30, 0.78);
  ALPHA = halo * 0.9;
 } else {
  ALBEDO = vec3(0.015, 0.018, 0.025);
  ALPHA = (1.0 - smoothstep(-0.008, 0.008, d)) * 0.36;
 }
}
