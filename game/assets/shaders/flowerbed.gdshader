shader_type spatial;
// Ortabahçe çiçek tarhı: tabanda segmentli taş bordür çerçevesi, üstte koyu yaprak dokusu ve
// 4 renkli (kırmızı, pembe, sarı, beyaz) doğal çiçek öbekleri.
uniform vec4 stone_color : source_color = vec4(0.72, 0.70, 0.66, 1.0);
uniform vec4 leaf_color : source_color = vec4(0.20, 0.37, 0.16, 1.0);
uniform vec4 flower_red : source_color = vec4(0.84, 0.16, 0.20, 1.0);
uniform vec4 flower_pink : source_color = vec4(0.94, 0.46, 0.58, 1.0);
uniform vec4 flower_yellow : source_color = vec4(0.96, 0.78, 0.20, 1.0);
uniform vec4 flower_white : source_color = vec4(0.95, 0.94, 0.90, 1.0);
uniform float cell = 0.20;

varying vec3 world_pos;
varying float local_y;
varying vec3 local_n;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Silindir yüksekliği 0.45 m (-0.225..+0.225) -> 0..0.45
	local_y = VERTEX.y + 0.225;
	local_n = normalize(NORMAL);
}

void fragment() {
	if (local_n.y < 0.5 && local_y < 0.28) {
		// Segmentli taş bordür çerçevesi
		float ang = atan(local_n.z, local_n.x);
		float seg = fract((ang / 6.283185) * 18.0);
		float joint = smoothstep(0.0, 0.07, min(seg, 1.0 - seg));
		float shade = 0.88 + 0.18 * hash(vec2(floor((ang / 6.283185) * 18.0), 3.0));
		ALBEDO = stone_color.rgb * shade * mix(0.68, 1.0, joint);
		ROUGHNESS = 0.90;
	} else {
		vec2 p = world_pos.xz + vec2(local_y * 0.4);
		vec2 id = floor(p / cell);
		vec2 f = fract(p / cell) - 0.5;
		float h = hash(id);
		vec3 col = leaf_color.rgb * mix(0.76, 1.18, hash(id + 7.0));
		float r = length(f + (vec2(hash(id + 13.0), hash(id + 29.0)) - 0.5) * 0.24);
		if (h > 0.72 && r < 0.28 && local_n.y > 0.35) {
			if (h > 0.93) {
				col = flower_white.rgb;
			} else if (h > 0.86) {
				col = flower_yellow.rgb;
			} else if (h > 0.79) {
				col = flower_pink.rgb;
			} else {
				col = flower_red.rgb;
			}
		}
		ALBEDO = col;
		ROUGHNESS = 0.95;
	}
	METALLIC = 0.0;
}
