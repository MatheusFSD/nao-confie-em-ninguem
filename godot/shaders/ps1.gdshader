shader_type spatial;
// Visual de PlayStation 1 para a malha do lote: vértices encaixados na grade da
// tela, textura afim (sem correção de perspectiva) e atlas sem filtro.
// O encaixe é feito igual ao do shader do modelo da rua (ps1_artefato), na
// mesma resolução, para que os vértices que se encontram na emenda entre o
// lote e a calçada tremam juntos e não abram fresta.
render_mode diffuse_lambert, specular_disabled, cull_back, depth_prepass_alpha;

uniform sampler2D atlas : source_color, filter_nearest_mipmap, repeat_disable;
// Peças por linha/coluna no atlas.
uniform vec2 grade = vec2(4.0, 5.0);
// Grade do tremido: quanto menor, mais tosco.
uniform vec2 resolucao_tela = vec2(320.0, 240.0);
// O tremor mexe na posição da tela sem mexer na profundidade: em superfície
// rente a outra isso vira briga de pixel a cada quadro. Desligado por isso.
uniform bool tremido = false;
// Lado de cada peça do atlas, em pixels.
uniform float lado_peca = 32.0;
// Até que nível de mipmap descer. Mais que isso e as peças vizinhas do atlas
// começam a se misturar, porque elas não têm borda de folga entre si.
uniform float nivel_maximo = 2.0;

varying vec3 uv_afim;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (tremido && clip.w > 0.0) {
		vec2 g = resolucao_tela * 0.5;
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
	// Sem a multiplicação por w a textura não escorrega: o desenho fica reto.
	uv_afim = vec3(UV, 1.0);
}

void fragment() {
	// UV traz a repetição em metros; UV2 diz qual peça do atlas usar.
	vec2 metros = uv_afim.xy / uv_afim.z;
	vec2 dentro = fract(metros);
	// Quantos texels cabem num pixel da tela: é isso que diz o nível de mipmap.
	// Sem mipmap, chão e parede vistos de esguelha viravam chuvisco.
	float texels = max(length(dFdx(metros)), length(dFdy(metros))) * lado_peca;
	float nivel = clamp(log2(max(texels, 1.0)), 0.0, nivel_maximo);
	// Margem de meio texel do nível em uso, para não puxar a peça vizinha.
	vec2 margem = vec2(0.5 * exp2(nivel) / lado_peca) / grade;
	vec2 uv = (UV2 + clamp(dentro, margem, 1.0 - margem)) / grade;
	vec4 textura = textureLod(atlas, uv, nivel);
	// A luz é do motor (sol, sombras e ambiente): aqui vai só a cor da peça.
	ALBEDO = textura.rgb * COLOR.rgb;
	ALPHA = textura.a;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
