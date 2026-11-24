shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// Kampüs araç yolları (service): pürüzsüz ince asfalt agregası, şerit tekerlek izleri,
// gerçek metre (UV.y) tabanlı kesikli orta çizgi, banket çizgisi ve segmentli beton bordür taşları.
uniform vec4 asphalt_color : source_color = vec4(0.22, 0.24, 0.27, 1.0);
uniform vec4 curb_color : source_color = vec4(0.62, 0.61, 0.58, 1.0);
uniform vec4 line_color : source_color = vec4(0.90, 0.88, 0.82, 1.0);
uniform float curb_width = 0.26;

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
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_width = UV2.x > 0.0 ? UV2.x : 4.6;
	v_cap = UV2.y;
}

void fragment() {
	// Yumuşak 2 katmanlı asfalt agregası + makro aşınma (bloklu kare piksel yok)
	float macro = value_noise(world_pos.xz * 0.28) - 0.5;
	float micro = value_noise(world_pos.xz * 3.8) - 0.5;
	vec3 col = asphalt_color.rgb * (1.0 + macro * 0.14 + micro * 0.08);
	float rough = 0.93;

	// Kavşak uç kapaklarında (v_cap > 0.5) bordür ve şerit çizgisi çizme — kesintisiz asfalt birleşimi
	if (v_cap < 0.5) {
		// İki şerit ortasında doğal tekerlek izi koyulaşması ve hafif parlama
		float track_l = exp(-pow((UV.x - 0.28) * 11.0, 2.0));
		float track_r = exp(-pow((UV.x - 0.72) * 11.0, 2.0));
		float track = max(track_l, track_r);
		col *= (1.0 - track * 0.09);
		rough = mix(rough, 0.83, track * 0.7);

		float dist_edge = min(UV.x, 1.0 - UV.x) * v_width;

		// Bordür dibinde ince yağmur oluğu gölgesi + kenar banket çizgisi
		float gutter = 1.0 - smoothstep(curb_width, curb_width + 0.18, dist_edge);
		col *= (1.0 - gutter * 0.14);
		if (v_width >= 3.8) {
			float shoulder = 1.0 - smoothstep(0.04, 0.07, abs(dist_edge - (curb_width + 0.18)));
			col = mix(col, line_color.rgb, shoulder * 0.36);
		}

		// Segmentli beton bordür taşları (her 0.85 m'de bir koyu derz + hafif taş tonu farkı)
		float curb_mask = 1.0 - smoothstep(curb_width - 0.03, curb_width + 0.02, dist_edge);
		if (curb_mask > 0.01) {
			float stone_id = floor(UV.y / 0.85);
			float stone_f = fract(UV.y / 0.85);
			float joint = smoothstep(0.0, 0.04, min(stone_f, 1.0 - stone_f));
			float bevel = smoothstep(0.0, 0.06, dist_edge) * (0.94 + 0.12 * hash(vec2(stone_id, 5.0)));
			vec3 curb_col = curb_color.rgb * bevel * mix(0.68, 1.0, joint);
			col = mix(col, curb_col, curb_mask);
			rough = mix(rough, 0.88, curb_mask);
		}

		// Gerçek yol uzunluğu (UV.y) tabanlı kesikli orta çizgi (2.2 m çizgi, 2.8 m boşluk — her açıda düzgün)
		if (v_width >= 3.4) {
			float center_dist = abs(UV.x - 0.5) * v_width;
			float dash_pos = fract(UV.y / 5.0);
			float dash = (1.0 - smoothstep(0.42, 0.46, dash_pos)) * smoothstep(0.0, 0.03, dash_pos);
			float line_m = dash * (1.0 - smoothstep(0.055, 0.085, center_dist));
			col = mix(col, line_color.rgb, line_m * 0.78);
			rough = mix(rough, 0.80, line_m * 0.5);
		}
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.0;
}
