shader_type canvas_item;
render_mode unshaded;

// A fresta: o que se vê quando a cortina é afastada só um pouco. O shader não
// desenha a rua — ele tapa o resto da tela, deixando aberta uma faixa estreita
// no meio, de beirada macia, com o pano escuro fechando os lados.
/// Largura da abertura, em partes da tela.
uniform float abertura : hint_range(0.02, 0.6) = 0.26;
/// Altura da abertura, em partes da tela.
uniform float altura : hint_range(0.1, 1.0) = 0.62;
/// O quanto a beirada do pano é macia.
uniform float macio : hint_range(0.005, 0.2) = 0.045;
/// Cor do pano fechado.
uniform vec4 pano : source_color = vec4(0.02, 0.018, 0.02, 1.0);

void fragment() {
	vec2 meio = abs(UV - vec2(0.5));
	// Uma fresta é mais estreita embaixo, onde a cortina pesa: a abertura
	// aperta nas pontas de cima e de baixo.
	float aperto = 1.0 - smoothstep(altura * 0.35, altura * 0.5, meio.y) * 0.45;
	float dentro = 1.0 - smoothstep(abertura * 0.5 * aperto - macio, abertura * 0.5 * aperto + macio, meio.x);
	dentro *= 1.0 - smoothstep(altura * 0.5 - macio * 2.0, altura * 0.5 + macio * 2.0, meio.y);
	// Mesmo na parte aberta o vidro suja a imagem nas beiradas.
	float sujeira = smoothstep(0.0, 0.35, dentro) * 0.12;
	COLOR = vec4(pano.rgb, (1.0 - dentro) + sujeira * 0.0);
	COLOR.a = clamp(1.0 - dentro, 0.0, 1.0);
}
