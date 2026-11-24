shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// Kampüs araç yolları (service): pürüzsüz ince asfalt agregası, şerit tekerlek izleri,
// gerçek metre (UV.y) tabanlı kesikli orta çizgi, banket çizgisi ve segmentli beton bordür taşları.
uniform vec4 asphalt_color : source_color = vec4(0.24, 0.26, 0.29, 1.0);
uniform vec4 curb_color : source_color = vec4(0.62, 0.61, 0.58, 1.0);
uniform vec4 curb_yellow : source_color = vec4(0.88, 0.72, 0.16, 1.0);
uniform vec4 curb_white : source_color = vec4(0.90, 0.90, 0.88, 1.0);
uniform vec4 bike_blue : source_color = vec4(0.22, 0.56, 0.86, 1.0);
uniform vec4 line_color : source_color = vec4(0.92, 0.91, 0.88, 1.0);
uniform float curb_width = 0.26;
uniform bool draw_center_line = true;
uniform bool draw_curbs = true;
// Çift yönlü bitişik ana kampüs bulvarının tek yarısı (UV.x=0 iç orta çift beyaz çizgi, UV.x=1 dış sarı-beyaz bordür + mavi bisiklet şeridi)
uniform bool is_boulevard_half = false;
uniform bool yellow_white_curb = false;

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
		if (is_boulevard_half) {
			// Bitişik ana kampüs bulvarı yarısı (link3.jpg & link4.jpg):
			// Sol kenar (UV.x = 0): karşı şeritle bitişen eksen -> bordürsüz asfalt + çift düz beyaz orta çizginin yarısı
			// Sağ kenar (UV.x = 1): dış kenar -> sarı-beyaz boyalı bordür + mavi bisiklet şeridi + çift beyaz ayırıcı
			float d_in = UV.x * v_width;
			float d_out = (1.0 - UV.x) * v_width;

			// Araç şeridinde hafif tekerlek izi
			float car_u = (d_in - 1.6) / max(v_width - 3.6, 1.5);
			float tr = exp(-pow((car_u - 0.5) * 3.2, 2.0));
			col *= (1.0 - tr * 0.07);
			rough = mix(rough, 0.85, tr * 0.5);

			// İç kenar (UV.x=0): düz beyaz şerit (karşı yarıyla birleşip çift düz beyaz orta çizgi oluşturur!)
			float mid_line = 1.0 - smoothstep(0.045, 0.075, abs(d_in - 0.16));
			col = mix(col, line_color.rgb, mid_line * 0.88);
			rough = mix(rough, 0.80, mid_line * 0.4);

			// Dış kenar (UV.x=1): mavi boyalı bisiklet şeridi (0.28..1.38 m) + çift beyaz ayırıcı (1.42..1.86 m)
			if (v_width >= 5.2) {
				float bike_m = smoothstep(curb_width + 0.01, curb_width + 0.05, d_out)
					* (1.0 - smoothstep(curb_width + 1.08, curb_width + 1.14, d_out));
				vec3 bcol = bike_blue.rgb * (0.94 + macro * 0.10 + micro * 0.07);
				col = mix(col, bcol, bike_m * 0.90);
				rough = mix(rough, 0.87, bike_m * 0.6);

				// Bisiklet şeridi kenarındaki çift düz beyaz çizgi (fotoğraftaki gibi)
				float sep1 = 1.0 - smoothstep(0.04, 0.068, abs(d_out - (curb_width + 1.18)));
				float sep2 = 1.0 - smoothstep(0.04, 0.068, abs(d_out - (curb_width + 1.56)));
				float sep_m = max(sep1, sep2);
				col = mix(col, line_color.rgb, sep_m * 0.86);
				rough = mix(rough, 0.80, sep_m * 0.4);
			}

			// Dış sarı-beyaz boyalı kampüs bordür taşları (her 0.65 m'de bir sarı / beyaz dönüşümlü)
			float gutter = 1.0 - smoothstep(curb_width, curb_width + 0.14, d_out);
			col *= (1.0 - gutter * 0.12);
			float curb_mask = 1.0 - smoothstep(curb_width - 0.03, curb_width + 0.02, d_out);
			if (curb_mask > 0.01) {
				float stone_id = floor(UV.y / 0.65);
				float stone_f = fract(UV.y / 0.65);
				float joint = smoothstep(0.0, 0.045, min(stone_f, 1.0 - stone_f));
				float is_yel = mod(stone_id, 2.0);
				vec3 base_c = mix(curb_white.rgb, curb_yellow.rgb, is_yel);
				float bevel = smoothstep(0.0, 0.05, d_out) * (0.93 + 0.10 * hash(vec2(stone_id, 5.0)));
				col = mix(col, base_c * bevel * mix(0.68, 1.0, joint), curb_mask);
				rough = mix(rough, 0.86, curb_mask);
			}
		} else {
			// İki şerit ortasında doğal tekerlek izi koyulaşması ve hafif parlama
			float track_l = exp(-pow((UV.x - 0.28) * 11.0, 2.0));
			float track_r = exp(-pow((UV.x - 0.72) * 11.0, 2.0));
			float track = max(track_l, track_r);
			col *= (1.0 - track * 0.09);
			rough = mix(rough, 0.83, track * 0.7);

			float dist_edge = min(UV.x, 1.0 - UV.x) * v_width;

			if (draw_curbs) {
				// Bordür dibinde ince yağmur oluğu gölgesi + kenar banket çizgisi
				float gutter = 1.0 - smoothstep(curb_width, curb_width + 0.18, dist_edge);
				col *= (1.0 - gutter * 0.14);
				if (v_width >= 3.8) {
					float shoulder = 1.0 - smoothstep(0.04, 0.07, abs(dist_edge - (curb_width + 0.18)));
					col = mix(col, line_color.rgb, shoulder * 0.42);
				}

				// Segmentli beton (veya ana yollarda sarı-beyaz) bordür taşları
				float curb_mask = 1.0 - smoothstep(curb_width - 0.03, curb_width + 0.02, dist_edge);
				if (curb_mask > 0.01) {
					float step_m = yellow_white_curb ? 0.65 : 0.85;
					float stone_id = floor(UV.y / step_m);
					float stone_f = fract(UV.y / step_m);
					float joint = smoothstep(0.0, 0.04, min(stone_f, 1.0 - stone_f));
					vec3 base_c = yellow_white_curb ? mix(curb_white.rgb, curb_yellow.rgb, mod(stone_id, 2.0)) : curb_color.rgb;
					float bevel = smoothstep(0.0, 0.06, dist_edge) * (0.94 + 0.12 * hash(vec2(stone_id, 5.0)));
					vec3 curb_col = base_c * bevel * mix(0.68, 1.0, joint);
					col = mix(col, curb_col, curb_mask);
					rough = mix(rough, 0.88, curb_mask);
				}
			}

			// Gerçek yol uzunluğu (UV.y) tabanlı kesikli orta çizgi (sadece çift yönlü ana yollarda)
			if (draw_center_line && v_width >= 3.4) {
				float center_dist = abs(UV.x - 0.5) * v_width;
				float dash_pos = fract(UV.y / 5.0);
				float dash = (1.0 - smoothstep(0.42, 0.46, dash_pos)) * smoothstep(0.0, 0.03, dash_pos);
				float line_m = dash * (1.0 - smoothstep(0.055, 0.085, center_dist));
				col = mix(col, line_color.rgb, line_m * 0.82);
				rough = mix(rough, 0.80, line_m * 0.5);
			}
		}
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.0;
}
