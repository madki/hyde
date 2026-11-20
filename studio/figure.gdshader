shader_type spatial;
// Material for the Jekyll / Hyde figures in the street scenes.
//
// In the light passes it is plain dark cloth. In the bake's "figure" pass (`data_pass` on) it
// writes drawing data instead of colour, which shaders/background.gdshader turns into the
// inked look at runtime:
//
//   R = figure mask + form shading (0 = not the figure, 0.3..1 = dark fold .. lit top)
//   G = rim highlight on edges that face screen-left (the key lamp side)
//   B = rim highlight on edges that face screen-right (the wall lantern side)

/** Set by studio/bake.gd; leave off. */
uniform bool data_pass = false;
uniform vec3 cloth : source_color = vec3(0.05, 0.05, 0.06);
/** Higher = thinner rim highlights. */
uniform float rim_power : hint_range(0.5, 8.0) = 3.5;
/** How far round the body each rim reaches. */
uniform float rim_wrap : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	if (data_pass) {
		vec3 n = normalize(NORMAL);
		float fresnel = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), rim_power);
		float left = fresnel * smoothstep(-rim_wrap, 0.6, -n.x + n.y * 0.25);
		float right = fresnel * smoothstep(-rim_wrap, 0.6, n.x + n.y * 0.25);
		float shade = clamp(n.y * 0.6 + 0.5, 0.0, 1.0);
		ALBEDO = vec3(0.0);
		EMISSION = vec3(0.3 + 0.7 * shade, left, right);
	} else {
		ALBEDO = cloth;
		ROUGHNESS = 0.9;
	}
}
