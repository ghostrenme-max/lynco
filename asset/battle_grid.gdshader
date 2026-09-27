shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform int opponent_mask = 0;
void fragment() {
 vec2 grid = UV * vec2(5.0,6.0);
 ivec2 cell = clamp(ivec2(floor(grid)),ivec2(0),ivec2(4,5));
 bool enemy = (opponent_mask & (1 << (cell.y*5+cell.x))) != 0;
 vec2 edge = min(fract(grid),1.0-fract(grid))*vec2(1.65,2.35);
 float distance_to_line = min(edge.x,edge.y);
 float line = 1.0-smoothstep(0.007,0.018,distance_to_line);
 float halo = exp(-distance_to_line*24.0);
 if (enemy) {
  ALBEDO=vec3(0.95,0.10,0.16);
  ALPHA=0.12+0.50*line+0.22*halo;
 } else {
  ALBEDO=vec3(0.72,0.80,0.78);
  ALPHA=0.17*line+0.07*halo;
 }
}
