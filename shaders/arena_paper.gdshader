shader_type canvas_item;
// The arena's page: a sheet of old paper in Jekyll's slate.
//
// The texture is a mask, a scan of real paper saved as greys (studio/paper_mask_bake.gd). Its
// grey value alone picks the place on a ramp of three colours, so the stains, the cross fold and
// the fibre are the scan's own and the colour is ours. Drawn by a TextureRect that covers the
// screen, so a wider window shows more of the sheet.

group_uniforms mask;
/** The mask's median grey (printed by the bake): it lands on `mid_at` of the ramp. */
uniform float mask_mid : hint_range(0.0, 1.0) = 0.82;
/** How far the mask's light and dark are spread over the ramp. */
uniform float contrast : hint_range(0.0, 8.0) = 3.8;
/** Where on the ramp (0 = dark, 1 = light) the mask's median grey sits. */
uniform float mid_at : hint_range(0.0, 1.0) = 0.48;

group_uniforms colours;
uniform vec3 paper_dark : source_color = vec3(0.122, 0.141, 0.157);
uniform vec3 paper_mid : source_color = vec3(0.184, 0.243, 0.275);
uniform vec3 paper_light : source_color = vec3(0.306, 0.376, 0.447);

void fragment() {
	float grey = texture(TEXTURE, UV).r;
	float t = clamp(mid_at + (grey - mask_mid) * contrast, 0.0, 1.0);
	vec3 col = t < 0.5 ? mix(paper_dark, paper_mid, t * 2.0) : mix(paper_mid, paper_light, t * 2.0 - 1.0);
	COLOR = vec4(col, 1.0);
}
