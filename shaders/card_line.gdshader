shader_type canvas_item;
// A line printed on a card in heavy ink, for the ribbons built by scripts/pencil.gd.
//
// The same ribbons as the pencil's (UV.y runs -1..1 across, COLOR.a carries the pressure), but
// the ink is all or nothing: the line has a hard, rough edge that follows the card's texels,
// and the ink fails to take in small patches, so the paper shows through.

/** Size of a texel in pixels (set by arena_card.gd): the same as the card's body. */
uniform float texel : hint_range(0.0, 4.0) = 1.0;
/** How rough the line's edge is. */
uniform float rough : hint_range(0.0, 1.0) = 0.45;
/** How much of the line the ink fails to take on. */
uniform float missing : hint_range(0.0, 1.0) = 0.12;
/** Size of the patches where it fails, in pixels. */
uniform float patch_size : hint_range(1.0, 24.0) = 5.0;
varying vec2 at;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	at = VERTEX;
}

void fragment() {
	vec2 p = texel > 0.0 ? (floor(at / texel) + 0.5) * texel : at;
	float pressure = COLOR.a;
	float half_width = pressure * (1.0 + rough * (hash(p) - 0.5));
	float soft = texel > 0.0 ? 0.001 : fwidth(UV.y) * 0.75;
	float line = smoothstep(half_width + soft, half_width - soft, abs(UV.y));
	float taken = 0.55 * value_noise(p / patch_size) + 0.3 * value_noise(p / (patch_size * 0.3) + 7.0)
			+ 0.15 * hash(p + 3.0);
	// Lightly pressed parts of a line lose more ink.
	float fails = missing * (1.0 + 0.8 * (1.0 - smoothstep(0.1, 0.35, pressure)));
	COLOR = vec4(COLOR.rgb, line * step(fails * 0.75, taken));
}
