shader_type canvas_item;
// A gauge's picture in chalk (art/gauge_pictures, baked by studio/card_picture_bake.gd): the
// picture's lines, kept in its red, in the colour scripts/arena_symbols.gd draws it with, and
// grainy and a little broken, as chalk lies on a slate. The grain is a speck a screen pixel
// across, fixed to the picture, so it neither swims nor washes out as the picture is made small.

// The colour it is drawn with: in `fragment`, COLOR has already been mixed with the picture.
varying vec4 tint;

// How much of the chalk a speck can take away, and the share of the line that breaks.
uniform float grain : hint_range(0.0, 1.0) = 0.45;
uniform float breaks : hint_range(0.0, 1.0) = 0.22;

void vertex() {
	tint = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth noise over cells one unit wide.
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// Where in the picture this is, counted in screen pixels.
	vec2 px = UV / max(fwidth(UV), vec2(1e-5));
	float line = texture(TEXTURE, UV).r;
	float speck = 1.0 - grain * hash(floor(px));
	float broken = smoothstep(breaks - 0.12, breaks + 0.12, noise(px / 2.5));
	COLOR = vec4(tint.rgb, tint.a * line * speck * mix(0.35, 1.0, broken));
}
