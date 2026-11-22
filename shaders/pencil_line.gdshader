shader_type canvas_item;
// A hand-drawn line of varying width, for the ribbons built by scripts/pencil.gd.
//
// A ribbon is wider than any line. UV.y runs -1..1 across it and COLOR.a carries the pressure
// at that point (0..1), which sets how much of the ribbon is filled: the line swells and thins
// along its length and fades out where the pressure drops to nothing. The paper's tooth
// roughens the edge, and breaks the line up where it is drawn lightly.

/** How much a lightly drawn line breaks up. */
uniform float grain : hint_range(0.0, 1.0) = 0.5;
/** Size of the tooth, in pixels. */
uniform float tooth_size : hint_range(0.5, 8.0) = 1.2;
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
	float pressure = COLOR.a;
	float tooth = 0.6 * value_noise(at / tooth_size) + 0.4 * value_noise(at / (tooth_size * 2.25) + 5.0);
	float half_width = pressure * (0.8 + 0.4 * tooth);
	float soft = fwidth(UV.y) * 0.75;
	float line = smoothstep(half_width + soft, half_width - soft, abs(UV.y));
	float broken = mix(1.0, smoothstep(0.2, 0.55, tooth), grain * (1.0 - smoothstep(0.15, 0.45, pressure)));
	float dark = clamp(0.8 + pressure * 1.5, 0.0, 1.0);
	COLOR = vec4(COLOR.rgb, line * broken * dark);
}
