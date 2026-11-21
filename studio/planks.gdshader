shader_type spatial;
// Floorboards for the laboratory, worked out from world position: boards run along Z, away
// from the camera, so their joints draw the room's perspective. Greyscale like the brickwork
// (studio/brick.gdshader): the bake only records how much light lands.

/** Width and length of one board, in metres. */
uniform vec2 board = vec2(0.17, 2.6);
/** Width of the gap between boards, in metres. */
uniform float gap = 0.012;
uniform float board_dark : hint_range(0.0, 1.0) = 0.24;
uniform float board_light : hint_range(0.0, 1.0) = 0.42;
uniform float gap_tone : hint_range(0.0, 1.0) = 0.03;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = world_pos.xz / board;
	vec2 px = fwidth(p); // boards per pixel: fades the joints out before they can shimmer
	p.y += hash(vec2(floor(p.x), 3.0)); // every row of boards starts somewhere else
	vec2 f = fract(p);
	vec2 d = min(f, 1.0 - f) * board;
	float aa_x = px.x * board.x;
	float aa_y = px.y * board.y;
	float joint = max(1.0 - smoothstep(gap * 0.5, gap * 0.5 + aa_x, d.x),
			1.0 - smoothstep(gap * 0.5, gap * 0.5 + aa_y, d.y));
	float h = hash(floor(p));
	float tone = mix(mix(board_dark, board_light, h), gap_tone, joint);
	float average = mix(board_dark, board_light, 0.5);
	ALBEDO = vec3(mix(average, tone, 1.0 - smoothstep(0.25, 0.6, px.x)));
	ROUGHNESS = 0.6; // worn smooth: lets the window's light streak along the boards
}
