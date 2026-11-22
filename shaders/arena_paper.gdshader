shader_type canvas_item;
// The arena's page: a sheet of old paper in Jekyll's slate, with Hyde's ink in it.
//
// The texture is a mask, a scan of real paper saved as greys (studio/paper_mask_bake.gd). Its
// grey value alone picks the place on a ramp of three colours, so the stains, the cross fold and
// the fibre are the scan's own and the colour is ours. Drawn by a TextureRect that covers the
// screen, so a wider window shows more of the sheet.
//
// The ink comes in from the right border and covers `presence` of the page (see ink_rank in
// arena_ink.gdshaderinc). Inside that it lies in layers, each cut from the wet layer's paint
// (arena_wet.gdshader) where the paint is above a level: a pale wash over all of it, a pink
// mid tone, a dark layer and a deeper one inside that. scripts/arena_ink.gd sets how much of
// the ink each takes and how fast any of it moves.

#include "res://shaders/arena_ink.gdshaderinc"

group_uniforms mask;
/** The mask's median grey (printed by the bake): it lands on `mid_at` of the ramp. */
uniform float mask_mid : hint_range(0.0, 1.0) = 0.82;
/** How far the mask's light and dark are spread over the ramp. */
uniform float contrast : hint_range(0.0, 8.0) = 3.8;
/** Where on the ramp (0 = dark, 1 = light) the mask's median grey sits. */
uniform float mid_at : hint_range(0.0, 1.0) = 0.48;

group_uniforms colours;
uniform vec3 paper_dark : source_color = vec3(0.122, 0.141, 0.157);
uniform vec3 paper_mid : source_color = vec3(0.184, 0.243, 0.275);
uniform vec3 paper_light : source_color = vec3(0.306, 0.376, 0.447);
/** The ink's four colours, palest to darkest: pale wash, pink where the ink thins, wine, and
 * the darkest. */
uniform vec3 ink_wash : source_color = vec3(0.415, 0.325, 0.455);
uniform vec3 ink_bloom : source_color = vec3(0.40, 0.21, 0.37);
uniform vec3 ink_body : source_color = vec3(0.29, 0.14, 0.25);
uniform vec3 ink_deep : source_color = vec3(0.13, 0.05, 0.115);

group_uniforms ink;
/** The wet layer's paint (read with ink_paint): 1 at the right border, 0 at the ink's limit,
 * stirred. */
uniform sampler2D wet : filter_linear, repeat_disable;
/** The page's size in pixels (set by arena_ink.gd), to tell where on the page a pixel is. */
uniform vec2 page_size = vec2(1152.0, 648.0);
/** Share of the inked area under the dark layer, and under the deeper one inside it. */
uniform float dark_share : hint_range(0.0, 1.0) = 0.7;
uniform float deep_share : hint_range(0.0, 1.0) = 0.6;
/** Share of the inked area the pink mid tone takes outside the dark layer. */
uniform float mid_share : hint_range(0.0, 1.0) = 0.2;
/** How strongly the mid tone shows: it belongs to Jekyll's stance. */
uniform float mid_cover : hint_range(0.0, 1.0) = 0.0;
/** How much of the page's own light and dark shows in the ink: it is a dye, not a coat. */
uniform float ink_paper : hint_range(0.0, 1.5) = 0.5;
/** How strongly the pale wash tints the page. */
uniform float wash_cover : hint_range(0.0, 1.0) = 0.8;
/** How far the page turns to the ink's colour where the paint is thick, and where thin. */
uniform float ink_cover : hint_range(0.0, 1.0) = 0.95;
uniform float ink_cover_thin : hint_range(0.0, 1.0) = 0.7;
/** How far thick paint goes toward the darkest colour. */
uniform float ink_deepen : hint_range(0.0, 1.0) = 0.8;
/** Strength of the dark lines where a layer dried at its edge: the dark layers', the washes'. */
uniform float rim_dark : hint_range(0.0, 1.0) = 0.75;
uniform float wash_rim_dark : hint_range(0.0, 1.0) = 0.4;
/** Width of those lines, softness of the layers' edges, and how far a noise shifts the levels
 * the layers are cut at; all in paint level. */
uniform float rim_width : hint_range(0.0, 0.3) = 0.05;
uniform float edge_soft : hint_range(0.005, 0.15) = 0.025;
uniform float uneven : hint_range(0.0, 0.4) = 0.12;
/** Softness of the ink's outer edge, in rank. */
uniform float limit_soft : hint_range(0.001, 0.05) = 0.004;

varying vec2 page_uv;

void vertex() {
	page_uv = VERTEX / page_size;
}

void fragment() {
	float grey = texture(TEXTURE, UV).r;
	float t = clamp(mid_at + (grey - mask_mid) * contrast, 0.0, 1.0);
	vec3 col = t < 0.5 ? mix(paper_dark, paper_mid, t * 2.0) : mix(paper_mid, paper_light, t * 2.0 - 1.0);

	// All of the ink lies inside presence's limit.
	vec2 drifted = ink_drifted(page_uv);
	float inside = ink_reach(page_uv) - ink_rank(drifted);
	// A full page is inked to its last corner: the rank goes a little over 1 near the left
	// border, which would leave those places bare, or with the drying line all over them.
	inside = max(inside, step(0.999, presence));
	float total = smoothstep(0.0, limit_soft, inside) * step(0.0005, presence);
	if (total > 0.0) {
		float sheet = 1.0 + (t - mid_at) * 2.0 * ink_paper;
		float paint = ink_paint(texture(wet, page_uv));
		// Smooth noises that travel with the ink: one shifts the layers' levels so their edges
		// do not run alongside each other, one is how much pigment dried where.
		vec2 w = drifted * page_shape;
		float shift = texture(noise_b, w * 1.1 + vec2(0.61, 0.29)).r - 0.5;
		float vary = smoothstep(0.25, 0.75, shift + 0.5);
		float pigment = 0.9 + 1.1 * (texture(noise_a, w * 0.8 + vec2(0.37, 0.11)).r - 0.5)
				+ 0.5 * (texture(noise_b, w * 2.3 + vec2(0.11, 0.53)).r - 0.5);
		float has_dark = smoothstep(0.0, 0.05, dark_share);
		float dark_at = 1.0 - dark_share + shift * uneven * 0.5;
		float deep_at = 1.0 - deep_share - shift * uneven * 0.8;
		float mid_at_level = 1.0 - dark_share - min(mid_share, 0.985 - dark_share) - shift * uneven;

		// 1. The pale wash: everything inside the limit, with a faint line where it dried.
		col = mix(col, ink_wash * sheet, total * wash_cover);
		col = mix(col, ink_body * sheet, total * (1.0 - smoothstep(0.0, limit_soft * 6.0, inside)) * wash_rim_dark);
		// 2. The mid tone.
		float mid = total * smoothstep(mid_at_level - edge_soft, mid_at_level + edge_soft, paint);
		col = mix(col, mix(ink_bloom, ink_body, 0.55) * sheet, mid * mid_cover);
		col = mix(col, ink_body * sheet, mid * (1.0 - smoothstep(mid_at_level, mid_at_level + 0.09, paint)) * wash_rim_dark * mid_cover / 0.6);
		// 3. Two dark layers, one inside the other. Inside them thin paint is pink, thicker the
		// body's wine, the thickest nearly black, under slow clouds that travel with the clock.
		float dark = total * has_dark * smoothstep(dark_at - edge_soft, dark_at + edge_soft, paint);
		float deeper = dark * smoothstep(deep_at - edge_soft, deep_at + edge_soft, paint);
		vec2 wide = page_uv * page_shape;
		float cloud = texture(noise_b, wide * 1.3 + vec2(ink_time * 0.031, -ink_time * 0.022)).r
				+ 0.6 * texture(noise_a, wide * 2.7 - vec2(ink_time * 0.027, ink_time * 0.035)).r;
		float tone = clamp(pigment * mix(0.5, 1.0, deeper) * mix(0.55, 1.25, cloud / 1.6), 0.0, 1.0);
		vec3 ink = mix(ink_bloom, ink_body, smoothstep(0.0, 0.35, tone));
		ink = mix(ink, ink_deep, smoothstep(0.3, 0.9, tone) * ink_deepen);
		col = mix(col, ink * sheet, dark * mix(ink_cover_thin, ink_cover, tone));
		// Pigment collects at the edge of a drying wash: a dark line at each dark layer's edge.
		float rim = dark * (1.0 - smoothstep(dark_at, dark_at + rim_width, paint));
		rim = max(rim, deeper * (1.0 - smoothstep(deep_at, deep_at + rim_width, paint)) * 0.7);
		col = mix(col, ink_deep * sheet, rim * rim_dark * mix(0.4, 1.0, vary));
	}
	COLOR = vec4(col, 1.0);
}
