shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// Kampüs otopark alanları (amenity=parking): koyu aşınmış asfalt + analitik AA'lı ince park yeri çizgileri.
uniform vec4 asphalt_color : source_color = vec4(0.24, 0.26, 0.29, 1.0);
uniform vec4 paint_color : source_color = vec4(0.84, 0.84, 0.80, 1.0);

varying vec3 world_pos;

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
}

void fragment() {
	float macro = value_noise(world_pos.xz * 0.22) - 0.5;
	float micro = value_noise(world_pos.xz * 3.5) - 0.5;
	vec3 col = asphalt_color.rgb * (1.0 + macro * 0.16 + micro * 0.08);
	float rough = 0.93;

	// Park bölmesi çizgileri: 2.6 m eninde cepler, 12 m şerit + koridor ritmi (uzakta yumuşak fade)
	vec2 stall_uv = vec2(world_pos.x / 2.6, world_pos.z / 12.0);
	vec2 fw = fwidth(stall_uv);
	float aa = max(fw.x, fw.y);
	float detail = 1.0 - smoothstep(0.18, 0.45, aa);
	if (detail > 0.01) {
		float row_f = fract(stall_uv.y);
		// Her 12 m'lik bandın 4.6 m'si park cepleri, geri kalanı araç manevra koridoru
		float in_bay = step(0.06, row_f) * (1.0 - step(0.44, row_f));
		float x_f = fract(stall_uv.x);
		float x_dist = min(x_f, 1.0 - x_f) * 2.6;
		float stall_line = (1.0 - smoothstep(0.04, 0.075 + aa * 0.25, x_dist)) * in_bay;
		float back_dist = abs(row_f - 0.06) * 12.0;
		float back_line = 1.0 - smoothstep(0.045, 0.085 + aa * 0.25, back_dist);
		float line_m = max(stall_line, back_line) * detail * 0.28;
		col = mix(col, paint_color.rgb, line_m);
		rough = mix(rough, 0.84, line_m);
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.0;
}
