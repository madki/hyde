shader_type canvas_item;
// A card's body: a piece of old paper with a torn outline, and the shadow it throws.
//
// Drawn on a rectangle larger than the card by scripts/arena_card.gd, so that the shadow has
// room. Everything is worked out in the card's own pixels: the outline is a rounded rectangle
// pushed in and out by noise (a slow waver, a fine fray and a few bites), so no two cards are
// torn alike, and `seed` picks which. The paper's fibre and stains come from the same scan
// as the arena's page, coloured by a ramp of three colours; over it lie an aged edge, washes
// with a dried rim, a darker band behind the title and a dark line along the outline.
//
// The card is printed coarsely: it is worked out in square texels of `texel` pixels, and the
// paper's tones are cut down to a few levels, with a grain that carries one level into the
// next.

/** The card's size in pixels, and a number that changes its tears and stains. */
uniform vec2 card_size = vec2(96.0, 140.0);
uniform float seed = 0.0;

group_uniforms print;
/** Size of a texel in pixels (set by arena_card.gd): 0 for a smooth card. */
uniform float texel : hint_range(0.0, 4.0) = 1.0;
/** Number of tones the paper is cut down to: 0 for all of them. */
uniform float levels : hint_range(0.0, 16.0) = 7.0;

group_uniforms outline;
/** Radius of the corners, in pixels. */
uniform float corner : hint_range(0.0, 24.0) = 5.0;
/** How far the edge wanders slowly, how rough it is close up, and how deep a bite goes; all
 * in pixels. */
uniform float waver : hint_range(0.0, 6.0) = 0.6;
uniform float fray : hint_range(0.0, 3.0) = 0.4;
uniform float bite : hint_range(0.0, 12.0) = 1.6;
/** How much of the edge is bitten. */
uniform float bite_rate : hint_range(0.0, 1.0) = 0.15;
/** How much more the corners are worn away than the sides, in pixels: each corner by its own
 * amount. */
uniform float corner_wear : hint_range(0.0, 16.0) = 2.5;
/** The dark line along the outline: its colour, strength and width in pixels. */
uniform vec3 line_colour : source_color = vec3(0.09, 0.06, 0.04);
uniform float line_strength : hint_range(0.0, 1.0) = 0.8;
uniform float line_width : hint_range(0.0, 4.0) = 1.0;

group_uniforms paper;
/** A scan of paper saved as greys: its grey picks the place on the ramp. */
uniform sampler2D fibre : filter_linear, repeat_enable;
/** Pixels of the scan to one pixel of the card. */
uniform float fibre_scale : hint_range(0.2, 6.0) = 2.0;
uniform float fibre_mid : hint_range(0.0, 1.0) = 0.82;
uniform float fibre_contrast : hint_range(0.0, 8.0) = 1.6;
uniform float mid_at : hint_range(0.0, 1.0) = 0.6;
/** Strength of the fine grain laid over the scan. */
uniform float grain : hint_range(0.0, 0.5) = 0.12;
uniform vec3 paper_dark : source_color = vec3(0.50, 0.38, 0.24);
uniform vec3 paper_mid : source_color = vec3(0.80, 0.70, 0.52);
uniform vec3 paper_light : source_color = vec3(0.94, 0.88, 0.72);

group_uniforms age;
/** The colour the paper turns toward its edge, how far in that reaches in pixels, and how
 * strongly. */
uniform vec3 edge_colour : source_color = vec3(0.36, 0.23, 0.12);
uniform float edge_reach : hint_range(1.0, 60.0) = 14.0;
uniform float edge_strength : hint_range(0.0, 1.0) = 0.6;
/** Washes that dried on the paper: their colour, the colour of their dried rim, how much of
 * the card they cover, how strongly they tint it, and their size in pixels. */
uniform vec3 wash_colour : source_color = vec3(0.62, 0.48, 0.30);
uniform vec3 wash_rim_colour : source_color = vec3(0.42, 0.29, 0.16);
uniform float wash_share : hint_range(0.0, 1.0) = 0.25;
uniform float wash_strength : hint_range(0.0, 1.0) = 0.16;
uniform float wash_rim : hint_range(0.0, 1.0) = 0.14;
uniform float wash_size : hint_range(8.0, 120.0) = 30.0;
/** Softness of a wash's edge. */
uniform float wash_soft : hint_range(0.005, 0.2) = 0.07;
/** A darker band behind the title: its colour, strength, and how far down it comes, in
 * pixels. */
uniform vec3 band_colour : source_color = vec3(0.1, 0.05, 0.1);
uniform float band_strength : hint_range(0.0, 1.0) = 0.0;
uniform float band_height : hint_range(0.0, 120.0) = 30.0;

group_uniforms hatch;
/** Pencil hatching on the stock: its colour (Palette.OUTLINE), strength, the distance between
 * strokes and their width in pixels, their slant from level, and the share of the card the
 * hatched patches take. */
uniform vec3 hatch_colour : source_color = vec3(0.051, 0.012, 0.125);
uniform float hatch_strength : hint_range(0.0, 1.0) = 0.35;
uniform float hatch_spacing : hint_range(2.0, 16.0) = 4.0;
uniform float hatch_width : hint_range(0.5, 4.0) = 1.1;
uniform float hatch_angle : hint_range(-1.6, 1.6) = -0.75;
uniform float hatch_cover : hint_range(0.0, 1.0) = 0.6;

group_uniforms shadow;
uniform vec3 shadow_colour : source_color = vec3(0.01, 0.015, 0.03);
/** The wide soft shadow: how far it falls, how soft it is (both in pixels) and how dark. */
uniform vec2 shadow_offset = vec2(3.0, 6.0);
uniform float shadow_soft : hint_range(1.0, 40.0) = 13.0;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.8;
/** The close dark shadow right under the card's edge. */
uniform float contact_soft : hint_range(0.5, 12.0) = 4.0;
uniform float contact_strength : hint_range(0.0, 1.0) = 0.7;

group_uniforms rim;
/** Light along the card's outline: a thin line on it and a falloff outward over `rim_reach`
 * pixels, which must stay under the margin the card is drawn with (24 pixels). */
uniform vec3 rim_colour : source_color = vec3(1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
uniform float rim_reach : hint_range(1.0, 20.0) = 12.0;

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

// Distance in pixels to a rounded rectangle the size of the card, negative inside.
float box(vec2 p, float radius) {
	vec2 q = abs(p - card_size * 0.5) - card_size * 0.5 + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void vertex() {
	at = VERTEX;
}

void fragment() {
	// Where on the card this pixel is, moved to the middle of its texel.
	vec2 p = texel > 0.0 ? (floor(at / texel) + 0.5) * texel : at;
	vec2 s = p + seed * vec2(37.0, 91.0);
	float pixel = texel > 0.0 ? 0.001 : max(fwidth(at.x) + fwidth(at.y), 0.001);

	// The torn outline.
	float straight = box(p, corner);
	float torn = straight + 0.5
			+ waver * (value_noise(s / 26.0) * 2.0 - 1.0)
			+ fray * (value_noise(s / 1.9) * 2.0 - 1.0)
			+ bite * smoothstep(1.0 - max(bite_rate, 0.001), 1.0, value_noise(s / 8.0 + 7.0))
				* value_noise(s / 3.1 + 3.0);
	vec2 to_side = card_size * 0.5 - abs(p - card_size * 0.5);
	float worn = hash(sign(p - card_size * 0.5) + seed);
	torn += corner_wear * worn * (1.0 - smoothstep(0.0, 16.0, max(to_side.x, to_side.y)))
			* (0.35 + 0.65 * value_noise(s / 4.0 + 13.0));
	float inside = 1.0 - smoothstep(-pixel * 0.6, pixel * 0.6, torn);
	float depth = -torn; // pixels in from the edge

	// The paper.
	float grey = texture(fibre, s * fibre_scale / vec2(textureSize(fibre, 0))).r;
	float t = mid_at + (grey - fibre_mid) * fibre_contrast;
	t += grain * (value_noise(s * vec2(1.4, 0.45)) + value_noise(s * 2.6 + 11.0) - 1.0);
	t = clamp(t, 0.0, 1.0);
	if (levels > 0.0) {
		t = clamp(floor(t * levels + hash(s)) / levels, 0.0, 1.0);
	}
	vec3 col = t < 0.5 ? mix(paper_dark, paper_mid, t * 2.0) : mix(paper_mid, paper_light, t * 2.0 - 1.0);

	// Washes, each with the darker line it dried to.
	float level = 0.6 * value_noise(s / wash_size + 19.0) + 0.3 * value_noise(s / (wash_size * 0.37) + 5.0)
			+ 0.1 * value_noise(s / (wash_size * 0.11) + 41.0);
	float wash_at = 1.0 - wash_share;
	float wash = smoothstep(wash_at - wash_soft, wash_at + wash_soft, level);
	col = mix(col, wash_colour * (0.6 + 0.8 * t), wash * wash_strength);
	col = mix(col, wash_rim_colour, wash * (1.0 - smoothstep(wash_at, wash_at + 0.05, level)) * wash_rim);

	// The band behind the title, with an uneven lower edge.
	float band_edge = band_height + 3.0 * (value_noise(vec2(s.x / 8.0, seed)) - 0.5)
			+ 5.0 * (value_noise(vec2(s.x / 30.0, seed + 3.0)) - 0.5);
	float band = 1.0 - smoothstep(band_edge - 2.0, band_edge + 1.0, p.y);
	col = mix(col, band_colour * (0.7 + 0.6 * t), band * band_strength);
	col = mix(col, band_colour * 0.6, band * smoothstep(band_edge - 3.0, band_edge, p.y) * band_strength * 0.6);

	// Pencil hatching: slanted strokes, each row broken by a noise, in patches.
	vec2 hatch_dir = vec2(cos(hatch_angle), sin(hatch_angle));
	float hatch_across = dot(s, vec2(-hatch_dir.y, hatch_dir.x)) + (value_noise(s / 20.0 + 61.0) - 0.5) * hatch_spacing * 0.4;
	float hatch_along = dot(s, hatch_dir);
	float hatch_row = floor(hatch_across / hatch_spacing);
	float hatch = 1.0 - smoothstep(hatch_width * 0.5 - 0.5, hatch_width * 0.5 + 0.5,
			abs(fract(hatch_across / hatch_spacing) - 0.5) * hatch_spacing);
	float hatch_run = value_noise(vec2(hatch_row * 7.3, hatch_along / (hatch_spacing * 5.0)));
	hatch *= smoothstep(0.35, 0.5, hatch_run) * mix(0.55, 1.0, hatch_run);
	hatch *= smoothstep(1.0 - hatch_cover - 0.1, 1.0 - hatch_cover + 0.1, value_noise(s / 28.0 + 71.0));
	col = mix(col, hatch_colour, hatch * hatch_strength);

	// Age: darker toward the edge, by an uneven amount.
	float reach = edge_reach * (0.45 + 1.1 * value_noise(s / 18.0 + 31.0));
	float aged = 1.0 - smoothstep(0.0, reach, depth);
	col = mix(col, edge_colour * (0.7 + 0.6 * t), aged * aged * edge_strength);

	// The line along the outline, pressed harder in some places than others.
	float press = 0.45 + 0.55 * value_noise(s / 11.0 + 53.0);
	float line = (1.0 - smoothstep(line_width * 0.4, line_width + pixel, depth)) * press;
	col = mix(col, line_colour, line * line_strength);

	// The shadow: a wide soft one that falls away from the card, and a close dark one.
	float cast = shadow_strength * (1.0 - smoothstep(-shadow_soft * 0.5, shadow_soft, box(at - shadow_offset, corner + 4.0)));
	float contact = contact_strength * (1.0 - smoothstep(-contact_soft * 0.3, contact_soft, box(at - shadow_offset * 0.25, corner)));
	float shade = max(cast, contact) * (1.0 - inside);

	float alpha = inside + shade;
	vec3 lit = mix(shadow_colour, col, inside / max(alpha, 0.0001));

	// The rim light, added on top: a 1.5 pixel line on the outline and a glow outside it.
	float rim_line = 1.0 - smoothstep(0.75, 0.75 + pixel + 0.5, abs(torn));
	float out_from = max(torn, 0.0) / rim_reach;
	float rim_fall = 0.55 * (1.0 - smoothstep(0.0, 1.0, out_from)) * (1.0 - smoothstep(0.0, 1.0, out_from));
	float rim = rim_strength * max(rim_line, rim_fall * (1.0 - inside));
	float total = clamp(alpha + rim, 0.0, 1.0);
	COLOR = vec4((lit * alpha + rim_colour * rim) / max(total, 0.0001), total);
}
