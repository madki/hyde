shader_type spatial;
// Brickwork for the house walls, worked out from world position so every facade piece lines
// up with its neighbours. Greyscale on purpose: the bake only records how much light lands,
// and the pale joints are what catch the lamp colour at runtime.

/** Length and height of one brick, in metres. */
uniform vec2 brick = vec2(0.42, 0.14);
/** Width of the mortar joint, in metres. */
uniform float joint = 0.022;
uniform float brick_dark : hint_range(0.0, 1.0) = 0.2;
uniform float brick_light : hint_range(0.0, 1.0) = 0.5;
uniform float mortar : hint_range(0.0, 1.0) = 0.85;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 n = normalize(world_normal);
	float along = abs(n.x) > abs(n.z) ? world_pos.z : world_pos.x;
	vec2 p = vec2(along, world_pos.y) / brick;
	vec2 px = fwidth(p); // bricks per pixel: fades the pattern out before it can shimmer
	p.x += 0.5 * mod(floor(p.y), 2.0);
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 d = min(f, 1.0 - f) * brick;
	float gap = min(d.x, d.y);
	float aa = max(px.x * brick.x, px.y * brick.y);
	float in_joint = 1.0 - smoothstep(joint * 0.5, joint * 0.5 + aa, gap);
	float h = hash(cell);
	float tone = mix(brick_dark, brick_light, h * h);
	tone = mix(tone, mortar, in_joint);
	float average = mix(brick_dark, brick_light, 0.4);
	float detail = (1.0 - smoothstep(0.2, 0.55, max(px.x, px.y))) * (1.0 - smoothstep(0.6, 0.9, abs(n.y)));
	ALBEDO = vec3(mix(average, tone, detail));
	ROUGHNESS = 0.9;
}
