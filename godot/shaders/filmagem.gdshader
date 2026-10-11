shader_type canvas_item;
render_mode unshaded;

// Imagem de celular passando no jornal: granulado, linhas tremendo, foco que
// vai e volta e, no deserto, o ar quente ondulando. Por cima, o mesmo vidro de
// tubo dos programas (varredura e canto escuro).
uniform float desfoque : hint_range(0.0, 6.0) = 0.0;
uniform float calor : hint_range(0.0, 1.0) = 0.0;
uniform float tremor : hint_range(0.0, 1.0) = 0.2;
uniform float granulado : hint_range(0.0, 0.5) = 0.12;
uniform float apagar : hint_range(0.0, 1.0) = 0.0;

float ruido(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float linha = floor(uv.y * 240.0);
	// Linhas que escorregam de lado, de vez em quando.
	float salto = step(0.985 - tremor * 0.05, ruido(vec2(linha, floor(TIME * 12.0))));
	uv.x += (ruido(vec2(linha, floor(TIME * 30.0))) - 0.5) * 0.004 * tremor + salto * 0.02 * tremor;
	// Ar quente: ondas finas que sobem.
	uv.x += sin(uv.y * 90.0 + TIME * 9.0) * 0.0025 * calor * smoothstep(0.35, 0.65, uv.y);
	uv.y += sin(uv.x * 60.0 + TIME * 6.0) * 0.0015 * calor * smoothstep(0.35, 0.65, uv.y);
	vec2 px = TEXTURE_PIXEL_SIZE * desfoque;
	vec3 cor = texture(TEXTURE, uv).rgb * 0.36;
	cor += texture(TEXTURE, uv + vec2(px.x, 0.0)).rgb * 0.16;
	cor += texture(TEXTURE, uv - vec2(px.x, 0.0)).rgb * 0.16;
	cor += texture(TEXTURE, uv + vec2(0.0, px.y)).rgb * 0.16;
	cor += texture(TEXTURE, uv - vec2(0.0, px.y)).rgb * 0.16;
	float g = ruido(floor(FRAGCOORD.xy / 2.0) + vec2(floor(TIME * 24.0) * 7.0));
	cor += (g - 0.5) * granulado;
	cor *= 1.0 - 0.25 * step(0.5, fract(FRAGCOORD.y / 4.0));
	vec2 canto = UV * (1.0 - UV.yx);
	cor *= pow(clamp(canto.x * canto.y * 22.0, 0.0, 1.0), 0.45);
	cor = mix(cor, vec3(g * 0.5 + 0.1), apagar);
	COLOR = vec4(cor, 1.0);
}
