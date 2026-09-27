shader_type spatial;
render_mode blend_mix, cull_back;
varying vec3 object_position;
varying vec3 object_normal;
void vertex() {
 object_position = VERTEX;
 object_normal = NORMAL;
}
void fragment() {
 vec3 n = normalize(NORMAL);
 vec3 v = normalize(VIEW);
 float fresnel = pow(1.0 - abs(dot(n,v)),3.0);
 vec3 local_n = normalize(object_normal);
 // One continuous glass material: internal light fades smoothly through it.
 float transmission = exp(-max(length(object_position)-0.43,0.0)*4.2);
 float illumination = 0.18 + 0.72*max(local_n.y,0.0) + 0.30*max(local_n.x,0.0) + 0.10*max(local_n.z,0.0);
 float reflection = pow(max(dot(reflect(-v,n),normalize(vec3(-0.45,0.85,0.35))),0.0),24.0);
 ALBEDO = vec3(0.012,0.009,0.019);
 METALLIC = 0.0;
 ROUGHNESS = 0.13;
 SPECULAR = 0.7;
 EMISSION = vec3(0.28,0.085,0.62)*transmission*illumination
          + vec3(0.22,0.20,0.28)*reflection*0.28;
 ALPHA = 0.48 + fresnel*0.10;
}
