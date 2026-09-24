shader_type spatial;
// Visual de PlayStation 1: vértices encaixados na grade da tela, textura sem
// filtro vinda de um atlas de 128 × 128 e iluminação simples.
render_mode diffuse_lambert, specular_disabled, vertex_lighting, cull_back, depth_prepass_alpha;

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
// Peças por linha/coluna no atlas.
uniform vec2 grade = vec2(4.0, 5.0);
// Quanto menor, mais grosseira a grade em que os vértices se encaixam.
uniform float resolucao_vertices = 130.0;

void vertex() {
	vec4 posicao = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// Encaixa na grade: é o tremor característico do hardware da época.
	float passo = resolucao_vertices / max(0.001, abs(posicao.z));
	posicao.xyz = round(posicao.xyz * passo) / passo;
	POSITION = PROJECTION_MATRIX * posicao;
}

void fragment() {
	// UV traz a repetição em metros; UV2 diz qual peça do atlas usar.
	vec2 dentro = fract(UV);
	// Meio pixel de margem para não puxar a peça vizinha do atlas.
	vec2 margem = vec2(0.5 / 32.0) / grade;
	vec2 uv = (UV2 + clamp(dentro, margem, 1.0 - margem)) / grade;
	vec4 textura = texture(atlas, uv);
	// A luz é do motor (sol, sombras e ambiente): aqui vai só a cor da peça.
	ALBEDO = textura.rgb * COLOR.rgb;
	ALPHA = textura.a;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
