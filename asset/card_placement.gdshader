shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(1.0, 0.84, 0.26, 1.0);
void fragment() {
 vec2 p = abs((UV - 0.5) * vec2(1.48, 2.14)) - (vec2(0.74, 1.07) - vec2(0.15));
 float d = length(max(p, vec2(0.0))) + min(max(p.x, p.y), 0.0) - 0.10;
 float distance_to_line = abs(d);
 float aa = max(fwidth(d), 0.001);
 float line = 1.0 - smoothstep(0.009, 0.009 + aa, distance_to_line);
 float halo = exp(-distance_to_line * distance_to_line / 0.00065);
 ALBEDO = mix(tint.rgb, vec3(1.0, 0.97, 0.78), line * 0.4);
 ALPHA = clamp(line * 0.9 + halo * 0.32, 0.0, 1.0) * tint.a;
}