shader_type canvas_item;
// A card's picture, printed on the card in the same heavy ink as its frame: the lines waver a
// little, have a hard rough edge that follows the card's texels, and lose their ink in small
// patches. The texture is a line drawing; only its alpha is used.

/** The colour of the ink. */
uniform vec3 tint : source_color = vec3(0.09, 0.06, 0.04);
uniform float strength : hint_range(0.0, 1.0) = 0.95;
/** Size of one of the card's texels in pixels of the texture (set by arena_card.gd): 0 for
 * smooth lines. */
uniform float texel = 0.0;
/** How much ink a place needs to print: lower keeps thin lines. */
uniform float cut : hint_range(0.05, 0.95) = 0.3;
/** How far the lines waver, in pixels of the texture, and over what length. */
uniform float waver : hint_range(0.0, 6.0) = 1.8;
uniform float waver_size : hint_range(4.0, 120.0) = 38.0;
/** How much of the lines the ink fails to take on, and the size of those patches in pixels of
 * the texture. */
uniform float missing : hint_range(0.0, 1.0) = 0.22;
uniform float patch_size : hint_range(1.0, 120.0) = 22.0;
uniform float seed = 0.0;

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

void fragment() {
	vec2 p = UV / TEXTURE_PIXEL_SIZE;
	if (texel > 0.0) {
		p = (floor(p / texel) + 0.5) * texel;
	}
	vec2 s = p + seed * 17.0;
	vec2 push = vec2(value_noise(s / waver_size), value_noise(s / waver_size + 23.0)) - 0.5;
	float ink = texture(TEXTURE, (p + push * 2.0 * waver) * TEXTURE_PIXEL_SIZE).a;
	float soft = texel > 0.0 ? 0.001 : 0.15;
	float drawn = smoothstep(cut - soft, cut + soft, ink + 0.15 * (hash(s) - 0.5));
	float taken = 0.55 * value_noise(s / patch_size) + 0.3 * value_noise(s / (patch_size * 0.3) + 7.0)
			+ 0.15 * hash(s + 3.0);
	COLOR = vec4(tint, drawn * step(missing * 0.75, taken) * strength);
}
