shader_type spatial;
// Kampüs çimenliği: 3 ölçekli organik çim alacalığı, düz parklarda hafif biçilmiş çim şeritleri
// ve dik yamaçlarda doğal toprak/kuru ot geçişi (tek doku okuma, mobil dostu).
uniform vec4 base_color : source_color = vec4(0.36, 0.53, 0.24, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float patch_scale = 0.0085;  // büyük çayır/güneş lekeleri
uniform float detail_scale = 0.095;  // orta ölçek çim kümesi
uniform float micro_scale = 1.45;    // yakın mesafe çimen pütürü (mipmap ile uzakta pürüzsüz)
uniform float strength = 0.18;

varying vec2 wxz;
varying float v_up;

void vertex() {
	wxz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	float big = texture(noise_tex, wxz * patch_scale).r;
	float med = texture(noise_tex, wxz * detail_scale + vec2(0.37, 0.71)).r;
	float micro = texture(noise_tex, wxz * micro_scale + vec2(0.19, 0.53)).r;

	float t = (big - 0.5) + (med - 0.5) * 0.42 + (micro - 0.5) * 0.22;
	vec3 c = base_color.rgb * (1.0 + t * strength * 2.0);

	// Büyük güneşli alanlarda sıcak yonca/zeytin yeşili tonu, gölgeli ceplerde derin zümrüt yeşili
	c = mix(c, c * vec3(1.10, 1.05, 0.84), smoothstep(0.60, 0.86, big) * 0.55);
	c = mix(c, c * vec3(0.84, 0.94, 0.86), smoothstep(0.38, 0.16, big) * 0.45);

	// Düz çim/park alanlarında çok hafif doğal biçilmiş çim şeritleri
	float flat_mask = smoothstep(0.980, 0.996, v_up);
	float stripe = sin((wxz.x * 0.78 + wxz.y * 0.62) * 0.55) * 0.5 + 0.5;
	c *= (1.0 + (stripe - 0.5) * 0.065 * flat_mask);

	// Dik yamaçlarda (Stadyum / Teknopark tepeleri) hafif kuru ot / toprak geçişi
	float slope_mask = smoothstep(0.955, 0.84, v_up);
	vec3 dry_slope = vec3(0.43, 0.40, 0.25) * (0.9 + 0.2 * med);
	c = mix(c, dry_slope, slope_mask * 0.55);

	ALBEDO = c;
	ROUGHNESS = mix(0.93, 0.98, micro);
	METALLIC = 0.0;
}
