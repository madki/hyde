shader_type canvas_item;
// A card's body: cut card stock with a dark outline, hatched in pencil, and the hard shadow it
// throws.
//
// Drawn on a rectangle larger than the card by scripts/arena_card.gd, so that the shadow and
// the rim light have room. Everything is worked out in the card's own pixels. The stock is a
// smooth slant from its light tone at the top to its own tone further down, crossed by even
// slanted strokes; over it lie the ink stain of a Root that is Hyde's, and the rim light of a
// chosen card.

/** The card's size in pixels, and a number that changes where its stain starts. */
uniform vec2 card_size = vec2(96.0, 140.0);
uniform float seed = 0.0;

group_uniforms outline;
/** Radius of the card's corners, and the outline's colour (Palette.OUTLINE) and width. */
uniform float corner : hint_range(0.0, 24.0) = 3.0;
uniform vec3 line_colour : source_color = vec3(0.051, 0.012, 0.125);
uniform float line_width : hint_range(0.0, 4.0) = 1.5;

group_uniforms stock;
/** The stock's light tone, at the top, and its own tone, reached `shade_at` of the way down
 * the slant, and the slant's direction (radians from straight down, toward the left). */
uniform vec3 stock_light : source_color = vec3(0.1647, 0.2745, 0.4471);
uniform vec3 stock : source_color = vec3(0.1059, 0.1843, 0.3216);
uniform float shade_at : hint_range(0.05, 1.0) = 0.7;
uniform float slant : hint_range(-1.6, 1.6) = 0.26;

group_uniforms hatch;
/** Pencil hatching on the stock: its colour (Palette.OUTLINE), strength, the distance between
 * strokes and their width in pixels, and the direction they are spaced along (radians from
 * level, downward). */
uniform vec3 hatch_colour : source_color = vec3(0.051, 0.012, 0.125);
uniform float hatch_strength : hint_range(0.0, 1.0) = 0.34;
uniform float hatch_spacing : hint_range(2.0, 16.0) = 5.0;
uniform float hatch_width : hint_range(0.5, 4.0) = 1.0;
uniform float hatch_angle : hint_range(-1.6, 1.6) = 0.436;

group_uniforms stain;
/** Ink soaked in from one corner of a Root that is Hyde's: how far it has crept (0 to 1, set
 * by arena_card.gd: 0 for no stain), how strongly it shows (for a stain that fades in instead
 * of creeping), and how much of the card's diagonal it reaches once settled. */
uniform float stain : hint_range(0.0, 1.0) = 0.0;
uniform float stain_shown : hint_range(0.0, 1.0) = 1.0;
uniform float stain_reach : hint_range(0.0, 1.5) = 0.5;
uniform float stain_strength : hint_range(0.0, 1.0) = 0.85;
/** The ink's ramp, from the corner out to the front (Palette.INK_DEEP, INK_BODY, INK_BLOOM),
 * and the light on its front (Palette.HYDE): bright while it creeps, `front_rest` once settled. */
uniform vec3 stain_deep : source_color = vec3(0.1216, 0.0118, 0.0902);
uniform vec3 stain_body : source_color = vec3(0.2471, 0.0118, 0.1725);
uniform vec3 stain_bloom : source_color = vec3(0.3686, 0.0627, 0.2510);
uniform vec3 stain_front : source_color = vec3(1.0, 0.3098, 0.6980);
uniform float front_rest : hint_range(0.0, 1.0) = 0.3;

group_uniforms shadow;
/** The hard shadow the card throws: its colour (Palette.OUTLINE) and how far it falls, in
 * pixels. */
uniform vec3 shadow_colour : source_color = vec3(0.051, 0.012, 0.125);
uniform vec2 shadow_offset = vec2(3.0, 4.0);

group_uniforms rim;
/** Light along the card's outline: a solid line just outside it and a falloff outward over
 * `rim_reach` pixels, which must stay under the margin the card is drawn with (24 pixels). */
uniform vec3 rim_colour : source_color = vec3(1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
uniform float rim_reach : hint_range(1.0, 20.0) = 14.0;

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
	vec2 p = at;
	vec2 s = p + seed * vec2(37.0, 91.0);
	// One screen pixel, in the card's pixels: the card may be scaled.
	float pixel = max(length(vec2(fwidth(at.x), fwidth(at.y))) * 0.5, 0.001);

	float edge = box(p, corner);
	float inside = 1.0 - smoothstep(-pixel, pixel, edge);
	float depth = -edge; // pixels in from the edge

	// The stock: a smooth slant from its light tone to its own.
	vec2 down = vec2(sin(slant), cos(slant));
	float across = abs(card_size.x * down.x) + abs(card_size.y * down.y);
	float t = clamp(dot(p - card_size * 0.5, down) / across + 0.5, 0.0, 1.0);
	vec3 col = mix(stock_light, stock, smoothstep(0.0, 1.0, t / shade_at));

	// The ink stain: it soaks in from the corner the seed picks, deep there and blooming
	// toward its uneven front, which is lit.
	if (stain > 0.0) {
		float pick = floor(hash(vec2(seed * 1.37, 17.0)) * 4.0);
		vec2 from = vec2(mod(pick, 2.0), floor(pick * 0.5)) * card_size;
		float diagonal = length(card_size);
		float out_to = length(p - from) + diagonal * (0.16 * (value_noise(s / 14.0 + 83.0) - 0.5)
				+ 0.05 * (value_noise(s / 4.0 + 89.0) - 0.5));
		float front = stain * stain_reach * diagonal;
		float in_by = front - out_to; // pixels behind the front
		float soaked = smoothstep(-0.5, 0.5, in_by);
		float r = clamp(out_to / max(front, 0.001), 0.0, 1.0);
		r = r * r;
		vec3 ink = r < 0.5 ? mix(stain_deep, stain_body, r * 2.0) : mix(stain_body, stain_bloom, r * 2.0 - 1.0);
		col = mix(col, ink, soaked * stain_strength * stain_shown);
		float lit = mix(1.0, front_rest, smoothstep(0.8, 1.0, stain));
		col = mix(col, stain_front, (1.0 - smoothstep(0.4, 1.4, abs(in_by - 0.5))) * lit * stain_shown);
	}

	// Pencil hatching: even slanted strokes over the whole card.
	vec2 hatch_dir = vec2(cos(hatch_angle), sin(hatch_angle));
	float hatch_at = mod(dot(p, hatch_dir), hatch_spacing);
	float hatch = 1.0 - smoothstep(hatch_width - pixel, hatch_width + pixel, hatch_at);
	col = mix(col, hatch_colour, hatch * hatch_strength);

	// The outline.
	float line = 1.0 - smoothstep(line_width - pixel, line_width + pixel, depth);
	col = mix(col, line_colour, line);

	// The hard shadow, under the card and offset from it.
	float shade = (1.0 - smoothstep(-pixel, pixel, box(at - shadow_offset, corner))) * (1.0 - inside);

	float alpha = inside + shade;
	vec3 lit = mix(shadow_colour, col, inside / max(alpha, 0.0001));

	// The rim light, added on top: a 1.5 pixel line just outside the outline and a glow
	// beyond it.
	float outside = max(edge, 0.0);
	float rim_line = 1.0 - smoothstep(1.5 - pixel, 1.5 + pixel, outside);
	float out_from = outside / rim_reach;
	float rim_fall = 0.55 * (1.0 - smoothstep(0.0, 1.0, out_from)) * (1.0 - smoothstep(0.0, 1.0, out_from));
	float rim = rim_strength * max(rim_line, rim_fall) * (1.0 - inside);
	float total = clamp(alpha + rim, 0.0, 1.0);
	COLOR = vec4((lit * alpha + rim_colour * rim) / max(total, 0.0001), total);
}
