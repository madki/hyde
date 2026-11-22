shader_type canvas_item;
// The wet layer of Hyde's ink: one value of paint for every place on the page, redrawn from
// itself every frame (scripts/arena_ink.gd keeps two small viewports for it). The page's
// shader cuts the ink's layers out of this paint, which is why their edges are alive.
//
// The paint settles towards a level that falls from 1 at the right border to 0 at the ink's
// limit. It is kept from resting there: each place takes last frame's paint from a spot
// shifted towards thicker paint, so paint swells outward, and shifted again along a direction
// read from slow noise that turns with time, which throws out arms. (Swelling and a turning
// noise on a picture that feeds on itself is the method of Leon Denise's "Liquid Toy",
// shadertoy.com/view/fljBWc. The code here is this project's own.)

#include "res://shaders/arena_ink.gdshaderinc"

/** Last frame of this same layer. */
uniform sampler2D previous : filter_linear, repeat_disable;
/** Size of one pixel of the layer, as a share of it. */
uniform vec2 texel = vec2(0.001736, 0.003086);
/** This frame's length, in sixtieths of a second. */
uniform float frame = 1.0;
/** How hard the paint is stirred: 0 = not at all. */
uniform float unrest = 1.0;
/** Pixels a frame the paint moves outward. */
uniform float swell = 1.3;
/** Pixels a frame the noise carries it. */
uniform float push = 1.1;
/** How fast, per second, stirred paint goes back to its level. */
uniform float settle = 0.3;
/** 1 = forget last frame and start from the level (the first frames, when there is none). */
uniform float prime = 0.0;

void fragment() {
	vec2 wide = UV * page_shape;
	float n = texture(noise_a, wide * 0.9 + vec2(ink_time * 0.011, -ink_time * 0.007)).r
			+ 0.5 * texture(noise_b, wide * 1.7 - vec2(ink_time * 0.009, ink_time * 0.013)).r;
	float turn = n * 12.566 + ink_time * 0.05;
	vec2 dir = vec2(cos(turn), sin(turn));
	float l = ink_paint(texture(previous, UV - vec2(texel.x * 3.0, 0.0)));
	float r = ink_paint(texture(previous, UV + vec2(texel.x * 3.0, 0.0)));
	float u = ink_paint(texture(previous, UV - vec2(0.0, texel.y * 3.0)));
	float d = ink_paint(texture(previous, UV + vec2(0.0, texel.y * 3.0)));
	vec2 slope = vec2(r - l, d - u);
	vec2 thicker = slope / (length(slope) + 0.02);
	float live = unrest * mix(0.5, 1.0, smoothstep(0.1, 0.8, presence)) * frame;
	float paint = ink_paint(texture(previous, UV + (thicker * swell + dir * push) * texel * live));

	float level = clamp(1.0 - ink_rank(ink_drifted(UV)) / max(ink_reach(UV), 0.001), 0.0, 1.0);
	paint = mix(paint, level, max(1.0 - exp(-settle * frame / 60.0), prime));
	COLOR = ink_stored(paint);
}
