shader_type canvas_item;
render_mode unshaded;

// Filtro de TV de tubo, por cima da imagem do programa: a tela abaulada, o
// risco de varredura, a máscara de fósforo (as três tiras de cor do vidro), o
// sangramento de cor do sinal composto, o brilho do centro e o canto escuro.
//
// As medidas são em linhas da imagem, não em pixels da janela: o efeito não
// muda de tamanho quando a tela cresce.
/// O quanto o vidro entorta a imagem.
uniform float barriga : hint_range(0.0, 0.4) = 0.12;
/// O escuro entre uma linha de varredura e a seguinte.
uniform float risco : hint_range(0.0, 0.8) = 0.22;
/// A máscara de fósforo: tiras verticais de vermelho, verde e azul.
uniform float mascara : hint_range(0.0, 0.6) = 0.1;
/// Quanto o vermelho e o azul escorregam, em pixels da imagem.
uniform float sangria : hint_range(0.0, 3.0) = 0.7;
/// O canto escuro do tubo.
uniform float vinheta : hint_range(0.0, 1.0) = 0.3;
/// O ganho, para o filtro não deixar a imagem apagada.
uniform float brilho : hint_range(0.5, 2.0) = 1.3;

vec2 abaular(vec2 uv, float k) {
	vec2 meio = uv * 2.0 - 1.0;
	vec2 fora = abs(meio.yx) / vec2(5.0, 4.0);
	meio += meio * fora * fora * k * 4.0;
	return meio * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = abaular(UV, barriga);
	// Fora do vidro não há imagem: é a moldura preta do aparelho.
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec2 pixel = TEXTURE_PIXEL_SIZE;
		vec3 cor = texture(TEXTURE, uv).rgb;
		// Sinal composto: a cor não chega junto com o desenho.
		float s = sangria * pixel.x;
		cor.r = texture(TEXTURE, uv + vec2(s, 0.0)).r;
		cor.b = texture(TEXTURE, uv - vec2(s, 0.0)).b;
		// Varredura: uma linha acesa, uma linha escura.
		float linha = fract(uv.y / pixel.y * 0.5);
		cor *= 1.0 - risco * smoothstep(0.35, 0.5, abs(linha - 0.5) * 2.0);
		// Máscara de fósforo, presa aos pixels da janela, como o vidro é.
		float tira = mod(FRAGCOORD.x, 3.0);
		vec3 vidro = vec3(1.0 - mascara);
		if (tira < 1.0) { vidro.r = 1.0 + mascara; }
		else if (tira < 2.0) { vidro.g = 1.0 + mascara; }
		else { vidro.b = 1.0 + mascara; }
		cor *= vidro * brilho;
		// O tubo escurece para as beiradas.
		vec2 canto = uv * (1.0 - uv.yx);
		cor *= pow(clamp(canto.x * canto.y * 26.0, 0.0, 1.0), vinheta);
		COLOR = vec4(cor, 1.0);
	}
}
