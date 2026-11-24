shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 wall_color : source_color = vec4(0.91, 0.93, 0.94, 1.0);
uniform vec4 window_color : source_color = vec4(0.18, 0.24, 0.32, 1.0);
uniform vec4 frame_color : source_color = vec4(0.78, 0.82, 0.85, 1.0);
uniform vec4 roof_color : source_color = vec4(0.68, 0.71, 0.74, 1.0);
uniform int style : hint_range(0, 6) = 0;
// Kışla dış cephesi (Street View 2025): sıvasız kaba taş örgü + pencere kemerleri tuğla. Avlu tarafı krem sıva kalır.
// outer_stone açıkken, normali avlu merkezinden DIŞARI bakan duvarlar taş çizilir.
uniform bool outer_stone = false;
// Davutpaşa Kışlası Mescidi: neredeyse tamamen masif eskitilmiş kesme kireçtaşı duvar, yalnızca birkaç küçük dikdörtgen pencere.
uniform bool sparse_stone = false;
uniform vec2 courtyard_center = vec2(0.0);
// Yeni Merkez Kütüphanesi (style == 6): L-kanat beyaz çerçeve + dev cam vs. çıkmalı siyah cam küp yerel koordinatları.
uniform vec2 lib_origin = vec2(-74.33, -236.71);
uniform vec2 lib_u = vec2(0.8099, 0.5866);
uniform vec2 lib_v = vec2(-0.5866, 0.8099);
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
	// Greybox extrude mesh'leri UV.x = 2.0 ve UV.y = bina tabanina gore yerel yukseklik tasir
	// (batched mesh'lerde VERTEX.y dunya kotuna kaydigi icin kat hizasi buradan okunur).
	local_y = UV.x > 1.5 ? UV.y : VERTEX.y;
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
				if (sparse_stone) {
					// Mescit: eskitilmiş açık krem-gri masif kesme taş duvar + seyrek küçük dikdörtgen taş söveli pencereler
					float srow = floor(local_y / 0.36);
					float sbu = wall_u / 0.62 + mod(srow, 2.0) * 0.5;
					vec2 scell = vec2(floor(sbu), srow);
					float sfu = fract(sbu);
					float sfy = fract(local_y / 0.36);
					float stone_var = 0.92 + 0.14 * hash12(scell);
					float weather = 0.90 + 0.16 * hash12(vec2(floor(wall_u * 0.45), floor(local_y * 0.55)));
					col = wall_color.rgb * stone_var * weather;
					if (sfu < 0.04 || sfy < 0.06) {
						col *= 0.84;  // ince kesme taş derzi
					}
					if (local_y < 0.65) {
						col *= 0.88;  // alt taş kaide
					}
					roughness = 0.96;
					// Yalnızca zemin katta, 5.4 m arayla küçük dikdörtgen pencere (0.86 x 1.35 m)
					float um = mod(wall_u + 1.8, 5.4);
					if (local_y >= 1.35 && local_y <= 2.85 && um >= 2.20 && um <= 3.20) {
						bool in_pane = local_y >= 1.48 && local_y <= 2.72 && um >= 2.32 && um <= 3.08;
						if (!in_pane) {
							col = wall_color.rgb * 0.72;  // taş söve
						} else if (abs(um - 2.70) < 0.03 || abs(local_y - 2.10) < 0.03) {
							col = vec3(0.32, 0.33, 0.34);  // ince demir parmaklık/kayıt
						} else {
							col = window_color.rgb * 0.85;
							roughness = 0.25;
							metallic = 0.12;
						}
					}
				} else {
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
		if (style == 5) {
			// 5: YTÜ Davutpaşa Lojmanları (Yapı Dergisi renk & cephe tasarımı):
			// Büyük ebatlı Sinterflex seramik kaplama derz ızgarası + geniş sürgülü balkon camları +
			// gümüş-gri yatay metal korkuluklar + Fransız balkon pencereleri.
			float p_u5 = fract(wall_u / 1.35);
			float p_y5 = fract(local_y / 0.88);
			float tile_var = 0.965 + 0.06 * hash12(vec2(floor(wall_u / 1.35), floor(local_y / 0.88)));
			col = wall_color.rgb * tile_var;
			if (p_u5 < 0.022 || p_y5 < 0.028) {
				col *= 0.82;  // Sinterflex seramik derzi
			}
			roughness = 0.78;
			float fl_idx = floor(local_y / FLOOR_HEIGHT);
			// Kat silmesi / beton balkon döşeme şeridi
			if (floor_y < 0.26) {
				col = wall_color.rgb * 0.90;
				roughness = 0.88;
			} else {
				// Katlar arası hafif şaşırtmalı 5.4 m modül (geniş salon balkonu + dar oda penceresi)
				float shift_u = mod(fl_idx, 2.0) * 1.15;
				float u5 = mod(wall_u + shift_u, 5.4);
				bool in_wide = (u5 >= 0.45 && u5 <= 3.15) && (floor_y >= 0.36 && floor_y <= 2.80);
				bool in_narrow = (u5 >= 3.85 && u5 <= 4.95) && (floor_y >= 0.72 && floor_y <= 2.80);
				// Alt çıkıntılı açık beton denizlik/balkon tablası
				if ((u5 >= 0.38 && u5 <= 3.22 && floor_y >= 0.26 && floor_y < 0.38) ||
					(u5 >= 3.78 && u5 <= 5.02 && floor_y >= 0.60 && floor_y < 0.74)) {
					col = wall_color.rgb * 1.06;
					roughness = 0.85;
				} else if (in_wide || in_narrow) {
					float u_lo = in_wide ? 0.45 : 3.85;
					float u_hi = in_wide ? 3.15 : 4.95;
					float y_lo = in_wide ? 0.36 : 0.72;
					float y_hi = 2.80;
					bool outer_f = (u5 <= u_lo + 0.09 || u5 >= u_hi - 0.09 || floor_y <= y_lo + 0.08 || floor_y >= y_hi - 0.09);
					bool mull_v = in_wide && (abs(u5 - 1.35) < 0.045 || abs(u5 - 2.25) < 0.045);
					bool mull_h = abs(floor_y - 2.28) < 0.04;
					// Alt kısımda ince açık-gri metal balkon korkuluğu (yatay küpeşte + dikey parmaklık)
					bool in_rail = floor_y >= y_lo + 0.08 && floor_y <= 1.36;
					bool rail_top = abs(floor_y - 1.32) < 0.036;
					bool rail_bars = in_rail && (fract((u5 - u_lo) / 0.22) < 0.15 || abs(floor_y - 0.84) < 0.025);
					if (rail_top || rail_bars) {
						col = vec3(0.54, 0.56, 0.58);  // mat gümüş-gri korkuluk (uzaktan parlamasın)
						roughness = 0.48;
						metallic = 0.35;
					} else if (outer_f || mull_v || mull_h) {
						col = frame_color.rgb;  // koyu antrasit doğrama
						roughness = 0.50;
						metallic = 0.25;
					} else {
						float sky_g = clamp((floor_y - y_lo) / (y_hi - y_lo), 0.0, 1.0);
						col = mix(window_color.rgb * 0.72, window_color.rgb * 1.45 + vec3(0.06, 0.09, 0.11), sky_g);
						roughness = 0.16;
						metallic = 0.32;
					}
				}
			}
		}
		if (style == 6) {
			// 6: YTÜ Yeni Merkez Kütüphanesi (TEB Mimarlık 2024):
			// - Kare özel kullanımlar küpü (u ∈ [24.8, 50.8], v ∈ [34.8, 70.4]): altta beyaz kaide / cam, üstte tamamen siyah cam giydirme
			// - İki kütleyi bağlayan üst cam köprü (u ∈ [18.1, 25.5], v ∈ [55.2, 66.2]): beyaz kiriş + siyah kafesli cam
			// - L-formlu ana kütüphane kanatları: kalın beyaz dikey kolonlar + kat döşemesi + dev siyah kayıtlı şeffaf perde camlar
			vec2 rel = world_pos.xz - lib_origin;
			float lu = dot(rel, lib_u);
			float lv = dot(rel, lib_v);
			bool in_cube = (lu >= 24.8 && lu <= 51.0 && lv >= 34.8 && lv <= 70.6);
			bool in_bridge = (!in_cube) && (lu >= 18.0 && lu <= 25.6 && lv >= 55.0 && lv <= 66.4);
			if (in_cube) {
				if (local_y >= 4.15) {
					// Tamamen siyah reflekte giydirme cam küp (lib_mim_1.jpg & lib_gal_19.jpg)
					float gm_u = mod(wall_u, 1.95);
					float gm_y = mod(local_y - 4.15, 1.50);
					bool is_mull = (gm_u < 0.075 || gm_u > 1.875 || gm_y < 0.065 || gm_y > 1.435 || local_y > 9.95 || local_y < 4.28);
					if (is_mull) {
						col = vec3(0.08, 0.09, 0.11);
						roughness = 0.42;
						metallic = 0.38;
					} else {
						float sky_c = clamp((local_y - 4.2) / 6.0, 0.0, 1.0);
						col = mix(vec3(0.045, 0.065, 0.095), vec3(0.11, 0.17, 0.23), sky_c);
						roughness = 0.12;
						metallic = 0.52;
					}
				} else {
					// Alt kat: dış güney/meydan yüzleri temiz beyaz beton (lib_mim_1.jpg), avlu/geçit yüzleri siyah çerçeveli cam
					bool outer_white = (lv > 68.8 || lu > 49.4);
					if (outer_white) {
						float cu = fract(wall_u / 2.4);
						float cy = fract(local_y / 1.4);
						col = wall_color.rgb * (0.97 + 0.03 * hash12(vec2(floor(wall_u / 2.4), floor(local_y / 1.4))));
						if (cu < 0.02 || cy < 0.02) {
							col *= 0.90;
						}
						roughness = 0.82;
					} else {
						float gm_u = mod(wall_u, 1.65);
						float gm_y = mod(local_y, 1.45);
						bool is_mull = (gm_u < 0.08 || gm_y < 0.07 || local_y < 0.22 || local_y > 3.95);
						col = is_mull ? vec3(0.09, 0.10, 0.12) : vec3(0.07, 0.11, 0.15);
						roughness = is_mull ? 0.48 : 0.15;
						metallic = is_mull ? 0.35 : 0.40;
					}
				}
			} else if (in_bridge) {
				// Üst kat siyah kafes kirişli cam köprü (lib_gal_20.jpg)
				if (local_y < 4.25) {
					col = vec3(0.035, 0.040, 0.048);  // alt açık geçit derin gölge tonu
					roughness = 0.95;
				} else if (local_y < 5.05) {
					col = wall_color.rgb;  // beyaz köprü tabliyesi
					roughness = 0.80;
				} else if (local_y > 9.15) {
					col = vec3(0.10, 0.11, 0.13);
					roughness = 0.48;
				} else {
					float bu = mod(wall_u, 1.6);
					float by = local_y - 5.05;
					bool truss = abs(mod(wall_u + by * 0.85, 2.6) - 1.3) < 0.11 || abs(mod(wall_u - by * 0.85, 2.6) - 1.3) < 0.11;
					bool fr_b = bu < 0.08 || abs(by - 2.05) < 0.06 || truss;
					col = fr_b ? vec3(0.09, 0.10, 0.12) : vec3(0.08, 0.13, 0.18);
					roughness = fr_b ? 0.45 : 0.15;
					metallic = 0.38;
				}
			} else if (lv > 72.8 && lu < 18.6) {
				// Arm B GB kalkan ucu (lib_mim_1.jpg sol uç): masif temiz beyaz duvar + tek dikey siyah cam yarık
				bool in_slit = (lu >= 11.4 && lu <= 15.2 && local_y >= 0.25 && local_y <= 8.95);
				if (in_slit) {
					bool fm = (lu <= 11.55 || lu >= 15.05 || abs(lu - 13.3) < 0.07 || mod(local_y, 1.6) < 0.07);
					col = fm ? vec3(0.08, 0.09, 0.11) : vec3(0.07, 0.11, 0.16);
					roughness = fm ? 0.45 : 0.15;
					metallic = 0.40;
				} else {
					col = wall_color.rgb * 0.99;
					roughness = 0.82;
				}
			} else {
				// L-kanat ana kütüphane cephesi (lib_ytu_1.jpg, lib_gal_11.jpg & lib_gal_18.jpg):
				// - Çökük avlu cephesinde (lu ∈ [18.0, 58.6], lv ∈ [17.7, 32.0]) local_y ∈ [-3.50, -0.22] -1. kat (giriş katı) camları!
				// - local_y ∈ [-0.22, +0.42]: merdiven üst kotu ve üst terasla birebir hizalı beyaz zemin döşeme bandı!
				// - local_y ∈ [+0.42, +9.35]: iki kat yüksekliğinde şeffaf perde camlar + 6.8 m beyaz taşıyıcı kolonlar.
				bool in_sunk_facade = (lu >= 18.0 && lu <= 58.6 && lv >= 17.7 && lv <= 32.0);
				float bay_u = mod(wall_u, 6.8);
				bool white_pier = (bay_u < 0.92);
				bool white_band = (!in_sunk_facade && local_y < 0.18) ||
					(in_sunk_facade && local_y < -3.36) ||
					(local_y >= -0.22 && local_y <= 0.42) ||
					(local_y >= 9.35);
				if (white_pier || white_band) {
					float j_u = fract(wall_u / 1.7);
					float j_y = fract((local_y + 4.0) / 1.3);
					col = wall_color.rgb * 0.99;
					if (j_u < 0.018 || j_y < 0.018) {
						col *= 0.92;  // ince beyaz prekast panel derzi
					}
					roughness = 0.80;
				} else {
					float in_u = bay_u - 0.92;
					float mu = mod(in_u, 1.47);
					float my = local_y < -0.22 ? mod(local_y + 3.36, 1.56) : mod(local_y - 0.42, 1.48);
					bool mull_l = (mu < 0.075 || mu > 1.395 || my < 0.065 || my > 1.415 ||
						in_u < 0.08 || in_u > 5.80 || abs(local_y - 4.78) < 0.08);
					if (mull_l) {
						col = vec3(0.09, 0.10, 0.12);
						roughness = 0.46;
						metallic = 0.35;
					} else {
						// Cam içinde gökyüzü yansıması + -1. kat giriş fuayesi ve üst okuma salonu sıcak ışık tonu
						float sky_l = clamp((local_y + 3.5) / 13.0, 0.0, 1.0);
						vec3 glass_c = mix(vec3(0.07, 0.12, 0.17), vec3(0.16, 0.25, 0.33), sky_l);
						if (local_y < -0.22) {
							// -1. kat çökük avlu giriş fuayesi sıcak aydınlatması (lib_ytu_1.jpg alt kat!)
							glass_c = mix(glass_c, vec3(0.38, 0.32, 0.23), 0.34);
						} else if (local_y > 5.10 && local_y < 5.75) {
							glass_c = mix(glass_c, vec3(0.44, 0.21, 0.14), 0.34);
						} else if (local_y > 1.25 && local_y < 1.80) {
							glass_c = mix(glass_c, vec3(0.34, 0.29, 0.21), 0.24);
						}
						col = glass_c;
						roughness = 0.14;
						metallic = 0.42;
					}
				}
			}
		}
		ALBEDO = col;
		ROUGHNESS = roughness;
		METALLIC = metallic;
	}
}
