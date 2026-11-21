shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
// Draws one moment of Jekyll turning into Hyde, for studio/figure_bake.gd. Desktop only.
//
// Both figures are distance fields (studio/figure_sdf.gd), so one can be blended into the other
// like clay. This shader finds the surface of that clay along each pixel's ray and writes the
// same drawing data as studio/figure.gdshader (see studio/figure_data.gdshaderinc), so the game
// inks and lights it like the still figures.
//
// The change is one smooth move: Jekyll turns to liquid, the liquid flows into Hyde's shape,
// and it sets. While liquid, the surface loses its small detail, swells a little so the blend
// never runs thin, and shines like poured metal. The game plays the same frames backwards for
// Hyde turning into Jekyll.

#include "res://studio/figure_data.gdshaderinc"

/** Seconds into the change, 0..`duration`. */
uniform float time = 0.0;

group_uniforms moves;
/** Seconds the figure takes to turn liquid at the start, and to set at the end. */
uniform float liquid_time = 0.3;
/** The shape flows from one man to the other between these times, as shares of `duration`. */
uniform float flow_from : hint_range(0.0, 1.0) = 0.12;
uniform float flow_to : hint_range(0.0, 1.0) = 0.88;
/** How far the liquid puffs out, in metres, and how much more half-way through the flow, where
 * a blend of two shapes runs thinnest. */
uniform float swell = 0.02;
uniform float swell_midway = 1.6;
/** How deep the slow swells in the liquid's surface are, in metres. 0 = glass smooth. */
uniform float boil = 0.008;
/** Swells per metre: low is heavy liquid, high turns it to cloud. */
uniform float boil_scale = 2.0;
uniform float boil_speed = 1.2;
/** How far the liquid's surface is smoothed, in metres: buttons, folds and fingers melt away. */
uniform float smoothing = 0.03;

group_uniforms liquid_look;
/** How much of the form shading turns into bands of reflection, like polished metal. */
uniform float chrome : hint_range(0.0, 1.0) = 0.85;
/** Bands of reflection across the body. */
uniform float chrome_bands = 6.5;
/** Brightness of the highlights the lamps throw on the liquid. */
uniform float shine : hint_range(0.0, 2.0) = 1.0;
/** Higher = smaller, sharper highlights. */
uniform float gloss = 22.0;

group_uniforms set_by_script;
uniform sampler3D jekyll_field : filter_linear, repeat_disable;
uniform sampler3D hyde_field : filter_linear, repeat_disable;
uniform vec3 jekyll_box_pos;
uniform vec3 jekyll_box_size;
uniform vec3 hyde_box_pos;
uniform vec3 hyde_box_size;
/** World space -> each figure's own space. */
uniform mat4 jekyll_from_world;
uniform mat4 hyde_from_world;
/** How much larger or smaller than his model Hyde stands in the street. */
uniform float hyde_scale = 1.0;
/** Length of the whole change in seconds. */
uniform float duration = 1.5;
/** The street camera: its transform and the tangent of half its field of view (x, y). */
uniform mat4 camera;
uniform vec2 view_tan;
/** The part of the full picture this render covers: x, y, width, height in 0..1, y down. */
uniform vec4 crop = vec4(0.0, 0.0, 1.0, 1.0);
/** Centre and radius of a ball that holds everything, in world space. */
uniform vec4 bounds;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0); // cover the whole picture
}

float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

// Smooth lumps, -1..1.
float lumps(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z) * 2.0 - 1.0;
}

float jekyll(vec3 p) {
	vec3 q = clamp(p, jekyll_box_pos + 0.006, jekyll_box_pos + jekyll_box_size - 0.006);
	return texture(jekyll_field, (q - jekyll_box_pos) / jekyll_box_size).r + length(p - q);
}

float hyde(vec3 p) {
	vec3 q = clamp(p, hyde_box_pos + 0.006, hyde_box_pos + hyde_box_size - 0.006);
	// The field is in Hyde's own metres; `hyde_scale` turns it into the world's.
	return (texture(hyde_field, (q - hyde_box_pos) / hyde_box_size).r + length(p - q)) * hyde_scale;
}

// The figures with their surface smoothed over `r` metres.
float jekyll_smooth(vec3 p, float r) {
	if (r < 0.002) {
		return jekyll(p);
	}
	vec2 e = vec2(r, 0.0);
	return (jekyll(p) * 2.0 + jekyll(p + e.xyy) + jekyll(p - e.xyy) + jekyll(p + e.yxy)
			+ jekyll(p - e.yxy) + jekyll(p + e.yyx) + jekyll(p - e.yyx)) / 8.0;
}

float hyde_smooth(vec3 p, float r) {
	if (r < 0.002) {
		return hyde(p);
	}
	vec2 e = vec2(r, 0.0);
	return (hyde(p) * 2.0 + hyde(p + e.xyy) + hyde(p - e.xyy) + hyde(p + e.yxy)
			+ hyde(p - e.yxy) + hyde(p + e.yyx) + hyde(p - e.yyx)) / 8.0;
}

// How liquid the figure is at `time`: 0 at both ends, where it has to match the still men.
float wetness() {
	return smoothstep(0.0, liquid_time, time) * (1.0 - smoothstep(duration - liquid_time, duration, time));
}

// How far the shape has flowed from Jekyll's (0) to Hyde's (1).
float flowed() {
	return smoothstep(flow_from * duration, flow_to * duration, time);
}

// Distance from world point `p` to the surface at `time` (negative inside).
float clay(vec3 p) {
	vec3 pj = (jekyll_from_world * vec4(p, 1.0)).xyz;
	vec3 ph = (hyde_from_world * vec4(p, 1.0)).xyz;
	float wet = wetness();
	float flow = flowed();
	float r = smoothing * wet;
	float d = mix(jekyll_smooth(pj, r), hyde_smooth(ph, r), flow);
	d -= swell * wet * (1.0 + swell_midway * sin(flow * PI));
	// Broad slow swells drifting down the surface.
	vec3 drift = vec3(0.0, -time * boil_speed, time * boil_speed * 0.6);
	return d + lumps(p * boil_scale + drift) * boil * wet;
}

void fragment() {
	vec2 at = (crop.xy + SCREEN_UV * crop.zw) * 2.0 - 1.0;
	vec3 ray_view = normalize(vec3(at.x * view_tan.x, -at.y * view_tan.y, -1.0));
	vec3 ray = mat3(camera) * ray_view;
	vec3 eye = camera[3].xyz;

	// Only walk the part of the ray that passes through the ball holding the figures.
	vec3 oc = eye - bounds.xyz;
	float b = dot(oc, ray);
	float disc = b * b - dot(oc, oc) + bounds.w * bounds.w;
	if (disc <= 0.0) {
		discard;
	}
	float along = max(-b - sqrt(disc), 0.0);
	float end = -b + sqrt(disc);
	bool hit = false;
	for (int i = 0; i < 320 && along < end; i++) {
		float d = clay(eye + ray * along);
		if (d < 0.0012) {
			hit = true;
			break;
		}
		along += max(d * 0.55, 0.0015);
	}
	if (!hit) {
		discard; // nothing here: the figure layer stays clear
	}
	vec3 p = eye + ray * along;
	float wet = wetness();
	vec2 e = vec2(0.007 + 0.012 * wet, 0.0); // liquid has no small creases
	vec3 n_world = normalize(vec3(clay(p + e.xyy) - clay(p - e.xyy),
			clay(p + e.yxy) - clay(p - e.yxy), clay(p + e.yyx) - clay(p - e.yyx)));
	vec3 n = n_world * mat3(camera); // world -> view
	// Lit by Jekyll's street at first and by Hyde's by the end.
	vec3 data = figure_data(n, -ray_view, p, n_world, flowed(), -along * ray_view.z);
	if (!depth_pass) {
		// Liquid shine: what the surface mirrors folds into bands as it curves, and each lamp
		// throws a hard highlight that slides over it.
		vec3 mirrored = reflect(ray_view, n);
		float bands = 0.5 + 0.5 * sin(mirrored.y * chrome_bands + n.x * 2.0);
		data.r = mix(data.r, 0.3 + 0.7 * bands, wet * chrome);
		float glint_left = pow(max(dot(mirrored, normalize(vec3(-0.55, 0.45, 0.7))), 0.0), gloss);
		float glint_right = pow(max(dot(mirrored, normalize(vec3(0.6, 0.35, 0.7))), 0.0), gloss);
		data.g = max(data.g, glint_left * shine * wet);
		data.b = max(data.b, glint_right * shine * wet);
	}
	ALBEDO = data;
}
