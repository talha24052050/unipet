shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 wall_color : source_color = vec4(0.91, 0.93, 0.94, 1.0);
uniform vec4 window_color : source_color = vec4(0.18, 0.24, 0.32, 1.0);
uniform vec4 frame_color : source_color = vec4(0.78, 0.82, 0.85, 1.0);
uniform vec4 roof_color : source_color = vec4(0.68, 0.71, 0.74, 1.0);
uniform int style : hint_range(0, 4) = 0;
// Kışla dış cephesi (Street View 2025): sıvasız kaba taş örgü + pencere kemerleri tuğla. Avlu tarafı krem sıva kalır.
// outer_stone açıkken, normali avlu merkezinden DIŞARI bakan duvarlar taş çizilir.
uniform bool outer_stone = false;
uniform vec2 courtyard_center = vec2(0.0);
uniform vec4 rubble_color : source_color = vec4(0.60, 0.56, 0.49, 1.0);
uniform vec4 brick_arch_color : source_color = vec4(0.62, 0.30, 0.22, 1.0);
// Tarihi binalar: pilastır (dikey taş şerit) ve kaide rengi (gerçek Kışla cephesi: krem duvar, gri-bej taş pilastırlar).
uniform vec4 stone_color : source_color = vec4(0.80, 0.76, 0.68, 1.0);
const float PILASTER_SPACING = 9.0;
const float PILASTER_WIDTH = 0.9;
const float PLINTH_HEIGHT = 0.9;

varying vec3 world_pos;
varying vec3 world_normal;
varying float local_y;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

const float FLOOR_HEIGHT = 3.5;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	local_y = VERTEX.y;
}

void fragment() {
	if (world_normal.y > 0.5) {
		// Çatı veya yukarı bakan yatay yüzeyler: pencere yok, düz renk
		ALBEDO = roof_color.rgb;
		ROUGHNESS = 0.9;
		METALLIC = 0.0;
	} else if (world_normal.y < -0.5) {
		// Aşağı bakan yüzeyler
		ALBEDO = wall_color.rgb;
		ROUGHNESS = 0.9;
		METALLIC = 0.0;
	} else {
		// Dikey duvar yüzeyleri: kat yüksekliği 3.5m (arazi kotundan bağımsız yerel yükseklik)
		float floor_y = local_y - FLOOR_HEIGHT * floor(local_y / FLOOR_HEIGHT);

		// Duvar teğet vektörü boyunca yatay metrik konum (u)
		vec2 wall_dir = normalize(vec2(-world_normal.z, world_normal.x));
		float wall_u = world_pos.x * wall_dir.x + world_pos.z * wall_dir.y;

		vec3 col = wall_color.rgb;
		float roughness = 0.85;
		float metallic = 0.0;

		// Zemin/kat süpürgeliği: her katta alttan 0.3m (arazi kotu negatif olan doğu binalarında da pencereler çalışır)
		if (floor_y >= 0.3) {
			if (style == 0) {
				// 0: Modern kompozit panel cephe (Alucobond derz ızgarası + yatay cam pencere şeridi)
				float p_u = fract(wall_u / 1.8);
				float p_y = fract(floor_y / 1.15);
				float panel_tone = 0.97 + 0.04 * hash12(vec2(floor(wall_u / 1.8), floor(local_y / 1.15)));
				col = wall_color.rgb * panel_tone;
				if (p_u < 0.025 || p_y < 0.025) {
					col *= 0.88;  // ince alüminyum panel derzi
				}
				if (floor_y >= 1.05 && floor_y <= 2.48) {
					float u_grid = mod(wall_u, 1.8);
					if (floor_y <= 1.14 || floor_y >= 2.39 || u_grid <= 0.07 || u_grid >= 1.73 || abs(u_grid - 0.9) < 0.03) {
						col = frame_color.rgb;
						roughness = 0.55;
					} else {
						float sky_grad = clamp((floor_y - 1.14) / 1.25, 0.0, 1.0);
						col = mix(window_color.rgb * 0.82, window_color.rgb * 1.35 + vec3(0.05, 0.08, 0.07), sky_grad);
						roughness = 0.18;
						metallic = 0.25;
					}
				}
			} else if (style == 1) {
				// 1: Yurt / lojman pencere ızgarası
				float u_mod = mod(wall_u, 2.4);
				if (floor_y >= 1.0 && floor_y <= 2.4 && u_mod >= 0.6 && u_mod <= 1.8) {
					if (floor_y <= 1.12 || floor_y >= 2.28 || u_mod <= 0.72 || u_mod >= 1.68) {
						col = frame_color.rgb;
					} else {
						col = window_color.rgb;
						roughness = 0.25;
						metallic = 0.2;
					}
				}
			} else if (style == 2) {
				// 2: Tarihi Taşbina (Kışla) cephesi — YTÜ resmi fotoğraf referansı:
				// İç avlu: eskitilmiş gri-bej kireçtaşı sıva, koyu kat silmesi, yağmur oluğu,
				// taş kemer söveli ve beyaz çok bölmeli (mullion) kemerli pencereler.
				// Dış cephe: organik çok tonlu kaba moloz taş örgü + tuğla kemer + beyaz bölmeli cam.
				float u_mod = mod(wall_u, 3.0);
				bool outer = outer_stone && dot(world_normal.xz, world_pos.xz - courtyard_center) > 0.0;
				bool on_band = floor_y > FLOOR_HEIGHT - 0.26;
				bool under_band = floor_y > FLOOR_HEIGHT - 0.38 && !on_band;
				if (outer) {
					// Kaba moloz taş örgü: düzensiz bloklar + koyu gölgeli derz
					float row = floor(local_y / 0.38);
					float row_w = 0.55 + 0.45 * hash12(vec2(row, 3.1));
					float bu = wall_u / row_w + hash12(vec2(row, 7.3)) * 3.0;
					vec2 cell = vec2(floor(bu), row);
					float fu = fract(bu);
					float fy = fract(local_y / 0.38);
					float tone = 0.78 + 0.34 * hash12(cell);
					float warm = hash12(cell + vec2(11.0, 5.0));
					vec3 stone_tint = mix(rubble_color.rgb, rubble_color.rgb * vec3(1.06, 0.98, 0.88), warm);
					col = stone_tint * tone;
					if (fu < 0.06 || fy < 0.09) {
						col = rubble_color.rgb * 0.62;  // koyu harç/gölge derzi
					}
					roughness = 0.98;
				} else {
					// İç avlu: eskitilmiş kireçtaşı sıva dokusu (hafif ton çeşitliliği)
					float grain = 0.96 + 0.08 * hash12(vec2(floor(wall_u * 1.4), floor(local_y * 1.4)));
					float blotch = 0.97 + 0.06 * hash12(vec2(floor(wall_u * 0.35), floor(local_y * 0.4)));
					col = wall_color.rgb * grain * blotch;
					roughness = 0.93;
					if (local_y >= 0.0 && local_y < PLINTH_HEIGHT) {
						col = wall_color.rgb * 0.80;  // taş subasman
					} else if (on_band) {
						col = wall_color.rgb * 0.58;  // koyu taş kat silmesi (tasbina_stone.jpg)
						roughness = 0.96;
					} else if (under_band) {
						col = col * 0.86;  // silme altı gölge
					}
					// Dikey yağmur oluğu borusu (her 15 m'de bir)
					if (mod(wall_u + 1.5, 15.0) < 0.13) {
						col = vec3(0.64, 0.66, 0.68);
						roughness = 0.55;
						metallic = 0.25;
					}
				}
				// Kemerli pencereler: dış taş/tuğla kemer sövesi + beyaz çok bölmeli doğrama + cam
				if (u_mod >= 0.78 && u_mod <= 2.22 && !on_band) {
					float center_u = 1.5;
					float half_w_outer = 0.70;
					float half_w_inner = 0.56;
					float dx_o = (u_mod - center_u) / half_w_outer;
					float arch_outer = 2.48 + 0.48 * sqrt(max(0.0, 1.0 - dx_o * dx_o));
					if (floor_y >= 0.82 && floor_y <= arch_outer) {
						float dx_i = (u_mod - center_u) / half_w_inner;
						bool in_opening = abs(dx_i) <= 1.0 && floor_y >= 0.94 && floor_y <= (2.46 + 0.40 * sqrt(max(0.0, 1.0 - dx_i * dx_i)));
						if (!in_opening) {
							// Kemer sövesi / denizlik: iç cephede koyu taş söve, dış cephede tuğla kemer
							col = outer ? brick_arch_color.rgb * (0.9 + 0.16 * hash12(vec2(floor(u_mod * 8.0), floor(floor_y * 8.0)))) : wall_color.rgb * 0.68;
							roughness = 0.94;
						} else {
							// Beyaz pencere çerçevesi + çok bölmeli kayıtlar (1 dikey + 2 yatay + kemer yelpazesi)
							float arch_in = 2.46 + 0.40 * sqrt(max(0.0, 1.0 - dx_i * dx_i));
							bool outer_frame = floor_y <= 1.02 || floor_y >= arch_in - 0.06 || abs(u_mod - center_u) >= half_w_inner - 0.06;
							bool mid_vert = abs(u_mod - center_u) < 0.042;
							bool horiz_bars = abs(floor_y - 1.50) < 0.036 || abs(floor_y - 2.02) < 0.036 || abs(floor_y - 2.46) < 0.042;
							bool arch_fan = floor_y > 2.46 && (abs(abs(u_mod - center_u) - (floor_y - 2.46) * 0.95) < 0.032);
							if (outer_frame || mid_vert || horiz_bars || arch_fan) {
								col = frame_color.rgb;
								roughness = 0.65;
							} else {
								float g_grad = clamp((floor_y - 1.0) / 1.8, 0.0, 1.0);
								col = mix(window_color.rgb * 0.78, window_color.rgb * 1.45 + vec3(0.04, 0.06, 0.09), g_grad);
								roughness = 0.22;
								metallic = 0.15;
							}
						}
					}
				}
			}
		}

		if (style == 4 && floor_y >= 0.3) {
			// 4: Dükkân cephesi: 0.4–3.1 m tavana kadar cam, 1.6 m'de bir siyah kayıt, üstte siyah bant
			float u4 = mod(wall_u, 1.6);
			if (floor_y < 3.1) {
				bool mull = u4 < 0.1 || floor_y < 0.45 || floor_y > 3.0;
				col = mull ? frame_color.rgb : window_color.rgb;
				roughness = mull ? 0.6 : 0.15;
				metallic = mull ? 0.3 : 0.2;
			} else {
				col = frame_color.rgb;  // tabela/saçak bandı
			}
		}
		if (style == 3 && floor_y >= 0.3) {
			// 3: Kırmızı tuğla + kat döşemesi hizasında beyaz beton bant + beyaz çerçeveli pencereler (Yemekhane)
			float brow = floor(local_y / 0.075);
			float bu2 = wall_u / 0.22 + mod(brow, 2.0) * 0.5;
			float tone2 = 0.9 + 0.16 * hash12(vec2(floor(bu2), brow));
			col = wall_color.rgb * tone2;
			if (fract(local_y / 0.075) < 0.12 || fract(bu2) < 0.05) {
				col = wall_color.rgb * 1.25;
			}
			roughness = 0.95;
			float u3 = mod(wall_u, 3.4);
			if (floor_y < 0.45) {
				col = frame_color.rgb;  // beyaz döşeme bandı
			} else if (floor_y >= 1.0 && floor_y <= 2.7 && u3 >= 0.6 && u3 <= 2.8) {
				bool fr = floor_y <= 1.1 || floor_y >= 2.6 || u3 <= 0.7 || u3 >= 2.7 || abs(u3 - 1.7) < 0.04;
				col = fr ? frame_color.rgb : window_color.rgb;
				roughness = fr ? 0.8 : 0.25;
			}
		}
		ALBEDO = col;
		ROUGHNESS = roughness;
		METALLIC = metallic;
	}
}
