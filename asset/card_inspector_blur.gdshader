shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float radius = 2.2;
void fragment() {
 vec3 blurred = vec3(0.0);
 float weights[5] = float[5](1.0, 4.0, 6.0, 4.0, 1.0);
 for (int y = 0; y < 5; y++) {
  for (int x = 0; x < 5; x++) {
   vec2 offset = vec2(float(x - 2), float(y - 2)) * SCREEN_PIXEL_SIZE * radius;
   blurred += texture(screen_texture, SCREEN_UV + offset).rgb * weights[x] * weights[y];
  }
 }
 COLOR = vec4(blurred / 256.0 * 0.72, 1.0);
}