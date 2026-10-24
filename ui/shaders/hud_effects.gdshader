shader_type canvas_item;
// Koko ruudun HUD-efektit: tukahdutusvinjetti, osumavälähdys, verenvuodon syke
// ja piipun kuumuusväreily. Kaikki arvot 0–1, ja niitä ohjaa ui/hud.gd.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// Tukahdutus: reunat tummuvat, sumenevat ja värit haalistuvat.
uniform float suppression : hint_range(0.0, 1.0) = 0.0;
// Osuman punainen reunavälähdys.
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
// Verenvuodon sykkivä reuna (sydämen lyönti lasketaan skriptissä).
uniform float bleed_pulse : hint_range(0.0, 1.0) = 0.0;
// Kuumuusväreily ruudun alaosassa aseen kohdalla.
uniform float heat_shimmer : hint_range(0.0, 1.0) = 0.0;
uniform vec3 blood_color : source_color = vec3(0.45, 0.02, 0.02);

void fragment() {
	vec2 uv = SCREEN_UV;

	// Kuumuusväreily: ilma värisee piipun yllä, voimakkaimmin oikeassa alakulmassa.
	float heat_mask = smoothstep(0.4, 1.0, uv.y) * smoothstep(0.1, 0.75, uv.x);
	vec2 wobble = vec2(
		sin(uv.y * 90.0 + TIME * 13.0) + sin(uv.y * 37.0 - TIME * 7.0),
		cos(uv.x * 70.0 + TIME * 11.0)
	) * 0.0025 * heat_shimmer * heat_mask;
	uv += wobble;

	vec2 centered = uv - vec2(0.5);
	centered.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float radius = length(centered);
	float edge = smoothstep(0.2, 0.9, radius);

	vec3 col = textureLod(screen_tex, uv, 0.0).rgb;
	if (suppression > 0.001) {
		vec3 blurred = textureLod(screen_tex, uv, 3.0 * suppression * edge).rgb;
		col = mix(col, blurred, clamp(suppression * edge * 1.5, 0.0, 1.0));
		float gray = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(col, vec3(gray), suppression * 0.55);
		col *= 1.0 - edge * suppression * 0.85;
	}

	float red_edge = smoothstep(0.35, 0.95, radius);
	float red = clamp(red_edge * (hit_flash * 1.3 + bleed_pulse * 0.8), 0.0, 1.0);
	col = mix(col, blood_color, red * 0.85);

	COLOR = vec4(col, 1.0);
}
