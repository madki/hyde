shader_type canvas_item;
// The mist at the screen's edges while the table is in danger (scripts/arena_danger.gd).
//
// A soft fall from each edge inward, `reach` deep: of the page's width from the left and the
// right, of its height from the top and the bottom, so a wide page's mist stays off the hand. One sample of the
// page's noise, drifting slowly, makes it deeper in some places and thinner in others, so it
// lies as a mist and not as a frame. Nothing is drawn past the mist's depth: the middle of the
// page is left alone.

/** One of the page's tiling pictures of smooth noise (made by arena_ink.gd). */
uniform sampler2D noise : filter_linear, repeat_enable;
/** The mist's colour. */
uniform vec3 tint : source_color = vec3(1.0, 0.31, 0.70);
/** How far in from each edge the mist reaches, as a share of the page across that edge. */
uniform float reach = 0.08;
/** The mist's alpha at the edge itself. */
uniform float strength = 0.0;
/** The page's size in pixels. */
uniform vec2 page_size = vec2(1152.0, 648.0);

/** How many times the noise repeats across the page's width. */
const float GRAIN = 2.3;
/** The least and the most of `reach` the noise leaves the mist, from place to place. */
const float THIN = 0.4;
const float DEEP = 1.0;

void fragment() {
	vec2 px = UV * page_size;
	vec2 from_edge = min(UV, 1.0 - UV);
	vec2 at = px / page_size.x * GRAIN + vec2(TIME * 0.011, -TIME * 0.007);
	// The noise keeps to the middle of its range: spread it out.
	float n = clamp((texture(noise, at).r - 0.5) * 2.4 + 0.5, 0.0, 1.0);
	float depth = reach * mix(THIN, DEEP, n);
	vec2 near = clamp(1.0 - from_edge / depth, 0.0, 1.0);
	// Both edges of a corner count, without a seam along its diagonal.
	float mist = 1.0 - (1.0 - near.x) * (1.0 - near.y);
	// A soft curve inward, and thinner where it is shallower.
	COLOR = vec4(tint, strength * mist * sqrt(mist) * mix(0.8, 1.0, n));
}
