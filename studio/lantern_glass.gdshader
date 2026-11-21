shader_type spatial;
render_mode unshaded, cull_disabled;
// Glowing pane of a street lantern: white at the heart of each pane, dimmer towards its frame,
// so the baked light pass has a hot core and coloured edges instead of a flat white box.
// Made for a four-sided CylinderMesh (one pane per quarter of U, the sides in the top half of V).

/** Brightness at the frame, relative to the middle of the pane. */
uniform float edge : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec2 p = vec2(fract(UV.x * 4.0), clamp(UV.y * 2.0, 0.0, 1.0)) * 2.0 - 1.0;
	float d = length(p * vec2(0.9, 0.8));
	ALBEDO = vec3(mix(1.0, edge, smoothstep(0.15, 1.1, d)));
}
