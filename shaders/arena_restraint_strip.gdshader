shader_type canvas_item;
// The strip under the restraint gauge's numbers (scripts/arena_restraint.gd): places where the
// page's slate has come off like old paint and the cream of the paper shows, one round patch
// under each number, each touching the next. A patch is nearly a circle: its edge is chipped
// a little where the paint broke away, and a few flecks of slate are left just inside it.
//
// Drawn by a rectangle laid over the gauge; all places are in its pixels.

/** Centre of the first patch, and the distance from one to the next. */
uniform vec2 first = vec2(40.0, 58.0);
uniform float pitch = 34.0;
/** How many patches there are. */
uniform float steps = 5.0;
/** A patch's usual radius. */
uniform float radius = 17.0;
/** Changes the patches while keeping the look. */
uniform float seed = 3.0;
/** The paper under the slate. */
uniform vec3 paper : source_color = vec3(0.86, 0.8, 0.68);
/** How deep the chips in a patch's edge go, in pixels. */
uniform float chip : hint_range(0.0, 8.0) = 2.6;
/** How much slate is left in the flecks just inside the edge. */
uniform float left_over : hint_range(0.0, 1.0) = 0.6;

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

void vertex() {
	at = VERTEX;
}

void fragment() {
	// How far inside a patch this place is, in pixels.
	float inside = -1000.0;
	for (int i = 0; i < 8; i++) {
		if (float(i) >= steps) {
			break;
		}
		float n = float(i) * 5.7 + seed;
		vec2 centre = first + vec2(float(i) * pitch, (hash(vec2(n, 3.0)) - 0.5) * 3.0);
		vec2 d = at - centre;
		float far = length(d);
		vec2 dir = d / max(far, 0.001);
		// Nearly a circle, a little out of round in its own way.
		float reach = radius * (0.95 + 0.1 * value_noise(dir * 1.6 + n));
		inside = max(inside, reach - far);
	}
	// The paint broke away in small chips: the edge goes in and out by a little, abruptly.
	float chips = value_noise(at * 0.28 + seed);
	inside += (smoothstep(0.35, 0.65, chips) - 0.5) * chip + (value_noise(at * 0.9 + seed) - 0.5) * 1.4;
	float shown = smoothstep(-0.5, 0.5, inside);
	// A few flecks of slate still hold, just inside the edge.
	float fleck = smoothstep(0.7, 0.76, value_noise(at * 0.55 + seed + 20.0));
	shown *= 1.0 - fleck * left_over * (1.0 - smoothstep(1.0, 5.0, inside));
	// The bared paper is not one flat colour.
	vec3 col = paper * (0.93 + 0.1 * value_noise(at * 0.25 + seed + 7.0));
	COLOR = vec4(col, shown);
}
