shader_type canvas_item;
// Street background. Recolours baked greyscale light passes (see studio/bake.gd) and animates
// them, so the whole mood can move between the two faces with one value: `shift`.
//
//   *_a   R = key lamp   G = wall lanterns   B = ambient
//   *_b   R = lit windows   G = mist (distance + ground fog)   B = sky mask
//   *_c   the figure: R = mask + form shading   G = left rim   B = right rim
//
// Mipmaps of the pass textures double as a free blur: they tint the mist and make the glow.
// Every look setting is a parameter: edit them on shaders/background_material.tres.

/** 0 = Jekyll, 1 = Hyde. */
uniform float shift : hint_range(0.0, 1.0) = 0.0;

group_uniforms jekyll;
uniform vec3 jekyll_key : source_color = vec3(0.03, 0.95, 0.92);
uniform vec3 jekyll_wall : source_color = vec3(1.0, 0.12, 0.72);
uniform vec3 jekyll_ambient : source_color = vec3(0.2, 0.16, 0.5);
uniform vec3 jekyll_windows : source_color = vec3(1.0, 0.75, 0.9);
uniform float jekyll_key_power : hint_range(0.0, 3.0) = 1.1;
uniform float jekyll_wall_power : hint_range(0.0, 3.0) = 0.8;
/** How much the flames waver. */
uniform float jekyll_flicker : hint_range(0.0, 1.0) = 0.08;

group_uniforms hyde;
uniform vec3 hyde_key : source_color = vec3(0.55, 0.2, 1.0);
uniform vec3 hyde_wall : source_color = vec3(1.0, 0.06, 0.5);
uniform vec3 hyde_ambient : source_color = vec3(0.34, 0.07, 0.36);
uniform vec3 hyde_windows : source_color = vec3(0.3, 1.0, 0.85);
uniform float hyde_key_power : hint_range(0.0, 3.0) = 1.1;
uniform float hyde_wall_power : hint_range(0.0, 3.0) = 1.0;
uniform float hyde_flicker : hint_range(0.0, 1.0) = 0.5;
/** How far the key lamp dips when it gutters. */
uniform float hyde_gutter : hint_range(0.0, 1.0) = 0.45;

group_uniforms look;
/** Colour of the darkest ink. */
uniform vec3 ink : source_color = vec3(0.055, 0.02, 0.13);
/** Contrast of the baked light: higher keeps the light tighter around the lamps. */
uniform float light_contrast : hint_range(0.5, 3.0) = 1.45;
uniform float light_gain : hint_range(0.0, 3.0) = 1.5;
/** Black level of the baked lamp light: anything dimmer stays ink. Raise it if the lamp colours
 * wash over the whole street, lower it to let the light reach further. */
uniform float light_floor : hint_range(0.0, 0.5) = 0.16;
/** Overall brightness, applied last. */
uniform float exposure : hint_range(0.2, 2.0) = 1.0;
uniform float ambient_strength : hint_range(0.0, 2.0) = 0.45;
/** Soft halo around the lamps. */
uniform float glow : hint_range(0.0, 3.0) = 1.9;
/** Brush rings in the halos: 0 = smooth glow, 1 = bold strokes that curl round each lamp. */
uniform float swirl : hint_range(0.0, 1.0) = 0.75;
/** How many brush rings fit in a halo. */
uniform float swirl_rings : hint_range(1.0, 20.0) = 11.0;
/** Pen hatching in the shadows and the sky. */
uniform float hatch : hint_range(0.0, 1.0) = 0.35;
/** Pen strokes across the height of the picture. */
uniform float hatch_density : hint_range(40.0, 400.0) = 150.0;
/** How far into the mid-tones the hatching reaches. */
uniform float hatch_reach : hint_range(0.05, 1.0) = 0.42;
/** Uneven watercolour wash over everything. */
uniform float wash : hint_range(0.0, 1.0) = 0.5;
/** Unsteady hand: how far drawn lines wander. */
uniform float wobble : hint_range(0.0, 0.01) = 0.0018;
/** Wide wash of lamp colour over the whole street. */
uniform float bloom : hint_range(0.0, 3.0) = 0.35;
/** Drifting fog that takes the colour of the nearest lamp. 0 = none. */
uniform float mist : hint_range(0.0, 1.0) = 0.3;
/** How brightly the lamps light the fog. */
uniform float mist_light : hint_range(0.0, 3.0) = 1.0;
uniform float outline : hint_range(0.0, 1.0) = 0.85;
uniform float sky_clouds : hint_range(0.0, 2.0) = 1.1;
/** How much the lamps light the sky. */
uniform float sky_light : hint_range(0.0, 3.0) = 0.3;
uniform float grain : hint_range(0.0, 1.0) = 0.2;
uniform float vignette : hint_range(0.0, 2.0) = 0.9;

group_uniforms figure;
/** Brightness of the inked rim highlights on the figure. */
uniform float figure_rim : hint_range(0.0, 3.0) = 1.0;
/** Where the rim highlight cuts off: lower = wider highlights. */
uniform float figure_rim_edge : hint_range(0.0, 1.0) = 0.4;
/** 0 = hard comic-book edge on the highlights, higher = airbrushed. */
uniform float figure_rim_soft : hint_range(0.005, 0.5) = 0.05;
/** How much of the real lamp light stays on the figure, under the inked look. */
uniform float figure_baked_light : hint_range(0.0, 1.0) = 0.3;
/** Pen hatching in the figure's shadows. */
uniform float figure_hatch : hint_range(0.0, 1.0) = 0.5;

group_uniforms motion;
/** Speed of the flame flicker. */
uniform float flicker_speed : hint_range(0.0, 4.0) = 1.0;
/** Drift speed of the sky clouds and the mist. */
uniform float cloud_speed : hint_range(0.0, 4.0) = 1.0;
/** Slow zoom in and out. */
uniform float breathing : hint_range(0.0, 0.02) = 0.004;
/** How far near things slide when `sway` moves. */
uniform float parallax_depth : hint_range(0.0, 0.02) = 0.006;

group_uniforms transition;
/** Width of the glowing front where one face bleeds into the other. */
uniform float front_softness : hint_range(0.005, 0.3) = 0.05;
uniform float front_glow : hint_range(0.0, 2.0) = 0.7;
uniform float front_warp : hint_range(0.0, 0.1) = 0.02;
/** 0 = the change spreads as scattered blots, 1 = as a ring from the middle. */
uniform float front_from_centre : hint_range(0.0, 1.0) = 0.48;

group_uniforms textures;
uniform sampler2D jekyll_a : filter_linear_mipmap, repeat_disable;
uniform sampler2D jekyll_b : filter_linear_mipmap, repeat_disable;
uniform sampler2D jekyll_c : filter_linear, repeat_disable;
uniform sampler2D hyde_a : filter_linear_mipmap, repeat_disable;
uniform sampler2D hyde_b : filter_linear_mipmap, repeat_disable;
uniform sampler2D hyde_c : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;

group_uniforms set_by_script;
/** Maps the rect onto the 16:9 bake so it always covers the screen. */
uniform vec2 uv_scale = vec2(1.0);
/** Small view offset (-1..1 on each axis) for parallax, e.g. from the mouse. */
uniform vec2 sway = vec2(0.0);

// Flame flicker, worked out once per vertex instead of per pixel.
varying vec3 flicker;

void vertex() {
	float t = TIME * flicker_speed;
	flicker = vec3(texture(noise_tex, vec2(t * 0.11, 0.37)).r,
			texture(noise_tex, vec2(t * 0.17, 0.71)).g,
			texture(noise_tex, vec2(t * 0.05, 0.13)).b);
}

// Removes the haze the bake leaves in the lamp passes, so unlit areas stay dark.
vec2 lift(vec2 l) {
	return max(l - light_floor, 0.0) / (1.0 - light_floor);
}

// Light amount -> colour: ink, then the pure hue, then blown out to white at the core.
vec3 ramp(float l, vec3 hue) {
	return hue * l * (1.0 - 0.3 * l) + vec3(1.0) * smoothstep(0.75, 1.15, l) * 0.9;
}

vec3 street(sampler2D tex_a, sampler2D tex_b, sampler2D tex_c, vec2 uv, float s) {
	// Parallax: near things slide more than far ones.
	float depth = textureLod(tex_b, uv, 2.0).g; // mist is thicker with distance
	uv += sway * (1.0 - depth) * parallax_depth;
	uv += (texture(noise_tex, uv * vec2(7.1, 4.0)).rg - 0.5) * wobble;

	vec3 a = texture(tex_a, uv).rgb;
	vec3 b = texture(tex_b, uv).rgb;
	vec3 soft = textureLod(tex_a, uv, 4.0).rgb;
	vec3 wide = textureLod(tex_a, uv, 6.5).rgb;
	a.rg = lift(a.rg);
	soft.rg = lift(soft.rg);
	wide.rg = lift(wide.rg);

	// Gas flames: steady for Jekyll, guttering for Hyde.
	float waver = mix(jekyll_flicker, hyde_flicker, s);
	float gutter = smoothstep(0.62, 0.72, flicker.b) * hyde_gutter * s;
	float key_power = mix(jekyll_key_power, hyde_key_power, s)
			* (1.0 + (flicker.r - 0.5) * waver - gutter);
	float wall_power = mix(jekyll_wall_power, hyde_wall_power, s)
			* (1.0 + (flicker.g - 0.5) * waver * 0.7);

	vec3 key_hue = mix(jekyll_key, hyde_key, s);
	vec3 wall_hue = mix(jekyll_wall, hyde_wall, s);
	vec3 ambient_hue = mix(jekyll_ambient, hyde_ambient, s);
	vec3 window_hue = mix(jekyll_windows, hyde_windows, s);

	float key = pow(a.r, light_contrast) * light_gain * key_power;
	float wall = pow(a.g, light_contrast) * light_gain * wall_power;
	float amb = a.b;

	// Ink outlines from the ambient pass (cheap two-tap edge).
	vec2 e = vec2(1.5 / 1920.0, 1.5 / 1080.0);
	float edge = abs(amb - texture(tex_a, uv + vec2(e.x, 0.0)).b)
			+ abs(amb - texture(tex_a, uv + vec2(0.0, e.y)).b);
	float line = 1.0 - smoothstep(0.03, 0.12, edge) * outline;

	vec3 col = ink;
	col += ambient_hue * amb * ambient_strength;
	col += ramp(key, key_hue) + ramp(wall, wall_hue);
	col *= line;
	col += window_hue * b.r * (1.0 + (flicker.g - 0.5) * waver);

	// The figure: an ink silhouette with banded form shading, pen hatching in the shadows
	// and hard rim highlights in the colour of the lamp on each side.
	vec3 c = texture(tex_c, uv).rgb;
	float fig_mask = smoothstep(0.1, 0.25, c.r);
	float shade = clamp((c.r - 0.35) / 0.65, 0.0, 1.0);
	vec3 fig = ink * 0.45 + ambient_hue * (0.22 * step(0.5, shade) + 0.2 * step(0.8, shade));
	float pen = step(0.5, fract((uv.x * 1.78 + uv.y) * 150.0));
	fig *= 1.0 - figure_hatch * pen * (1.0 - step(0.5, shade)) * 0.7;
	fig = mix(fig, col, figure_baked_light);
	float rim_k = smoothstep(figure_rim_edge - figure_rim_soft, figure_rim_edge + figure_rim_soft, c.g);
	float rim_w = smoothstep(figure_rim_edge - figure_rim_soft, figure_rim_edge + figure_rim_soft, c.b);
	rim_k += smoothstep(0.75, 0.8, c.g) * 0.5;
	rim_w += smoothstep(0.75, 0.8, c.b) * 0.5;
	fig += ramp(rim_k * 0.8 * key_power, key_hue) * figure_rim + ramp(rim_w * 0.8 * wall_power, wall_hue) * figure_rim;
	col = mix(col, fig, fig_mask);

	// Sky: ink wash clouds.
	float t = TIME * cloud_speed;
	vec3 n = texture(noise_tex, uv * vec2(1.6, 0.9) + vec2(t * 0.012, t * 0.004)).rgb;
	vec3 n2 = texture(noise_tex, uv * vec2(3.1, 1.7) - vec2(t * 0.02, 0.0)).rgb;
	vec3 sky = mix(ink, ambient_hue, 0.3) * (0.55 + n.r * sky_clouds)
			+ ambient_hue * 0.3 * n2.g * n.g * sky_clouds
			+ (key_hue * (wide.r + soft.r * 0.5) * key_power + wall_hue * (wide.g + soft.g * 0.5) * wall_power) * sky_light;
	col = mix(col, sky, b.b);

	// Pen hatching: slanted strokes that thicken as the picture darkens, crossed in the
	// deepest shadow. Each stroke breaks up along its length so it reads as drawn.
	vec2 q = uv * vec2(1.78, 1.0);
	float lum = dot(col, vec3(0.35, 0.45, 0.2));
	vec2 r1 = vec2(q.x * 0.64 + q.y * 0.77, q.x * 0.77 - q.y * 0.64);
	vec2 r2 = vec2(q.x * 0.94 - q.y * 0.34, q.x * 0.34 + q.y * 0.94);
	float b1 = texture(noise_tex, r1 * vec2(1.3, 37.0)).g;
	float b2 = texture(noise_tex, r2 * vec2(1.7, 29.0) + 0.5).r;
	float l1 = abs(fract(r1.y * hatch_density + b1 * 1.5) - 0.5) * 2.0;
	float l2 = abs(fract(r2.y * hatch_density * 0.8 + b2 * 1.5) - 0.5) * 2.0;
	float tone1 = (1.0 - smoothstep(0.0, hatch_reach, lum)) * (0.25 + 1.1 * b1);
	float tone2 = (1.0 - smoothstep(0.0, hatch_reach * 0.45, lum)) * (0.25 + 1.1 * b2);
	float strokes = max(smoothstep(1.0 - tone1 * 0.8, 1.15 - tone1 * 0.8, 1.0 - l1),
			smoothstep(1.0 - tone2 * 0.7, 1.15 - tone2 * 0.7, 1.0 - l2));
	col = mix(col, col * 0.3 + ink * 0.25, strokes * hatch * (1.0 - fig_mask));

	// Halos are painted in rings: the blurred light itself is the distance from each lamp,
	// so bands of it curl round every lantern, and the drifting noise bends them into strokes.
	float turn = (n.r - 0.5) * 2.2 + n2.g * 1.4 - t * 0.12;
	vec2 halo = log(soft.rg * 0.7 + wide.rg + 0.05) * swirl_rings;
	vec2 brush = smoothstep(-0.35, 0.35, sin(halo + turn));
	vec2 stroke = mix(vec2(1.0), 0.5 + 1.1 * brush, swirl);

	// Mist takes the colour of whatever lamp is near it, and drifts.
	float fog = pow(b.g * (1.0 - b.b * 0.3), 1.6) * (0.35 + 2.6 * n.g * n2.b);
	vec3 fog_col = ink * 1.5 + ambient_hue * 0.12
			+ key_hue * (pow(wide.r, 1.5) * 5.0 + soft.r * soft.r * 1.2) * key_power * mist_light
			+ wall_hue * (pow(wide.g, 1.5) * 5.0 + soft.g * soft.g * 1.2) * wall_power * mist_light;
	col = mix(col, fog_col, clamp(fog, 0.0, 1.0) * mist);

	// Glow around the lamps and a wide wash of their colour.
	col += (key_hue * soft.r * soft.r * key_power * stroke.r
			+ wall_hue * soft.g * soft.g * wall_power * stroke.g) * glow;
	col += (key_hue * wide.r * key_power * stroke.r
			+ wall_hue * wide.g * wall_power * stroke.g) * bloom;
	// Watercolour: the wash pools unevenly on the paper.
	col *= mix(1.0, 0.62 + 0.8 * texture(noise_tex, uv * vec2(2.3, 1.3) + 0.21).r, wash);
	// Where two lamp colours pile up, keep the hue instead of clipping to white.
	col *= exposure;
	float peak = max(col.r, max(col.g, col.b));
	return mix(col / max(1.0, peak), vec3(1.0), smoothstep(1.6, 3.2, peak) * 0.7);
}

void fragment() {
	vec2 uv = (UV - 0.5) * uv_scale + 0.5;
	uv = (uv - 0.5) * (1.0 - parallax_depth * 2.5 + breathing * sin(TIME * 0.13)) + 0.5;

	vec3 col;
	if (shift <= 0.001) {
		col = street(jekyll_a, jekyll_b, jekyll_c, uv, 0.0);
	} else if (shift >= 0.999) {
		col = street(hyde_a, hyde_b, hyde_c, uv, 1.0);
	} else {
		// The change bleeds in like ink through wet paper, with a hot edge and a wobble.
		float centre = 1.0 - clamp(length((uv - vec2(0.5, 0.58)) * vec2(1.0, 1.3)) * 1.25, 0.0, 1.0);
		float blot = (texture(noise_tex, uv * vec2(1.1, 0.62)).r * 0.77
				+ texture(noise_tex, uv * vec2(3.6, 2.0) + 0.3).g * 0.23) * (1.0 - front_from_centre)
				+ centre * front_from_centre;
		float front = shift * (1.0 + front_softness * 4.0) - front_softness * 2.0;
		float m = 1.0 - smoothstep(front - front_softness, front + front_softness, 1.0 - blot);
		float rim = 1.0 - abs(m - 0.5) * 2.0;
		vec2 warp = (texture(noise_tex, uv * 2.0 + TIME * 0.05).rg - 0.5) * front_warp * rim;
		vec3 j = street(jekyll_a, jekyll_b, jekyll_c, uv + warp, shift);
		vec3 h = street(hyde_a, hyde_b, hyde_c, uv - warp, shift);
		col = mix(j, h, m);
		col += mix(jekyll_key, hyde_wall, shift) * rim * rim * rim * front_glow;
	}

	// Paper grain and vignette.
	float g = texture(noise_tex, FRAGCOORD.xy / 512.0 * 3.7
			+ fract(floor(TIME * 12.0) * vec2(0.37, 0.61))).b;
	col *= 1.0 - grain * 0.5 + g * grain;
	vec2 v = UV - 0.5;
	col *= 1.0 - dot(v, v) * vignette;
	COLOR = vec4(col, 1.0);
}
