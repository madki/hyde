shader_type canvas_item;
// The ink on the restraint gauge (scripts/arena_restraint.gd): a blot over every step of the
// track that has been reached, run together into one stain, with arms thrown out of it and
// drops around it. The amount of ink is the reading.
//
// `threat` is the gauge one step short of its end. The blots throw their arms and drops
// wider, the stain's edge shows the ink's pink, and thin runs of ink reach from the last blot
// over the last step of the track. Only then does anything move, and slowly: the edge
// sways and the runs creep out and back.
//
// Drawn by a rectangle laid over the track with room around it; all places are in its pixels.

/** Centre of step 1, the first that takes ink. */
uniform vec2 first = vec2(80.0, 60.0);
/** Distance from one step to the next. */
uniform float pitch = 36.0;
/** How many steps are inked: whole numbers at rest, between them while the ink comes or goes. */
uniform float level = 0.0;
/** 0 to 1: the gauge is one step short of its end. */
uniform float threat = 0.0;
/** Seconds, counted only while there is a threat. */
uniform float clock = 0.0;
/** Changes the blots while keeping the look. */
uniform float seed = 3.0;
/** The size of the rectangle, to let the ink fade out before its edge. */
uniform vec2 rect_size = vec2(300.0, 150.0);

group_uniforms colours;
/** Hyde's ink as it is on the page (arena_paper.gdshader): pale wash, pink, wine, darkest. */
uniform vec3 ink_wash : source_color = vec3(0.415, 0.325, 0.455);
uniform vec3 ink_bloom : source_color = vec3(0.40, 0.21, 0.37);
uniform vec3 ink_body : source_color = vec3(0.29, 0.14, 0.25);
uniform vec3 ink_deep : source_color = vec3(0.13, 0.05, 0.115);
/** How strongly the pale wash around the stain shows. */
uniform float wash_cover : hint_range(0.0, 1.0) = 0.45;

varying vec2 at;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// How far inside the stain a place is, in pixels: under 0 outside it.
float stain(vec2 p) {
	float inside = -1000.0;
	for (int i = 0; i < 7; i++) {
		float grown = clamp(level - float(i), 0.0, 1.0);
		if (grown <= 0.0) {
			break;
		}
		float n = float(i) * 7.3 + seed;
		vec2 centre = first + vec2(float(i) * pitch, 0.0)
				+ (vec2(hash(vec2(n, 1.0)), hash(vec2(n, 2.0))) - 0.5) * vec2(5.0, 6.0);
		vec2 d = p - centre;
		float far = length(d);
		vec2 dir = d / max(far, 0.001);
		// The blot's outline as seen from its centre: lumps, and a few thin arms thrown out.
		// At its narrowest it still covers the round piece of paper under its number.
		float lump = value_noise(dir * 1.7 + n);
		// The clock stands still without a threat, so the arms stay where it left them.
		float arms = pow(value_noise(dir * 5.5 + n * 0.7 + clock * 0.02), 6.0);
		float radius = pitch * (0.6 + 0.16 * lump) + pitch * arms * mix(0.45, 1.1, threat);
		inside = max(inside, radius * smoothstep(0.0, 1.0, grown) - far);
	}
	return inside;
}

// The thin runs of ink that reach from the last blot towards the end of the track: how far
// inside one a place is, in pixels.
float runs(vec2 p) {
	float inside = -1000.0;
	if (threat <= 0.0) {
		return inside;
	}
	vec2 from = first + vec2((level - 1.0) * pitch, 0.0);
	for (int i = 0; i < 3; i++) {
		float n = float(i) * 3.7 + seed;
		// Each creeps out and back on its own slow beat.
		float reach = pitch * threat * (0.72 + 0.3 * hash(vec2(n, 5.0)) + 0.1 * sin(clock * 0.7 + n));
		float along = (p.x - from.x) / max(reach, 0.001);
		float lane = (float(i) - 1.0) * 7.0 + (value_noise(vec2(p.x * 0.09, n)) - 0.5) * 9.0 * along;
		float width = mix(3.6, 1.1, clamp(along, 0.0, 1.0));
		float run = width - abs(p.y - from.y - lane);
		run = min(run, min(p.x - from.x, from.x + reach - p.x) + 1.0);
		// A drop gathers at the end of a run.
		vec2 tip = from + vec2(reach, (float(i) - 1.0) * 7.0 + (value_noise(vec2((from.x + reach) * 0.09, n)) - 0.5) * 9.0);
		inside = max(inside, max(run, 2.6 - length(p - tip)));
	}
	return inside;
}

// Drops thrown around the stain: how far inside one a place is, in pixels.
float drops(vec2 p) {
	float inked = clamp(level, 0.0, 1.0);
	if (inked <= 0.0) {
		return -1000.0;
	}
	float inside = -1000.0;
	float reach = mix(13.0, 30.0, threat);
	float cell_size = 7.0;
	vec2 from = first;
	// With a threat they fall as far as the end of the track.
	float to_x = first.x + max(level - 1.0, 0.0) * pitch + threat * pitch * 0.9;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cell = floor(p / cell_size) + vec2(float(x), float(y));
			vec2 h = vec2(hash(cell + seed), hash(cell * 1.3 + seed + 4.0));
			vec2 centre = (cell + 0.15 + 0.7 * h) * cell_size;
			// How far the drop lies from the stain, taken as a bar along the track.
			float away = length(centre - vec2(clamp(centre.x, from.x, to_x), from.y)) - pitch * 0.5;
			float chance = (1.0 - smoothstep(0.0, reach, away)) * mix(0.45, 0.65, threat) * inked;
			float there = step(hash(cell * 2.1 + seed + 9.0), chance);
			float radius = mix(0.6, 2.7, pow(hash(cell * 1.7 + seed + 2.0), 3.0));
			inside = max(inside, there * radius - (1.0 - there) * 1000.0 - length(p - centre));
		}
	}
	return inside;
}

void vertex() {
	at = VERTEX;
}

void fragment() {
	if (level <= 0.0) {
		discard;
	}
	// With a threat the edge sways: every place is looked up a little aside, slowly changing.
	vec2 sway = vec2(value_noise(at * 0.06 + vec2(clock * 0.11, 3.0)),
			value_noise(at * 0.06 + vec2(17.0, -clock * 0.09))) - 0.5;
	vec2 p = at + sway * 5.0 * threat;
	// The paper's tooth roughens the edge.
	float tooth = (value_noise(p * 0.33 + seed) - 0.5) * 5.0 + (value_noise(p * 1.1 + seed) - 0.5) * 1.6;
	float stained = stain(p) + tooth;
	float inside = max(stained, runs(p) + tooth * 0.25);

	float cover = smoothstep(-0.7, 0.7, inside);
	// Thin at its edge, the ink is wine; thick, nearly black, as its pigment dried.
	float pigment = 0.75 + 0.5 * value_noise(p * 0.12 + seed + 30.0);
	vec3 col = mix(ink_body, ink_deep, clamp(smoothstep(0.0, pitch * 0.22, inside) * pigment, 0.0, 1.0));
	// The stain's edge: a dark line where it dried, or with a threat the pink of wet ink.
	float rim = 1.0 - smoothstep(0.0, 3.0, inside);
	col = mix(col, mix(ink_deep, ink_bloom * 1.25, threat), rim * mix(0.5, 0.85, threat));
	// A pale wash lies around the stain.
	float halo = 6.0 + 7.0 * value_noise(p * 0.07 + seed + 11.0);
	float wash = smoothstep(-halo, -halo * 0.2, stained) * wash_cover;
	float drop = smoothstep(-0.6, 0.6, drops(at));

	vec3 out_col = mix(ink_wash, col, cover);
	float alpha = wash + cover * (1.0 - wash);
	out_col = mix(out_col, ink_deep, drop);
	alpha = max(alpha, drop);
	// No ink reaches the rectangle's edge.
	vec2 edge = min(at, rect_size - at);
	alpha *= smoothstep(0.0, 6.0, min(edge.x, edge.y));
	COLOR = vec4(out_col, alpha);
}
