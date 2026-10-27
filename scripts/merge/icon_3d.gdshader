// Turns a flat icon into a glossy, lit, slightly puffy "3D" icon (IconBaker).
// Height = blurred coverage, nudged by brightness so colour edges inside the icon
// also get relief; normals from its slope; key light from the upper left, a soft
// specular highlight, edge occlusion, and a contact shadow under the icon.
shader_type canvas_item;

uniform sampler2D src : filter_linear;   // the flat atlas (helper functions cannot read TEXTURE)
uniform vec2 px;                 // 1 / atlas size
uniform float radius = 10.0;     // bevel width in pixels
uniform float relief = 9.0;      // slope strength
uniform float grid = 8.0;
uniform float lum_weight = 0.22; // how much colour edges inside an icon add relief (low for faces)        // icons per atlas side (for the top-to-bottom shading)
const vec3 KEY_LIGHT = vec3(-0.42, -0.68, 0.6);   // screen space: up and to the left

float field(vec2 uv) {
	vec4 c = texture(src, uv);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	return c.a * (1.0 - lum_weight + lum_weight * lum);
}

float height(vec2 uv) {
	float h = field(uv) * 2.0;
	float w = 2.0;
	for (int i = 0; i < 12; i++) {
		float a = 6.2831853 * float(i) / 12.0;
		vec2 d = vec2(cos(a), sin(a)) * px;
		h += field(uv + d * radius) * 0.7 + field(uv + d * radius * 0.5) * 1.0;
		w += 1.7;
	}
	return h / w;
}

void fragment() {
	vec4 c = texture(src, UV);
	vec2 e = px * 1.5;
	float hx = height(UV + vec2(e.x, 0.0)) - height(UV - vec2(e.x, 0.0));
	float hy = height(UV + vec2(0.0, e.y)) - height(UV - vec2(0.0, e.y));
	vec3 n = normalize(vec3(-hx * relief, -hy * relief, 1.0));
	vec3 l = normalize(KEY_LIGHT);
	float diff = dot(n, l);
	float h = height(UV);
	float ao = mix(0.72, 1.0, smoothstep(0.15, 0.8, h));
	vec3 v = vec3(0.0, 0.0, 1.0);
	vec3 r = reflect(-l, n);
	float spec = pow(max(dot(r, v), 0.0), 14.0) * 0.6 * smoothstep(0.3, 0.9, h);
	float cell_y = fract(UV.y * grid);           // 0 at the top of this icon, 1 at the bottom
	float body = mix(1.12, 0.8, smoothstep(0.15, 0.9, cell_y));
	vec3 lit = c.rgb * (0.55 + 0.6 * clamp(diff, 0.0, 1.0)) * ao * body + vec3(spec);
	// contact shadow below and slightly right of the icon
	float sh = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = 6.2831853 * float(i) / 8.0;
		sh += texture(src, UV - vec2(px.x * 3.0, px.y * 7.0) + vec2(cos(a), sin(a)) * px * 6.0).a;
	}
	sh = sh / 8.0 * 0.32;
	vec4 shadow = vec4(0.05, 0.03, 0.02, sh);
	COLOR = mix(shadow, vec4(clamp(lit, 0.0, 1.0), 1.0), c.a);
	COLOR.a = max(c.a, sh);
}
