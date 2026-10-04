shader_type spatial;
// A cidade do horizonte. Ela fica a centenas de metros, muito além do alcance
// da névoa do jogo — se recebesse névoa, sumiria por completo. Então ela é
// desenhada sem névoa e já entra com o tom do dia misturado na cor, que é o que
// dá a sensação de distância. Sem luz também: a esta distância o sol não muda
// nada, e assim a silhueta fica chapada como nos jogos da época.
render_mode unshaded, cull_back, fog_disabled;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
// Cor do ar naquele dia e quanto dela entra por cima do desenho.
uniform vec4 ar : source_color = vec4(0.78, 0.78, 0.76, 1.0);
uniform float distancia : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec4 c = texture(albedo_tex, UV) * tint;
	if (c.a < 0.5) discard;
	ALBEDO = mix(c.rgb, ar.rgb, distancia);
}
