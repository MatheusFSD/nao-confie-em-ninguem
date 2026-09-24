extends CanvasLayer

# Protótipo local: estado, interações e UI. Sem autoload ou dependências.
const MAX_DAYS := 10
const DAILY_ACTIONS := 4
const PURCHASES := {
	"comida": {"cost": 10, "amount": 2, "message": "Você guardou comida."},
	"agua": {"cost": 10, "amount": 2, "message": "Você guardou água."},
	"pilhas": {"cost": 15, "amount": 20, "message": "Você recuperou energia."}}
# Ir trabalhar pelo ponto de ônibus.
const WORK := {"actions": 2, "pay": 40, "energy": 10}
const MEDIA_MENU := preload("res://ui/menu_midia.gd")
const MARKET_MENU := preload("res://ui/menu_mercado.gd")
const TRANSITIONS := preload("res://ui/transicoes.gd")
## Duração, em segundos, das telas de passagem.
const FADE_SECONDS := 0.45
const BUS_SECONDS := 3.4
const RETURN_SECONDS := 2.8
const WORK_SECONDS := 3.0
const SLEEP_SECONDS := 4.5
const TALK_SECONDS := 5.0
const BUBBLE := preload("res://ui/balao.gd")
const DIALOGUE := preload("res://ui/dialogo.gd")
## O dia 0 é o tutorial com a irmã: começa sem comida e com mais tempo.
const DIA_TUTORIAL := 0
const TUTORIAL_ACTIONS := 6
## Avisa o tutorial (e qualquer outro sistema) do que o jogador acabou de fazer.
signal evento(nome: String)
var dialogo: Control
var objective_label: Label
var footer_panel: PanelContainer
## Enquanto a irmã fala, o morador espera.
var em_dialogo := false
## Recados guardados para aparecer no resumo do dia seguinte.
var avisos_extra: Array[String] = []
## Frases dos pedestres por fase de dias (data/conversas.json).
var conversations: Dictionary = {}
var heard_lines: Dictionary = {}
var bubble: Control
var media_menu: Control
var market_menu: Control
var transitions: Control
## Enquanto uma animação de ônibus, trabalho ou sono toca, o jogo não aceita comandos.
var in_transition := false
# Dia 0: a geladeira está vazia e a primeira comida vem do mercado.
var comida := 0
var agua := 5
var energia := 100
var dinheiro := 100
var dia := DIA_TUTORIAL
var acoes := TUTORIAL_ACTIONS
## Ações com que o dia começou (menos quando há penalidade); define a hora do dia.
var acoes_do_dia := TUTORIAL_ACTIONS
var agua_da_rede := true
var concluido := false
var lidos: Array[String] = []
var noticias: Dictionary = {}
var pontos: Array[Dictionary] = []
var proximo: Dictionary = {}
var menu := ""
var feedback := ""
var player_was_processing := true
var day_label: Label
# Ícones do HUD (ui/icones.png, 12 × 12 px, mostrados em 2×).
const ICONS := preload("res://ui/hud/icones.png")
const ICON_SIZE := 12
const ICON_FOOD := 0
const ICON_WATER := 1
const ICON_ENERGY := 2
const ICON_ACTION := 3
const MAX_ICONS := 12
var actions_box: HBoxContainer
var food_box: HBoxContainer
var water_box: HBoxContainer
var energy_label: Label
var money_label: Label
var prompt_label: Label
var feedback_label: Label
var phone_button: Button
var sleep_button: Button
var shade: ColorRect
var center: CenterContainer
var content: VBoxContainer
@onready var house: Node2D = get_parent()
@onready var player: CharacterBody2D = house.get_node("Morador")

func _ready() -> void:
	layer = 30
	noticias = JSON.parse_string(FileAccess.get_file_as_string("res://data/dias.json"))
	conversations = JSON.parse_string(FileAccess.get_file_as_string("res://data/conversas.json"))
	build_ui()
	# A casa preenche o mobiliário no _ready do pai, depois dos filhos.
	call_deferred("setup_points")
	say(apply_day_event() + "\nE: interagir. Ler um canal custa 1 ação por dia; reler e consultar estoques é grátis.")

func setup_points() -> void:
	var kinds := {"fridge": ["geladeira", "Geladeira"], "counter": ["torneira", "Torneira"], "sink": ["torneira", "Torneira"], "tv": ["tv", "TV"], "radio": ["radio", "Rádio"], "bed": ["cama", "Cama"]}
	for item: Dictionary in house.furniture:
		if kinds.has(item.kind):
			pontos.append({"id": kinds[item.kind][0], "title": kinds[item.kind][1], "rect": item.rect})
	# Portas e portão: E abre/fecha, T tranca. O texto vem do estado da porta.
	for door: Node2D in house.doors:
		pontos.append({"id": "porta", "title": "Porta", "rect": door.area_do_vao(house), "node": door})
	for stop: Node2D in house.bus_stops:
		pontos.append({"id": "onibus", "title": "Ponto de ônibus", "rect": stop.area_de_espera(house)})

func _physics_process(_delta: float) -> void:
	if menu != "" or in_transition or em_dialogo: return
	proximo = nearest_point()
	var cost := ""
	if not proximo.is_empty() and proximo.id in ["tv", "radio"]:
		cost = " · releitura grátis" if proximo.id in lidos else " · 1 ação"
	if not proximo.is_empty() and proximo.id == "porta":
		prompt_label.text = proximo.node.descricao()
	else:
		prompt_label.text = "E — " + proximo.title + cost if not proximo.is_empty() else "E: interagir perto dos móveis · Tab: celular"

func nearest_point() -> Dictionary:
	var best: Dictionary = {}
	var distance := 27.0
	var local := house.to_local(player.global_position)
	for point in pontos:
		var rect: Rect2 = point.rect
		var target := house.to_global(local.clamp(rect.position, rect.end))
		var d := player.global_position.distance_to(target)
		if d >= distance: continue
		var ray := PhysicsRayQueryParameters2D.create(player.global_position, target, 1, [player.get_rid()])
		var hit := house.get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.position.distance_to(target) > 1.5: continue
		best = point
		distance = d
	# Pedestres da rua: conversa com quem estiver colado no morador.
	for person: Node2D in get_tree().get_nodes_in_group("pedestres"):
		if not person.visible or person.modulate.a < 0.5: continue
		var d := player.global_position.distance_to(person.global_position) - 7.0
		if d < minf(distance, 22.0):
			best = {"id": "pessoa", "title": "Conversar", "node": person}
			distance = d
	return best

# Cada pedestre tem UMA fala por fase dos dias: falar de novo repete a mesma frase.
# Pessoas diferentes recebem frases diferentes enquanto houver frases livres na fase.
func talk_to(person: Node2D) -> void:
	var phase: Dictionary = {}
	for candidate: Dictionary in conversations.get("fases", []):
		if int(candidate.a_partir_do_dia) <= dia: phase = candidate
	var lines: Array = phase.get("frases", ["..."])
	var key := str(phase.get("a_partir_do_dia", 0))
	var assigned: Dictionary = person.get_meta("falas", {})
	if not assigned.has(key):
		var taken: Array = heard_lines.get(key, [])
		if taken.size() >= lines.size(): taken.clear()
		var options := range(lines.size()).filter(func(i): return i not in taken)
		assigned[key] = options.pick_random()
		taken.append(assigned[key])
		heard_lines[key] = taken
		person.set_meta("falas", assigned)
	var choice: int = assigned[key]
	person.conversar(player.global_position, TALK_SECONDS)
	bubble.falar(person, player, lines[choice], TALK_SECONDS)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	# A caixa de diálogo cuida das próprias teclas.
	if dialogo.visible: return
	if in_transition:
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_ESCAPE and menu == "mercado":
		leave_market()
	elif event.physical_keycode == KEY_ESCAPE and menu != "":
		close_menu()
	elif event.physical_keycode == KEY_TAB:
		if menu == "celular": close_menu()
		else: open_menu("celular")
	elif event.physical_keycode == KEY_E and menu == "":
		proximo = nearest_point()
		if proximo.get("id") == "porta": say(proximo.node.alternar())
		elif proximo.get("id") == "pessoa": talk_to(proximo.node)
		elif not proximo.is_empty(): open_menu(proximo.id)
	elif event.physical_keycode == KEY_T and menu == "":
		proximo = nearest_point()
		if proximo.get("id") != "porta": return
		say(proximo.node.alternar_tranca())
		if proximo.node.trancada: evento.emit("trancou:" + proximo.node.name)
	else:
		return
	get_viewport().set_input_as_handled()

# Fala da irmã: segura o morador até a conversa acabar.
func mostrar_dialogo(nome: String, falas: Array) -> void:
	if falas.is_empty(): return
	em_dialogo = true
	bubble.hide()
	# O rodapé sairia por trás da caixa de fala.
	footer_panel.hide()
	player.set_physics_process(false)
	dialogo.mostrar(nome, falas)

func _dialogo_terminou() -> void:
	em_dialogo = false
	footer_panel.show()
	if menu == "" and not in_transition: player.set_physics_process(true)

## Recado que aparece agora ou, com `ao_acordar`, junto do resumo do dia seguinte.
func avisar(texto: String, ao_acordar := false) -> void:
	if ao_acordar: avisos_extra.append(texto)
	else: say(texto)

## Objetivo atual no HUD; texto vazio esconde a linha.
func definir_objetivo(texto: String) -> void:
	objective_label.text = "Objetivo: " + texto if texto != "" else ""
	objective_label.visible = texto != ""

func spend_action() -> bool:
	if concluido:
		say("Os 10 dias do protótipo já foram concluídos.")
		return false
	if acoes <= 0:
		say("Você está sem ações. Use Dormir / Encerrar dia.")
		return false
	acoes -= 1
	if acoes == 0: evento.emit("sem_acoes")
	return true

# No mercado, a viagem de ônibus já custou a ação; cada compra custa só dinheiro.
func buy(kind: String, at_market := false) -> bool:
	if not PURCHASES.has(kind): return false
	var offer: Dictionary = PURCHASES[kind]
	if dinheiro < int(offer.cost):
		say("Dinheiro insuficiente.")
		return false
	if kind == "pilhas" and energia >= 100:
		say("Sua energia já está no máximo.")
		return false
	if not at_market and not spend_action(): return false
	dinheiro -= int(offer.cost)
	match kind:
		"comida": comida += int(offer.amount)
		"agua": agua += int(offer.amount)
		"pilhas": energia = mini(100, energia + int(offer.amount))
	say(offer.message + ("" if at_market else " Você gastou uma ação."))
	if menu == "mercado": render_menu()
	evento.emit("comprou:" + kind)
	return true

func go_to_work() -> bool:
	if concluido:
		say("Os 10 dias do protótipo já foram concluídos.")
		return false
	if acoes < WORK.actions:
		say("Trabalhar ocupa %d ações. Você não tem ações suficientes hoje." % WORK.actions)
		return false
	if energia < WORK.energy:
		say("Você está sem energia para trabalhar.")
		return false
	# O resultado vale na hora; as animações só mostram a viagem e o expediente.
	var night := current_night()
	acoes -= WORK.actions
	dinheiro += WORK.pay
	energia -= WORK.energy
	play_work(night)
	say("Você pegou o ônibus e trabalhou. +R$ %d, −%d energia, %d ações." % [WORK.pay, WORK.energy, WORK.actions])
	evento.emit("trabalhou")
	return true

func current_night() -> float:
	return house.get_node("Iluminacao").progresso if house.has_node("Iluminacao") else 0.0

func play_work(night: float) -> void:
	lock(true)
	await transitions.executar("escurecer", FADE_SECONDS)
	close_under_black()
	await transitions.executar("onibus", BUS_SECONDS, {"texto": "Indo trabalhar", "letreiro": "CENTRO", "noite": night})
	await transitions.executar("preto", WORK_SECONDS, {"texto": "Trabalhando"})
	await transitions.executar("onibus", RETURN_SECONDS, {"texto": "Voltando para casa", "letreiro": "BAIRRO", "noite": current_night(), "volta": true})
	lock(false)

func go_to_market() -> bool:
	var night := current_night()
	if not spend_action(): return false
	say("Você pegou o ônibus até o mercado. Você gastou uma ação; as compras lá custam só dinheiro.")
	play_market(night)
	return true

# Escurece, troca para a tela do mercado no escuro e o ônibus revela as compras.
func play_market(night: float) -> void:
	lock(true)
	await transitions.executar("escurecer", FADE_SECONDS)
	open_menu("mercado")
	await transitions.executar("onibus", BUS_SECONDS, {"texto": "Indo ao mercado", "letreiro": "MERCADO", "noite": night})
	lock(false)

# Volta do mercado: escurece, ônibus no sentido contrário e a casa reaparece.
func leave_market() -> void:
	if in_transition or menu != "mercado": return
	lock(true)
	await transitions.executar("escurecer", FADE_SECONDS)
	close_under_black()
	await transitions.executar("onibus", RETURN_SECONDS, {"texto": "Voltando para casa", "letreiro": "BAIRRO", "noite": current_night(), "volta": true})
	lock(false)

# Fecha o menu sem devolver o controle: a animação seguinte ainda está tocando.
func close_under_black() -> void:
	close_menu()
	player.set_physics_process(false)

func sleep() -> void:
	if concluido or in_transition: return
	close_menu()
	evento.emit("dormiu")
	lock(true)
	# O dia vira no meio da tela escura; a legenda final já mostra o novo dia.
	await transitions.executar("sono", SLEEP_SECONDS, {"meio": end_day, "texto_final": sleep_caption})
	lock(false)

# Nomes das portas para a rua que passaram a noite abertas ou destrancadas.
func doors_unlocked() -> Array[String]:
	var nomes: Array[String] = []
	for door: Node2D in house.doors:
		if door.da_para_fora and (door.aberta or not door.trancada):
			nomes.append(str(door.name))
	return nomes

func sleep_caption() -> String:
	return "Fim do teste" if concluido else "Dia %d · Manhã" % dia

# Trava o morador e os comandos durante uma animação; com menu aberto, o menu mantém a trava.
func lock(enabled: bool) -> void:
	in_transition = enabled
	if enabled: bubble.hide()
	if enabled:
		if menu == "":
			player_was_processing = player.is_physics_processing()
		player.set_physics_process(false)
	elif menu == "":
		player.set_physics_process(true)

func store_water() -> bool:
	if not agua_da_rede:
		say("A torneira está sem abastecimento. Use a água guardada ou compre mais no mercado.")
		return false
	if not spend_action(): return false
	agua += 2
	say("Você guardou água. Você gastou uma ação.")
	if menu == "torneira": render_menu()
	evento.emit("agua")
	return true

func apply_day_event() -> String:
	var data: Dictionary = noticias.get(str(dia), {})
	if data.has("agua_da_rede"): agua_da_rede = data.agua_da_rede
	if data.has("energia"): energia = clampi(int(data.energia), 0, 100)
	return "Dia %d. %s" % [dia, data.get("evento", "Sem novo evento cadastrado para este dia.")]

func end_day() -> bool:
	if concluido: return false
	var messages: Array[String] = []
	if comida == 0: messages.append("Você passou o dia sem comer.")
	if agua == 0: messages.append("Você passou o dia sem beber água.")
	comida = maxi(0, comida - 1)
	agua = maxi(0, agua - 1)
	messages.append("Dia encerrado: consumo de 1 comida e 1 água, quando disponíveis.")
	var penalty := 0
	if comida == 0:
		messages.append("Você está com fome.")
		penalty += 1
	if agua == 0:
		messages.append("Você está com sede.")
		penalty += 1
	# Porta ou portão para a rua destrancado: alguém entra de madrugada.
	var abertas := doors_unlocked()
	if not abertas.is_empty() and (comida > 0 or agua > 0):
		var levou: Array[String] = []
		if comida > 0:
			comida = maxi(0, comida - 1)
			levou.append("uma comida")
		if agua > 0:
			agua = maxi(0, agua - 1)
			levou.append("uma água")
		messages.append("Alguém entrou de madrugada e levou %s. %s ficou sem tranca." % [" e ".join(levou), " e ".join(abertas)])
	close_menu()
	if dia == MAX_DAYS:
		concluido = true
		acoes = 0
		messages.append("Limite de teste: 10 dias concluídos. Reinicie a cena para testar novamente.")
	else:
		dia += 1
		acoes = DAILY_ACTIONS - penalty
		acoes_do_dia = acoes
		lidos.clear()
		if penalty > 0: messages.append("Hoje você tem %d ações por falta de reservas." % acoes)
		messages.append(apply_day_event())
	messages.append_array(avisos_extra)
	avisos_extra.clear()
	say("\n".join(messages))
	return true

func open_menu(id: String) -> void:
	# A conversa na rua termina quando qualquer menu abre.
	bubble.hide()
	if id in ["tv", "radio", "celular"] and id not in lidos:
		if not spend_action(): return
		lidos.append(id)
		say("Você gastou uma ação para consultar esta fonte. Releituras hoje são grátis.")
	if menu == "":
		player_was_processing = player.is_physics_processing()
		player.set_physics_process(false)
	menu = id
	shade.show()
	center.show()
	render_menu()
	evento.emit("menu:" + id)
	if id in ["tv", "radio"]: evento.emit("midia")

func close_menu() -> void:
	if menu != "": player.set_physics_process(player_was_processing)
	menu = ""
	shade.hide()
	center.hide()
	if media_menu.visible: media_menu.close()
	if market_menu.visible: market_menu.close()

func render_menu() -> void:
	if menu == "mercado":
		shade.hide()
		center.hide()
		market_menu.open({"dia": dia, "dinheiro": dinheiro, "comida": comida, "agua": agua, "energia": energia}, PURCHASES, feedback)
		return
	if market_menu.visible: market_menu.close()
	if menu in ["tv", "radio"]:
		shade.hide()
		center.hide()
		var data: Dictionary = noticias.get(str(dia), {})
		media_menu.open(menu, dia, data.get(menu, []))
		return
	if media_menu.visible: media_menu.close()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	var titles := {"geladeira": "Geladeira", "torneira": "Torneira", "tv": "TV / Jornal", "radio": "Rádio", "celular": "Celular / Mensagens", "cama": "Dormir / Encerrar dia", "onibus": "Ponto de ônibus", "mercado": "Mercado do bairro"}
	var title := add_label(content, "%s · Dia %d" % [titles.get(menu, menu), dia])
	title.add_theme_font_size_override("font_size", 22)
	match menu:
		"geladeira": add_label(content, "Comida guardada: %d" % comida)
		"torneira":
			add_label(content, "Água guardada: %d\n%s" % [agua, "A rede ainda fornece água." if agua_da_rede else "O abastecimento de água está instável. Não sai água da torneira."])
			add_button(content, "Encher recipientes: +2 água · 1 ação · grátis", store_water, not agua_da_rede or acoes == 0 or concluido)
		"celular":
			var data: Dictionary = noticias.get(str(dia), {})
			var messages: Array = data.get(menu, [])
			if messages.is_empty(): add_label(content, "Nenhuma nova mensagem cadastrada para este dia.")
			for message: Dictionary in messages:
				add_label(content, "%s\n“%s”" % [message.fonte, message.texto])
		"onibus":
			add_label(content, "Dinheiro: R$ %d · Energia: %d · Ações: %d\nPara onde você vai?" % [dinheiro, energia, acoes])
			add_button(content, "Ir trabalhar · %d ações · +R$ %d · −%d energia" % [WORK.actions, WORK.pay, WORK.energy], go_to_work, concluido or acoes < WORK.actions or energia < WORK.energy)
			add_button(content, "Ir ao mercado · 1 ação", go_to_market, concluido or acoes == 0)
		"cama":
			add_label(content, "Encerrar o dia consome 1 comida e 1 água.\nAções restantes hoje: %d. Elas não acumulam.\nCada reserva em zero reduz em 1 as ações de amanhã." % acoes)
			add_button(content, "Dormir / Encerrar dia", sleep, concluido)
	add_button(content, "Fechar [Esc]", close_menu)

func say(message: String) -> void:
	feedback = message
	if acoes == 0 and not concluido: feedback += "\nSem ações: você já pode encerrar o dia."
	feedback_label.text = feedback
	# Cada ação gasta leva o dia da manhã para a noite.
	var lighting := house.get_node_or_null("Iluminacao")
	var period := ""
	if lighting:
		lighting.definir_progresso(1.0 - float(acoes) / maxf(acoes_do_dia, 1))
		period = " · " + lighting.periodo()
	day_label.text = "Dia %d/%d%s" % [dia, MAX_DAYS, period]
	refresh_resources()
	phone_button.text = "Celular [Tab] · " + ("reler" if "celular" in lidos else "1 ação")
	sleep_button.disabled = concluido

func refresh_resources() -> void:
	fill_icons(actions_box, ICON_ACTION, acoes)
	fill_icons(food_box, ICON_FOOD, comida)
	fill_icons(water_box, ICON_WATER, agua)
	energy_label.text = str(energia)
	money_label.text = "R$ %d" % dinheiro

# Um ícone por unidade; acima do limite mostra o limite e o restante em número.
func fill_icons(box: HBoxContainer, index: int, amount: int) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	for i in mini(amount, MAX_ICONS):
		box.add_child(icon_rect(index))
	if amount > MAX_ICONS:
		var extra := add_label(box, "+%d" % (amount - MAX_ICONS))
		extra.autowrap_mode = TextServer.AUTOWRAP_OFF
		extra.size_flags_horizontal = Control.SIZE_FILL
	elif amount == 0:
		# Reserva vazia: o ícone aparece apagado para o espaço não sumir.
		var empty := icon_rect(index)
		empty.modulate = Color(1, 1, 1, 0.22)
		box.add_child(empty)

func icon_row(parent: Control) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(box)
	return box

func icon_rect(index: int) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = ICONS
	atlas.region = Rect2(index * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)
	var rect := TextureRect.new()
	rect.texture = atlas
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE) * 2
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect

func build_ui() -> void:
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	var hud := PanelContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.offset_left = 12
	hud.offset_right = -12
	hud.offset_top = 12
	ui.add_child(hud)
	var top := box(hud)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	top.add_child(row)
	day_label = add_label(row, "")
	day_label.size_flags_horizontal = Control.SIZE_FILL
	day_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Ampulhetas: uma por ação que ainda resta no dia.
	actions_box = icon_row(row)
	actions_box.tooltip_text = "Ações restantes"
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	phone_button = add_button(row, "Celular [Tab] · 1 ação", open_menu.bind("celular"))
	sleep_button = add_button(row, "Dormir / Encerrar dia", open_menu.bind("cama"))
	# Recursos: um ícone por comida e por água, raio com a energia e o dinheiro em R$.
	var resources := HBoxContainer.new()
	resources.add_theme_constant_override("separation", 22)
	top.add_child(resources)
	food_box = icon_row(resources)
	food_box.tooltip_text = "Comida"
	water_box = icon_row(resources)
	water_box.tooltip_text = "Água"
	var energy_row := icon_row(resources)
	energy_row.tooltip_text = "Energia"
	energy_row.add_child(icon_rect(ICON_ENERGY))
	energy_label = add_label(energy_row, "")
	energy_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	energy_label.size_flags_horizontal = Control.SIZE_FILL
	money_label = add_label(resources, "")
	money_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	money_label.size_flags_horizontal = Control.SIZE_FILL
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.offset_top = -96
	bottom.offset_bottom = -12
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(bottom)
	footer_panel = bottom
	var footer := box(bottom)
	objective_label = add_label(footer, "")
	objective_label.add_theme_color_override("font_color", Color("e8c16a"))
	objective_label.hide()
	prompt_label = add_label(footer, "")
	feedback_label = add_label(footer, "")
	feedback_label.add_theme_font_size_override("font_size", 14)
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(shade)
	shade.hide()
	center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 550
	center.add_child(panel)
	content = box(panel)
	center.hide()
	# Tela cheia de TV e rádio; a ilustração só é carregada quando o aparelho é aberto.
	media_menu = MEDIA_MENU.new()
	media_menu.close_requested.connect(close_menu)
	ui.add_child(media_menu)
	market_menu = MARKET_MENU.new()
	market_menu.buy_requested.connect(func(kind: String): buy(kind, true))
	market_menu.close_requested.connect(leave_market)
	ui.add_child(market_menu)
	# Balão de fala é o primeiro filho da interface: fica abaixo do HUD e de todos os menus.
	bubble = BUBBLE.new()
	ui.add_child(bubble)
	ui.move_child(bubble, 0)
	# Conversa da irmã: acima dos menus, abaixo das animações de passagem.
	dialogo = DIALOGUE.new()
	dialogo.terminou.connect(_dialogo_terminou)
	ui.add_child(dialogo)
	# Por último, para ficar acima de todos os menus.
	transitions = TRANSITIONS.new()
	ui.add_child(transitions)

func box(parent: Control) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	parent.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	return column

func add_label(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func add_button(parent: Control, text: String, callback: Callable, disabled := false) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
