extends SceneTree

## Ctrl agacha: devagar, e os caçadores e o Observador demoram mais a notar.
var falhas := 0
var verificacoes := 0

func _initialize() -> void:
	call_deferred("rodar")

func checar(ok: bool, texto: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		printerr("FAIL: ", texto)

func rodar() -> void:
	var jogo: Node = load("res://scenes/mundo3d.tscn").instantiate()
	jogo.dia = 8
	root.add_child(jogo)
	jogo.voltar_ao_menu_no_fim = false
	for i in 4: await process_frame
	var jogador: CharacterBody3D = jogo.jogador
	checar(InputMap.has_action("agachar"), "Ctrl vira a ação agachar")
	var bichos := get_nodes_in_group("cacadores3d")
	checar(not bichos.is_empty(), "dia 8 tem caçador")
	if not bichos.is_empty():
		var bicho = bichos[0]
		jogador.velocity = Vector3(3.2, 0, 0)
		jogador.agachado = false
		var andando: float = bicho.alcance_do_ouvido()
		jogador.velocity = Vector3(1.5, 0, 0)
		jogador.agachado = true
		var agachado: float = bicho.alcance_do_ouvido()
		checar(agachado < andando, "agachado ele ouve de mais perto (%.1f < %.1f)" % [agachado, andando])
	Input.action_press("agachar")
	for i in 20: await physics_frame
	checar(jogador.agachado and jogador.camera.position.y < 1.3, "agachado: olhos baixos (%.2f)" % jogador.camera.position.y)
	Input.action_release("agachar")
	for i in 30: await physics_frame
	checar(not jogador.agachado and jogador.camera.position.y > 1.5, "solto: de pé de novo")
	jogo.queue_free()
	await process_frame
	print("AGACHAR: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
