shader_type spatial;
render_mode cull_disabled, unshaded;
uniform sampler2D positions : filter_nearest, repeat_disable;
uniform sampler2D normals : filter_nearest, repeat_disable;
uniform sampler2D cloth : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float mirror_side = 1.0;
uniform float frame = 0.0;
uniform float frame_count = 131.0;
void vertex() {
 float a=floor(clamp(frame,0.0,frame_count-1.0));
 float b=min(a+1.0,frame_count-1.0);
 float blend=fract(clamp(frame,0.0,frame_count-1.0));
 vec2 uv_a=vec2(UV2.x,(a+0.5)/frame_count);
 vec2 uv_b=vec2(UV2.x,(b+0.5)/frame_count);
 VERTEX=mix(textureLod(positions,uv_a,0.0).rgb,textureLod(positions,uv_b,0.0).rgb,blend);
 VERTEX.x *= mirror_side;
 NORMAL=normalize(mix(textureLod(normals,uv_a,0.0).rgb,textureLod(normals,uv_b,0.0).rgb,blend));
 NORMAL.x *= mirror_side;
}
void fragment() {
 // Preserve the illustration's pigment and printed texture. A broad, soft
 // normal-based wash follows the baked folds without shiny 3D highlights.
 vec3 pigment=texture(cloth,UV).rgb;
 float facing=abs(normalize(NORMAL).z);
 float painted_shade=mix(0.76,1.0,smoothstep(0.08,0.88,facing));
 ALBEDO=pigment*painted_shade;
 ROUGHNESS=1.0;
 SPECULAR=0.0;
}


