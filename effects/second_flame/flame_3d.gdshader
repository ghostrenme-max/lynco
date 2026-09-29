shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
#include "res://effects/second_flame/flame_shape.gdshaderinc"
uniform float vertical_anchor = 0.0;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
void vertex() {
	VERTEX.y += vertical_anchor;
	// Face the camera while preserving the object's scale.
	mat4 facing = mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
	facing[0].xyz *= length(MODEL_MATRIX[0].xyz);
	facing[1].xyz *= length(MODEL_MATRIX[1].xyz);
	facing[2].xyz *= length(MODEL_MATRIX[2].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
}
void fragment() {
	vec4 fire = render_flame(UV);
	ALBEDO = fire.rgb * intensity;
	ALPHA = fire.a;
}
