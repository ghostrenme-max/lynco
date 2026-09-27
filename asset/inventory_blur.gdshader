shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
void fragment() {
 vec3 background=textureLod(screen_texture,SCREEN_UV,2.6).rgb;
 COLOR=vec4(background*0.40,1.0);
}
