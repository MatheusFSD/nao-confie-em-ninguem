extends Node3D
## Caçador: quadrúpede sem cabeça, com animações "parado", "andar" e "correr" em loop.
## Os poros no lugar da cabeça brilham no escuro: material emissivo, halo e uma luz verde.

@export_enum("parado", "andar", "correr") var estado := "andar":
	set(v):
		estado = v
		_tocar()
@export var cor_brilho := Color("#d8ff7a")
@export var forca_brilho := 6.0       ## intensidade da emissão dos poros
@export var energia_luz := 1.5        ## luz que ilumina em volta dele
@export var alcance_luz := 3.5

# posição (x, y, z) e tamanho (w) de cada poro, no espaço do osso "peito"
const POROS := [Vector4(0.0, 0.25, 0.52, 0.045), Vector4(0.07, 0.22, 0.5, 0.032), Vector4(-0.07, 0.22, 0.5, 0.032),
	Vector4(0.04, 0.28, 0.47, 0.026), Vector4(-0.05, 0.27, 0.46, 0.028)]

var anim: AnimationPlayer
var luz: OmniLight3D
var mat_poro: StandardMaterial3D
var mat_halo: StandardMaterial3D
var t := 0.0

func _ready() -> void:
	var players := find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		anim = players[0]
		for nome in anim.get_animation_list():
			anim.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
	_tocar()
	var esqueletos := find_children("*", "Skeleton3D", true, false)
	if esqueletos.is_empty(): return
	var preso := BoneAttachment3D.new()
	preso.bone_name = "peito"
	(esqueletos[0] as Skeleton3D).add_child(preso)

	mat_poro = StandardMaterial3D.new()
	mat_poro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_poro.albedo_color = cor_brilho
	mat_poro.emission_enabled = true
	mat_poro.emission = cor_brilho
	mat_poro.emission_energy_multiplier = forca_brilho
	for p in POROS:
		var esfera := SphereMesh.new()
		esfera.radius = p.w; esfera.height = p.w * 2.0; esfera.radial_segments = 6; esfera.rings = 3
		var m := MeshInstance3D.new()
		m.mesh = esfera; m.material_override = mat_poro; m.position = Vector3(p.x, p.y, p.z)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		preso.add_child(m)

	# halo que soma luz na imagem: faz o brilho aparecer de longe no escuro
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1)); grad.set_color(1, Color(1, 1, 1, 0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad; gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5); gtex.fill_to = Vector2(1.0, 0.5); gtex.width = 32; gtex.height = 32
	mat_halo = StandardMaterial3D.new()
	mat_halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat_halo.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat_halo.albedo_texture = gtex; mat_halo.albedo_color = cor_brilho
	var quad := QuadMesh.new(); quad.size = Vector2(0.6, 0.6)
	var halo := MeshInstance3D.new()
	halo.mesh = quad; halo.material_override = mat_halo; halo.position = Vector3(0, 0.25, 0.58)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preso.add_child(halo)

	luz = OmniLight3D.new()
	luz.light_color = cor_brilho; luz.light_energy = energia_luz; luz.omni_range = alcance_luz
	luz.position = Vector3(0, 0.3, 0.62)
	preso.add_child(luz)

func _tocar() -> void:
	if anim and anim.has_animation(estado):
		anim.play(estado, 0.25)

func _process(delta: float) -> void:
	t += delta
	var pulso := 0.85 + 0.15 * sin(t * 5.3) * sin(t * 1.7)      # pulsa de leve, como algo vivo
	if mat_poro: mat_poro.emission_energy_multiplier = forca_brilho * pulso
	if luz: luz.light_energy = energia_luz * pulso
	if mat_halo: mat_halo.albedo_color = Color(cor_brilho, pulso * (1.3 if estado == "correr" else 1.0))
