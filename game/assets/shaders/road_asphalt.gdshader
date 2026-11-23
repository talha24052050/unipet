shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// Kampüs araç yolları (service): koyu asfalt dokusu, açık gri kenar bordürü ve orta kesikli çizgi.
uniform vec4 asphalt_color : source_color = vec4(0.24, 0.26, 0.29, 1.0);
uniform vec4 curb_color : source_color = vec4(0.58, 0.57, 0.55, 1.0);
uniform vec4 line_color : source_color = vec4(0.88, 0.86, 0.80, 1.0);
uniform float curb_width = 0.24;

varying vec3 world_pos;
varying float v_width;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_width = UV2.x > 0.0 ? UV2.x : 4.0;
}

void fragment() {
	float grain = (hash(floor(world_pos.xz * 6.0)) - 0.5) * 0.06;
	vec3 col = asphalt_color.rgb + vec3(grain);

	// Kenar kaldırım / bordür şeridi
	float dist_edge = min(UV.x, 1.0 - UV.x) * v_width;
	float curb_mask = 1.0 - smoothstep(curb_width - 0.04, curb_width + 0.02, dist_edge);
	col = mix(col, curb_color.rgb, curb_mask);

	// Orta kesikli yol çizgisi (sadece yeterince geniş araç yollarında)
	if (v_width >= 3.2) {
		float center_dist = abs(UV.x - 0.5) * v_width;
		float dash_phase = fract((world_pos.x + world_pos.z) * 0.18);
		float dash = step(0.45, dash_phase) * (1.0 - smoothstep(0.05, 0.08, center_dist));
		col = mix(col, line_color.rgb, dash * 0.72);
	}

	ALBEDO = col;
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
}
