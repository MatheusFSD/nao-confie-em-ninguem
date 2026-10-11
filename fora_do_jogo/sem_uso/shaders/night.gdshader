shader_type canvas_item;
render_mode unshaded;

// Vinheta nas bordas; a Iluminacao aumenta a força à noite.
uniform float forca = 0.40;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.25, 1.45, length(p * vec2(0.85, 1.0)));
	COLOR = vec4(0.012, 0.025, 0.028, edge * forca);
}
