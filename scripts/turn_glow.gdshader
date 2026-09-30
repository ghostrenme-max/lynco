shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float emission_strength : hint_range(0.0, 8.0) = 2.4;
uniform vec4 emission_color : source_color = vec4(0.10, 0.52, 1.0, 1.0);

void fragment() {
 float r = length(UV - vec2(0.5)) * 2.0;
 float edge = 1.0 - smoothstep(0.72, 1.0, r);
 // Analytic Gaussian bloom for this point emitter, compatible with the GL renderer.
 float halo = exp(-5.8 * r * r) * 0.10;
 float bloom = exp(-24.0 * r * r) * 0.32;
 float core = exp(-125.0 * r * r) * 0.85;
 vec3 light = emission_strength * (emission_color.rgb * (halo + bloom)
            + vec3(0.74, 0.94, 1.0) * core);
 COLOR = vec4(light * edge, 1.0) * COLOR;
}
