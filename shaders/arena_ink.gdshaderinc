// Hyde's ink on the arena's page: what the page's shader (arena_paper.gdshader) and the wet
// layer's (arena_wet.gdshader) must agree on. scripts/arena_ink.gd sets these in both.

/** Two tiling pictures of smooth noise, made by arena_ink.gd when the arena opens. */
uniform sampler2D noise_a : filter_linear, repeat_enable;
uniform sampler2D noise_b : filter_linear, repeat_enable;
/** Share of the page the ink covers, 0 to 1. */
uniform float presence = 0.5;
/** The ink's own clock, in seconds: stopped while Jekyll has the table. */
uniform float ink_time = 0.0;
/** How far the whole body of ink sways, as a share of the page. */
uniform float ink_drift = 0.035;
/** How much presence the ink's edge gains and loses from place to place. */
uniform float ink_breathe = 0.035;
/** How far a slow noise moves the ink's limit. */
uniform float rank_wander = 0.18;

/** The page's shape, width over height and 1, so the noise is not stretched on any window. */
uniform vec2 page_shape = vec2(1.778, 1.0);

// The wet layer's paint is kept finer than one channel's 256 steps: red holds the step and
// green how far it is to the next. Without that a slow settling is rounded away every frame
// and the paint never comes back to its level. The sum stays right under linear filtering.
float ink_paint(vec4 stored) {
	return stored.r + stored.g / 255.0;
}

vec4 ink_stored(float paint) {
	float steps = clamp(paint, 0.0, 1.0) * 255.0;
	return vec4(floor(steps) / 255.0, fract(steps), 0.0, 1.0);
}

// A place on the page, pushed a little by a slow noise: everything about the ink is looked up
// through this, so all of it sways together.
vec2 ink_drifted(vec2 uv) {
	vec2 w = uv * page_shape * 0.6;
	float a = texture(noise_a, w + vec2(ink_time * 0.010, ink_time * 0.006)).r;
	float b = texture(noise_b, w + vec2(-ink_time * 0.007, ink_time * 0.011)).r;
	return uv + (vec2(a, b) - 0.5) * ink_drift;
}

// Where the ink may be. Every place has a rank from 0 to 1, lowest at the right border, with
// an edge that a noise keeps moving; the ink lives where the rank is under `ink_reach`. So
// all its layers together cover presence's share of the page and no more.
float ink_rank(vec2 drifted) {
	vec2 w = drifted * page_shape;
	float wander = (texture(noise_a, w * 0.45 + vec2(ink_time * 0.022, -ink_time * 0.016)).r - 0.5) * rank_wander;
	wander += (texture(noise_a, w * 1.9 - vec2(ink_time * 0.019, ink_time * 0.027)).r - 0.5) * rank_wander * 0.45;
	// The noise seldom goes to its extremes, so only a part of its range is allowed for:
	// with all of it, low presences come out far under their share.
	return (1.0 - drifted.x + wander + rank_wander * 0.15) / (1.0 + rank_wander * 0.3);
}

// Presence as it is felt at one place: the limit creeps out and back a little.
float ink_reach(vec2 uv) {
	float breath = texture(noise_a, uv * page_shape * 1.3 - vec2(ink_time * 0.013, ink_time * 0.009)).r - 0.5;
	return presence + breath * ink_breathe * smoothstep(0.0, 0.05, presence);
}
