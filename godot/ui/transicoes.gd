extends Control

# Telas de passagem desenhadas em código: ônibus andando, tela preta e sono.
# Uso: await transicoes.executar("onibus", 3.2, {"texto": "...", "letreiro": "CENTRO", "noite": 0.8})
# Opções: "texto" (legenda), "letreiro" (ônibus), "noite" (0 dia a 1 noite),
# "meio" (Callable chamado uma vez com a tela preta), "texto_final" (Callable que devolve a legenda do fim do sono).
signal terminou

var tipo := ""
var duracao := 1.0
var opcoes: Dictionary = {}
var _t := 0.0
var _meio_chamado := false
var _texto_final := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

func executar(novo_tipo: String, segundos: float, novas_opcoes := {}) -> void:
	tipo = novo_tipo
	duracao = segundos
	opcoes = novas_opcoes
	_t = 0.0
	_meio_chamado = false
	_texto_final = ""
	show()
	queue_redraw()
	await terminou

## Pula o que estiver tocando (usado em testes).
func concluir() -> void:
	if visible: _t = duracao

func _process(delta: float) -> void:
	if not visible: return
	_t += delta
	if not _meio_chamado and _t >= duracao * 0.5:
		_meio_chamado = true
		if opcoes.has("meio"): (opcoes.meio as Callable).call()
		if opcoes.has("texto_final"): _texto_final = (opcoes.texto_final as Callable).call()
	queue_redraw()
	if _t >= duracao:
		hide()
		terminou.emit()

func _draw() -> void:
	var p := clampf(_t / duracao, 0.0, 1.0)
	match tipo:
		"escurecer": draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, smoothstep(0.0, 1.0, p)))
		"onibus": _desenhar_onibus(p)
		"preto": _desenhar_preto(p)
		"sono": _desenhar_sono(p)

# Opacidade do preto nas bordas da transição.
func _escuro(p: float, entrada: float, saida: float) -> float:
	return maxf(1.0 - smoothstep(0.0, entrada, p), smoothstep(1.0 - saida, 1.0, p))

func _legenda(texto: String, alpha: float, y := 0.86, tamanho := 22) -> void:
	var fonte := ThemeDB.fallback_font
	draw_string(fonte, Vector2(0, size.y * y) + Vector2(2, 2), texto, HORIZONTAL_ALIGNMENT_CENTER, size.x, tamanho, Color(0, 0, 0, 0.7 * alpha))
	draw_string(fonte, Vector2(0, size.y * y), texto, HORIZONTAL_ALIGNMENT_CENTER, size.x, tamanho, Color(0.95, 0.92, 0.84, alpha))

func _desenhar_preto(p: float) -> void:
	# Começa já no preto (vindo do ônibus); termina no preto se outra cena vem depois.
	var alpha := 1.0 if opcoes.get("continua", true) else 1.0 - smoothstep(0.85, 1.0, p)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, alpha))
	var pontos := ".".repeat(int(_t * 2.0) % 4)
	_legenda(opcoes.get("texto", "") + pontos, alpha * smoothstep(0.0, 0.15, p), 0.5, 26)

func _desenhar_sono(p: float) -> void:
	var alpha := maxf(smoothstep(0.0, 0.15, p), 0.0) * (1.0 - smoothstep(0.88, 1.0, p))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.012, 0.02, alpha))
	var fonte := ThemeDB.fallback_font
	var centro := size * Vector2(0.5, 0.52)
	# Respiração lenta e "Z"s que sobem, crescem e somem.
	var respiro := 0.5 + 0.5 * sin(_t * 1.6)
	draw_circle(centro + Vector2(0, 40), 70 + 8 * respiro, Color(0.25, 0.3, 0.5, 0.06 * alpha))
	for i in 6:
		var fase := fmod(_t * 0.45 + i / 6.0, 1.0)
		var pos := centro + Vector2(-30 + fase * 90 + sin(fase * 9.0 + i) * 10, 40 - fase * 170)
		var tamanho := int(18 + fase * 34)
		var cor := Color(0.78, 0.82, 1.0, alpha * sin(fase * PI) * 0.9)
		draw_string(fonte, pos, "z" if i % 2 else "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)
	if _meio_chamado and _texto_final != "":
		_legenda(_texto_final, alpha * smoothstep(0.55, 0.7, p), 0.8, 26)
	else:
		_legenda("Dormindo", alpha * (1.0 - smoothstep(0.4, 0.5, p)), 0.8, 22)

func _desenhar_onibus(p: float) -> void:
	var noite: float = opcoes.get("noite", 0.0)
	var w := size.x
	var h := size.y
	# "volta": espelha a cena para o ônibus seguir no sentido contrário (legenda fica normal).
	var volta: bool = opcoes.get("volta", false)
	if volta: draw_set_transform(Vector2(w, 0), 0, Vector2(-1, 1))
	# Céu e prédios ao fundo, mudando com a hora do dia.
	var ceu := Color(0.55, 0.66, 0.72).lerp(Color(0.04, 0.06, 0.12), noite)
	var ceu_baixo := Color(0.86, 0.78, 0.62).lerp(Color(0.12, 0.1, 0.14), noite)
	# Fundo opaco na tela toda: nada do jogo aparece entre as camadas da cena.
	draw_rect(Rect2(Vector2.ZERO, size), ceu_baixo)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h * 0.65), Vector2(0, h * 0.65)]), PackedColorArray([ceu, ceu, ceu_baixo, ceu_baixo]))
	var rolagem := _t * 60.0
	for camada in 2:
		var velocidade := 0.4 if camada == 0 else 1.0
		var base := h * (0.62 if camada == 0 else 0.64)
		var cor_predio := Color(0.36, 0.38, 0.4).lerp(Color(0.07, 0.08, 0.1), noite).darkened(0.15 * camada)
		for i in 14:
			var largura := 90.0 + fmod(i * 53.0, 70.0)
			var altura := 90.0 + fmod(i * 97.0, 150.0) - camada * 30.0
			var x := fmod(i * 150.0 - rolagem * velocidade * (1 + camada), 150.0 * 14) - 150.0
			draw_rect(Rect2(x, base - altura, largura, altura), cor_predio)
			for j in 6:
				var janela := Rect2(x + 12 + (j % 3) * 26, base - altura + 16 + (j / 3) * 30, 12, 14)
				var acesa := fmod(i * 7.0 + j * 3.0, 5.0) < 2.0
				var cor_janela := Color(0.3, 0.34, 0.36, 0.6).lerp(Color(1.0, 0.8, 0.45, 0.9) if acesa else Color(0.05, 0.05, 0.07), noite)
				draw_rect(janela, cor_janela)
	# Calçada, meio-fio, asfalto e faixas passando.
	draw_rect(Rect2(0, h * 0.64, w, h * 0.06), Color(0.52, 0.52, 0.48).lerp(Color(0.14, 0.14, 0.15), noite))
	draw_rect(Rect2(0, h * 0.7, w, h * 0.3), Color(0.24, 0.25, 0.26).lerp(Color(0.06, 0.065, 0.075), noite))
	var faixa := fmod(rolagem * 6.0, 140.0)
	for i in 9:
		draw_rect(Rect2(i * 140.0 - faixa, h * 0.9, 70, 6), Color(0.85, 0.8, 0.55).lerp(Color(0.35, 0.33, 0.25), noite))
	# Postes passando rápido; à noite, com luz amarelada.
	var poste := fmod(rolagem * 4.0, 420.0)
	for i in 4:
		var x := i * 420.0 - poste + 120.0
		if noite > 0.3:
			draw_circle(Vector2(x + 26, h * 0.46), 90, Color(1.0, 0.7, 0.35, 0.08 * noite))
		draw_rect(Rect2(x, h * 0.3, 7, h * 0.35), Color(0.2, 0.2, 0.2))
		draw_rect(Rect2(x, h * 0.3, 34, 6), Color(0.2, 0.2, 0.2))
		draw_rect(Rect2(x + 22, h * 0.31, 14, 6), Color(1.0, 0.82, 0.5).lerp(Color(0.5, 0.5, 0.45), 1.0 - noite))
	# Ônibus atravessando a tela com leve balanço.
	var corpo := Vector2(430, 150)
	var x_onibus := lerpf(-corpo.x - 40, w + 40, p)
	var y_onibus := h * 0.9 - corpo.y - 26 + sin(_t * 18.0) * 1.5
	_onibus(Vector2(x_onibus, y_onibus), corpo, noite)
	draw_set_transform(Vector2.ZERO)
	_legenda(opcoes.get("texto", ""), smoothstep(0.08, 0.2, p) * (1.0 - smoothstep(0.8, 0.9, p)), 0.18, 24)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, _escuro(p, 0.12, 0.12)))

func _onibus(origem: Vector2, corpo: Vector2, noite: float) -> void:
	var fonte := ThemeDB.fallback_font
	var roda_r := 28.0
	# Farol à frente, sombra, carroceria e faixa.
	if noite > 0.3:
		draw_colored_polygon(PackedVector2Array([origem + Vector2(corpo.x, corpo.y - 30), origem + Vector2(corpo.x + 260, corpo.y - 70), origem + Vector2(corpo.x + 260, corpo.y + 40), origem + Vector2(corpo.x, corpo.y - 14)]), Color(1.0, 0.9, 0.6, 0.12 * noite))
	draw_rect(Rect2(origem + Vector2(10, corpo.y + 10), Vector2(corpo.x - 10, 16)), Color(0, 0, 0, 0.35))
	var carroceria := Color("d2a43a")
	draw_rect(Rect2(origem + Vector2(0, 8), corpo - Vector2(0, 8)), carroceria)
	draw_rect(Rect2(origem + Vector2(8, 0), Vector2(corpo.x - 20, 10)), carroceria.darkened(0.08))
	draw_rect(Rect2(origem + Vector2(0, corpo.y - 42), Vector2(corpo.x, 16)), Color("2f5d8a"))
	draw_rect(Rect2(origem + Vector2(0, corpo.y - 26), Vector2(corpo.x, 4)), Color("f2efe2"))
	# Janelas com passageiros; iluminadas por dentro à noite.
	var vidro := Color(0.2, 0.28, 0.32).lerp(Color(0.95, 0.85, 0.55), noite * 0.85)
	for i in 6:
		var janela := Rect2(origem + Vector2(18 + i * 58, 22), Vector2(48, 50))
		draw_rect(janela, vidro)
		if i % 2 == 0:
			draw_circle(janela.position + Vector2(24, 36), 9, Color(0.1, 0.1, 0.12, 0.7))
			draw_rect(Rect2(janela.position + Vector2(13, 44), Vector2(22, 8)), Color(0.1, 0.1, 0.12, 0.7))
	# Porta, para-brisa, letreiro, farol e lanterna.
	draw_rect(Rect2(origem + Vector2(corpo.x - 70, 22), Vector2(34, corpo.y - 40)), Color(0.16, 0.2, 0.22).lerp(Color(0.8, 0.7, 0.45), noite * 0.6))
	draw_line(origem + Vector2(corpo.x - 53, 24), origem + Vector2(corpo.x - 53, corpo.y - 20), Color(0.1, 0.1, 0.1), 2)
	draw_rect(Rect2(origem + Vector2(corpo.x - 28, 18), Vector2(24, 60)), vidro.lightened(0.1))
	var letreiro := Rect2(origem + Vector2(corpo.x - 150, 2), Vector2(116, 16))
	draw_rect(letreiro, Color(0.08, 0.08, 0.08))
	# Com a cena espelhada, o texto do letreiro é desenhado desespelhado no mesmo lugar.
	if opcoes.get("volta", false):
		draw_set_transform(Vector2.ZERO)
		var tela := Rect2(Vector2(size.x - letreiro.end.x, letreiro.position.y), letreiro.size)
		draw_string(fonte, tela.position + Vector2(0, 13), opcoes.get("letreiro", ""), HORIZONTAL_ALIGNMENT_CENTER, tela.size.x, 13, Color(1.0, 0.72, 0.2))
		draw_set_transform(Vector2(size.x, 0), 0, Vector2(-1, 1))
	else:
		draw_string(fonte, letreiro.position + Vector2(0, 13), opcoes.get("letreiro", ""), HORIZONTAL_ALIGNMENT_CENTER, letreiro.size.x, 13, Color(1.0, 0.72, 0.2))
	draw_rect(Rect2(origem + Vector2(corpo.x - 8, corpo.y - 30), Vector2(8, 10)), Color(1.0, 0.95, 0.75))
	draw_rect(Rect2(origem + Vector2(0, corpo.y - 30), Vector2(6, 12)), Color(0.8, 0.2, 0.15))
	# Rodas girando.
	for x in [70.0, corpo.x - 95.0]:
		var centro := origem + Vector2(x, corpo.y)
		draw_circle(centro, roda_r + 4, Color(0.12, 0.1, 0.08))
		draw_circle(centro, roda_r, Color(0.08, 0.08, 0.08))
		draw_circle(centro, roda_r * 0.5, Color(0.55, 0.55, 0.52))
		for k in 5:
			var angulo := _t * 14.0 + k * TAU / 5.0
			draw_line(centro, centro + Vector2.from_angle(angulo) * roda_r * 0.48, Color(0.25, 0.25, 0.25), 3)
	# Fumaça saindo do escapamento.
	for k in 4:
		var fase := fmod(_t * 1.5 + k * 0.25, 1.0)
		draw_circle(origem + Vector2(-10 - fase * 60, corpo.y - 6 - fase * 20), 6 + fase * 16, Color(0.55, 0.55, 0.55, 0.25 * (1.0 - fase)))
