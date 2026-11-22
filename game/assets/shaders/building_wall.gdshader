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

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

const float FLOOR_HEIGHT = 3.5;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
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
		// Dikey duvar yüzeyleri: kat yüksekliği 3.5m
		float floor_y = world_pos.y - FLOOR_HEIGHT * floor(world_pos.y / FLOOR_HEIGHT);

		// Duvar teğet vektörü boyunca yatay metrik konum (u)
		vec2 wall_dir = normalize(vec2(-world_normal.z, world_normal.x));
		float wall_u = world_pos.x * wall_dir.x + world_pos.z * wall_dir.y;

		vec3 col = wall_color.rgb;
		float roughness = 0.85;
		float metallic = 0.0;

		// Zemin seviyesi (en alt 0.3m süpürgelik)
		if (world_pos.y >= 0.3) {
			if (style == 0) {
				// 0: Modern yatay pencere şeridi
				if (floor_y >= 1.05 && floor_y <= 2.45) {
					float u_grid = mod(wall_u, 2.0);
					if (floor_y <= 1.15 || floor_y >= 2.35 || u_grid <= 0.08 || u_grid >= 1.92) {
						col = frame_color.rgb;
					} else {
						col = window_color.rgb;
						roughness = 0.25;
						metallic = 0.2;
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
				// 2: Tarihi binalar: taş kaide, pilastırlar, kat silmesi, kemerli pencereler
				float pil = mod(wall_u, PILASTER_SPACING);
				bool on_pilaster = pil < PILASTER_WIDTH;
				bool on_band = floor_y > FLOOR_HEIGHT - 0.22;  // kat silmesi
				float u_mod = mod(wall_u, 3.0);
				bool outer = outer_stone && dot(world_normal.xz, world_pos.xz - courtyard_center) > 0.0;
				if (outer) {
					// Kaba taş örgü: 0.45 m sıralar, sıra başına kaydırılmış düzensiz blok uzunlukları
					float row = floor(world_pos.y / 0.45);
					float bu = wall_u / (0.7 + 0.5 * hash12(vec2(row, 3.0))) + hash12(vec2(row, 7.0));
					vec2 cell = vec2(floor(bu), row);
					float fu = fract(bu);
					float fy = fract(world_pos.y / 0.45);
					float tone = 0.86 + 0.24 * hash12(cell);
					col = rubble_color.rgb * tone;
					if (fu < 0.05 || fy < 0.08) {
						col = rubble_color.rgb * 1.18;  // açık renk derz
					}
					roughness = 1.0;
				}
				if (!outer && (world_pos.y < PLINTH_HEIGHT || on_pilaster || on_band)) {
					col = stone_color.rgb;
					roughness = 0.95;
				} else
				if (u_mod >= 0.9 && u_mod <= 2.1) {
					float center_u = 1.5;
					float half_w = 0.6;
					float dx = (u_mod - center_u) / half_w;
					float arch_top = 2.55 + 0.4 * sqrt(max(0.0, 1.0 - dx * dx));

					if (floor_y >= 0.9 && floor_y <= arch_top) {
						float inner_arch = 2.45 + 0.35 * sqrt(max(0.0, 1.0 - dx * dx));
						if (floor_y <= 1.0 || floor_y >= inner_arch || u_mod <= 1.0 || u_mod >= 2.0) {
							col = outer ? brick_arch_color.rgb : frame_color.rgb;
						} else {
							col = window_color.rgb;
							roughness = 0.3;
							metallic = 0.1;
						}
					}
				}
			}
		}

		if (style == 4 && world_pos.y >= 0.3) {
			// 4: Dükkân cephesi: 0.4–3.1 m tavana kadar cam, 1.6 m'de bir siyah kayıt, üstte siyah bant
			float u4 = mod(wall_u, 1.6);
			if (world_pos.y < 3.1) {
				bool mull = u4 < 0.1 || world_pos.y < 0.45 || world_pos.y > 3.0;
				col = mull ? frame_color.rgb : window_color.rgb;
				roughness = mull ? 0.6 : 0.15;
				metallic = mull ? 0.3 : 0.2;
			} else if (world_pos.y < 3.5) {
				col = frame_color.rgb;  // tabela/saçak bandı
			}
		}
		if (style == 3 && world_pos.y >= 0.3) {
			// 3: Kırmızı tuğla + kat döşemesi hizasında beyaz beton bant + beyaz çerçeveli pencereler (Yemekhane)
			float brow = floor(world_pos.y / 0.075);
			float bu2 = wall_u / 0.22 + mod(brow, 2.0) * 0.5;
			float tone2 = 0.9 + 0.16 * hash12(vec2(floor(bu2), brow));
			col = wall_color.rgb * tone2;
			if (fract(world_pos.y / 0.075) < 0.12 || fract(bu2) < 0.05) {
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
