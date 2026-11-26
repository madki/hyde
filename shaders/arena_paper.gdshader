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
//
// Over all of it lie pencil hatching, slanted strokes broken up by the noise, and two lamps:
// Jekyll's from the top left and Hyde's from the right, the lamp of whoever holds the table at
// full strength and the other's dimmer (`lamp_hold`, set by arena_ink.gd).

#include "res://shaders/arena_ink.gdshaderinc"

group_uniforms mask;
/** The mask's median grey (printed by the bake): it lands on `mid_at` of the ramp. */
uniform float mask_mid : hint_range(0.0, 1.0) = 0.82;
/** How far the mask's light and dark are spread over the ramp. */
uniform float contrast : hint_range(0.0, 8.0) = 3.8;
/** Where on the ramp (0 = dark, 1 = light) the mask's median grey sits. */
uniform float mid_at : hint_range(0.0, 1.0) = 0.48;

group_uniforms colours;
uniform vec3 paper_dark : source_color = vec3(0.016, 0.114, 0.165);
uniform vec3 paper_mid : source_color = vec3(0.004, 0.176, 0.247);
uniform vec3 paper_light : source_color = vec3(0.063, 0.263, 0.333);
/** The ink's four colours, palest to darkest: pale wash, pink where the ink thins, wine, and
 * the darkest. */
uniform vec3 ink_wash : source_color = vec3(0.361, 0.184, 0.349);
uniform vec3 ink_bloom : source_color = vec3(0.369, 0.063, 0.251);
uniform vec3 ink_body : source_color = vec3(0.247, 0.012, 0.173);
uniform vec3 ink_deep : source_color = vec3(0.122, 0.012, 0.090);

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
/** The ink's wet edge, lit for a moment as the ink surges (set by arena_ink.gd): x is how
 * strongly, 0 to 1, and y the height on the page (0 top, 1 bottom) it is brightest at, or
 * negative for all of the edge alike. */
uniform vec2 edge_lit = vec2(0.0, -1.0);

group_uniforms hatch;
/** The strokes' colour (Palette.OUTLINE) and how strongly they darken the page. */
uniform vec3 hatch_colour : source_color = vec3(0.051, 0.012, 0.125);
uniform float hatch_strength : hint_range(0.0, 1.0) = 0.55;
/** Distance between strokes and their width, in pixels, and their slant from level. */
uniform float hatch_spacing : hint_range(2.0, 24.0) = 6.0;
uniform float hatch_width : hint_range(0.5, 6.0) = 1.4;
uniform float hatch_angle : hint_range(-1.6, 1.6) = -0.75;
/** Share of the page the hatched patches take, and of a stroke left unbroken. */
uniform float hatch_cover : hint_range(0.0, 1.0) = 0.65;
uniform float hatch_unbroken : hint_range(0.0, 1.0) = 0.6;
/** How much of the hatching a lamp's light lifts where it is strongest. */
uniform float hatch_lit : hint_range(0.0, 1.0) = 0.8;

group_uniforms lamps;
/** The lamps' colours (Palette.JEKYLL, Palette.HYDE). */
uniform vec3 lamp_jekyll : source_color = vec3(0.290, 0.914, 0.976);
uniform vec3 lamp_hyde : source_color = vec3(1.0, 0.310, 0.698);
/** A lamp's strength where it is strongest, and how far it reaches, in page heights. */
uniform float lamp_strength : hint_range(0.0, 1.0) = 0.28;
uniform float lamp_reach : hint_range(0.1, 3.0) = 0.8;
/** Who holds the table: 0 Jekyll, 1 Hyde (eased by arena_ink.gd). The other's lamp burns at
 * `lamp_other` of its strength. */
uniform float lamp_hold : hint_range(0.0, 1.0) = 1.0;
uniform float lamp_other : hint_range(0.0, 1.0) = 0.5;
/** How far Hyde's lamp, a hot light, washes out the dye it falls on before tinting it (times
 * its strength there). */
uniform float lamp_bleach : hint_range(0.0, 3.0) = 3.0;

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
	float to_limit = inside;
	// A full page is inked to its last corner: the rank goes a little over 1 near the left
	// border, which would leave those places bare, or with the drying line all over them.
	inside = max(inside, step(0.999, presence));
	float total = smoothstep(0.0, limit_soft, inside) * step(0.0005, presence);
	if (total > 0.0) {
		float sheet = clamp(1.0 + (t - mid_at) * 2.0 * ink_paper, 0.85, 1.0);
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

	// The wet edge, lit as the ink surges: a band of Hyde's pink along the ink's limit.
	if (edge_lit.x > 0.0) {
		float band = smoothstep(-0.004, 0.0, to_limit) * (1.0 - smoothstep(0.0, 0.035, to_limit));
		float near = edge_lit.y < 0.0 ? 1.0 : 1.0 - smoothstep(0.1, 0.5, abs(page_uv.y - edge_lit.y));
		col = mix(col, lamp_hyde, band * near * edge_lit.x * 0.75 * step(0.0005, presence));
	}

	// The lamps: soft washes that fade out from a point just off the page.
	vec2 spot = page_uv * page_shape;
	float near_j = 1.0 - smoothstep(0.0, 1.0, length(spot - vec2(-0.08, -0.12)) / lamp_reach);
	float near_h = 1.0 - smoothstep(0.0, 1.0, length(spot - vec2(page_shape.x + 0.08, 0.45)) / lamp_reach);
	float lamp_j = near_j * near_j * lamp_strength * mix(1.0, lamp_other, lamp_hold);
	float lamp_h = near_h * near_h * lamp_strength * mix(lamp_other, 1.0, lamp_hold);

	// The hatching: strokes along a slanted line, each row broken where a noise is low, and
	// only in patches. A lamp's light lifts it.
	vec2 px = page_uv * page_size;
	vec2 dir = vec2(cos(hatch_angle), sin(hatch_angle));
	float across = dot(px, vec2(-dir.y, dir.x)) + (texture(noise_a, spot * 1.2).r - 0.5) * hatch_spacing * 0.4;
	float along = dot(px, dir);
	float row = floor(across / hatch_spacing);
	float off_line = abs(fract(across / hatch_spacing) - 0.5) * hatch_spacing;
	float stroke = 1.0 - smoothstep(hatch_width * 0.5 - 0.5, hatch_width * 0.5 + 0.5, off_line);
	float run = texture(noise_b, vec2(row * 0.173, along / (hatch_spacing * 30.0))).r;
	stroke *= smoothstep(1.0 - hatch_unbroken - 0.08, 1.0 - hatch_unbroken + 0.08, run) * mix(0.55, 1.0, run);
	float patch = texture(noise_a, spot * 0.9 + vec2(0.43, 0.71)).r;
	stroke *= smoothstep(1.0 - hatch_cover - 0.1, 1.0 - hatch_cover + 0.1, patch);
	float lit = clamp((lamp_j + lamp_h) / max(lamp_strength, 0.001), 0.0, 1.0);
	col = mix(col, hatch_colour, stroke * hatch_strength * (1.0 - hatch_lit * lit));

	float lit_grey = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lit_grey), clamp(lamp_h * lamp_bleach, 0.0, 1.0));
	col = mix(col, lamp_jekyll, lamp_j);
	col = mix(col, lamp_hyde, lamp_h);
	COLOR = vec4(col, 1.0);
}
