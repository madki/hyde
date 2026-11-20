shader_type spatial;
// Material for the Jekyll / Hyde figures in the street scenes.
//
// In the street it is plain dark cloth. When studio/figure_bake.gd draws the figure layer it
// turns `data_pass` on, and the shader writes drawing data instead of colour (see
// studio/figure_data.gdshaderinc), which shaders/background.gdshader turns into the inked look.

#include "res://studio/figure_data.gdshaderinc"

/** Set by studio/figure_bake.gd; leave off. */
uniform bool data_pass = false;
/** Whose lamps light the figure in the data pass: 0 = Jekyll's street, 1 = Hyde's. */
uniform float street = 0.0;
uniform vec3 cloth : source_color = vec3(0.05, 0.05, 0.06);

void fragment() {
	if (data_pass) {
		vec3 n = normalize(NORMAL);
		vec3 p_world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
		ALBEDO = vec3(0.0);
		EMISSION = figure_data(n, normalize(VIEW), p_world, n_world, street, -VERTEX.z);
	} else {
		ALBEDO = cloth;
		ROUGHNESS = 0.9;
	}
}
