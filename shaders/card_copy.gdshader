shader_type canvas_item;
render_mode blend_add;
// A copy of a card's lines in light, added onto whatever lies under it: the wet reflection
// under a chosen card, and the three coloured copies of the shift's split. No screen is read:
// scripts/arena_card.gd draws the card's own ribbons again (built by scripts/pencil.gd: UV.y
// runs -1..1 across, COLOR.a carries the pressure), in the colour they were built with.

/** How strongly the copy shows (set by arena_card.gd for the reflection as it comes and goes). */
uniform float strength : hint_range(0.0, 1.0) = 0.55;
/** How soft the copy's lines are, in the ribbon's units: a reflection is blurred. */
uniform float soft : hint_range(0.0, 1.0) = 0.15;
/** The copy fades out going up the card from `fade_from` (the card's lower edge, the line it
 * is mirrored on), and is gone `fade_reach` pixels up: 0 for no fade. */
uniform float fade_from = 0.0;
uniform float fade_reach : hint_range(0.0, 200.0) = 0.0;

varying float y;

void vertex() {
	y = VERTEX.y;
}

void fragment() {
	float pressure = COLOR.a;
	float line = 1.0 - smoothstep(pressure - soft, pressure + soft, abs(UV.y));
	float fade = fade_reach > 0.0 ? 1.0 - smoothstep(0.0, fade_reach, fade_from - y) : 1.0;
	COLOR = vec4(COLOR.rgb, line * strength * fade * fade);
}
