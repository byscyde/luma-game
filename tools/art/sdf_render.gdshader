// Offline renderer for the merge art (tools/bake_merge_art.gd): ray-marches a model
// made of smoothly blended primitives (ArtModel) and lights it like a glossy toy —
// wrapped key light with soft shadows, sky/bounce ambient, ambient occlusion,
// fresnel rim and a specular highlight. 2x2 supersampling, transparent background,
// straight (not premultiplied) alpha.
shader_type canvas_item;
render_mode blend_disabled;   // write straight alpha as is

const int MAXP = 128;
uniform int count = 0;
uniform vec4 p_pos[MAXP];    // xyz position, w radius / rounding
uniform vec4 p_size[MAXP];   // xyz size (meaning per type), w shell thickness
uniform vec4 p_rot[MAXP];    // world -> local rotation (quaternion)
uniform vec4 p_col[MAXP];    // rgb (sRGB), a gloss
uniform vec4 p_info[MAXP];   // x type, y op, z blend k, w mirror x

uniform vec3 cam_pos = vec3(0.0, 1.35, 3.6);
uniform vec3 cam_target = vec3(0.0, 0.0, 0.0);
uniform float fov = 0.36;          // tan(half angle)
uniform vec3 key_dir = vec3(-0.55, 0.85, 0.65);
uniform float bound = 1.6;         // the model fits in this sphere
uniform float exposure = 1.0;
uniform int debug = 0;             // 1 normal, 2 colour, 3 occlusion, 4 shadow

vec3 qrot(vec4 q, vec3 v) {
	return v + 2.0 * cross(q.xyz, cross(q.xyz, v) + q.w * v);
}

float sd_capped_cone(vec3 p, float h, float r1, float r2) {
	vec2 q = vec2(length(p.xz), p.y);
	vec2 k1 = vec2(r2, h);
	vec2 k2 = vec2(r2 - r1, 2.0 * h);
	vec2 ca = vec2(q.x - min(q.x, (q.y < 0.0) ? r1 : r2), abs(q.y) - h);
	vec2 cb = q - k1 + k2 * clamp(dot(k1 - q, k2) / dot(k2, k2), 0.0, 1.0);
	float s = (cb.x < 0.0 && ca.y < 0.0) ? -1.0 : 1.0;
	return s * sqrt(min(dot(ca, ca), dot(cb, cb)));
}

float prim(int i, vec3 p) {
	vec4 info = p_info[i];
	vec4 pp = p_pos[i];
	vec4 sz = p_size[i];
	if (info.w > 0.5) {
		p.x = abs(p.x);
	}
	vec3 q = qrot(p_rot[i], p - pp.xyz);
	int t = int(info.x + 0.5);
	float r = pp.w;
	float d;
	if (t == 0) {            // sphere
		d = length(q) - r;
	} else if (t == 1) {     // ellipsoid (half axes)
		float k0 = length(q / sz.xyz);
		float k1 = length(q / (sz.xyz * sz.xyz));
		d = k0 * (k0 - 1.0) / max(k1, 1e-5);
	} else if (t == 2) {     // rounded box (half extents, rounding r)
		vec3 b = abs(q) - sz.xyz + r;
		d = length(max(b, 0.0)) + min(max(b.x, max(b.y, b.z)), 0.0) - r;
	} else if (t == 3) {     // capsule along y (half length sz.y, radius r)
		q.y -= clamp(q.y, -sz.y, sz.y);
		d = length(q) - r;
	} else if (t == 4) {     // torus in the xz plane (major sz.x, minor r)
		d = length(vec2(length(q.xz) - sz.x, q.y)) - r;
	} else if (t == 5) {     // rounded cylinder along y (radius sz.x, half height sz.y, rounding r)
		vec2 dd = vec2(length(q.xz) - sz.x + r, abs(q.y) - sz.y + r);
		d = min(max(dd.x, dd.y), 0.0) + length(max(dd, 0.0)) - r;
	} else if (t == 6) {     // rounded cone along y (bottom radius sz.x, top sz.z, half height sz.y)
		d = sd_capped_cone(q, sz.y - r, sz.x - r, sz.z - r) - r;
	} else if (t == 7) {     // half space below the local xz plane
		d = q.y;
	} else {                 // 8: tapered capsule along y (bottom radius sz.x, top sz.z, half length sz.y)
		float h = sz.y * 2.0;
		q.y += sz.y;
		float k = clamp(q.y / h, 0.0, 1.0);
		d = length(vec3(q.x, q.y - k * h, q.z)) - mix(sz.x, sz.z, k);
	}
	if (sz.w > 0.0) {
		d = abs(d) - sz.w;
	}
	return d;
}

// Distance and colour (rgb + gloss) of the model.
float scene(vec3 p, out vec4 col) {
	float d = 1e5;
	col = vec4(1.0, 0.0, 1.0, 0.0);
	float gd = 1e5;            // the model outside the current group
	vec4 gcol = col;
	for (int i = 0; i < MAXP; i++) {
		if (i >= count) {
			break;
		}
		int op = int(p_info[i].y + 0.5);
		float k = max(p_info[i].z, 1e-4);
		vec4 ci = p_col[i];
		if (op == 5) {           // end of a group: blend it into the model
			if (gd > 1e4) {
				gd = d;
				gcol = col;
			} else {
				float h = clamp(0.5 + 0.5 * (gd - d) / k, 0.0, 1.0);
				gd = mix(gd, d, h) - k * h * (1.0 - h);
				gcol = mix(gcol, col, h);
			}
			d = gd;
			col = gcol;
			gd = 1e5;
			continue;
		}
		float di = prim(i, p);
		if (op == 4) {           // start of a group: set the model aside
			gd = d;
			gcol = col;
			d = di;
			col = ci;
			continue;
		}
		if (op == 0 && d > 1e4) {   // the first shape (mixing with 1e5 would lose precision)
			d = di;
			col = ci;
		} else if (op == 0) {    // smooth union
			float h = clamp(0.5 + 0.5 * (d - di) / k, 0.0, 1.0);
			d = mix(d, di, h) - k * h * (1.0 - h);
			col = mix(col, ci, h);
		} else if (op == 1) {    // smooth subtraction (the cut takes the cutter's colour if ci.a >= 0)
			float h = clamp(0.5 - 0.5 * (d + di) / k, 0.0, 1.0);
			d = mix(d, -di, h) + k * h * (1.0 - h);
			if (ci.r >= 0.0) {   // the cut surface takes the cutter's colour
				col = mix(col, ci, smoothstep(0.35, 0.65, h));
			}
		} else if (op == 2) {    // smooth intersection
			float h = clamp(0.5 - 0.5 * (di - d) / k, 0.0, 1.0);
			d = mix(di, d, h) + k * h * (1.0 - h);
		} else {                 // 3: paint inside the primitive, shape unchanged
			col = mix(col, ci, 1.0 - smoothstep(-k, k, di));
		}
	}
	return d;
}

float map(vec3 p) {
	vec4 c;
	return scene(p, c);
}

vec3 calc_normal(vec3 p) {
	const float h = 0.0012;
	const vec2 k = vec2(1.0, -1.0);
	return normalize(k.xyy * map(p + k.xyy * h) + k.yyx * map(p + k.yyx * h)
		+ k.yxy * map(p + k.yxy * h) + k.xxx * map(p + k.xxx * h));
}

float calc_ao(vec3 p, vec3 n) {
	float occ = 0.0;
	float sca = 1.0;
	for (int i = 0; i < 5; i++) {
		float h = 0.02 + 0.09 * float(i);
		occ += (h - map(p + h * n)) * sca;
		sca *= 0.8;
	}
	return clamp(1.0 - 1.8 * occ, 0.0, 1.0);
}

float soft_shadow(vec3 ro, vec3 rd) {
	float res = 1.0;
	float t = 0.03;
	for (int i = 0; i < 48; i++) {
		vec3 p = ro + rd * t;
		if (dot(p, p) > bound * bound) {
			break;
		}
		float h = map(p);
		res = min(res, 10.0 * h / t);
		t += clamp(h, 0.01, 0.18);
		if (res < 0.003) {
			break;
		}
	}
	res = clamp(res, 0.0, 1.0);
	return res * res * (3.0 - 2.0 * res);
}

vec3 to_lin(vec3 c) { return pow(c, vec3(2.2)); }
vec3 to_srgb(vec3 c) { return pow(c, vec3(1.0 / 2.2)); }

// Returns rgb (linear) and coverage for one ray.
vec4 trace(vec3 ro, vec3 rd) {
	// start at the bounding sphere
	float b = dot(ro, rd);
	float c = dot(ro, ro) - bound * bound;
	float disc = b * b - c;
	if (disc < 0.0) {
		return vec4(0.0);
	}
	float t = max(-b - sqrt(disc), 0.0);
	float tmax = -b + sqrt(disc);
	vec4 m;
	bool hit = false;
	float edge = 1e5;   // closest miss (for the outline)
	for (int i = 0; i < 160; i++) {
		vec3 p = ro + rd * t;
		float d = scene(p, m);
		edge = min(edge, d / t);
		if (d < 0.0002 * t) {
			hit = true;
			break;
		}
		t += d * 0.9;
		if (t > tmax) {
			break;
		}
	}
	if (!hit) {
		return vec4(0.0);
	}
	vec3 p = ro + rd * t;
	vec3 n = calc_normal(p);
	vec3 base = to_lin(m.rgb);
	float gloss = m.a;
	vec3 l = normalize(key_dir);
	float ao = calc_ao(p, n);
	float sh = soft_shadow(p + n * 0.012, l);
	float wrap = clamp((dot(n, l) + 0.4) / 1.4, 0.0, 1.0);
	vec3 key = vec3(1.0, 0.95, 0.86) * 1.55 * wrap * mix(0.35, 1.0, sh);
	float sky = 0.5 + 0.5 * n.y;
	vec3 amb = mix(vec3(0.42, 0.33, 0.30), vec3(0.62, 0.72, 0.92), sky) * 0.62 * ao;
	vec3 v = -rd;
	float fres = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
	vec3 h = normalize(l + v);
	float sp = pow(clamp(dot(n, h), 0.0, 1.0), mix(18.0, 110.0, gloss)) * (0.25 + 1.5 * gloss) * sh;
	// a second, softer light from the front-right keeps the shadow side readable
	vec3 l2 = normalize(vec3(0.8, 0.2, 0.7));
	float fill = clamp(dot(n, l2), 0.0, 1.0) * 0.28;
	vec3 lin = base * (key + amb + vec3(0.9, 0.95, 1.0) * fill * ao);
	lin += vec3(1.0, 0.97, 0.92) * fres * (0.18 + 0.3 * gloss) * ao;
	lin += vec3(1.0, 0.98, 0.94) * sp;
	lin *= exposure;
	lin = lin / (1.0 + lin * 0.18);   // soft shoulder
	if (debug == 1) { lin = to_lin(n * 0.5 + 0.5); }
	if (debug == 2) { lin = base; }
	if (debug == 3) { lin = vec3(ao); }
	if (debug == 4) { lin = vec3(sh); }
	return vec4(lin, 1.0);
}

void fragment() {
	vec3 fw = normalize(cam_target - cam_pos);
	vec3 right = normalize(cross(fw, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(right, fw);
	vec3 acc = vec3(0.0);
	float cov = 0.0;
	for (int sy = 0; sy < 2; sy++) {
		for (int sx = 0; sx < 2; sx++) {
			vec2 off = (vec2(float(sx), float(sy)) - 0.5) * 0.5 * SCREEN_PIXEL_SIZE;
			vec2 uv = (UV + off) * 2.0 - 1.0;
			uv.y = -uv.y;
			vec3 rd = normalize(fw + (uv.x * right + uv.y * up) * fov);
			vec4 s = trace(cam_pos, rd);
			acc += s.rgb * s.a;
			cov += s.a;
		}
	}
	if (cov <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = vec4(to_srgb(acc / cov), cov * 0.25);
	}
}
