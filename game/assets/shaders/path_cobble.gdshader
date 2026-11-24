shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// Gerçek Davutpaşa yaya yolları: yol yönüne hizalı (UV.x * v_width, UV.y) kilit/küp taş döşeme,
// paralel kırmızı tuğla kenar şeridi ve Ortabahçe pembe-kiremit beton plakaları.
uniform vec4 cobble_color : source_color = vec4(0.71, 0.70, 0.68, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.49, 0.48, 0.47, 1.0);
uniform vec4 brick_color : source_color = vec4(0.58, 0.28, 0.21, 1.0);
uniform vec4 brick_mortar_color : source_color = vec4(0.46, 0.44, 0.42, 1.0);
uniform vec4 center_band_color : source_color = vec4(0.44, 0.45, 0.47, 1.0);

uniform float cobble_size = 0.22;
uniform float road_width = 2.2;
varying float v_width;
varying float v_cap;
uniform float edge_margin = 0.30;
// 0: gri parke + paralel tuğla kenar (dış yollar), 1: pembe-kiremit beton plaka (Ortabahçe)
uniform int pattern = 0;
uniform vec4 pink_color : source_color = vec4(0.66, 0.47, 0.43, 1.0);
uniform vec4 pink_border_color : source_color = vec4(0.74, 0.72, 0.69, 1.0);

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_width = UV2.x > 0.0 ? UV2.x : road_width;
	v_cap = UV2.y;
}

vec3 cobble(vec2 p) {
	vec2 uv_c = p / cobble_size;
	vec2 fw = fwidth(uv_c);
	float aa = max(fw.x, fw.y);
	float c_row = floor(uv_c.y);
	float px = uv_c.x + mod(c_row, 2.0) * 0.5;
	vec2 cell = vec2(floor(px), c_row);
	vec2 c_f = vec2(fract(px), fract(uv_c.y));
	vec2 c_d = min(c_f, 1.0 - c_f);
	float c_mortar = smoothstep(0.035, 0.08 + aa * 0.6, min(c_d.x, c_d.y));
	vec3 c_stone = cobble_color.rgb * mix(0.91, 1.08, hash(cell));
	vec3 detailed = mix(mortar_color.rgb, c_stone, c_mortar);
	// Uzak/yatay bakış açısında moiré halkalarını yumuşat (analitik AA filtresi)
	vec3 avg_col = mix(mortar_color.rgb, cobble_color.rgb, 0.80);
	return mix(avg_col, detailed, 1.0 - smoothstep(0.24, 0.62, aa));
}

vec3 brick(vec2 p) {
	// Yol yönüne tam paralel bordür tuğlaları (0.14 x 0.26 m) + analitik AA
	vec2 uv_b = vec2(p.x / 0.26, p.y / 0.14);
	vec2 fw = fwidth(uv_b);
	float aa = max(fw.x, fw.y);
	float b_row = floor(uv_b.y);
	float bx = uv_b.x + mod(b_row, 2.0) * 0.5;
	vec2 cell = vec2(floor(bx), b_row);
	vec2 b_f = vec2(fract(bx), fract(uv_b.y));
	vec2 b_d = min(b_f, 1.0 - b_f);
	float b_mortar = smoothstep(0.04, 0.09 + aa * 0.6, min(b_d.x, b_d.y));
	vec3 b_stone = brick_color.rgb * mix(0.89, 1.09, hash(cell));
	vec3 detailed = mix(brick_mortar_color.rgb, b_stone, b_mortar);
	vec3 avg_col = mix(brick_mortar_color.rgb, brick_color.rgb, 0.78);
	return mix(avg_col, detailed, 1.0 - smoothstep(0.24, 0.62, aa));
}

void fragment() {
	// Yol eksenine hizalı metrik koordinat (testere dişi kesilme olmaz)
	vec2 path_uv = vec2(UV.x * v_width, UV.y);
	float dist_to_edge = min(UV.x, 1.0 - UV.x) * v_width;
	float edge_ao = v_cap > 0.5 ? 1.0 : (0.88 + 0.12 * smoothstep(0.0, 0.12, dist_to_edge));

	if (pattern == 1) {
		// Ortabahçe: yol boyunca hizalı pembe-kiremit beton plakalar + ince taş kenar bordürü
		float border_m = v_cap > 0.5 ? 0.0 : (1.0 - smoothstep(0.11, 0.15, dist_to_edge));
		vec2 sp = path_uv / vec2(max(v_width * 0.5, 0.9), 1.45);
		vec2 sf = fract(sp);
		float joint = min(min(sf.x, 1.0 - sf.x), min(sf.y, 1.0 - sf.y));
		float wear = (hash(floor(sp)) - 0.5) * 0.10 + (hash(floor(path_uv * 2.2)) - 0.5) * 0.04;
		vec3 slab = pink_color.rgb * (0.98 + wear);
		vec3 col = mix(slab * 0.80, slab, smoothstep(0.0, 0.025, joint));
		// Kenar bordür taşı
		float b_joint = smoothstep(0.0, 0.05, min(fract(UV.y / 0.72), 1.0 - fract(UV.y / 0.72)));
		vec3 bcol = pink_border_color.rgb * mix(0.76, 1.0, b_joint);
		ALBEDO = mix(col, bcol, border_m) * edge_ao;
	} else if (v_cap > 0.5) {
		ALBEDO = cobble(path_uv);
	} else {
		float edge_blend = smoothstep(edge_margin - 0.02, edge_margin + 0.02, dist_to_edge);
		vec3 col;
		if (edge_blend <= 0.0) {
			col = brick(path_uv);
		} else if (edge_blend >= 1.0) {
			col = cobble(path_uv);
		} else {
			col = mix(brick(path_uv), cobble(path_uv), edge_blend);
		}
		// Geniş yaya bulvarlarında (pedestrian, >=3.4m) orta dekoratif koyu şerit
		if (v_width >= 3.4) {
			float mid_dist = abs(UV.x - 0.5) * v_width;
			float band = 1.0 - smoothstep(0.24, 0.28, mid_dist);
			col = mix(col, center_band_color.rgb * (0.94 + 0.10 * hash(floor(path_uv * 3.5))), band * 0.75);
		}
		ALBEDO = col * edge_ao;
	}
	ROUGHNESS = 0.89;
	METALLIC = 0.0;
}
