shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// Gerçek Davutpaşa yaya yolları: gri küp taş (#B9B7B2), aralarda koyu derz (#8E8C88),
// kenarlarda 0.35 m kırmızı tuğla şeridi (#A9553F).
uniform vec4 cobble_color : source_color = vec4(0.725, 0.718, 0.698, 1.0);     // #B9B7B2
uniform vec4 mortar_color : source_color = vec4(0.557, 0.549, 0.533, 1.0);     // #8E8C88
uniform vec4 brick_color : source_color = vec4(0.663, 0.333, 0.247, 1.0);      // #A9553F
uniform vec4 brick_mortar_color : source_color = vec4(0.557, 0.549, 0.533, 1.0); // #8E8C88

uniform float cobble_size = 0.25;
uniform float road_width = 2.0;  // UV2.x verilmezse (eski mesh) kullanılır
// Yol genişliği (m) köşe başına UV2.x'te gelir: tüm genişlikler tek malzemeyle birleştirilebilsin (çizim çağrısı)
varying float v_width;
uniform float edge_margin = 0.35;
// 0: gri parke + tuğla kenar (dış yollar), 1: pembe-kırmızı beton plaka (Ortabahçe; Street View referansı)
uniform int pattern = 0;
uniform vec4 pink_color : source_color = vec4(0.69, 0.50, 0.46, 1.0);

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_width = UV2.x > 0.0 ? UV2.x : road_width;
}

vec3 cobble(vec2 xz) {
	// Küp taş (~0.25 m), sıralar yarım kaydırmalı
	vec2 cp = xz;
	float c_row = floor(cp.y / cobble_size);
	cp.x += mod(c_row, 2.0) * (cobble_size * 0.5);
	vec2 c_f = fract(cp / cobble_size);
	vec2 c_d = min(c_f, 1.0 - c_f);
	float c_mortar = smoothstep(0.03, 0.07, min(c_d.x, c_d.y));
	vec3 c_stone = cobble_color.rgb * mix(0.92, 1.08, hash(floor(cp / cobble_size)));
	return mix(mortar_color.rgb, c_stone, c_mortar);
}

vec3 brick(vec2 xz) {
	// Tuğla (~0.125 x 0.25 m)
	float b_row = floor(xz.y / 0.125);
	float bx = xz.x + mod(b_row, 2.0) * 0.125;
	vec2 b_f = vec2(fract(bx / 0.25), fract(xz.y / 0.125));
	vec2 b_d = min(b_f, 1.0 - b_f);
	float b_mortar = smoothstep(0.04, 0.08, min(b_d.x, b_d.y));
	vec3 b_stone = brick_color.rgb * mix(0.90, 1.10, hash(vec2(floor(bx / 0.25), b_row)));
	return mix(brick_mortar_color.rgb, b_stone, b_mortar);
}

void fragment() {
	// Sadece gereken desen hesaplanır (mobil GPU: her pikselde iki desen + hash pahalı)
	if (pattern == 1) {
		vec2 sp = world_pos.xz / 1.6;  // 1.6 m pembe beton plaka (Ortabahçe)
		vec2 sf = fract(sp);
		float joint = min(min(sf.x, 1.0 - sf.x), min(sf.y, 1.0 - sf.y));
		float wear = hash(floor(sp)) * 0.12 + hash(floor(world_pos.xz * 1.7)) * 0.05;
		vec3 slab = pink_color.rgb * (0.94 + wear);
		ALBEDO = mix(slab * 0.82, slab, smoothstep(0.0, 0.025, joint));
	} else {
		// Kenar şeridi: kenara edge_margin kala tuğla, içi parke
		float dist_to_edge = min(UV.x, 1.0 - UV.x) * v_width;
		float edge_blend = smoothstep(edge_margin - 0.02, edge_margin + 0.02, dist_to_edge);
		if (edge_blend <= 0.0) {
			ALBEDO = brick(world_pos.xz);
		} else if (edge_blend >= 1.0) {
			ALBEDO = cobble(world_pos.xz);
		} else {
			ALBEDO = mix(brick(world_pos.xz), cobble(world_pos.xz), edge_blend);
		}
	}
	ROUGHNESS = 0.88;
	METALLIC = 0.0;
}
