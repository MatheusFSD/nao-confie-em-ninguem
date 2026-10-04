extends Node3D
## Aplica o shader PS1 no carro. O modelo fica com a frente para +Z, rodas no chão (y = 0).
@export var aplicar_ps1 := true
func _ready() -> void:
	if aplicar_ps1: PS1Util.aplicar(self)
