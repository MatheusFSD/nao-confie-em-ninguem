shader_type spatial;
// Visual de PlayStation 1: vértices "tremendo" na grade da tela, sem filtro de
// textura (o cenário usa cor por vértice), iluminação simples e névoa curta.
render_mode diffuse_lambert, specular_disabled, vertex_lighting, cull_back;

// Quanto menor, mais grosseira a grade em que os vértices se encaixam.
uniform float resolucao_vertices = 110.0;
uniform vec3 cor_ambiente : source_color = vec3(0.46, 0.48, 0.54);
uniform vec3 cor_luz : source_color = vec3(1.0, 0.94, 0.82);
uniform vec3 direcao_luz = vec3(0.4, -1.0, 0.35);

void vertex() {
	COLOR = COLOR;
	vec4 posicao = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// Encaixa na grade: é o tremor característico do hardware da época.
	float grade = resolucao_vertices / max(0.001, abs(posicao.z));
	posicao.xyz = round(posicao.xyz * grade) / grade;
	POSITION = PROJECTION_MATRIX * posicao;
}

void fragment() {
	vec3 normal = normalize(NORMAL);
	float luz = max(dot(normal, normalize(-direcao_luz)), 0.0);
	// Céu clareia o que aponta para cima; o sol dá o contraste das faces.
	float ceu = 0.72 + 0.28 * normal.y;
	vec3 base = COLOR.rgb * (cor_ambiente * ceu + cor_luz * luz * 0.8);
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
