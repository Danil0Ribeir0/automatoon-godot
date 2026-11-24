shader_type canvas_item;

// Blur gaussiano da tela atrás deste nó (o jogo pausado), com um véu de cor.
// `amount` vai de 0 (nítido) a 1 (blur total) — animado ao abrir a pausa.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float radius = 3.5;
uniform vec4 tint : source_color = vec4(0.05, 0.12, 0.2, 0.45);

void fragment() {
	vec2 step_px = SCREEN_PIXEL_SIZE * radius * amount;
	float lod = 2.5 * amount;
	vec3 sum = vec3(0.0);
	float weight = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			float k = exp(-float(x * x + y * y) / 8.0);
			sum += textureLod(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * step_px, lod).rgb * k;
			weight += k;
		}
	}
	COLOR = vec4(mix(sum / weight, tint.rgb, tint.a * amount), 1.0);
}
