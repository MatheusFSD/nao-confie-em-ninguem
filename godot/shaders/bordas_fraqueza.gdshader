shader_type canvas_item;
// Bordas vermelhas da fraqueza: a tela escurece em vermelho pelas beiradas e
// pulsa devagar, como um coração cansado. `forca` vai de 0 a 1.
uniform float forca : hint_range(0.0, 1.0) = 0.0;
uniform float tempo = 0.0;

void fragment() {
	vec2 centro = UV - vec2(0.5);
	float distancia = length(centro * vec2(1.25, 1.0));
	float pulso = 0.85 + 0.15 * sin(tempo * 2.2);
	float borda = smoothstep(0.62 - forca * 0.32, 0.95, distancia) * forca * pulso;
	COLOR = vec4(0.55, 0.0, 0.02, clamp(borda * 1.4, 0.0, 0.9));
}
