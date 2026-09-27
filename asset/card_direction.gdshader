shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform bool reduced_motion = false;
void fragment() {
 float y = fract(UV.y + (reduced_motion ? 0.0 : TIME * 0.6));
 float x = abs(UV.x - 0.5);
 float head = step(0.12, y) * step(y, 0.48) * step(x, (y - 0.12) * 0.85);
 float stem = step(0.43, y) * step(y, 0.83) * step(x, 0.075);
 ALBEDO = vec3(0.953, 0.282, 0.741);
 ALPHA = max(head, stem) * 0.95;
}
