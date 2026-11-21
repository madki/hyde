shader_type canvas_item;
// The colour split: the whole screen comes apart into three coloured pictures, which slide
// away from each other and snap back together. While they are apart, each one in turn stops
// showing the screen as it was (`before`) and shows it as it is now, so the scene changes
// inside the split.
//
// It is the red / green / blue split of a glitch effect, with three colours of our own in
// place of red, green and blue. Every pixel is rewritten as so much of each colour
// (`to_parts`), and the three amounts are read from three different places. With the
// pictures together the amounts add up to the pixel again, so the effect starts and ends on
// the untouched screen.
//
// The split can also linger round one place (`linger`), with the rest of the screen whole.
//
// Drawn by scripts/split_transition.gd, which sets everything under `set_by_script`.

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;

group_uniforms look;
/** How far apart the pictures go, as a fraction of the screen's height. */
uniform float reach : hint_range(0.0, 0.3) = 0.05;
/** Which way each picture goes: Jekyll's colour, Hyde's colour, the third colour. */
uniform vec2 way_jekyll = vec2(-1.0, 0.1);
uniform vec2 way_hyde = vec2(1.0, 0.1);
uniform vec2 way_third = vec2(0.0, -0.45);
/** How much each picture also grows (or, below zero, shrinks) as it goes. */
uniform vec3 swell = vec3(0.0, 0.0, 0.03);
/** Sideways tearing: some bands of the screen are pushed along while the pictures are apart. */
uniform float tear : hint_range(0.0, 2.0) = 0.5;
/** How many bands there are down the screen. */
uniform float tear_bands : hint_range(2.0, 80.0) = 18.0;
/** How many of the bands are pushed: 0 = none, 1 = all. */
uniform float tear_share : hint_range(0.0, 1.0) = 0.3;
/** Lifts the picture while it is apart, so the change reads as a flash and not a dimming. */
uniform float lift : hint_range(0.0, 1.0) = 0.12;

group_uniforms set_by_script;
/** The screen as it was when the change began. */
uniform sampler2D before : filter_linear, repeat_disable;
uniform vec3 colour_jekyll = vec3(0.03, 0.95, 0.92);
uniform vec3 colour_hyde = vec3(0.88, 0.06, 0.46);
uniform vec3 colour_third = vec3(0.9, 1.0, 0.1);
/** Turns a colour into amounts of the three colours above: the inverse of their matrix. */
uniform mat3 to_parts = mat3(1.0);
/** How far apart the pictures are: 0 = together, 1 = fully apart, below 0 = swung past. */
uniform float split = 0.0;
/** How far apart the pictures stay round `linger_at` when the rest of the screen is back
	together, on the same scale as `split`. */
uniform float linger = 0.0;
/** The middle of the place the split lingers round, and how far it reaches each way, both
	in 0..1 of the screen. */
uniform vec2 linger_at = vec2(0.5);
uniform vec2 linger_size = vec2(0.1);
/** For each picture, 0 = it still shows the screen as it was, 1 = as it is now. */
uniform vec3 arrived = vec3(1.0);
/** Changes a few times in the change, to move the torn bands. */
uniform float tear_seed = 0.0;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

vec3 picture(vec2 uv, float here) {
	vec3 now = texture(screen, uv).rgb;
	if (here >= 1.0) {
		return now;
	}
	return mix(texture(before, uv).rgb, now, here);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// One unit is the screen's height both ways, so a slanted `way` keeps its angle.
	vec2 unit = vec2(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 1.0);
	vec2 from_place = (uv - linger_at) / linger_size;
	float here = split + linger * (1.0 - smoothstep(0.45, 1.0, length(from_place)));
	float apart = abs(here);

	// The tearing goes first, so that the three pictures are torn alike and then pulled apart.
	float band = floor(uv.y * tear_bands + hash(tear_seed) * 7.0);
	float pushed = step(1.0 - tear_share, hash(band * 1.31 + tear_seed));
	uv.x += (hash(band + tear_seed * 3.7) - 0.5) * pushed * tear * reach * apart * unit.x;

	vec2 go = unit * reach * here;
	vec2 from_centre = uv - 0.5;
	vec3 parts = vec3(
			(to_parts * picture(uv - way_jekyll * go - from_centre * swell.x * apart, arrived.x)).x,
			(to_parts * picture(uv - way_hyde * go - from_centre * swell.y * apart, arrived.y)).y,
			(to_parts * picture(uv - way_third * go - from_centre * swell.z * apart, arrived.z)).z);
	vec3 col = colour_jekyll * parts.x + colour_hyde * parts.y + colour_third * parts.z;
	col *= 1.0 + lift * min(apart, 1.0);
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
