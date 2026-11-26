shader_type canvas_item;
// A card's picture printed from a drawing (art/card_pictures, baked by
// studio/card_picture_bake.gd): the drawing's lines, kept in the picture's red, in the colour
// scripts/arena_card.gd draws it with.

// The colour it is drawn with: in `fragment`, COLOR has already been mixed with the picture.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	COLOR = vec4(tint.rgb, tint.a * texture(TEXTURE, UV).r);
}
