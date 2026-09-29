shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz/2.4;
 float tile=mod(floor(p.x)+floor(p.y),2.0);
 float noise=fract(sin(dot(floor(world_pos.xz*60.0),vec2(12.9898,78.233)))*43758.5453);
 vec3 ink=vec3(0.025,0.019,0.016);
 vec3 cream=vec3(0.24,0.19,0.13);
 float falloff=1.0-smoothstep(17.0,28.0,max(abs(world_pos.x),abs(world_pos.z+8.9)));
 ALBEDO=mix(ink,cream,tile)*(0.92+noise*0.08)*mix(0.03,1.0,falloff);
 ROUGHNESS=0.94;
}
