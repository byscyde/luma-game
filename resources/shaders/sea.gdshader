shader_type spatial;
render_mode specular_schlick_ggx;
// Opaque stylised sea: colour by depth sampled from the baked island height
// map, animated shore foam and soft ripples. No transparency needed.

uniform sampler2D heightmap : filter_linear, repeat_disable;
uniform vec4 bounds; // xmin, zmin, xsize, zsize
uniform vec3 shallow : source_color = vec3(0.62, 0.90, 0.84);
uniform vec3 mid : source_color = vec3(0.36, 0.74, 0.80);
uniform vec3 deep : source_color = vec3(0.26, 0.56, 0.70);
uniform vec3 foam_col : source_color = vec3(1.0, 1.0, 0.97);

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (world_pos.xz - bounds.xy) / bounds.zw;
	float h = -0.95;
	if (uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0) {
		h = texture(heightmap, uv).r;
	}
	float depth = clamp(-h, 0.0, 2.0);
	vec3 col = mix(shallow, mid, smoothstep(0.02, 0.35, depth));
	col = mix(col, deep, smoothstep(0.35, 1.0, depth));
	float n = noise(world_pos.xz * 3.0 + vec2(TIME * 0.25, TIME * 0.18));
	float n2 = noise(world_pos.xz * 7.0 - vec2(TIME * 0.4, -TIME * 0.3));
	// soft sparkles on the open water
	col += vec3(0.035) * smoothstep(0.8, 0.98, n * 0.5 + n2 * 0.5);
	// shore foam: a solid lip plus a travelling ring
	float lip = smoothstep(0.10, 0.0, depth);
	float ring = smoothstep(0.08, 0.0, abs(depth - (0.12 + 0.1 * sin(TIME * 1.2)))) * smoothstep(0.35, 0.1, depth);
	float foam = clamp(lip + ring * (0.6 + 0.4 * n2), 0.0, 1.0);
	col = mix(col, foam_col, foam * 0.9);
	ALBEDO = col;
	EMISSION = col * 0.32; // keep the sea luminous and cheerful
	ROUGHNESS = mix(0.18, 0.6, foam);
	SPECULAR = 0.2;
}
