class_name Rua3D
extends RefCounted

# Casario de fundo: as casas que ficam atrás e ao lado do lote, vistas só de
# longe, para fechar o horizonte. As fachadas da rua (portas, comércio,
# marquises, caixas d'água) vêm do modelo do artefato, em modelos/rua_penha.glb.
const P := MalhaLowPoly.Peca

## Cores de reboco comuns no subúrbio; o tijolo sem reboco entra à parte.
const PINTURAS := [
	Color("dfe6d6"), Color("e8dcc6"), Color("d8dde6"), Color("e7e2d2"),
	Color("dde3cf"), Color("e9d9c4"), Color("cfd9d8"),
]

var malha: MalhaLowPoly
var adornos: MalhaLowPoly

func _init(cenario: MalhaLowPoly, decoracao: MalhaLowPoly) -> void:
	malha = cenario
	adornos = decoracao

## Casa cega: caixa com laje ou telhado de duas águas e, às vezes, caixa-d'água.
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

## Caixa-d'água sobre a laje, no lugar mais carioca possível.
func caixa_agua(centro: Vector2, base: float, indice: int) -> void:
	var suporte := 0.35 + float(indice % 2) * 0.25
	for canto: Vector2 in [Vector2(-0.35, -0.35), Vector2(0.35, -0.35), Vector2(-0.35, 0.35), Vector2(0.35, 0.35)]:
		malha.caixa(Vector3(centro.x + canto.x - 0.06, base, centro.y + canto.y - 0.06), Vector3(0.12, suporte, 0.12), Color("c9ccc6"), Color("bcbfb9"), P.CIMENTO, P.CIMENTO)
	malha.cilindro(Vector3(centro.x, base + suporte, centro.y), 0.62, 0.95, 6, Color("9fc0c4"), Color("b4d2d6"), P.METAL)
