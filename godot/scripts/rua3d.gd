class_name Rua3D
extends RefCounted

# Fachadas do quarteirão: casas, bares e comércio vistos só por fora, como nos
# jogos de PS1 (o interior não existe). Cada módulo é uma casa estreita com
# porta, janelas, marquise, placa e caixa-d'água — poucas faces, muita leitura.
const P := MalhaLowPoly.Peca

## Cores de reboco comuns no subúrbio; a última é tijolo sem reboco.
const PINTURAS := [
	Color("dfe6d6"), Color("e8dcc6"), Color("d8dde6"), Color("e7e2d2"),
	Color("dde3cf"), Color("e9d9c4"), Color("cfd9d8"),
]
const LETREIROS := [Color("b8342c"), Color("2f5d8a"), Color("d0a53a"), Color("2f7a5a")]

var malha: MalhaLowPoly
var adornos: MalhaLowPoly

func _init(cenario: MalhaLowPoly, decoracao: MalhaLowPoly) -> void:
	malha = cenario
	adornos = decoracao

## Casa sem fachada trabalhada: preenche o quarteirão ao fundo e fecha o horizonte.
func bloco(canto: Vector2, tamanho: Vector2, indice: int) -> void:
	var tijolo := indice % 4 == 2
	var altura := 3.2 + float(indice % 4) * 0.8
	var cor: Color = Color("cbb6a4") if tijolo else PINTURAS[indice % PINTURAS.size()]
	var peca: int = P.TIJOLO if tijolo else P.PINTADO
	malha.caixa(Vector3(canto.x, 0.0, canto.y), Vector3(tamanho.x, altura, tamanho.y), cor.darkened(0.12), cor, P.CIMENTO, peca)
	if indice % 3 == 1:
		malha.telhado(canto, tamanho, altura, 0.9, Color("d8c0b2"), cor, P.TELHA, peca)
	else:
		malha.caixa(Vector3(canto.x, altura, canto.y), Vector3(tamanho.x, 0.3, tamanho.y), cor.lightened(0.05), cor, P.CIMENTO, peca)
		if indice % 2 == 0: caixa_agua(canto + tamanho * 0.5, altura + 0.3, indice)

## Uma casa da rua. `frente` é a direção para onde a fachada olha (±X ou ±Z).
func modulo(canto: Vector2, tamanho: Vector2, frente: Vector3, indice: int) -> void:
	var tijolo := indice % 5 == 3
	var comercio := indice % 4 == 1
	var altura := 3.0 + float(indice % 3) * 0.7
	var cor: Color = Color("cbb6a4") if tijolo else PINTURAS[indice % PINTURAS.size()]
	var peca: int = P.TIJOLO if tijolo else P.PINTADO
	var origem := Vector3(canto.x, 0.0, canto.y)
	var volume := Vector3(tamanho.x, altura, tamanho.y)
	malha.caixa(origem, volume, cor.darkened(0.1), cor, P.CIMENTO, peca)
	# Laje com platibanda, ou telhado de duas águas nas casas mais simples.
	if indice % 3 == 0:
		malha.telhado(canto, tamanho, altura, 0.8 + float(indice % 2) * 0.4, Color("d8c0b2"), cor, P.TELHA, peca)
	else:
		malha.caixa(origem + Vector3(0, altura, 0), Vector3(volume.x, 0.35, volume.z), cor.lightened(0.05), cor, P.CIMENTO, peca)
		caixa_agua(canto + tamanho * 0.5, altura + 0.35, indice)
	fachada(canto, tamanho, frente, altura, cor, comercio, indice)

## Caixa-d'água sobre a laje, no lugar mais carioca possível.
func caixa_agua(centro: Vector2, base: float, indice: int) -> void:
	var suporte := 0.35 + float(indice % 2) * 0.25
	for canto: Vector2 in [Vector2(-0.35, -0.35), Vector2(0.35, -0.35), Vector2(-0.35, 0.35), Vector2(0.35, 0.35)]:
		malha.caixa(Vector3(centro.x + canto.x - 0.06, base, centro.y + canto.y - 0.06), Vector3(0.12, suporte, 0.12), Color("c9ccc6"), Color("bcbfb9"), P.CIMENTO, P.CIMENTO)
	malha.cilindro(Vector3(centro.x, base + suporte, centro.y), 0.62, 0.95, 6, Color("9fc0c4"), Color("b4d2d6"), P.METAL)

## Frente da casa: porta, janelas e, no comércio, marquise com placa.
func fachada(canto: Vector2, tamanho: Vector2, frente: Vector3, altura: float, cor: Color, comercio: bool, indice: int) -> void:
	var ao_longo_de_x := absf(frente.z) > 0.5
	var largura: float = tamanho.x if ao_longo_de_x else tamanho.y
	# Eixo da fachada e um empurrãozinho para fora, para nada brigar com a parede.
	var eixo := Vector3(1, 0, 0) if ao_longo_de_x else Vector3(0, 0, 1)
	var base := Vector3(canto.x, 0.0, canto.y)
	if frente.x > 0.5: base.x += tamanho.x
	if frente.z > 0.5: base.z += tamanho.y
	var fora := frente * 0.02
	var porta_x := largura * (0.22 + 0.1 * float(indice % 3))
	# Porta: recuo escuro e a folha de madeira por cima.
	placa(base + eixo * (porta_x - 0.55) + fora, eixo, frente, 1.1, 2.15, Color("6f6a60"), P.LISO)
	placa(base + eixo * (porta_x - 0.45) + fora * 2.0, eixo, frente, 0.9, 2.05, Color("d9c4a6"), P.PORTA)
	if comercio:
		# Vitrine baixa com peitoril, marquise apoiada em tirantes e letreiro na testeira.
		var vitrine := largura * 0.5
		var vitrine_x := largura - vitrine - 0.35
		placa(base + eixo * (vitrine_x - 0.07), eixo, frente, vitrine + 0.14, 1.74, Color("6f6a60"), P.LISO, 0.56)
		placa(base + eixo * vitrine_x + fora, eixo, frente, vitrine, 1.6, Color("cfe0e4"), P.VIDRO, 0.63)
		for divisao in 2:
			placa(base + eixo * (vitrine_x + vitrine * (0.33 + 0.34 * divisao)) + fora * 2.0, eixo, frente, 0.07, 1.6, Color("9aa0a2"), P.METAL, 0.63)
		marquise(base, eixo, frente, largura, indice)
	else:
		for i in (2 if largura > 5.0 else 1):
			var x := largura * (0.55 + 0.2 * i)
			if x + 1.0 > largura: continue
			janela(base + eixo * x + fora, eixo, frente, 1.0, 1.1, 1.0)
	# Segundo andar: varanda com guarda-corpo nas casas mais altas.
	if altura > 4.0:
		placa(base + eixo * 0.25 + fora, eixo, frente, largura - 0.5, 0.9, Color("b9bdb6"), P.METAL, 3.1)
		for i in (2 if largura > 5.0 else 1):
			janela(base + eixo * (largura * (0.3 + 0.35 * i)) + fora, eixo, frente, 0.9, 1.0, 3.3)

## Marquise de concreto sobre a calçada, com tirantes e letreiro na testeira.
func marquise(base: Vector3, eixo: Vector3, frente: Vector3, largura: float, indice: int) -> void:
	var balanco := 1.25
	var altura := 2.72
	var ao_longo_de_x := absf(frente.z) > 0.5
	# A laje avança para fora da parede; a origem recua quando a frente é negativa.
	var avanco := frente * balanco
	var canto := base + eixo * 0.12 + Vector3(minf(avanco.x, 0.0), altura, minf(avanco.z, 0.0))
	var tamanho := Vector3(largura - 0.24, 0.16, balanco) if ao_longo_de_x else Vector3(balanco, 0.16, largura - 0.24)
	malha.caixa(canto, tamanho, Color("d3d6cf"), Color("c0c4bd"), P.CIMENTO, P.CIMENTO)
	# Testeira pintada com o nome do comércio (uma cor forte, à moda da época).
	var testeira := frente * (balanco + 0.02)
	var frente_canto := base + eixo * 0.12 + Vector3(testeira.x, altura + 0.16, testeira.z)
	placa(frente_canto, eixo, frente, largura - 0.24, 0.46, LETREIROS[indice % LETREIROS.size()], P.LISO)
	# Tirantes ligando a ponta da marquise à parede.
	for lado: float in [0.35, largura - 0.5]:
		var pe := base + eixo * lado + Vector3(avanco.x, altura, avanco.z)
		var topo := base + eixo * lado + Vector3(0, altura + 0.75, 0)
		var direcao := (topo - pe).normalized()
		# Barra fina inclinada: duas faces bastam para ler como tirante.
		# A normal é perpendicular à própria barra, não à fachada.
		var lateral := eixo * 0.05
		var normal := eixo.cross(direcao).normalized()
		malha.quadrilatero(pe - lateral, pe + lateral, topo + lateral, topo - lateral, Color("9aa0a2"), P.METAL, normal)
		malha.quadrilatero(topo - lateral, topo + lateral, pe + lateral, pe - lateral, Color("9aa0a2"), P.METAL, -normal)

## Retângulo colado na fachada (porta, vitrine, placa, guarda-corpo).
func placa(origem: Vector3, eixo: Vector3, frente: Vector3, largura: float, altura: float, cor: Color, peca: int, base_y := 0.0) -> void:
	var a := origem + Vector3(0, base_y, 0)
	var b := a + eixo * largura
	var c := b + Vector3(0, altura, 0)
	var d := a + Vector3(0, altura, 0)
	malha.quadrilatero(a, b, c, d, cor, peca, frente)

## Janela embutida: peitoril, moldura fina e o vidro rente à parede.
func janela(origem: Vector3, eixo: Vector3, frente: Vector3, largura: float, altura: float, base_y: float) -> void:
	placa(origem - eixo * 0.06, eixo, frente, largura + 0.12, altura + 0.12, Color("c9c3b4"), P.CIMENTO, base_y - 0.06)
	placa(origem, eixo, frente + frente * 0.01, largura, altura, Color("cfe0e4"), P.VIDRO, base_y)
	# Peitoril saliente, que dá a sombra da janela.
	var canto := origem + Vector3(minf(frente.x, 0.0) * 0.1, base_y - 0.1, minf(frente.z, 0.0) * 0.1)
	var tamanho := Vector3(largura + 0.12, 0.08, 0.14) if absf(frente.z) > 0.5 else Vector3(0.14, 0.08, largura + 0.12)
	malha.caixa(canto - eixo * 0.06, tamanho, Color("d2ccbc"), Color("c2bcac"), P.CIMENTO, P.CIMENTO)
