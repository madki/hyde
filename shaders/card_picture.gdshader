shader_type canvas_item;
render_mode blend_add;
// The halo around a card's picture: the light its lines give off onto the dark card.
//
// The picture's ribbons (built by scripts/pencil.gd: UV.y runs -1..1 across, COLOR.a carries
// the line's half width as a share of the ribbon's) are drawn under the printed lines by
// scripts/arena_card.gd several times: once in place and in two rings of copies moved a few
// pixels each way, each copy as bright as its COLOR.rgb. Each copy is a soft line, so that
// together they add up to a smooth light around the drawing, in `glow_colour`.

uniform vec3 glow_colour : source_color = vec3(1.0);
/** Half the ribbon's width in pixels (set by arena_card.gd). */
uniform float ribbon_half = 4.0;
/** How far each copy's light spreads past its line, in pixels, and how strong it is. */
uniform float spread : hint_range(0.5, 6.0) = 1.0;
uniform float strength : hint_range(0.0, 2.0) = 0.8;

void fragment() {
	float core = COLOR.a * ribbon_half;
	float out_by = max(abs(UV.y) * ribbon_half - core, 0.0);
	float light = strength * exp(-out_by * out_by / (2.0 * spread * spread));
	// The ribbon's own sides fade out, so that it does not end in a hard edge.
	light *= 1.0 - smoothstep(0.7, 1.0, abs(UV.y));
	COLOR = vec4(glow_colour * COLOR.rgb, light);
}
