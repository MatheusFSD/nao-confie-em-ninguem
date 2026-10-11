class_name PM3D
extends Node3D
## Policial militar. Animações "andar" e "parado" vêm dentro do .glb.
## Para ele não "patinar", mova o nó a VELOCIDADE_PASSO metros por segundo enquanto andando = true.

const VELOCIDADE_PASSO := 1.304

@export var andando := false:
	set(v):
		andando = v
		if is_inside_tree(): _tocar()
@export var aplicar_ps1 := true
## Resolução da tela pequena, para o tremido PS1 casar com o bairro.
var resolucao := Vector2(320, 213)
@export var velocidade_animacao := 1.0

var anim: AnimationPlayer

func _ready() -> void:
	if aplicar_ps1:
		RuaModelo.aplicar_ps1(self, resolucao)
	var achados := find_children("*", "AnimationPlayer", true, false)
	if achados.is_empty(): return
	anim = achados[0]
	for nome in ["andar", "parado"]:
		if anim.has_animation(nome): anim.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
	_tocar()

func _tocar() -> void:
	if anim == null: return
	anim.play("andar" if andando else "parado", 0.25, velocidade_animacao)
