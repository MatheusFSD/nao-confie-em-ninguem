class_name SalaDoMenu
extends TextureRect

# O fundo do menu inicial: a sala do jogo de noite, com a luz apagada e a TV de
# tubo ligada num canal sem sinal. A estática é a única luz do cômodo e pisca
# nas paredes. Renderizada em resolução baixa com o filtro PS1, como o jogo,
# e ampliada sem suavizar. A câmera respira devagar, de quem está no sofá.
const CASA_LUGAR := Vector3(12.25, 0.0, 9.4)
## Quantas vezes a imagem é ampliada até a janela.
const AMPLIA := 3

const ESTATICA := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float brilho = 1.0;
float ruido(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 grosso = floor(UV * vec2(80.0, 60.0));
	float g = ruido(grosso + vec2(floor(TIME * 22.0) * 7.0, floor(TIME * 22.0) * 13.0));
	float barra = smoothstep(0.09, 0.0, abs(fract(UV.y + TIME * 0.31) - 0.5));
	vec3 cor = vec3(g * 0.75 + 0.12 + barra * 0.18) * vec3(0.82, 0.9, 1.0);
	cor *= 1.0 - 0.3 * step(0.5, fract(UV.y * 60.0));
	vec2 canto = UV * (1.0 - UV);
	cor *= pow(clamp(canto.x * canto.y * 28.0, 0.0, 1.0), 0.35);
	ALBEDO = cor * brilho;
}
"""

var vista: SubViewport
var camera: Camera3D
var luz_da_tv: OmniLight3D
var _tempo := 0.0
var _base := Vector3.ZERO
var _olhar := Vector3.ZERO
var _proxima_piscada := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vista = SubViewport.new()
	vista.own_world_3d = true
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vista)
	ajustar()
	get_viewport().size_changed.connect(ajustar)
	var palco := Node3D.new()
	vista.add_child(palco)
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color(0.01, 0.012, 0.02)
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(0.3, 0.35, 0.55)
	ambiente.ambient_light_energy = 0.04
	var mundo_env := WorldEnvironment.new()
	mundo_env.environment = ambiente
	palco.add_child(mundo_env)
	var resolucao := Vector2(vista.size)
	var casa := Casa3D.new()
	casa.montar(palco, CASA_LUGAR, resolucao)
	var material := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = ESTATICA
	material.shader = sh
	var tela := casa.cobrir_a_tela(material)
	# A luz azulada da estática, na frente da tela.
	luz_da_tv = OmniLight3D.new()
	luz_da_tv.light_color = Color(0.68, 0.78, 1.0)
	luz_da_tv.omni_range = 4.5
	luz_da_tv.omni_attenuation = 1.6
	luz_da_tv.light_energy = 1.4
	luz_da_tv.shadow_enabled = true
	palco.add_child(luz_da_tv)
	camera = Camera3D.new()
	camera.fov = 58.0
	palco.add_child(camera)
	camera.make_current()
	if tela != null:
		var frente := tela.global_transform.basis.z
		luz_da_tv.global_position = tela.global_position + frente * 0.5
		# De quem está sentado no sofá, de lado, com a TV no terço da direita.
		_olhar = tela.global_position + Vector3(0.0, -0.05, 0.0) + frente.cross(Vector3.UP) * 0.55
		_base = tela.global_position + frente * 2.6 + frente.cross(Vector3.UP) * -1.2 + Vector3(0.0, 0.25, 0.0)
		camera.global_position = _base
		camera.look_at(_olhar)

## A tela pequena acompanha a janela, sempre ampliada pelo mesmo tanto.
func ajustar() -> void:
	var janela := get_viewport().get_visible_rect().size
	vista.size = Vector2i(maxi(160, int(janela.x / AMPLIA)), maxi(100, int(janela.y / AMPLIA)))
	texture = vista.get_texture()

func _process(delta: float) -> void:
	_tempo += delta
	if camera != null and _base != Vector3.ZERO:
		camera.global_position = _base + Vector3(sin(_tempo * 0.21) * 0.05, sin(_tempo * 0.37) * 0.02, cos(_tempo * 0.17) * 0.04)
		camera.look_at(_olhar)
	# A luz da estática treme o tempo todo e, às vezes, quase apaga.
	if luz_da_tv != null:
		_proxima_piscada -= delta
		var alvo := randf_range(1.0, 1.45)
		if _proxima_piscada <= 0.0:
			_proxima_piscada = randf_range(2.0, 6.0)
			alvo = 0.35
		luz_da_tv.light_energy = lerpf(luz_da_tv.light_energy, alvo, 0.5)
