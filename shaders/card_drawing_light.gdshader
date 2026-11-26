shader_type canvas_item;
render_mode blend_add;
// A card's drawn picture as light, added onto whatever lies under it: the halo around the
// picture, the wet reflection under a chosen card, and the three coloured copies of the shift's
// split. What shaders/card_picture.gdshader and shaders/card_copy.gdshader are to a picture
// made of the pencil's ribbons, this is to one baked by studio/card_picture_bake.gd: its lines
// are in the picture's red and the same lines blurred in its green.

/** How much of the light comes from the lines themselves, and how much from their blur. */
uniform float lines : hint_range(0.0, 2.0) = 1.0;
uniform float blur : hint_range(0.0, 4.0) = 0.0;
/** How strongly it shows (set by arena_card.gd for the reflection as it comes and goes). */
uniform float strength : hint_range(0.0, 1.0) = 0.55;
/** It fades out going up the card from `fade_from` (the card's lower edge, the line a
 * reflection is mirrored on), and is gone `fade_reach` pixels up: 0 for no fade. */
uniform float fade_from = 0.0;
uniform float fade_reach : hint_range(0.0, 200.0) = 0.0;

varying float y;
// The colour it is drawn with: in `fragment`, COLOR has already been mixed with the picture.
varying vec3 tint;

void vertex() {
	y = VERTEX.y;
	tint = COLOR.rgb;
}

void fragment() {
	vec4 drawn = texture(TEXTURE, UV);
	float fade = fade_reach > 0.0 ? 1.0 - smoothstep(0.0, fade_reach, fade_from - y) : 1.0;
	COLOR = vec4(tint, min(drawn.r * lines + drawn.g * blur, 1.0) * strength * fade * fade);
}
