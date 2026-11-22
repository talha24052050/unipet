shader_type spatial;
// Çim: düz tek renk yerine dünya koordinatına bağlı hafif alacalık (Street View'daki gibi lekeli çimen).
// Gürültü, oyun açılırken üretilen küçük dikişsiz dokudan okunur (piksel başına sin/hash hesabı telefonda pahalı).
uniform vec4 base_color : source_color = vec4(0.36, 0.53, 0.24, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float patch_scale = 0.012;   // büyük lekeler (doku ~83 m'de bir tekrar)
uniform float detail_scale = 0.17;   // küçük ton oynaması
uniform float strength = 0.16;

varying vec2 wxz;

void vertex() {
	wxz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float big = texture(noise_tex, wxz * patch_scale).r;
	float small = texture(noise_tex, wxz * detail_scale + vec2(0.37, 0.71)).r;
	float t = (big - 0.5) + (small - 0.5) * 0.35;
	vec3 c = base_color.rgb * (1.0 + t * strength * 2.0);
	// büyük lekelerde hafif sarımsı (kuru) ton
	c = mix(c, c * vec3(1.08, 1.04, 0.86), smoothstep(0.62, 0.85, big) * 0.6);
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
