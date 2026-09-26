shader_type canvas_item;
render_mode unshaded;
void fragment() {
 vec4 pixel = texture(TEXTURE, UV);
 vec2 half_size = vec2(79.0, 114.0);
 vec2 q = abs((UV - vec2(0.5)) * half_size * 2.0) - half_size + vec2(13.0);
 float distance = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 13.0;
 float edge = max(fwidth(distance), 0.1);
 COLOR = pixel * COLOR;
 COLOR.a *= 1.0 - smoothstep(-edge, edge, distance);
}
