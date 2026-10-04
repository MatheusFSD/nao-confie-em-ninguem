class_name Balao3D
extends "res://ui/balao.gd"

# O balão de fala do jogo 2D, agora preso a uma cabeça do mundo 3D. O desenho é
# o mesmo (ui/balao.gd): muda só como se acha o lugar dele na tela.
#
# Ele mora na camada de interface, fora da tela pequena, então o texto sai
# nítido enquanto o mundo continua grosso.
## De quão longe o balão ainda é atendido. Passou disso, a conversa acaba.
const ALCANCE := 4.5
## Altura da cabeça do modelo, de onde sai o rabicho.
const CABECA := 1.72

var camera: Camera3D
var pessoa: Node3D
var ouvinte3d: Node3D
## Quantas vezes a tela pequena é esticada até a janela.
var escala := 1.0

func falar_no_mundo(quem: Node3D, quem_ouve: Node3D, frase: String, segundos: float) -> void:
	pessoa = quem
	ouvinte3d = quem_ouve
	_texto.text = frase
	_texto.size = Vector2(LARGURA - 24, 0)
	_tempo = segundos
	show()
	_seguir()

func _process(delta: float) -> void:
	if not visible: return
	_tempo -= delta
	var vale := is_instance_valid(pessoa) and pessoa.visible and camera != null
	var longe := vale and ouvinte3d != null and ouvinte3d.global_position.distance_to(pessoa.global_position) > ALCANCE
	if _tempo <= 0.0 or not vale or longe or camera.is_position_behind(cabeca()):
		hide()
		return
	_seguir()

func cabeca() -> Vector3:
	return pessoa.global_position + Vector3(0.0, CABECA, 0.0)

# A câmera desenha na tela pequena; o balão está na janela. Por isso o ponto
# projetado é multiplicado pelo mesmo tanto que a tela é esticada.
func _seguir() -> void:
	var altura := _texto.get_combined_minimum_size().y + 18
	size = Vector2(LARGURA, altura)
	var na_tela := camera.unproject_position(cabeca()) * escala
	position = Vector2(na_tela.x - LARGURA / 2.0, na_tela.y - altura - 12.0)
	ponta = na_tela.x - position.x
	queue_redraw()
