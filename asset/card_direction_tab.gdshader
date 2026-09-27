shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform bool reduced_motion = false;
uniform float opacity = 1.0;
void fragment() {
 vec2 p = abs(UV - 0.5) - vec2(0.38, 0.44);
 float d = length(max(p, vec2(0.0))) + min(max(p.x, p.y), 0.0) - 0.055;
 float border = smoothstep(-0.065, -0.045, d);
 ALBEDO = mix(vec3(0.953, 0.282, 0.741), vec3(0.97), border);
 ALPHA = (1.0 - smoothstep(-0.01, 0.01, d)) * opacity;
}
