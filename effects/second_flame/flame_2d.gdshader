shader_type canvas_item;
render_mode unshaded;
#include "res://effects/second_flame/flame_shape.gdshaderinc"
void fragment() {
	COLOR = render_flame(UV) * COLOR;
}
