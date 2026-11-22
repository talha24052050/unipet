shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 wall_color : source_color = vec4(0.91, 0.93, 0.94, 1.0);
uniform vec4 window_color : source_color = vec4(0.18, 0.24, 0.32, 1.0);
uniform vec4 frame_color : source_color = vec4(0.78, 0.82, 0.85, 1.0);
uniform vec4 roof_color : source_color = vec4(0.68, 0.71, 0.74, 1.0);
uniform int style : hint_range(0, 2) = 0;

varying vec3 world_pos;
varying vec3 world_normal;

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
				// 2: Tarihi binalar: kemerli hissi için dikdörtgen + kemer tepe + çerçeve
				float u_mod = mod(wall_u, 3.0);
				if (u_mod >= 0.9 && u_mod <= 2.1) {
					float center_u = 1.5;
					float half_w = 0.6;
					float dx = (u_mod - center_u) / half_w;
					float arch_top = 2.3 + 0.35 * sqrt(max(0.0, 1.0 - dx * dx));

					if (floor_y >= 0.9 && floor_y <= arch_top) {
						float inner_arch = 2.2 + 0.3 * sqrt(max(0.0, 1.0 - dx * dx));
						if (floor_y <= 1.0 || floor_y >= inner_arch || u_mod <= 1.0 || u_mod >= 2.0) {
							col = frame_color.rgb;
						} else {
							col = window_color.rgb;
							roughness = 0.3;
							metallic = 0.1;
						}
					}
				}
			}
		}

		ALBEDO = col;
		ROUGHNESS = roughness;
		METALLIC = metallic;
	}
}
