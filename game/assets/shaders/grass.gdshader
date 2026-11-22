shader_type spatial;
// Çim: düz tek renk yerine dünya koordinatına bağlı hafif alacalık (Street View'daki gibi lekeli çimen). Doku dosyası yok.
uniform vec4 base_color : source_color = vec4(0.36, 0.53, 0.24, 1.0);
uniform float patch_scale = 0.045;   // büyük lekeler (~22 m)
uniform float detail_scale = 0.6;    // küçük ton oynaması (~1.7 m)
uniform float strength = 0.16;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

varying vec2 wxz;

void vertex() {
	wxz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float big = vnoise(wxz * patch_scale);
	float small = vnoise(wxz * detail_scale);
	float t = (big - 0.5) * 1.0 + (small - 0.5) * 0.35;
	vec3 c = base_color.rgb * (1.0 + t * strength * 2.0);
	// büyük lekelerde hafif sarımsı (kuru) ton
	c = mix(c, c * vec3(1.08, 1.04, 0.86), smoothstep(0.62, 0.85, big) * 0.6);
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
