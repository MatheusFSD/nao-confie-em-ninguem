shader_type canvas_item;
render_mode unshaded;

// Canal sem sinal: chuvisco de tubo. Pontos brancos e pretos sorteados a cada
// quadro, em pixels grossos, com uma barra clara subindo devagar — o que a TV
// mostrava quando a antena não pegava nada.
uniform float pixel : hint_range(1.0, 8.0) = 3.0;

float ruido(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 grosso = floor(FRAGCOORD.xy / pixel);
	float g = ruido(grosso + vec2(floor(TIME * 24.0)));
	// A barra de rolagem, que sobe uma vez a cada três segundos.
	float barra = smoothstep(0.08, 0.0, abs(fract(UV.y + TIME * 0.33) - 0.5));
	vec3 cor = vec3(g * 0.55 + 0.08 + barra * 0.18);
	// O mesmo vidro de tubo do filtro dos programas: varredura e canto escuro.
	cor *= 1.0 - 0.3 * step(0.5, fract(FRAGCOORD.y / (pixel * 2.0)));
	vec2 canto = UV * (1.0 - UV.yx);
	cor *= pow(clamp(canto.x * canto.y * 26.0, 0.0, 1.0), 0.4);
	COLOR = vec4(cor, 1.0);
}
