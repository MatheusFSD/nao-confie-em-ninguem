extends SceneTree

# Ferramenta de autoria: desenha sprites/atlas3d.png, a textura única do mundo 3D.
# 4 × 4 peças de 32 px (128 × 128 no total), como nos jogos de PlayStation 1:
# uma imagem pequena serve para o cenário inteiro.
#   godot --headless --path godot --script res://sprites/fontes/desenhar_atlas3d.gd
#   godot --headless --path godot --import
const PECA := 32
const GRADE := 4
const LINHAS := 5

var imagem: Image
var semente := 0

func _initialize() -> void:
	imagem = Image.create_empty(PECA * GRADE, PECA * LINHAS, false, Image.FORMAT_RGBA8)
	reboco(0, 0, Color("cfc7b4"), Color("bdb3a0"))          # 0 reboco claro
	reboco(1, 0, Color("9fb08f"), Color("8a9b7c"))          # 1 reboco pintado de verde
	tijolo(2, 0)                                            # 2 tijolo aparente
	telha(3, 0)                                             # 3 telha de barro
	granulado(0, 1, Color("41474c"), Color("363b40"), 0.5)  # 4 asfalto
	calcada(1, 1)                                           # 5 calçada
	granulado(2, 1, Color("8e9184"), Color("7c8073"), 0.35) # 6 cimento do quintal
	granulado(3, 1, Color("6d5a44"), Color("5c4b38"), 0.6)  # 7 terra
	taco(0, 2)                                              # 8 taco de madeira
	azulejo(1, 2)                                           # 9 azulejo
	metal(2, 2)                                             # 10 metal / grade
	vidro(3, 2)                                             # 11 vidro
	porta(0, 3)                                             # 12 porta de madeira
	tecido(1, 3)                                            # 13 tecido de sofá
	folha(2, 3)                                             # 14 folhagem
	liso(3, 3, Color("d8d4c8"))                             # 15 liso (peça neutra)
	rosto(0, 4, Color("c99a6c"))                            # 16 rosto
	cabelo(1, 4, Color("2a211c"))                           # 17 cabelo
	camisa(2, 4, Color("8fa8bd"))                           # 18 camisa
	calca(3, 4, Color("57606c"))                            # 19 calça
	assert(imagem.save_png(ProjectSettings.globalize_path("res://sprites/atlas3d.png")) == OK)
	print("atlas3d.png salvo")
	quit()

# Ruído estável: mesma peça sempre sai igual.
func ruido(x: int, y: int) -> float:
	semente = (x * 73856093) ^ (y * 19349663) ^ 0x5f3759df
	return float(absi(semente) % 1000) / 1000.0

func ponto(px: int, py: int, x: int, y: int, cor: Color) -> void:
	imagem.set_pixel(px * PECA + x, py * PECA + y, cor)

func liso(px: int, py: int, cor: Color) -> void:
	for y in PECA:
		for x in PECA:
			ponto(px, py, x, y, cor)

func granulado(px: int, py: int, cor: Color, escura: Color, forca: float) -> void:
	for y in PECA:
		for x in PECA:
			var r := ruido(px * 100 + x, py * 100 + y)
			ponto(px, py, x, y, cor.lerp(escura, r * forca))

## Reboco com manchas, sem barra de sujeira: a peça se repete a cada metro.
func reboco(px: int, py: int, cor: Color, suja: Color) -> void:
	for y in PECA:
		for x in PECA:
			var r := ruido(px * 31 + x, py * 57 + y)
			var base := cor.lerp(suja, r * 0.35)
			# Sem barra de sujeira embaixo: a peça se repete a cada metro e a barra
			# virava uma prateleira escura de metro em metro na parede.
			if r > 0.985: base = base.darkened(0.3)
			ponto(px, py, x, y, base)

func tijolo(px: int, py: int) -> void:
	var barro := Color("8f5136")
	var junta := Color("b4ad9a")
	for y in PECA:
		for x in PECA:
			var linha := y / 8
			var desloca := 0 if linha % 2 == 0 else 8
			var dentro_x := (x + desloca) % 16
			var cor := barro.lerp(barro.darkened(0.25), ruido(x, y) * 0.5)
			if y % 8 < 2 or dentro_x < 2: cor = junta
			ponto(px, py, x, y, cor)

func telha(px: int, py: int) -> void:
	var barro := Color("a8543a")
	for y in PECA:
		for x in PECA:
			var onda := absf(sin(float(x) * 0.6))
			var cor := barro.darkened(0.25 - onda * 0.25)
			if x % 8 == 0: cor = barro.darkened(0.42)
			cor = cor.lerp(cor.darkened(0.2), ruido(x, y) * 0.3)
			ponto(px, py, x, y, cor)

func calcada(px: int, py: int) -> void:
	var pedra := Color("a5a89b")
	for y in PECA:
		for x in PECA:
			var cor := pedra.lerp(pedra.darkened(0.28), ruido(x, y) * 0.4)
			if x % 16 == 0 or y % 16 == 0: cor = pedra.darkened(0.35)
			ponto(px, py, x, y, cor)

func taco(px: int, py: int) -> void:
	var madeira := Color("8a5c34")
	for y in PECA:
		for x in PECA:
			var bloco := (x / 8 + y / 8) % 2 == 0
			var veio := absf(sin(float(x if bloco else y) * 1.7)) * 0.18
			var cor := madeira.darkened(veio + (0.1 if bloco else 0.0))
			if x % 8 == 0 or y % 8 == 0: cor = cor.darkened(0.3)
			ponto(px, py, x, y, cor)

func azulejo(px: int, py: int) -> void:
	var branco := Color("cdd6cf")
	for y in PECA:
		for x in PECA:
			var cor := branco.lerp(branco.darkened(0.12), ruido(x, y) * 0.35)
			if x % 16 == 0 or y % 16 == 0: cor = Color("9aa79f")
			ponto(px, py, x, y, cor)

func metal(px: int, py: int) -> void:
	var aco := Color("7d837c")
	for y in PECA:
		for x in PECA:
			var cor := aco.darkened(absf(sin(float(x) * 0.9)) * 0.22)
			if x % 10 < 2: cor = aco.darkened(0.45)
			ponto(px, py, x, y, cor)

func vidro(px: int, py: int) -> void:
	var azul := Color("7f9aa3")
	for y in PECA:
		for x in PECA:
			var cor := azul.lerp(Color("b7ccd0"), clampf(1.0 - float(x + y) / 64.0, 0.0, 1.0) * 0.5)
			if x < 2 or y < 2 or x > 29 or y > 29: cor = Color("6c736e")
			ponto(px, py, x, y, cor)

func porta(px: int, py: int) -> void:
	var madeira := Color("7a5233")
	for y in PECA:
		for x in PECA:
			var cor := madeira.lerp(madeira.darkened(0.25), ruido(x, y) * 0.4)
			var almofada := x > 5 and x < 26 and ((y > 4 and y < 14) or (y > 18 and y < 28))
			if almofada: cor = cor.darkened(0.18)
			if x < 2 or x > 29: cor = madeira.darkened(0.35)
			ponto(px, py, x, y, cor)

func tecido(px: int, py: int) -> void:
	var verde := Color("53705c")
	for y in PECA:
		for x in PECA:
			var trama := (x % 4 == 0 or y % 4 == 0)
			ponto(px, py, x, y, verde.darkened(0.12 if trama else 0.0).lerp(verde.lightened(0.1), ruido(x, y) * 0.25))

func folha(px: int, py: int) -> void:
	var verde := Color("4d7040")
	for y in PECA:
		for x in PECA:
			var r := ruido(x * 3, y * 3)
			var cor := verde.lerp(verde.darkened(0.35), r)
			# Recorta as bordas para a folhagem não parecer um quadrado.
			var dentro := absf(float(x) - 16.0) / 16.0 + absf(float(y) - 16.0) / 18.0
			var alpha := 1.0 if dentro < 0.95 + r * 0.25 else 0.0
			imagem.set_pixel(px * PECA + x, py * PECA + y, Color(cor.r, cor.g, cor.b, alpha))

# --------------------------------------------------- peças de personagem (linha 5)

## Rosto de PS1: tudo pintado na textura, sem geometria a mais.
func rosto(px: int, py: int, pele: Color) -> void:
	liso(px, py, pele)
	for y in PECA:
		for x in PECA:
			var cor := pele.lerp(pele.darkened(0.18), ruido(x * 7, y * 5) * 0.25)
			# Sobrancelhas, olhos e boca em poucos pixels, como na época.
			if y >= 11 and y <= 12 and ((x >= 6 and x <= 12) or (x >= 19 and x <= 25)): cor = Color("2a211c")
			elif y >= 14 and y <= 16 and ((x >= 7 and x <= 11) or (x >= 20 and x <= 24)): cor = Color("f2ece0")
			elif y >= 15 and y <= 16 and ((x >= 8 and x <= 9) or (x >= 21 and x <= 22)): cor = Color("2c2620")
			elif y >= 19 and y <= 21 and x >= 14 and x <= 17: cor = pele.darkened(0.22)
			elif y >= 24 and y <= 25 and x >= 11 and x <= 20: cor = Color("7d4a42")
			ponto(px, py, x, y, cor)

func cabelo(px: int, py: int, cor: Color) -> void:
	for y in PECA:
		for x in PECA:
			ponto(px, py, x, y, cor.lerp(cor.lightened(0.18), ruido(x * 11, y * 13) * 0.5))

## Camisa com gola e costura lateral.
func camisa(px: int, py: int, cor: Color) -> void:
	for y in PECA:
		for x in PECA:
			var tom := cor.lerp(cor.darkened(0.2), ruido(x * 5, y * 9) * 0.3)
			if y < 4 and x > 9 and x < 22: tom = cor.darkened(0.35)
			if x < 2 or x > 29: tom = cor.darkened(0.25)
			ponto(px, py, x, y, tom)

func calca(px: int, py: int, cor: Color) -> void:
	for y in PECA:
		for x in PECA:
			var tom := cor.lerp(cor.lightened(0.12), ruido(x * 3, y * 7) * 0.35)
			if x == 15 or x == 16: tom = cor.darkened(0.3)
			ponto(px, py, x, y, tom)
