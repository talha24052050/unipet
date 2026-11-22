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

void fragment() {
	// Kenar mesafesi: UV.x (0..1) ve road_width üzerinden hesaplanır
	float dist_to_edge = min(UV.x, 1.0 - UV.x) * v_width;

	// Küp taş deseni (~0.25 m)
	vec2 cp = world_pos.xz;
	float c_row = floor(cp.y / cobble_size);
	cp.x += mod(c_row, 2.0) * (cobble_size * 0.5);
	vec2 c_id = floor(cp / cobble_size);
	vec2 c_f = fract(cp / cobble_size);
	vec2 c_d = min(c_f, 1.0 - c_f);
	float c_joint = min(c_d.x, c_d.y);
	float c_mortar = smoothstep(0.03, 0.07, c_joint);
	float c_h = hash(c_id);
	vec3 c_stone = mix(cobble_color.rgb * 0.92, cobble_color.rgb * 1.08, c_h);
	vec3 final_cobble = mix(mortar_color.rgb, c_stone, c_mortar);

	// Kırmızı tuğla deseni (~0.125 x 0.25 m)
	vec2 bp = world_pos.xz;
	float b_row = floor(bp.y / 0.125);
	bp.x += mod(b_row, 2.0) * 0.125;
	vec2 b_id = floor(vec2(bp.x / 0.25, b_row));
	vec2 b_f = vec2(fract(bp.x / 0.25), fract(bp.y / 0.125));
	vec2 b_d = min(b_f, 1.0 - b_f);
	float b_joint = min(b_d.x, b_d.y);
	float b_mortar = smoothstep(0.04, 0.08, b_joint);
	float b_h = hash(b_id);
	vec3 b_stone = mix(brick_color.rgb * 0.90, brick_color.rgb * 1.10, b_h);
	vec3 final_brick = mix(brick_mortar_color.rgb, b_stone, b_mortar);

	// Kenar şeridi geçişi (0.35 m kala kırmızı tuğla şerit)
	float edge_blend = smoothstep(edge_margin - 0.02, edge_margin + 0.02, dist_to_edge);
	if (pattern == 1) {
		vec2 sp = world_pos.xz / 1.6;  // 1.6 m beton plaka
		vec2 sf = fract(sp);
		float joint = min(min(sf.x, 1.0 - sf.x), min(sf.y, 1.0 - sf.y));
		float wear = hash(floor(sp)) * 0.12 + hash(floor(world_pos.xz * 1.7)) * 0.05;
		vec3 slab = pink_color.rgb * (0.94 + wear);
		ALBEDO = mix(slab * 0.82, slab, smoothstep(0.0, 0.025, joint));
	} else {
		ALBEDO = mix(final_brick, final_cobble, edge_blend);
	}
	ROUGHNESS = 0.88;
	METALLIC = 0.0;
}
