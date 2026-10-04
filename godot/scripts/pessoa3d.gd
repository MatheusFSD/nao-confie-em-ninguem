extends CharacterBody3D

# Gente do bairro, com os modelos do artefato: malha única de 590 a 822
# triângulos, textura própria de 64 × 64, 17 ossos e as animações "andar" e
# "parado" que vêm dentro de cada arquivo.
#
# Cada um anda no seu passo — o que vem medido do arquivo, para o pé não
# patinar no chão. Quem não escolhe `quem` sai sorteado entre os moradores.
#
# A irmã e o protagonista têm dono e por isso ficam fora do sorteio: ela é
# personagem da casa, ele é quem está segurando a câmera.
const ELENCO := {
	"marquinhos": {"arquivo": "res://modelos/marquinhos_ps1.glb", "passo": 1.35},
	"dona_celia": {"arquivo": "res://modelos/personagens/dona_celia.glb", "passo": 0.74},
	"seu_ze": {"arquivo": "res://modelos/personagens/seu_ze.glb", "passo": 0.85},
	"vanessa": {"arquivo": "res://modelos/personagens/vanessa.glb", "passo": 1.23},
	"tania": {"arquivo": "res://modelos/personagens/tania.glb", "passo": 1.26},
	"aline": {"arquivo": "res://modelos/personagens/aline.glb", "passo": 1.31},
	"jessica": {"arquivo": "res://modelos/personagens/jessica.glb", "passo": 1.35},
	"rogerio": {"arquivo": "res://modelos/personagens/rogerio.glb", "passo": 1.44},
	"anderson": {"arquivo": "res://modelos/personagens/anderson.glb", "passo": 1.55},
	"entregador": {"arquivo": "res://modelos/personagens/entregador.glb", "passo": 1.66},
	"irma": {"arquivo": "res://modelos/personagens/irma.glb", "passo": 1.27},
	"protagonista": {"arquivo": "res://modelos/personagens/protagonista.glb", "passo": 1.40},
}
## Quem pode aparecer andando na rua.
const DA_RUA := ["marquinhos", "dona_celia", "seu_ze", "vanessa", "tania", "aline", "jessica", "rogerio", "anderson", "entregador"]

## Qual dos moradores é este. Vazio sorteia um da rua.
var quem := ""
## Linha da calçada (eixo Z) e intervalo que percorre no eixo X.
var linha_z := 20.5
var limites := Vector2(-40.0, 60.0)
var sentido := 1.0
var parada := false
## A irmã não é gente de rua: com ela não se puxa conversa de calçada.
var conversa_livre := true
## Tom por cima da textura. Os modelos já vêm vestidos, então o normal é não
## pintar nada; fica para quando alguém quiser variar uma roupa.
var tinta := Color.WHITE
var resolucao := Vector2(320, 240)
## O passo do modelo, em metros por segundo. Vem do elenco.
var passo := 1.35
var _animacao: AnimationPlayer
var _corpo: Node3D
## Quanto tempo ainda fica parado conversando, e para onde olha enquanto isso.
var _pausa := 0.0
var _olhar := Vector3.ZERO

func _ready() -> void:
	add_to_group("pessoas3d")
	collision_layer = 4
	collision_mask = 1
	if not ELENCO.has(quem): quem = DA_RUA.pick_random()
	passo = float(ELENCO[quem].passo)
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.26
	capsula.height = 1.7
	forma.shape = capsula
	forma.position.y = 0.85
	add_child(forma)
	_corpo = (load(String(ELENCO[quem].arquivo)) as PackedScene).instantiate()
	add_child(_corpo)
	RuaModelo.aplicar_ps1(_corpo, resolucao)
	if tinta != Color.WHITE: pintar(_corpo)
	_animacao = _corpo.find_child("AnimationPlayer", true, false)
	if _animacao:
		# As animações vêm do arquivo sem repetição; aqui elas passam a repetir.
		for nome in _animacao.get_animation_list():
			_animacao.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
		_animacao.play("parado" if parada else "andar")
	rotation.y = PI / 2.0 if sentido > 0 else -PI / 2.0

## Cada pedestre sai com um tom diferente, sem trocar a textura. O material é
## copiado antes: os modelos dividem os mesmos materiais, e pintar direto no
## original pintaria a rua inteira da mesma cor.
func pintar(no: Node) -> void:
	if no is MeshInstance3D:
		var mi := no as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var material := mi.get_surface_override_material(i)
			if material is ShaderMaterial:
				var so_meu: ShaderMaterial = (material as ShaderMaterial).duplicate()
				so_meu.set_shader_parameter("tint", tinta)
				mi.set_surface_override_material(i, so_meu)
	for filho in no.get_children(): pintar(filho)

## Alguém puxou conversa: para, vira para quem falou e espera a fala acabar.
func conversar(onde: Vector3, segundos: float) -> void:
	_pausa = maxf(_pausa, segundos)
	_olhar = onde
	if _animacao != null: _animacao.play("parado")

func _physics_process(delta: float) -> void:
	if parada:
		velocity = Vector3.ZERO
		return
	if _pausa > 0.0:
		_pausa -= delta
		velocity = Vector3.ZERO
		# O modelo olha para o seu +Z: é esse nariz que se aponta para o ouvinte.
		var rumo := _olhar - global_position
		if Vector2(rumo.x, rumo.z).length() > 0.05: rotation.y = atan2(rumo.x, rumo.z)
		if _pausa <= 0.0 and _animacao != null: _animacao.play("andar")
		move_and_slide()
		return
	if position.x > limites.y: sentido = -1.0
	elif position.x < limites.x: sentido = 1.0
	velocity = Vector3(sentido * passo, 0.0, (linha_z - position.z) * 2.0)
	rotation.y = PI / 2.0 if sentido > 0 else -PI / 2.0
	move_and_slide()
