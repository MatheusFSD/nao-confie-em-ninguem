shader_type spatial;
render_mode unshaded, cull_disabled;
// Tela de TV sem sinal, para usar em 3D: a mesma ideia do chuvisco.gdshader.
uniform float graos = 48.0;
float ruido(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 g = floor(UV * vec2(graos, graos * 0.75));
	float v = ruido(g + vec2(floor(TIME * 20.0)));
	float barra = smoothstep(0.1, 0.0, abs(fract(UV.y + TIME * 0.3) - 0.5));
	ALBEDO = vec3(0.12 + v * 0.55 + barra * 0.2) * vec3(0.85, 0.92, 1.0);
}
