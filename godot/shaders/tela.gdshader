shader_type canvas_item;
render_mode unshaded;

// O filtro da tela: é a última coisa que acontece com a imagem do jogo, depois
// que o mundo já foi desenhado pequeno (320 × 213) e antes de ser esticado de
// volta na janela. Duas partes, cada uma desligável sozinha:
//
//   - pontilhado: reduz as cores e mistura as que sobram em xadrez, com a
//     matriz 4 × 4 de Bayer — é o mesmo truque do PlayStation e o que dá o
//     chuvisco de pontinhos da referência;
//   - VHS: separação de cor, borrão para a direita, tremor de linha, faixa de
//     fita passando, ruído e risco de varredura. Só a imagem: nada de relógio,
//     "PLAY" ou qualquer letreiro por cima.
//
// Tudo é medido em pixels da tela pequena, então o efeito não muda de tamanho
// quando a janela muda.

group_uniforms pontilhado;
/// 0 desliga, 1 é o xadrez cheio.
uniform float pontilhado : hint_range(0.0, 1.0) = 1.0;
/// Tons por canal. Quanto menos, mais visível fica o xadrez: 32 é o PS1, 8 é a
/// referência, 4 já é pôster.
uniform float tons : hint_range(2.0, 64.0) = 8.0;

group_uniforms vhs;
/// 0 desliga a fita inteira; o resto regula cada parte em cima disso.
uniform float vhs : hint_range(0.0, 1.0) = 0.6;
/// Quanto o vermelho e o azul se afastam, em pixels.
uniform float sangria : hint_range(0.0, 4.0) = 1.0;
/// O rastro que cada coisa deixa à direita, em pixels.
uniform float rastro : hint_range(0.0, 6.0) = 2.0;
/// Tremor das linhas.
uniform float tremor : hint_range(0.0, 4.0) = 0.8;
/// Ruído da fita.
uniform float chuvisco : hint_range(0.0, 0.3) = 0.06;
/// Escurecimento das linhas ímpares.
uniform float risco : hint_range(0.0, 0.5) = 0.10;
/// Quantas faixas de fita sobem pela tela por segundo.
uniform float passo_da_faixa : hint_range(0.0, 1.0) = 0.12;

// Matriz 4 × 4 de Bayer, a mesma do PS1, com os valores já em 0–1.
const mat4 BAYER = mat4(
	vec4( 0.0,  8.0,  2.0, 10.0),
	vec4(12.0,  4.0, 14.0,  6.0),
	vec4( 3.0, 11.0,  1.0,  9.0),
	vec4(15.0,  7.0, 13.0,  5.0)) / 16.0;

float ruido(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 pixel = TEXTURE_PIXEL_SIZE;              // 1 / tamanho da tela pequena
	vec2 lugar = UV / pixel;                                   // em pixels da tela pequena
	vec2 uv = UV;
	float brilho = 1.0;

	if (vhs > 0.001) {
		// A faixa de fita: uma linha larga que sobe devagar e desregula o que
		// passa por ela.
		float faixa = abs(fract(UV.y + TIME * passo_da_faixa) - 0.5);
		faixa = smoothstep(0.5, 0.46, faixa);
		// Tremor: cada linha entra um pouco fora do lugar, e dentro da faixa
		// entra bem fora.
		float linha = lugar.y;
		// Uma ondulação lenta na tela inteira, um tremor fino por cima e, só
		// dentro da faixa, o desalinhamento feio da fita.
		float desvio = sin(linha * 0.045 - TIME * 1.3) * 0.5
			+ sin(linha * 0.22 + TIME * 5.0) * 0.12
			+ (ruido(vec2(linha, floor(TIME * 20.0))) - 0.5) * faixa * 3.0;
		uv.x += desvio * tremor * vhs * pixel.x;
		brilho += faixa * 0.12 * vhs;
	}

	// Cor: o verde no lugar, o vermelho e o azul separados, e um rastro do que
	// veio antes na linha — é o que a fita faz com o sinal.
	vec3 cor = texture(TEXTURE, uv).rgb;
	if (vhs > 0.001) {
		float s = sangria * vhs * pixel.x;
		cor.r = texture(TEXTURE, uv + vec2(s, 0.0)).r;
		cor.b = texture(TEXTURE, uv - vec2(s, 0.0)).b;
		vec3 atras = texture(TEXTURE, uv - vec2(rastro * pixel.x, 0.0)).rgb;
		cor = mix(cor, max(cor, atras * 0.8), 0.22 * vhs);
		cor *= brilho;
		cor += (ruido(lugar + vec2(TIME * 60.0, 0.0)) - 0.5) * chuvisco * vhs;
		// Risco de varredura: linha sim, linha não, como na tela de tubo.
		cor *= 1.0 - risco * vhs * step(0.5, fract(lugar.y * 0.5));
	}

	if (pontilhado > 0.001) {
		// Xadrez de Bayer antes de cortar os tons: onde a cor cai no meio de
		// dois tons, os pixels se revezam entre eles.
		int bx = int(mod(lugar.x, 4.0));
		int by = int(mod(lugar.y, 4.0));
		float limiar = (BAYER[bx][by] - 0.5) * pontilhado;
		vec3 cortada = floor(clamp(cor, 0.0, 1.0) * tons + 0.5 + limiar) / tons;
		cor = mix(cor, cortada, pontilhado);
	}

	COLOR = vec4(clamp(cor, 0.0, 1.0), 1.0);
}
