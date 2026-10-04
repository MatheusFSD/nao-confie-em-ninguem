// Shader PS1 para Godot 4: vértices tremendo (snap) + textura afim (sem correção de perspectiva)
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 snap_resolution = vec2(320.0, 240.0); // grade do "tremido": menor = mais tosco
uniform bool jitter = true;
uniform bool affine = true;
// Até onde a textura pode ir desbotando com a distância. Sem este limite, o
// mipmap engole o grão do asfalto e a pista vira uma mancha cinza chapada a
// doze metros do nariz. Com ele, o chão guarda o desenho até o fim da rua —
// ao preço de um brilho de PlayStation, que é o que se quer aqui.
uniform float nivel_maximo : hint_range(0.0, 8.0) = 2.5;

varying vec3 affine_uv;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (jitter && clip.w > 0.0) {
		vec2 g = snap_resolution * 0.5;
		clip.xy = round(clip.xy / clip.w * g) / g * clip.w;
	}
	POSITION = clip;
	float w = affine ? clip.w : 1.0;
	affine_uv = vec3(UV * w, w);
}

void fragment() {
	vec2 uv_final = affine_uv.xy / affine_uv.z;
	vec2 tamanho = vec2(textureSize(albedo_tex, 0));
	// Muitas faces destes modelos são de cor chapada: as três UVs no mesmo
	// ponto, e esse ponto cai bem na divisa entre dois texels do atlas. Como a
	// amostragem é pelo vizinho mais próximo, cada pixel sorteia um lado da
	// divisa e a face inteira vira chuvisco. Quando a UV não varia de um pixel
	// para o outro, a amostra vai para o meio do texel mais próximo, o que dá
	// sempre a mesma cor. Face com textura de verdade não é tocada.
	vec2 em_texels = uv_final * tamanho;
	if (max(fwidth(em_texels).x, fwidth(em_texels).y) < 0.02) {
		em_texels = floor(em_texels + 0.5) + 0.5;
	}
	uv_final = em_texels / tamanho;
	// O nível de mipmap que a distância pede, preso no limite de cima.
	vec2 passo = fwidth(uv_final * tamanho);
	float nivel = max(0.0, log2(max(passo.x, passo.y)));
	vec4 c = textureLod(albedo_tex, uv_final, min(nivel, nivel_maximo)) * tint;
	if (c.a < 0.5) discard; // recortes (paninho de crochê)
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
}
