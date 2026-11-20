// The drawing data both figure shaders write, so the still figures (studio/figure.gdshader)
// and the changing one (studio/morph.gdshader) are inked and lit alike by the game:
//
//   R = form shading (0.3 = dark fold .. 1 = lit top)
//   G = light from the key lamp's side: its real light on the cloth + a rim on edges that face
//       screen-left
//   B = the same for the wall lanterns' side, screen-right
//
// or, with `depth_pass` on, how far the surface is from the camera (0 = near .. 1 = far end of
// `depth_range`). The lamps are the street's own (found by studio/figure_bake.gd).

const int MAX_LAMPS = 8;

/** Set by studio/figure_bake.gd; leave off. */
uniform bool depth_pass = false;
/** Higher = thinner rim highlights. */
uniform float rim_power : hint_range(0.5, 8.0) = 3.5;
/** How far round the body each rim reaches. */
uniform float rim_wrap : hint_range(0.0, 1.0) = 0.15;
/** How strongly the street's lamps light the cloth, next to the rims. */
uniform float lamp_light : hint_range(0.0, 2.0) = 0.1;

group_uniforms set_by_bake;
// Each street's lamps: xyz = place in the world, w = reach in metres; and their brightness.
uniform vec4 key_lamps_jekyll[MAX_LAMPS];
uniform float key_energy_jekyll[MAX_LAMPS];
uniform vec4 wall_lamps_jekyll[MAX_LAMPS];
uniform float wall_energy_jekyll[MAX_LAMPS];
uniform vec4 key_lamps_hyde[MAX_LAMPS];
uniform float key_energy_hyde[MAX_LAMPS];
uniform vec4 wall_lamps_hyde[MAX_LAMPS];
uniform float wall_energy_hyde[MAX_LAMPS];
/** Distances from the camera that the depth pass maps to 0 and 1, in metres. */
uniform vec2 depth_range = vec2(1.0, 6.0);

float lamp(vec4 at, float energy, vec3 p, vec3 n) {
	vec3 to = at.xyz - p;
	float d = length(to);
	return energy * pow(clamp(1.0 - d / max(at.w, 0.01), 0.0, 1.0), 1.4) * max(dot(n, to / d), 0.0);
}

// `n` and `to_eye` are in view space, `p_world` and `n_world` in the world. `street` is whose
// lamps light it: 0 = Jekyll's, 1 = Hyde's, between = part-way. `depth` is metres from the camera.
vec3 figure_data(vec3 n, vec3 to_eye, vec3 p_world, vec3 n_world, float street, float depth) {
	if (depth_pass) {
		return vec3(clamp((depth - depth_range.x) / (depth_range.y - depth_range.x), 0.0, 1.0));
	}
	vec2 lit_j = vec2(0.0);
	vec2 lit_h = vec2(0.0);
	for (int i = 0; i < MAX_LAMPS; i++) {
		lit_j.x += lamp(key_lamps_jekyll[i], key_energy_jekyll[i], p_world, n_world);
		lit_j.y += lamp(wall_lamps_jekyll[i], wall_energy_jekyll[i], p_world, n_world);
		lit_h.x += lamp(key_lamps_hyde[i], key_energy_hyde[i], p_world, n_world);
		lit_h.y += lamp(wall_lamps_hyde[i], wall_energy_hyde[i], p_world, n_world);
	}
	vec2 lit = mix(lit_j, lit_h, street) * lamp_light;
	float fresnel = pow(1.0 - clamp(dot(n, to_eye), 0.0, 1.0), rim_power);
	float left = fresnel * smoothstep(-rim_wrap, 0.6, -n.x + n.y * 0.25);
	float right = fresnel * smoothstep(-rim_wrap, 0.6, n.x + n.y * 0.25);
	float shade = clamp(n.y * 0.6 + 0.5, 0.0, 1.0);
	return vec3(0.3 + 0.7 * shade, clamp(left + lit.x, 0.0, 1.0), clamp(right + lit.y, 0.0, 1.0));
}
