shader_type canvas_item;
varying vec2 local_position;
uniform int mask_count = 0;
uniform vec4 masks[16];
void vertex() { local_position = VERTEX; }
void fragment() {
 for (int i = 0; i < mask_count; i++) {
  vec4 box = masks[i];
  if (local_position.x >= box.x && local_position.y >= box.y && local_position.x < box.z && local_position.y < box.w) {
   COLOR.a = 0.0;
  }
 }
}
