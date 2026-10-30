shader_type spatial;
// Island terrain. COLOR holds the rock/sand base colour; UV2.x is the area
// index (0..5, or -1), UV2.y is "grassiness" (0 = rock/sand, 1 = grass top),
// UV.x is a per-vertex variation value. Grass colour follows each area's
// restoration progress; locked areas are desaturated.

uniform float progress[6];
uniform float awake[6];
uniform vec3 dry_grass : source_color = vec3(0.80, 0.74, 0.55);
uniform vec3 lush_grass : source_color = vec3(0.36, 0.60, 0.30);
uniform vec3 lush_grass_b : source_color = vec3(0.48, 0.68, 0.34);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	int idx = int(clamp(UV2.x + 0.5, 0.0, 5.0));
	float valid = step(-0.5, UV2.x);
	float p = progress[idx] * valid;
	float aw = mix(1.0, awake[idx], valid);
	vec3 lush = mix(lush_grass, lush_grass_b, UV.x);
	vec3 grass = mix(dry_grass * (0.92 + 0.12 * UV.x), lush, smoothstep(0.0, 1.0, p));
	vec3 base = pow(COLOR.rgb, vec3(2.2)); // vertex colours are authored in sRGB
	vec3 col = mix(base, grass, UV2.y);
	float grey = dot(col, vec3(0.3, 0.55, 0.15));
	col = mix(vec3(grey) * vec3(0.82, 0.86, 0.9), col, 0.45 + 0.55 * aw);
	ALBEDO = col;
	// faceted look: face normal from screen-space derivatives
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
