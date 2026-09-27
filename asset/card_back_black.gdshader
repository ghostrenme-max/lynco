shader_type canvas_item;
render_mode unshaded;
// Visible bounds are measured once when the back texture is loaded.
uniform vec4 logo_region = vec4(0.0, 0.0, 1.0, 1.0);
varying vec4 tint;
void vertex() { tint = COLOR; }
float rounded_box(vec2 p, vec2 half_size, float radius) {
 vec2 q = abs(p) - half_size + vec2(radius);
 return length(max(q, vec2(0.0))) + min(max(q.x,q.y),0.0) - radius;
}
void fragment() {
 vec2 p = (UV - vec2(0.5)) * vec2(158.0,228.0);
 float outer = rounded_box(p,vec2(79.0,114.0),13.0);
 float edge = max(fwidth(outer),0.1);
 float border = rounded_box(p,vec2(73.0,108.0),10.0);
 float line = 1.0 - smoothstep(0.45,0.45+edge,abs(border));
 vec2 source_size = vec2(textureSize(TEXTURE,0));
 // Match the white back logo footprint, preserving the PNG aspect ratio.
 vec2 visible_size = source_size * logo_region.zw;
 float scale = 1.5 * min(65.0/visible_size.x,71.2/visible_size.y);
 vec2 logo_uv = p / (source_size*scale) + logo_region.xy + logo_region.zw*0.5;
 vec4 logo = texture(TEXTURE,clamp(logo_uv,vec2(0.0),vec2(1.0)));
 float inside = step(0.0,logo_uv.x)*step(logo_uv.x,1.0)*step(0.0,logo_uv.y)*step(logo_uv.y,1.0);
 vec3 color = mix(vec3(line*0.85),vec3(140.0,38.0,51.0)/255.0,logo.a*inside);
 COLOR = vec4(color,1.0-smoothstep(-edge,edge,outer))*tint;
}
