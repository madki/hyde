shader_type canvas_item;
render_mode blend_add;
// The halo around a card's picture: the light its lines give off onto the dark card.
//
// The picture's ribbons (built by scripts/pencil.gd: UV.y runs -1..1 across, COLOR.a carries
// the pressure) are drawn under the printed lines four times by scripts/arena_card.gd, moved
// by `glow_reach` pixels each way. Each copy adds a quarter of `glow_strength`, so the four
// together add the average of the drawing at those four places, in `glow_colour`.

uniform vec3 glow_colour : source_color = vec3(1.0);
/** How far the halo reaches from the lines, in pixels (read by arena_card.gd). */
uniform float glow_reach : hint_range(0.0, 12.0) = 3.0;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	float pressure = COLOR.a;
	float line = 1.0 - smoothstep(pressure * 0.5, pressure + 0.5, abs(UV.y));
	COLOR = vec4(glow_colour, line * glow_strength * 0.25);
}
