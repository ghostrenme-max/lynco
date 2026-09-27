shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
 float x = abs(UV.x - 0.5);
 float tip = step(0.08, UV.y) * step(UV.y, 0.43) * step(x, (UV.y - 0.08) * 1.25);
 float stem = step(0.34, UV.y) * step(UV.y, 0.96) * step(x, 0.16);
 ALBEDO = vec3(1.0, 0.42, 0.82);
 ALPHA = max(tip, stem);
}
