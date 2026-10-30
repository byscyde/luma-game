shader_type spatial;
render_mode cull_disabled;
// Flowing water ribbon (streams, channels, waterfalls). UV.y runs along the
// flow. `fill` reveals the ribbon from the start; `speed` scrolls highlights.

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float speed = 0.8;
uniform float stripes = 6.0;
uniform vec3 water : source_color = vec3(0.24, 0.74, 0.84);
uniform vec3 light : source_color = vec3(0.75, 0.96, 0.98);
uniform float emissive = 0.15;

void fragment() {
	if (UV.y > fill) {
		discard;
	}
	float s = sin((UV.y * stripes - TIME * speed) * 6.2831 + UV.x * 3.0);
	float hl = smoothstep(0.75, 1.0, s) * (0.6 + 0.4 * sin(UV.x * 12.0 + TIME));
	float edge = smoothstep(0.0, 0.2, UV.x) * smoothstep(1.0, 0.8, UV.x);
	vec3 col = mix(light, water, edge);
	col = mix(col, light, hl * 0.7);
	ALBEDO = col;
	EMISSION = col * emissive;
	ROUGHNESS = 0.1;
	SPECULAR = 0.7;
}
