shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// YTÜ Davutpaşa kampüs bisiklet yolları (cycleway): mavi boyalı asfalt, ince beyaz kenar çizgisi
// ve kesikli beyaz orta ayırıcı.
uniform vec4 lane_color : source_color = vec4(0.18, 0.42, 0.64, 1.0);
uniform vec4 stripe_color : source_color = vec4(0.92, 0.93, 0.94, 1.0);

varying vec3 world_pos;
varying float v_width;
varying float v_cap;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_width = UV2.x > 0.0 ? UV2.x : 1.6;
	v_cap = UV2.y;
}

void fragment() {
	float macro = value_noise(world_pos.xz * 0.35) - 0.5;
	float micro = value_noise(world_pos.xz * 4.2) - 0.5;
	vec3 col = lane_color.rgb * (1.0 + macro * 0.10 + micro * 0.07);
	float rough = 0.88;

	if (v_cap < 0.5) {
		float dist_edge = min(UV.x, 1.0 - UV.x) * v_width;
		// İnce koyu asfalt dış kenar + 7 cm beyaz sınır şeridi
		float edge_rim = 1.0 - smoothstep(0.03, 0.055, dist_edge);
		col = mix(col, vec3(0.24, 0.26, 0.29), edge_rim * 0.85);
		float side_line = 1.0 - smoothstep(0.028, 0.048, abs(dist_edge - 0.11));
		col = mix(col, stripe_color.rgb, side_line * 0.82);

		// Kesikli beyaz orta çizgi (1.1 m çizgi, 1.4 m boşluk)
		float center_dist = abs(UV.x - 0.5) * v_width;
		float dash_pos = fract(UV.y / 2.5);
		float dash = (1.0 - smoothstep(0.42, 0.46, dash_pos)) * smoothstep(0.0, 0.04, dash_pos);
		float center_line = dash * (1.0 - smoothstep(0.025, 0.045, center_dist));
		col = mix(col, stripe_color.rgb, center_line * 0.65);
		rough = mix(rough, 0.80, max(side_line, center_line) * 0.4);
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.0;
}
