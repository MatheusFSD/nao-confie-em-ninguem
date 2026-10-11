class_name Observador3D
extends Node3D
## O Observador: fica parado olhando o alvo; quando o alvo chega perto, percebe,
## vira com a cabeça ainda travada nele, foge correndo mais rápido que o jogador e some.
## Toda a animação é procedural (como era na cena de teste), a 15 quadros por segundo.

signal percebeu
signal fugiu
signal sumiu

@export var alvo: Node3D                                ## o protagonista
@export var rota_de_fuga: Array[Vector3] = []           ## pontos globais por onde ele foge; vazio = foge em linha reta, para longe do alvo
@export var distancia_alerta := 4.6
@export var velocidade_fuga := 6.8                      ## o protagonista correndo faz ~2,6 m/s
@export var distancia_para_sumir := 10.0                ## depois de correr isso, some
@export var cor_dos_olhos := Color("#d8ff7a")
@export var quadros_por_segundo := 15.0
@export var aplicar_ps1 := true
## Resolução da tela pequena, para o tremido PS1 casar com o resto do bairro.
var resolucao := Vector2(320, 213)

enum Estado { OBSERVANDO, ALERTA, VIRANDO, FUGINDO, SUMIU }
var estado := Estado.OBSERVANDO
var t := 0.0
var t_estado := 0.0
var fase := 0.0
var acc := 0.0
var percorrido := 0.0
var rota_i := 0
var direcao_livre := Vector3.FORWARD
var skel: Skeleton3D
var ossos := {}
var olho_brilho: StandardMaterial3D
var halo_mat: StandardMaterial3D
var halos: Array[MeshInstance3D] = []
var olhos: Array[MeshInstance3D] = []
var rastro: Array[MeshInstance3D] = []
var rastro_i := 0

func _ready() -> void:
	if aplicar_ps1:
		RuaModelo.aplicar_ps1(self, resolucao)
	var achados := find_children("*", "Skeleton3D", true, false)
	if achados.is_empty(): return
	skel = achados[0]
	for i in skel.get_bone_count(): ossos[skel.get_bone_name(i)] = i
	_criar_olhos()

## Depois do ataque ele é o olho dos caçadores: viu o jogador, grita e foge.
func gritar() -> void:
	if estado != Estado.OBSERVANDO: return
	var voz := AudioStreamPlayer3D.new()
	voz.stream = Sons3D.grito()
	voz.unit_size = 12.0
	voz.max_distance = 90.0
	voz.volume_db = 6.0
	voz.position.y = 1.9
	add_child(voz)
	voz.play()
	estado = Estado.ALERTA
	t_estado = 0.0
	percebeu.emit()

## Chame para ele voltar a aparecer em outro lugar.
func reaparecer(posicao_global: Vector3, olhando_para := Vector3.INF) -> void:
	global_position = posicao_global
	if olhando_para != Vector3.INF:
		rotation.y = atan2(olhando_para.x - posicao_global.x, olhando_para.z - posicao_global.z)
	estado = Estado.OBSERVANDO; t_estado = 0.0; percorrido = 0.0; rota_i = 0
	visible = true

# ---------- olhos que brilham no escuro
func _criar_olhos() -> void:
	var cabeca := BoneAttachment3D.new(); cabeca.bone_name = "head"; skel.add_child(cabeca)
	olho_brilho = StandardMaterial3D.new()
	olho_brilho.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	olho_brilho.albedo_color = cor_dos_olhos.lerp(Color.WHITE, 0.7)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1)); grad.set_color(1, Color(1, 1, 1, 0)); grad.add_point(0.35, Color(1, 1, 1, 0.55))
	var gtex := GradientTexture2D.new(); gtex.gradient = grad; gtex.width = 16; gtex.height = 16
	gtex.fill = GradientTexture2D.FILL_RADIAL; gtex.fill_from = Vector2(0.5, 0.5); gtex.fill_to = Vector2(1.0, 0.5)
	halo_mat = _material_halo(gtex, 0.8)
	for s in [-1.0, 1.0]:
		var o := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.024, 0.016); o.mesh = q
		o.material_override = olho_brilho; o.position = Vector3(s * 0.028, 0.114, 0.094); cabeca.add_child(o); olhos.append(o)
		var h := MeshInstance3D.new(); var qh := QuadMesh.new(); qh.size = Vector2(0.18, 0.18); h.mesh = qh
		h.material_override = halo_mat; h.position = Vector3(s * 0.028, 0.114, 0.11); cabeca.add_child(h); halos.append(h)
	for i in 14:
		var r := MeshInstance3D.new(); var qr := QuadMesh.new(); qr.size = Vector2(0.1, 0.1); r.mesh = qr
		r.material_override = _material_halo(gtex, 0.0); r.top_level = true; r.visible = false
		add_child(r); rastro.append(r)

func _material_halo(tex: Texture2D, alfa: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = false
	m.albedo_texture = tex
	m.albedo_color = Color(cor_dos_olhos, alfa)
	return m

# ---------- comportamento
func _process(delta: float) -> void:
	if skel == null or estado == Estado.SUMIU: return
	t += delta; t_estado += delta
	var alvo_pos := alvo.global_position if alvo else global_position + global_transform.basis.z * 5.0
	var dist := Vector2(alvo_pos.x - global_position.x, alvo_pos.z - global_position.z).length()
	match estado:
		Estado.OBSERVANDO:
			if alvo and dist < distancia_alerta:
				estado = Estado.ALERTA; t_estado = 0.0; percebeu.emit()
		Estado.ALERTA:
			if t_estado > 0.55:
				estado = Estado.VIRANDO; t_estado = 0.0
				var afastar := global_position - alvo_pos; afastar.y = 0
				direcao_livre = afastar.normalized() if afastar.length() > 0.01 else -global_transform.basis.z
		Estado.VIRANDO:
			var d := _direcao_da_fuga()
			rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(1.0, delta * 14.0))
			fase += delta * 15.0 * minf(1.0, t_estado / 0.28)
			if t_estado > 0.28:
				estado = Estado.FUGINDO; t_estado = 0.0; fugiu.emit()
		Estado.FUGINDO:
			fase += delta * 15.0
			var d := _direcao_da_fuga()
			var passo := velocidade_fuga * delta
			global_position += d * passo; percorrido += passo
			rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(1.0, delta * 16.0))
			if rota_de_fuga.size() > 0 and rota_i < rota_de_fuga.size():
				var alvo_rota := rota_de_fuga[rota_i]
				if Vector2(alvo_rota.x - global_position.x, alvo_rota.z - global_position.z).length() < passo * 1.5: rota_i += 1
			if percorrido > distancia_para_sumir or (rota_de_fuga.size() > 0 and rota_i >= rota_de_fuga.size()):
				estado = Estado.SUMIU; visible = false
				for r in rastro: r.visible = false
				sumiu.emit(); return
	acc += delta
	if acc >= 1.0 / quadros_por_segundo:
		_pose(alvo_pos); acc = 0.0

func _direcao_da_fuga() -> Vector3:
	if rota_de_fuga.size() > 0 and rota_i < rota_de_fuga.size():
		var d := rota_de_fuga[rota_i] - global_position; d.y = 0
		if d.length() > 0.01: return d.normalized()
	return direcao_livre

func _rot(nome: String, x := 0.0, y := 0.0, z := 0.0) -> void:
	if ossos.has(nome):
		skel.set_bone_pose_rotation(ossos[nome], Quaternion.from_euler(Vector3(deg_to_rad(x), deg_to_rad(y), deg_to_rad(z))))

func _pose(alvo_pos: Vector3) -> void:
	var para_alvo := atan2(alvo_pos.x - global_position.x, alvo_pos.z - global_position.z)
	var rel := wrapf(para_alvo - rotation.y, -PI, PI)
	if estado == Estado.OBSERVANDO or estado == Estado.ALERTA:
		# não respira, não pisca; só a cabeça segue o alvo, com um tranco seco de vez em quando
		skel.set_bone_pose_position(ossos["hips"], Vector3(0, 1.12, 0))
		for n in ["hips", "spine", "shin_L", "shin_R", "foot_L", "foot_R", "hand_L", "hand_R"]: _rot(n)
		_rot("chest", 1)
		_rot("thigh_L", 0, 0, -1.5); _rot("thigh_R", 0, 0, 1.5)
		_rot("upperarm_L", 0, 0, 3); _rot("upperarm_R", 0, 0, -3); _rot("forearm_L", -2); _rot("forearm_R", -2)
		rel = clampf(rel, -1.35, 1.35)
		var tranco := 9.0 if (estado == Estado.OBSERVANDO and fmod(t, 3.1) < 0.12) else 0.0
		var alerta := 1.0 if estado == Estado.ALERTA else 0.0
		_rot("neck", 0, rad_to_deg(rel) * 0.35, 0)
		_rot("head", -4 - 6 * alerta, rad_to_deg(rel) * 0.65, 9 + tranco - 9 * alerta)
	else:
		var sw := sin(fase); var cs := cos(fase)
		var k := minf(1.0, t_estado / 0.28) if estado == Estado.VIRANDO else 1.0
		skel.set_bone_pose_position(ossos["hips"], Vector3(0, 1.12 - 0.07 * k, 0))
		_rot("hips"); _rot("spine", 16 * k); _rot("chest", 8 * k)
		_rot("thigh_L", -44 * sw * k); _rot("thigh_R", 44 * sw * k)
		_rot("shin_L", (8 + 70 * maxf(0.0, cs)) * k); _rot("shin_R", (8 + 70 * maxf(0.0, -cs)) * k)
		_rot("foot_L", 10 * sw * k); _rot("foot_R", -10 * sw * k)
		_rot("upperarm_L", 30 * k, 0, 4); _rot("upperarm_R", 30 * k, 0, -4)          # braços duros para trás, sem balançar
		_rot("forearm_L", -4); _rot("forearm_R", -4); _rot("hand_L", 12 * k); _rot("hand_R", 12 * k)
		# a cabeça fica travada no alvo enquanto o corpo já vira, além do que um pescoço aguentaria
		var r := clampf(rel, -2.6, 2.6) if (estado == Estado.VIRANDO or t_estado < 0.45) else 0.0
		_rot("neck", -8 * k, rad_to_deg(r) * 0.4, 0)
		_rot("head", -16 * k, rad_to_deg(r) * 0.6, 0)
	# brilho dos olhos: sempre aceso, pulsando de leve; mais forte quando percebe
	var pulso := 0.9 + 0.1 * sin(t * 5.3) * sin(t * 1.7)
	olho_brilho.albedo_color = cor_dos_olhos.lerp(Color.WHITE, 0.7) * pulso
	halo_mat.albedo_color = Color(cor_dos_olhos, (1.0 if estado == Estado.ALERTA else 0.8) * pulso)
	var esc := 0.26 if estado == Estado.ALERTA else 0.18
	for h in halos: (h.mesh as QuadMesh).size = Vector2(esc, esc)
	if estado == Estado.FUGINDO:
		for o in olhos:
			var r := rastro[rastro_i % rastro.size()]; rastro_i += 1
			r.global_position = o.global_position; r.visible = true
			(r.material_override as StandardMaterial3D).albedo_color = Color(cor_dos_olhos, 0.7)
	for r in rastro:
		var m := r.material_override as StandardMaterial3D
		m.albedo_color.a = maxf(0.0, m.albedo_color.a - 0.12)
		if m.albedo_color.a <= 0.0: r.visible = false
