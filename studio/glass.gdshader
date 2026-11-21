shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
// Laboratory glass for the bake: clear where it is seen face on and solid along its outline,
// so a vessel is drawn as a line round whatever is behind or inside it. Greyscale like the
// rest of studio/: the bake only records how much light lands.

/** How solid the glass is seen face on: near 0 for clear glass, higher for brown bottles. */
uniform float body : hint_range(0.0, 1.0) = 0.07;
uniform float tone : hint_range(0.0, 1.0) = 0.9;
/** Where the outline starts: lower = a thicker line. */
uniform float edge : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = vec3(tone);
	ALPHA = mix(body, 1.0, smoothstep(edge, edge + 0.3, rim));
	ROUGHNESS = 0.2;
}
