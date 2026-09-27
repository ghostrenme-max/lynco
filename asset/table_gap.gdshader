shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
 vec2 edge = abs(UV - vec2(0.5)) * 2.0;
 float soft_edge = (1.0 - smoothstep(0.15, 1.0, edge.y))
                 * (1.0 - smoothstep(0.78, 1.0, edge.x));
 ALBEDO = vec3(0.025, 0.028, 0.04);
 ALPHA = soft_edge * 0.52;
}
