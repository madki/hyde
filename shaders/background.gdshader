shader_type canvas_item;
// Street background. Recolours baked greyscale light passes (see studio/bake.gd) and animates
// them, so the whole mood can move between the two faces with one value: `shift`.
//
//   *_a   R = key lamp   G = wall lanterns   B = ambient
//   *_b   R = lit windows   G = mist (distance + ground fog)   B = sky mask
//
// The streets are baked with nobody in them. The men are a layer of their own, drawn over the
// street and under its mist and glow (see studio/figure_bake.gd):
//
//   figures        RGB = drawing data: form shading, light from the key lamp's side, light
//                  from the wall lanterns' side;  A = how much of the pixel the figure covers.
//                  One sheet: the flipbook of one man turning into the other, and under it the
//                  two men standing still. scripts/background.gd picks what is shown.
//   figures_depth  how far the figure is from the camera, same layout at half the size
//
// A canvas shader gets eight textures in the Compatibility renderer (this one uses seven): a
// ninth silently breaks the others.
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
/** How bright the fog is where no lamp reaches it. */
uniform float mist_glow : hint_range(0.0, 2.0) = 0.12;
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
/** How much of the lamps' glow the figure hides where he stands in front of it. */
uniform float figure_blocks_glow : hint_range(0.0, 1.0) = 0.85;
/** How quickly distance hazes the figure and slows its parallax. Matches the fog the streets
 * were baked with, so a figure sits in the mist like the things beside it. */
uniform float figure_haze : hint_range(0.0, 0.2) = 0.028;
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

group_uniforms textures;
uniform sampler2D jekyll_a : filter_linear_mipmap, repeat_disable;
uniform sampler2D jekyll_b : filter_linear_mipmap, repeat_disable;
uniform sampler2D hyde_a : filter_linear_mipmap, repeat_disable;
uniform sampler2D hyde_b : filter_linear_mipmap, repeat_disable;
uniform sampler2D figures : filter_linear, repeat_disable;
uniform sampler2D figures_depth : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;

group_uniforms set_by_script;
/** Maps the rect onto the 16:9 bake so it always covers the screen. */
uniform vec2 uv_scale = vec2(1.0);
/** The point of the bake that stays put when it is cropped to fit: 0.5 = its centre. */
uniform vec2 uv_anchor = vec2(0.5);
/** Small view offset (-1..1 on each axis) for parallax, e.g. from the mouse. */
uniform vec2 sway = vec2(0.0);
/** Which man each street shows: -1 = its own, 0 = Jekyll in both, 1 = Hyde in both. */
uniform float figure_face = -1.0;
/** How far the figure's outline wanders, as a fraction of the picture. 0 = still. */
uniform float figure_wobble = 0.0;
/** 0 = the still man chosen above, 1 = the flipbook frame below. */
uniform float morph_mix = 0.0;
/** Which flipbook frame: a whole number shows that frame, between two it blends them. */
uniform float morph_frame = 0.0;
uniform float morph_frames = 36.0;
/** Flipbook frames across and down the figure sheet. */
uniform vec2 morph_grid = vec2(6.0, 6.0);
/** Width of one flipbook frame, and of one still man, on the figure sheet in pixels. */
uniform float morph_frame_px = 512.0;
uniform float figure_still_px = 768.0;
/** The part of the picture the figure layer covers: x, y, width, height. */
uniform vec4 figure_rect = vec4(0.0, 0.0, 1.0, 1.0);
/** Distances from the camera, in metres, that the depth sheet's 0 and 1 stand for. */
uniform vec2 figure_depth_range = vec2(1.0, 6.0);

// Flame flicker, worked out once per vertex instead of per pixel.
varying vec3 flicker;

void vertex() {
	float t = TIME * flicker_speed;
	flicker = vec3(texture(noise_tex, vec2(t * 0.11, 0.37)).r,
			texture(noise_tex, vec2(t * 0.17, 0.71)).g,
			texture(noise_tex, vec2(t * 0.05, 0.13)).b);
}

// Where on the figure sheet to read a picture `size` pixels wide whose corner is at `corner`,
// for the point `f` (0..1 across the figure layer's part of the picture).
vec2 on_sheet(vec2 corner, float size, vec2 f) {
	float edge = 0.5 / size; // keep the neighbouring pictures from bleeding in
	return (corner + clamp(f, edge, 1.0 - edge) * size) / vec2(textureSize(figures, 0));
}

// Where the figure layer keeps what it shows at `uv`: the still man (`own` = this street's:
// 0 Jekyll, 1 Hyde) and the current flipbook frame. Returns 0 outside the layer.
float figure_places(float own, vec2 uv, out vec2 still, out vec2 frame, out vec2 next) {
	vec2 f = (uv - figure_rect.xy) / figure_rect.zw;
	float face = figure_face < 0.0 ? own : figure_face;
	still = on_sheet(vec2(step(0.5, face) * figure_still_px, morph_grid.y * morph_frame_px),
			figure_still_px, f);
	float a = floor(morph_frame);
	float b = min(a + 1.0, morph_frames - 1.0);
	frame = on_sheet(vec2(mod(a, morph_grid.x), floor(a / morph_grid.x)) * morph_frame_px,
			morph_frame_px, f);
	next = on_sheet(vec2(mod(b, morph_grid.x), floor(b / morph_grid.x)) * morph_frame_px,
			morph_frame_px, f);
	// Beside and above the layer there is no figure; below it the last row carries on.
	return step(0.0, f.x) * step(f.x, 1.0) * step(0.0, f.y);
}

// How deep into the street's haze the figure is at `uv` (0 = at the camera): the same measure
// the streets' mist pass gives for everything else.
float figure_haze_at(float own, vec2 uv) {
	vec2 still;
	vec2 frame;
	vec2 next;
	figure_places(own, uv, still, frame, next);
	float d = texture(figures_depth, still).r;
	if (morph_mix > 0.0) {
		d = mix(d, mix(texture(figures_depth, frame).r, texture(figures_depth, next).r,
				fract(morph_frame)), morph_mix);
	}
	return 1.0 - exp(-figure_haze * mix(figure_depth_range.x, figure_depth_range.y, d));
}

// The figure layer at `uv`: rgb = drawing data, a = how much of the pixel the figure covers.
vec4 figure(float own, vec2 uv) {
	if (figure_wobble > 0.0) {
		// Redrawn twelve times a second, like the grain: the outline boils instead of sliding.
		vec2 drift = floor(TIME * 12.0) * vec2(0.071, 0.043);
		uv += (texture(noise_tex, uv * vec2(2.6, 1.5) + drift).rg - 0.5) * figure_wobble;
	}
	vec2 still;
	vec2 frame;
	vec2 next;
	float inside = figure_places(own, uv, still, frame, next);
	vec4 c = texture(figures, still);
	if (morph_mix > 0.0) {
		c = mix(c, mix(texture(figures, frame), texture(figures, next), fract(morph_frame)), morph_mix);
	}
	c *= inside;
	c.rgb /= max(c.a, 0.001); // the sheet holds data already scaled by coverage
	return c;
}

// Removes the haze the bake leaves in the lamp passes, so unlit areas stay dark.
vec2 lift(vec2 l) {
	return max(l - light_floor, 0.0) / (1.0 - light_floor);
}

// Light amount -> colour: ink, then the pure hue, then blown out to white at the core.
vec3 ramp(float l, vec3 hue) {
	return hue * l * (1.0 - 0.3 * l) + vec3(1.0) * smoothstep(0.75, 1.15, l) * 0.9;
}

// `own` is the man who belongs in this street: 0 = Jekyll, 1 = Hyde.
vec3 street(sampler2D tex_a, sampler2D tex_b, float own, vec2 uv, float s) {
	// Parallax: near things slide more than far ones.
	float depth = textureLod(tex_b, uv, 2.0).g; // mist is thicker with distance
	// The figure is a layer of its own, so it slides by its own depth, across the street.
	float fig_haze = figure_haze_at(own, uv);
	vec2 fig_uv = uv + sway * (1.0 - fig_haze) * parallax_depth;
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

	// The figure layer: an ink silhouette with banded form shading, pen hatching in the
	// shadows and hard-edged light in the colour of the lamp on each side.
	vec4 c = figure(own, fig_uv);
	float fig_mask = c.a;
	float shade = clamp((c.r - 0.35) / 0.65, 0.0, 1.0);
	vec3 fig = ink * 0.45 + ambient_hue * (0.22 * step(0.5, shade) + 0.2 * step(0.8, shade));
	float pen = step(0.5, fract((fig_uv.x * 1.78 + fig_uv.y) * 150.0));
	fig *= 1.0 - figure_hatch * pen * (1.0 - step(0.5, shade)) * 0.7;
	float rim_k = smoothstep(figure_rim_edge - figure_rim_soft, figure_rim_edge + figure_rim_soft, c.g);
	float rim_w = smoothstep(figure_rim_edge - figure_rim_soft, figure_rim_edge + figure_rim_soft, c.b);
	rim_k += smoothstep(0.75, 0.8, c.g) * 0.5;
	rim_w += smoothstep(0.75, 0.8, c.b) * 0.5;
	fig += ramp(rim_k * 0.8 * key_power, key_hue) * figure_rim + ramp(rim_w * 0.8 * wall_power, wall_hue) * figure_rim;
	col = mix(col, fig, fig_mask);
	// From here on the mist, the glow and the wash go over street and figure alike; the mist
	// is as thick as the distance to whichever of them is in front.
	b.g = mix(b.g, fig_haze, fig_mask);

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
	vec3 fog_col = ink * 1.5 + ambient_hue * mist_glow
			+ key_hue * (pow(wide.r, 1.5) * 5.0 + soft.r * soft.r * 1.2) * key_power * mist_light
			+ wall_hue * (pow(wide.g, 1.5) * 5.0 + soft.g * soft.g * 1.2) * wall_power * mist_light;
	col = mix(col, fog_col, clamp(fog, 0.0, 1.0) * mist);

	// Glow around the lamps and a wide wash of their colour.
	// A man standing in front of a lamp hides most of its halo.
	float halo_seen = 1.0 - fig_mask * figure_blocks_glow;
	col += (key_hue * soft.r * soft.r * key_power * stroke.r
			+ wall_hue * soft.g * soft.g * wall_power * stroke.g) * glow * halo_seen;
	col += (key_hue * wide.r * key_power * stroke.r
			+ wall_hue * wide.g * wall_power * stroke.g) * bloom * halo_seen;
	// Watercolour: the wash pools unevenly on the paper.
	col *= mix(1.0, 0.62 + 0.8 * texture(noise_tex, uv * vec2(2.3, 1.3) + 0.21).r, wash);
	// Where two lamp colours pile up, keep the hue instead of clipping to white.
	col *= exposure;
	float peak = max(col.r, max(col.g, col.b));
	return mix(col / max(1.0, peak), vec3(1.0), smoothstep(1.6, 3.2, peak) * 0.7);
}

void fragment() {
	vec2 uv = (UV - uv_anchor) * uv_scale + uv_anchor;
	uv = (uv - 0.5) * (1.0 - parallax_depth * 2.5 + breathing * sin(TIME * 0.13)) + 0.5;

	vec3 col;
	if (shift <= 0.001) {
		col = street(jekyll_a, jekyll_b, 0.0, uv, 0.0);
	} else if (shift >= 0.999) {
		col = street(hyde_a, hyde_b, 1.0, uv, 1.0);
	} else {
		// Part-way: both streets, each already in the in-between colours, laid over each other.
		col = mix(street(jekyll_a, jekyll_b, 0.0, uv, shift), street(hyde_a, hyde_b, 1.0, uv, shift), shift);
	}

	// Paper grain and vignette.
	float g = texture(noise_tex, FRAGCOORD.xy / 512.0 * 3.7
			+ fract(floor(TIME * 12.0) * vec2(0.37, 0.61))).b;
	col *= 1.0 - grain * 0.5 + g * grain;
	vec2 v = UV - 0.5;
	col *= 1.0 - dot(v, v) * vignette;
	COLOR = vec4(col, 1.0);
}
