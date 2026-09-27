shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform int opponent_mask = 0;
uniform int influence_mask = 0;
void fragment() {
 vec2 grid = UV * vec2(6.0,5.0);
 ivec2 cell = clamp(ivec2(floor(grid)),ivec2(0),ivec2(5,4));
 bool enemy = (opponent_mask & (1 << (cell.y*6+cell.x))) != 0;
 vec2 edge = min(fract(grid),1.0-fract(grid))*vec2(3.1,2.35);
 float distance_to_line = min(edge.x,edge.y);
 float line = 1.0-smoothstep(0.007,0.018,distance_to_line);
 float halo = exp(-distance_to_line*24.0);
 bool affected = (influence_mask & (1 << (cell.y*6+cell.x))) != 0;
 if (affected) {
  float border = 1.0-smoothstep(0.035,0.065,distance_to_line);
  ALBEDO=vec3(0.95,0.16,0.64);
  ALPHA=0.24+0.56*border+0.10*halo;
 } else if (enemy) {
  ALBEDO=vec3(0.95,0.10,0.16);
  ALPHA=0.12+0.50*line+0.22*halo;
 } else {
  ALBEDO=vec3(0.72,0.80,0.78);
  ALPHA=0.17*line+0.07*halo;
 }
}
