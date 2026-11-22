shader_type spatial;
// Ortabahçe çiçek tarhı: koyu yeşil çalı zemini üzerinde kırmızı/pembe çiçek noktaları (doku dosyası yok).
uniform vec4 leaf_color : source_color = vec4(0.22, 0.38, 0.18, 1.0);
uniform vec4 flower_color : source_color = vec4(0.82, 0.16, 0.2, 1.0);
uniform vec4 flower_color2 : source_color = vec4(0.93, 0.45, 0.55, 1.0);
uniform float cell = 0.22;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz + vec2(world_pos.y * 0.7);
	vec2 id = floor(p / cell);
	vec2 f = fract(p / cell) - 0.5;
	float h = hash(id);
	vec3 col = leaf_color.rgb * mix(0.8, 1.15, hash(id + 7.0));
	if (h > 0.78 && length(f) < 0.26 && world_pos.y > 0.3) {
		col = h > 0.9 ? flower_color2.rgb : flower_color.rgb;
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
