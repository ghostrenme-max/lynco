shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
void fragment() {
 vec2 step_uv=SCREEN_PIXEL_SIZE*3.5;
 vec3 sum=vec3(0.0);
 float weight_sum=0.0;
 for(int x=-3;x<=3;x++) {
  for(int y=-3;y<=3;y++) {
   float weight=exp(-float(x*x+y*y)/4.0);
   sum+=texture(screen_texture,SCREEN_UV+vec2(float(x),float(y))*step_uv).rgb*weight;
   weight_sum+=weight;
  }
 }
 COLOR=vec4(sum/weight_sum*0.72,COLOR.a);
}
