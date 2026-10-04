// Shader PS1 para Godot 4 com bandeira tremulando: vértices tremendo (snap) + textura afim (sem correção de perspectiva)
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 snap_resolution = vec2(320.0, 240.0); // grade do "tremido": menor = mais tosco
uniform bool jitter = true;
uniform bool affine = true;
uniform float velocidade = 4.19;   // bandeira tremulando

varying vec3 affine_uv;

void vertex() {
	float u = UV.x;
	VERTEX.z += sin(u * 5.0 - TIME * velocidade + (0.5 - UV.y) * 1.05) * 0.06 * u;
	VERTEX.y -= u * u * 0.05;
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
	vec4 c = texture(albedo_tex, affine_uv.xy / affine_uv.z) * tint;
	if (c.a < 0.5) discard; // recortes (paninho de crochê)
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
}
