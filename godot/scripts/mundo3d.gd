extends Node

# Monta o subúrbio em 3D com os modelos do artefato:
#   - a casa do protagonista, inteira num modelo só (Casa3D), com os móveis já
#     arrumados nos cômodos e sete portas que abrem;
#   - a rua — pista, calçadas, postes, fios — de modelos/rua_penha.glb, em três
#     trechos emendados para ela sumir na névoa em vez de acabar numa parede;
#   - as casas e os comércios dos vizinhos, de scenes/casario.tscn, que é
#     editada na mão no editor.
# O que ainda é gerado por código é só o terreno do bairro e o casario cego do
# fundo, que fecham o horizonte atrás de tudo.
#
# O mapa 2D (scenes/mapa.tscn) continua mandando no jogo 2D; o mundo 3D não
# depende mais dele.
const PS1 := preload("res://shaders/ps1.gdshader")
const ATLAS := preload("res://sprites/atlas3d.png")
const CASARIO := preload("res://scenes/casario.tscn")
const PONTO := preload("res://modelos/objetos/ponto_de_onibus.glb")
const Pessoa3D := preload("res://scripts/pessoa3d.gd")
## Onde a rua do modelo entra: eixo da pista, meio do trecho e altura.
## Com -0,15 o topo da calçada do modelo fica no nível 0, igual ao chão do lote.
const RUA_EIXO_Z := 28.2
const RUA_CENTRO_X := 8.62
const RUA_ALTURA := -0.15
## O lote da casa, do tamanho do modelo dela, e o miolo do bairro em volta.
const LOTE := Rect2(5.5, 0.8, 14.0, 18.5)
## Onde a origem do modelo da casa fica: o portão dele encosta na calçada.
const CASA_LUGAR := Vector3(12.25, 0.0, 9.4)
const BAIRRO := Rect2(-20.0, -12.5, 75.0, 31.5)
## Os blocos cegos do fundo param antes das casas da rua, que têm até 13 m.
const FUNDO_LIMITE := 6.0
## Tamanho da tela pequena, em pixels. Não se mexe aqui: ele sai da janela
## dividida pelo `stretch_shrink` do nó Tela, que é o botão do pixelado —
## 3 dá 320 × 213 numa janela de 960 × 640, 4 dá um pixel ainda mais grosso.
var RESOLUCAO := Vector2(320.0, 213.0)
## Até onde o jogador anda na rua. A barreira fica longe, e além dela a rua
## continua em cópias do modelo, sumindo na névoa.
const RUA_LIMITE := Vector2(-46.0, 62.0)
## Quanto de rua as cópias de continuação guardam além da barreira.
const ALCANCE_NEVOA := 85.0
## Linhas de caminhada das duas calçadas, medidas na seção do modelo.
## As duas faixas da pista, lidas do modelo: o eixo da rua mais ou menos 3 m.
const FAIXA_DE_CA := RUA_EIXO_Z - 3.0
const FAIXA_DE_LA := RUA_EIXO_Z + 3.0
## Quantos carros passam na rua.
## Quanta gente anda na calçada num dia normal.
const QUANTAS_PESSOAS := 6
const QUANTOS_CARROS := 6
## O calendário do fim. No dia 5 a cidade inteira tenta ir embora de uma vez e
## a rua entope; no 6 acaba a luz e o dia inteiro é breu; no 7 a criatura
## ataca, com o céu vermelho e o Exército passando na rua.
const DIA_DO_ENGARRAFAMENTO := 5
const DIA_DO_BREU := Ciclo3D.DIA_DO_BREU
const DIA_DO_ATAQUE := Ciclo3D.DIA_DO_CORTE
const CORPOS_DADOS := "res://data/corpos3d.json"
const CARROS_NO_ENGARRAFAMENTO := 14
## De quanto em quanto metro fica um carro na fila do engarrafamento.
const PASSO_DA_FILA := 6.5
## O comboio do dia do ataque: um blindado na frente e os caminhões atrás.
const CAMINHOES_DO_COMBOIO := 3
## Quantos caçadores andam pela rua no breu e depois que o Exército passa.
const CACADORES_NO_BREU := 2
const CACADORES_DEPOIS := 3
## Quantos helicópteros cruzam o céu enquanto a cidade está em guerra.
const QUANTOS_HELICOPTEROS := 3
const CALCADA_PERTO := 21.6
const CALCADA_LONGE := 34.9
## Onde fica o abrigo do ponto de ônibus, na calçada à esquerda do lote.
const PONTO_LUGAR := Vector3(1.0, 0.0, 20.6)
## Quantos vizinhos moram no quarteirão nesta partida.
const QUANTOS_VIZINHOS := 5
const DIALOGO := preload("res://ui/dialogo.gd")
const P := MalhaLowPoly.Peca
## Folga para as caixas vizinhas se invadirem um pouco: faces exatamente
## coladas brigam na tela, e a emenda vira um risco piscando.
const FOLGA := 0.004
## Quanto uma casa da rua invade a vizinha, pelo mesmo motivo.
const ENCAIXE := 0.15
## De dia o comércio está aberto. À noite e no apocalipse, entra a versão
## fechada, que é o mesmo modelo com a porta de aço baixada.
var comercio_aberto := true
## Até onde o jogador enxerga uma porta para abrir.
const ALCANCE_DA_MAO := 2.6
## Os cinco raios da mira: o do meio e quatro em volta.
const DESVIOS := [Vector2.ZERO, Vector2(0.11, 0.0), Vector2(-0.11, 0.0), Vector2(0.0, 0.11), Vector2(0.0, -0.11)]
var malha_cenario := MalhaLowPoly.new()
var rua: Rua3D
var material_ps1: ShaderMaterial
var mundo: Node3D
var jogador: CharacterBody3D
var camera: Camera3D
var rua_modelo: Node3D
var casa: Casa3D
var cidade: Cidade3D
var dica: Dica3D
var menu: MenuPonto
var expediente: Expediente3D
var status: Status3D
var ciclo: Ciclo3D
var postes: Array = []
var dormindo := false
var balao: Balao3D
var conversa := Conversa3D.new()
var tv: Tv3D
var noticias := Noticias3D.new()
## Os cinco vizinhos sorteados nesta partida, um por porta da rua.
var vizinhos: Array = []
var dialogo: Control
## Com quem se está falando na porta agora, e o menu de ajudar ou não.
var na_porta := -1
var escolha: MenuEscolha
var fresta: Fresta3D
var camera_da_fresta: Camera3D
## A mochila, o celular e o que chega nele.
var mochila: Mochila3D
var celular: Celular3D
var mensagens := Mensagens3D.new()
## A luz da lanterna, presa na câmera.
var luz_da_lanterna: SpotLight3D
## De qual janela se está espiando agora.
var de_qual_janela := Vector3.ZERO
## Cores da noite, misturadas por cima do ar do dia conforme as ações passam.
## As cores do breu: o dia em que a cidade inteira apagou.
const BREU_ALTO := Color("01010400")
const BREU_BAIXO := Color("03040a")
const BREU_NEVOA := Color("020309")
const NOITE_ALTA := Color("0d1120")
const NOITE_BAIXA := Color("2a2b3c")
const NOITE_NEVOA := Color("2c3040")
## O que o HUD mostra. Quem manda nisso é o jogo; aqui ficam os valores de
## partida, que o 2D substitui quando os dois forem ligados.
@export var comida := 2
@export var agua := 3
@export var energia := 100
@export var dinheiro := 80
## Guardado para voltar depois da cutscene, que põe o ambiente dela no lugar.
var ambiente_do_bairro: Environment
## Criados uma vez no breu; o horizonte muda, estes corpos não.
var corpos: Node3D
## Que dia da história o mundo mostra. Manda na cidade do horizonte e, com ela,
## na cor do céu e da névoa: 1 a 3 normal, 3 a 7 estranha, 7 a 9 em chamas,
## 9 em diante destruída. O jogo 2D troca isto ao virar o dia.
@export var dia := 1
## Modo deus desde o começo, para quem está testando. Em jogo, F10 liga e desliga.
@export var modo_deus := false
var inicio := Vector3(9.75, 0.25, 12.4)

func _ready() -> void:
	mundo = get_node("Tela/Render/Mundo")
	jogador = get_node("Tela/Render/Jogador")
	camera = jogador.get_node("Camera3D")
	medir_a_tela()
	rua = Rua3D.new(malha_cenario, malha_cenario)
	material_ps1 = ShaderMaterial.new()
	material_ps1.shader = PS1
	material_ps1.set_shader_parameter("atlas", ATLAS)
	material_ps1.set_shader_parameter("resolucao_tela", RESOLUCAO)
	construir()
	jogador.global_position = inicio
	jogador.interagiu.connect(usar_o_que_estiver_na_mira)
	jogador.trancou.connect(trancar_o_que_estiver_na_mira)
	jogador.pediu_modo_deus.connect(virar_deus)
	jogador.abriu_a_mochila.connect(abrir_a_mochila)
	jogador.mexeu_na_hora.connect(mudar_a_hora)

## Quanto o mundo é desenhado pequeno antes de ser esticado de volta. Quem manda
## é o `stretch_shrink` do nó Tela; aqui só se lê o resultado, para os materiais
## usarem a mesma grade que a tela.
func medir_a_tela() -> void:
	var tela := get_node("Tela") as SubViewportContainer
	var encolhe := maxi(1, tela.stretch_shrink)
	var janela := Vector2(get_window().size)
	RESOLUCAO = (janela / float(encolhe)).floor()

func construir() -> void:
	construir_terreno()
	construir_fundo()
	aplicar_malha()
	casa = Casa3D.new()
	casa.montar(mundo, CASA_LUGAR, RESOLUCAO)
	construir_ponto()
	rua_modelo = RuaModelo.instanciar(mundo, RUA_EIXO_Z, RUA_CENTRO_X, RUA_ALTURA, RESOLUCAO)
	# As pontas do trecho principal se abrem e a rua segue em cópias enxutas,
	# para quem chega na barreira ver rua sumindo na névoa, não uma parede.
	RuaModelo.tirar_tampas(rua_modelo, 0)
	var continuacoes := []
	for lado in [-1, 1]:
		continuacoes.append(RuaModelo.continuar(mundo, rua_modelo, lado, ALCANCE_NEVOA, RESOLUCAO))
	# As construções simples do modelo saem no trecho que a cena do casario
	# ocupa, e as casas e os comércios do artefato entram no lugar.
	var faixa := construir_casario()
	RuaModelo.tirar_casario(rua_modelo, faixa)
	for continuacao: Node3D in continuacoes:
		RuaModelo.tirar_casario(continuacao, faixa)
	por_os_vizinhos()
	construir_limites()
	povoar()
	ajustar_transito()
	ajustar_comboio()
	ajustar_cacadores()
	# A cidade do horizonte fica em volta da casa, que é de onde ela é vista.
	cidade = Cidade3D.new()
	cidade.name = "Cidade"
	cidade.position = CASA_LUGAR
	ambiente_do_bairro = (get_node("Tela/Render/Ambiente") as WorldEnvironment).environment
	cidade.ambiente = ambiente_do_bairro
	mundo.add_child(cidade)
	cidade.mostrar_o_dia(dia)
	ajustar_helicopteros()
	# A interface fica FORA da tela pequena: assim o texto sai nítido, na
	# resolução da janela, em vez de ampliado em blocos junto com o mundo.
	dica = Dica3D.new()
	add_child(dica)
	# O balão de fala fica numa camada só dele, acima do mundo e abaixo dos
	# menus. Ele precisa da câmera para achar a cabeça de quem está falando, e
	# do quanto a tela pequena é esticada para cair no lugar certo da janela.
	var camada_das_falas := CanvasLayer.new()
	camada_das_falas.name = "Falas"
	camada_das_falas.layer = 2
	add_child(camada_das_falas)
	balao = Balao3D.new()
	balao.camera = camera
	balao.escala = float((get_node("Tela") as SubViewportContainer).stretch_shrink)
	camada_das_falas.add_child(balao)
	# A caixa de fala com retrato, a mesma do jogo 2D, para os vizinhos.
	var camada_da_vizinhanca := CanvasLayer.new()
	camada_da_vizinhanca.name = "Vizinhanca"
	camada_da_vizinhanca.layer = 3
	add_child(camada_da_vizinhanca)
	dialogo = DIALOGO.new()
	dialogo.name = "CaixaDeFala"
	dialogo.terminou.connect(sair_da_porta)
	camada_da_vizinhanca.add_child(dialogo)
	status = Status3D.new()
	add_child(status)
	ciclo = Ciclo3D.new()
	ciclo.name = "Ciclo"
	ciclo.dia = dia
	ciclo.comida = comida
	ciclo.agua = agua
	ciclo.energia = energia
	ciclo.dinheiro = dinheiro
	add_child(ciclo)
	ciclo.mudou.connect(mostrar_o_estado)
	ciclo.virou_o_dia.connect(virar_o_dia)
	if modo_deus: ciclo.virar_deus(true)
	acender_a_rua()
	mostrar_o_estado()
	ajustar_corpos()

# ------------------------------------------------------------------ terreno

## Os três pedaços do bairro em volta do lote, como lajes rasas. Eles encostam
## na calçada do modelo sem cobrir o lote da casa: nada fica sobreposto, então
## não há z-fighting, e nenhuma fresta mostra o vazio embaixo do mundo.
func pedacos_do_bairro() -> Array:
	var esquerda := Rect2(BAIRRO.position.x, BAIRRO.position.y, LOTE.position.x - BAIRRO.position.x, BAIRRO.size.y)
	var direita := Rect2(LOTE.end.x, BAIRRO.position.y, BAIRRO.end.x - LOTE.end.x, BAIRRO.size.y)
	var fundo := Rect2(LOTE.position.x, BAIRRO.position.y, LOTE.size.x, LOTE.position.y - BAIRRO.position.y)
	return [esquerda, direita, fundo]

func construir_terreno() -> void:
	for pedaco: Rect2 in pedacos_do_bairro():
		malha_cenario.caixa(Vector3(pedaco.position.x, -0.4, pedaco.position.y), Vector3(pedaco.size.x, 0.4, pedaco.size.y), Color("c9bda8"), Color("d2c6b0"), P.TERRA, P.CIMENTO)

## Casario de fundo: fileiras de casas cegas atrás e ao lado do lote, só para
## fechar o horizonte. Param antes das casas da rua, que cuidam da frente.
func construir_fundo() -> void:
	var indice := 0
	for pedaco: Rect2 in pedacos_do_bairro():
		var limite: float = minf(pedaco.end.y, FUNDO_LIMITE)
		var faixa := Rect2(pedaco.position, Vector2(pedaco.size.x, limite - pedaco.position.y)).grow(-0.4)
		if faixa.size.x < 3.0 or faixa.size.y < 3.0: continue
		var colunas := maxi(1, int(round(faixa.size.x / 6.5)))
		var fileiras := maxi(1, int(round(faixa.size.y / 8.5)))
		var largura := faixa.size.x / colunas
		var fundura := faixa.size.y / fileiras
		for f in fileiras:
			for c in colunas:
				indice += 1
				# As casas se invadem 10 cm de cada lado: assim não sobra
				# corredor para o jogador entrar no quarteirão nem parede colada
				# em parede, que é o que faz duas faces brigarem na tela.
				var canto := faixa.position + Vector2(largura * c - 0.1, fundura * f - 0.1)
				rua.bloco(canto, Vector2(largura + 0.2, fundura + 0.2), indice)

func aplicar_malha() -> void:
	var instancia := MeshInstance3D.new()
	instancia.name = "Cenario"
	instancia.mesh = malha_cenario.gerar()
	instancia.material_override = material_ps1
	mundo.add_child(instancia)
	var corpo := StaticBody3D.new()
	corpo.name = "ColisaoCenario"
	var forma := CollisionShape3D.new()
	forma.shape = instancia.mesh.create_trimesh_shape()
	corpo.add_child(forma)
	mundo.add_child(corpo)

# ------------------------------------------------------------------- a rua

## Casas e comércios dos vizinhos, da cena editada à mão. Devolve o trecho que
## eles ocupam, para o casario simples do modelo sair de lá.
func construir_casario() -> Vector2:
	var casario := CASARIO.instantiate()
	casario.name = "Casario"
	mundo.add_child(casario)
	if not comercio_aberto: fechar_comercio(true)
	var faixa := Vector2(INF, -INF)
	for predio in casario.get_children():
		if not (predio is Node3D): continue
		# A guia da rua serve para posicionar no editor e não entra no jogo.
		if String(predio.name).begins_with("Guia"):
			casario.remove_child(predio)
			predio.queue_free()
			continue
		preparar_predio(predio)
		var caixa = RuaModelo.caixa_mundial(predio, Transform3D())
		if caixa == null: continue
		faixa.x = minf(faixa.x, (caixa as AABB).position.x)
		faixa.y = maxf(faixa.y, (caixa as AABB).end.x)
	if faixa.x > faixa.y: return Vector2.ZERO
	# Um metro de folga de cada lado: o trecho a limpar segue o que a cena tem,
	# então mover uma casa para mais longe leva o casario simples junto.
	return Vector2(faixa.x - 1.0, faixa.y + 1.0)

## Conserta as faces coladas e põe o shader de PS1.
func preparar_predio(predio: Node3D) -> void:
	Modelos3D.separar_coladas(predio)
	RuaModelo.aplicar_ps1(predio, RESOLUCAO)

## Baixa ou levanta a porta de aço do comércio, trocando cada modelo pelo par
## correspondente no mesmo lugar. Pode ser chamado a qualquer hora, com o mundo
## já de pé: é assim que a noite e o apocalipse fecham a rua.
func fechar_comercio(fechado: bool) -> int:
	comercio_aberto = not fechado
	var casario := mundo.get_node_or_null("Casario") as Node3D
	if casario == null: return 0
	var de := "_aberto" if fechado else "_fechado"
	var para := "_fechado" if fechado else "_aberto"
	var trocados := 0
	for predio in casario.get_children():
		var nome := String(predio.name)
		# O nome pode ter número no fim, quando há mais de um do mesmo modelo.
		var corte := nome.find(de)
		if corte < 0: continue
		var loja := nome.substr(0, corte)
		var cena: PackedScene = load("res://modelos/comercios/%s%s.glb" % [loja, para])
		if cena == null: continue
		var novo: Node3D = cena.instantiate()
		novo.name = loja + para
		novo.transform = (predio as Node3D).transform
		casario.add_child(novo, true)
		preparar_predio(novo)
		casario.remove_child(predio)
		predio.queue_free()
		trocados += 1
	return trocados

## O abrigo do ponto de ônibus, na calçada. Ele ganha um corpo marcado, que é o
## que o olhar do jogador encontra para oferecer a viagem.
func construir_ponto() -> void:
	var no: Node3D = PONTO.instantiate()
	no.name = "PontoDeOnibus"
	no.position = PONTO_LUGAR
	mundo.add_child(no)
	Modelos3D.separar_coladas(no)
	RuaModelo.aplicar_ps1(no, RESOLUCAO)
	for corpo in RuaModelo.colisores(no):
		corpo.set_meta("ponto", true)
	# Uma caixa larga na frente do abrigo: dá para chamar o ônibus de qualquer
	# lugar da parada, sem ter que mirar no poste.
	var chamada := StaticBody3D.new()
	chamada.name = "ChamadaDoOnibus"
	chamada.position = PONTO_LUGAR + Vector3(0.0, 1.0, 0.9)
	chamada.set_meta("ponto", true)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(4.4, 2.0, 0.3)
	forma.shape = caixa
	chamada.add_child(forma)
	mundo.add_child(chamada)

## Cerca invisível em volta do trecho jogável: as pontas da rua e o fundo das
## duas calçadas, para ninguém sair pelas frestas entre as casas do modelo.
## Com a névoa curta, não se vê onde o mundo acaba.
func construir_limites() -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "FimDaRua"
	mundo.add_child(corpo)
	var pontas := [RUA_LIMITE.x, RUA_LIMITE.y]
	for meio: float in pontas:
		barreira(corpo, Vector3(meio, 3.0, RUA_EIXO_Z), Vector3(0.6, 6.0, 19.0))
	var comprimento: float = pontas[1] - pontas[0]
	var meio_x: float = (pontas[0] + pontas[1]) / 2.0
	# Fundo da calçada oposta, atrás das fachadas do modelo.
	barreira(corpo, Vector3(meio_x, 3.0, RUA_EIXO_Z + 9.4), Vector3(comprimento, 6.0, 0.4))
	# Fundo da calçada de casa, só fora do lote: no meio fica o portão.
	for faixa: Vector2 in [Vector2(pontas[0], LOTE.position.x), Vector2(LOTE.end.x, pontas[1])]:
		if faixa.y - faixa.x < 0.5: continue
		barreira(corpo, Vector3((faixa.x + faixa.y) / 2.0, 3.0, LOTE.end.y - 0.3), Vector3(faixa.y - faixa.x, 6.0, 0.4))

func barreira(corpo: StaticBody3D, centro: Vector3, tamanho: Vector3) -> void:
	var parede := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tamanho
	parede.shape = caixa
	parede.position = centro
	corpo.add_child(parede)

# --------------------------------------------------------------- interação

func _physics_process(_delta: float) -> void:
	if dica == null or casa == null: return
	destravar()
	if fresta != null:
		# Na janela, o que muda é o que se vê: a nota acompanha a rua.
		fresta.notar(o_que_se_ve(de_qual_janela))
		dica.esconder()
		return
	if escolha != null or mochila != null or celular != null:
		dica.esconder()
		return
	if menu != null or expediente != null or tv != null or (dialogo != null and dialogo.visible):
		dica.esconder()
		return
	var alvo := na_mira()
	dica.apontar(not alvo.is_empty())
	if alvo.is_empty():
		dica.esconder()
		return
	if alvo["o_que"] == "ponto":
		dica.mostrar("Pegar o ônibus" if ciclo.onibus_funciona() else "Ônibus fora de serviço")
		return
	if alvo["o_que"] == "torneira":
		dica.mostrar("Guardar água · 1 ação" if ciclo.tem_agua_da_rede() else "Torneira sem água")
		return
	if alvo["o_que"] == "cama":
		dica.mostrar("Dormir até amanhã")
		return
	if alvo["o_que"] == "pessoa":
		dica.mostrar("Puxar conversa")
		return
	if alvo["o_que"] == "tv":
		dica.mostrar("Ver televisão" if ciclo.tem_energia_da_rede() else "Televisão sem energia")
		return
	if alvo["o_que"] == "janela":
		dica.mostrar("Olhar pela fresta")
		return
	if alvo["o_que"] == "vizinho":
		var morador: Vizinho3D = vizinhos[alvo["quem"]]
		dica.mostrar("Bater na porta" if morador.conversas == 0 else "Falar com %s" % morador.nome)
		return
	var porta: int = alvo["qual"]
	var o_que_e := "Fechar" if casa.esta_aberta(porta) else "Abrir"
	if not casa.tem_tranca(porta):
		dica.mostrar("%s %s" % [o_que_e, casa.nome_da_porta(porta)])
		return
	if casa.esta_trancada(porta):
		# Trancada não abre: a tecla que serve é a da tranca.
		dica.mostrar_duas("Trancad%s" % ("o" if casa.nome_da_porta(porta) == "portão" else "a"), "Destrancar")
		return
	if casa.esta_aberta(porta):
		dica.mostrar("%s %s" % [o_que_e, casa.nome_da_porta(porta)])
		return
	dica.mostrar_duas("%s %s" % [o_que_e, casa.nome_da_porta(porta)], "Trancar")

## Rede de segurança: se nada está aberto na tela, o morador tem de estar livre
## para andar e olhar. Qualquer caminho que esqueça de devolver o controle é
## corrigido no quadro seguinte, em vez de travar o jogo.
func destravar() -> void:
	if menu != null or expediente != null or tv != null or fresta != null or escolha != null: return
	if mochila != null or celular != null: return
	if mochila != null or celular != null: return
	if dialogo != null and dialogo.visible: return
	if dormindo: return
	if not jogador.is_physics_processing() or not jogador.is_processing_unhandled_input(): prender_o_jogo(false)

## Prende ou solta o jogo: com uma tela aberta o morador não anda, não olha e
## não recebe tecla nenhuma — quem manda nas teclas é a tela que está na frente.
func prender_o_jogo(preso: bool) -> void:
	jogador.set_physics_process(not preso)
	jogador.set_process_unhandled_input(not preso)
	jogador.prender_mouse(not preso)

## O que o jogador está olhando de perto: uma porta da casa, o ponto de ônibus,
## ou nada. Devolve {} quando não há nada ao alcance da mão.
func na_mira() -> Dictionary:
	# Cinco raios: o do meio e quatro em volta, abrindo uns seis graus. Mirar
	# exatamente no meio de uma maçaneta é pedir demais de quem está jogando,
	# e o primeiro que achar algo útil vale.
	var colisor = null
	for lado in DESVIOS:
		var achado := o_que_o_raio_acha(lado)
		if achado == null: continue
		colisor = achado
		if colisor.has_meta("ponto") or colisor.has_meta("cama") or colisor.has_meta("tv") or colisor.has_meta("torneira") \
			or colisor.has_meta("janela") or colisor.has_meta("vizinho") or casa.porta_de(colisor) >= 0 \
			or (colisor is Node and (colisor as Node).is_in_group("pessoas3d")):
			break
	if colisor == null: return {}
	if colisor != null and colisor.has_meta("ponto"): return {"o_que": "ponto"}
	if colisor != null and colisor.has_meta("cama"): return {"o_que": "cama"}
	if colisor != null and colisor.has_meta("tv"): return {"o_que": "tv"}
	if colisor != null and colisor.has_meta("torneira"): return {"o_que": "torneira"}
	if colisor != null and colisor.has_meta("janela"):
		return {"o_que": "janela", "qual": int(colisor.get_meta("janela"))}
	if colisor != null and colisor.has_meta("vizinho"):
		return {"o_que": "vizinho", "quem": int(colisor.get_meta("vizinho"))}
	if colisor is Node and (colisor as Node).is_in_group("pessoas3d") and colisor.conversa_livre:
		return {"o_que": "pessoa", "quem": colisor}
	var porta := casa.porta_de(colisor)
	if porta >= 0: return {"o_que": "porta", "qual": porta}
	return {}

## F6 e F7 puxam o relógio do dia para trás e para a frente, um período por
## vez: manhã, tarde, fim de tarde, anoitecer, noite. Só no modo deus — em
## jogo, a hora é consequência do que se faz.
func mudar_a_hora(passo: int) -> void:
	if not ciclo.modo_deus:
		dica.avisar("A hora só anda sozinha. F10 liga o modo deus.")
		return
	var quantos: int = Ciclo3D.PERIODOS.size()
	var agora := ciclo.indice_do_periodo()
	ciclo.por_o_periodo(posmod(agora + passo, quantos))

## F10 liga e desliga o modo deus: despensa cheia, carteira infinita, nada se
## gasta e nada mata. É ferramenta de quem está fazendo o jogo.
func virar_deus() -> void:
	ciclo.virar_deus(not ciclo.modo_deus)
	modo_deus = ciclo.modo_deus

## A tecla da tranca: só faz sentido na porta que se está olhando.
func trancar_o_que_estiver_na_mira() -> void:
	if menu != null or expediente != null or tv != null or fresta != null or escolha != null: return
	if mochila != null or celular != null: return
	if dialogo != null and dialogo.visible: return
	var alvo := na_mira()
	if alvo.get("o_que", "") != "porta": return
	dica.avisar(casa.trancar(alvo["qual"]))

## O que um raio acha, partindo do olho com um desvio pequeno.
func o_que_o_raio_acha(desvio: Vector2) -> Object:
	var de := camera.global_position
	var rumo := (-camera.global_basis.z + camera.global_basis.x * desvio.x + camera.global_basis.y * desvio.y).normalized()
	var consulta := PhysicsRayQueryParameters3D.create(de, de + rumo * ALCANCE_DA_MAO)
	consulta.exclude = [jogador.get_rid()]
	var achado := jogador.get_world_3d().direct_space_state.intersect_ray(consulta)
	return achado["collider"] if not achado.is_empty() else null

## Atalho para os testes e para quem só quer saber da porta.
func porta_na_mira() -> int:
	var alvo := na_mira()
	return alvo["qual"] if alvo.get("o_que", "") == "porta" else -1

func usar_o_que_estiver_na_mira() -> void:
	if menu != null or expediente != null or tv != null or fresta != null or escolha != null: return
	if mochila != null or celular != null: return
	if dialogo != null and dialogo.visible: return
	var alvo := na_mira()
	match alvo.get("o_que", ""):
		"porta":
			if casa.esta_trancada(alvo["qual"]) and not casa.esta_aberta(alvo["qual"]):
				dica.avisar("Está trancada. T destranca.")
			else:
				casa.acionar(alvo["qual"])
		"ponto": abrir_menu_do_ponto()
		"cama": dormir()
		"pessoa": puxar_conversa(alvo["quem"])
		"tv": ligar_a_tv()
		"torneira": ciclo.guardar_agua()
		"vizinho": bater_na_porta(alvo["quem"])
		"janela": olhar_pela_fresta(alvo["qual"])

## Conversa de calçada: a pessoa para, olha para quem chegou e diz a frase que
## cabe no dia. É o mesmo texto e a mesma regra do jogo 2D, num balão preso à
## cabeça dela.
func puxar_conversa(quem: Node3D) -> void:
	if balao == null or quem == null: return
	var frase := conversa.frase_de(quem, ciclo.dia)
	quem.conversar(jogador.global_position, Conversa3D.SEGUNDOS)
	balao.falar_no_mundo(quem, jogador, frase, Conversa3D.SEGUNDOS)

## A mochila: o que dá para usar agora. A lanterna só aparece depois de comprada;
## o celular está sempre no bolso, e avisa quantas mensagens ainda não foram
## lidas. Comida, água e dinheiro entram como conta, não como uso.
func abrir_a_mochila() -> void:
	if mochila != null:
		fechar_a_mochila()
		return
	if menu != null or expediente != null or tv != null or fresta != null or escolha != null or celular != null: return
	if dialogo != null and dialogo.visible: return
	if dormindo: return
	dica.esconder()
	balao.hide()
	prender_o_jogo(true)
	mochila = Mochila3D.new()
	mochila.name = "Mochila"
	mochila.usou.connect(usar_item)
	mochila.fechou.connect(fechar_a_mochila)
	add_child(mochila)
	mochila.mostrar(o_que_tem_na_mochila())

## O conteúdo da mochila, montado do estado do dia.
func o_que_tem_na_mochila() -> Array:
	var nao_lidas := mensagens.novas(ciclo.dia, ciclo.contatos, vizinhos)
	var lista: Array = [{
		"chave": "celular", "texto": "Celular",
		"abaixo": "%d mensagem(ns) por ler. Aparelho velho: só recebe, não procura nada." % nao_lidas,
	}]
	if ciclo.tem_lanterna:
		lista.append({
			"chave": "lanterna", "texto": "Lanterna (%s)" % ("acesa" if ciclo.lanterna_acesa else "apagada"),
			"abaixo": "Enquanto houver luz na rua ela não faz falta. Vai fazer.",
		})
	lista.append({"chave": "despensa", "texto": "Despensa", "abaixo": "%d de comida, %d de água, R$ %d na carteira." % [ciclo.comida, ciclo.agua, ciclo.dinheiro]})
	return lista

func fechar_a_mochila() -> void:
	if mochila == null: return
	mochila.queue_free()
	mochila = null
	if celular == null: prender_o_jogo(false)

## Usar o que estava marcado na mochila.
func usar_item(chave: String) -> void:
	match chave:
		"celular":
			fechar_a_mochila()
			abrir_o_celular()
		"lanterna":
			acender_a_lanterna(not ciclo.lanterna_acesa)
			mochila.mostrar(o_que_tem_na_mochila())
		"despensa":
			dica.avisar("%d de comida e %d de água." % [ciclo.comida, ciclo.agua])

## Acende ou apaga a lanterna. A luz anda com a cabeça do morador.
func acender_a_lanterna(acesa: bool) -> void:
	ciclo.lanterna_acesa = acesa and ciclo.tem_lanterna
	if luz_da_lanterna == null:
		luz_da_lanterna = SpotLight3D.new()
		luz_da_lanterna.name = "Lanterna"
		luz_da_lanterna.light_color = Color("ffeec8")
		luz_da_lanterna.light_energy = 6.0
		luz_da_lanterna.spot_range = 22.0
		luz_da_lanterna.spot_angle = 26.0
		luz_da_lanterna.light_specular = 0.0
		luz_da_lanterna.position = Vector3(0.12, -0.1, 0.0)
		camera.add_child(luz_da_lanterna)
	luz_da_lanterna.visible = ciclo.lanterna_acesa
	dica.avisar("Lanterna acesa." if ciclo.lanterna_acesa else "Lanterna apagada.")

## O celular: a caixa de entrada do dia, com o que a irmã e os vizinhos que
## confiam em você mandaram.
func abrir_o_celular() -> void:
	if celular != null: return
	prender_o_jogo(true)
	celular = Celular3D.new()
	celular.name = "Celular"
	celular.guardou.connect(guardar_o_celular)
	add_child(celular)
	var caixa := mensagens.caixa(ciclo.dia, ciclo.contatos, "Irmã", vizinhos)
	for m: Dictionary in caixa: m["lida"] = mensagens.ja_lida(String(m["chave"]))
	celular.ligar(caixa, mensagens.novas(ciclo.dia, ciclo.contatos, vizinhos))
	# Abrir o aparelho já dá por vistas as que estão na tela.
	for m: Dictionary in caixa: mensagens.marcar_lida(String(m["chave"]))

func guardar_o_celular() -> void:
	if celular == null: return
	celular.queue_free()
	celular = null
	prender_o_jogo(false)

## Espiar a rua pela fresta da cortina: a câmera vai para a janela, a tela fecha
## em volta e embaixo fica escrito o que se nota. Não custa nada — é o jeito
## barato de saber o que há lá fora antes de abrir a porta.
func olhar_pela_fresta(qual: int) -> void:
	if fresta != null or casa == null or qual < 0 or qual >= casa.frestas.size(): return
	var janela: Dictionary = casa.frestas[qual]
	de_qual_janela = janela["olhar"]
	dica.esconder()
	balao.hide()
	prender_o_jogo(true)
	if camera_da_fresta == null:
		camera_da_fresta = Camera3D.new()
		camera_da_fresta.name = "CameraDaFresta"
		# Um pouco mais fechada que a do morador: espiar é esticar o pescoço.
		camera_da_fresta.fov = 58.0
		camera_da_fresta.far = camera.far
		get_node("Tela/Render").add_child(camera_da_fresta)
	camera_da_fresta.global_position = de_qual_janela
	# A câmera olha para o seu −Z; a rua está do outro lado.
	camera_da_fresta.rotation = Vector3(0.05, PI, 0.0)
	camera_da_fresta.make_current()
	fresta = Fresta3D.new()
	fresta.name = "Fresta"
	fresta.fechou.connect(fechar_a_fresta)
	add_child(fresta)
	fresta.notar(o_que_se_ve(de_qual_janela))

func fechar_a_fresta() -> void:
	if fresta == null: return
	fresta.queue_free()
	fresta = null
	camera.make_current()
	prender_o_jogo(false)

## O que se nota da janela: a hora, o estado da cidade e quem está na calçada.
## É aqui que os perigos da rua vão aparecer primeiro, quando existirem.
func o_que_se_ve(de_onde: Vector3) -> String:
	var notas: Array[String] = []
	var noite := ciclo.e_noite()
	var quantos := 0
	var perto := false
	for alguem in get_tree().get_nodes_in_group("pessoas3d"):
		var quem := alguem as Node3D
		if String(quem.name) == "Irma" or not quem.visible: continue
		var quanto := quem.global_position.distance_to(de_onde)
		if quanto > 22.0: continue
		quantos += 1
		if quanto < 9.0: perto = true
	if e_dia_de_breu(): notas.append("Não clareou. A rua inteira está sem luz.")
	elif noite: notas.append("Está escuro. Os postes estão apagados." if not ciclo.tem_energia_da_rede() else "Está escuro. O poste acende só o pedaço de calçada em frente.")
	match (cidade.estado if cidade != null else "normal"):
		"estranha": notas.append("O céu está de uma cor que não é de hora nenhuma do dia.")
		"chamas": notas.append("Atrás dos telhados o clarão não apaga.")
		"destruida": notas.append("Do outro lado não sobrou prédio com janela inteira.")
	var mortos := 0
	for corpo: Node3D in get_tree().get_nodes_in_group("corpos3d"):
		if corpo.is_visible_in_tree() and corpo.global_position.distance_to(de_onde) < 22.0: mortos += 1
	if mortos > 0: notas.append("Há corpos imóveis na rua, no mesmo lugar.")
	if quantos == 0: notas.append("Não passa ninguém." if noite or mortos > 0 else "A rua está vazia.")
	elif perto: notas.append("Tem gente parada perto do portão.")
	elif quantos > 1: notas.append("Passa gente na calçada, sem pressa.")
	else: notas.append("Uma pessoa passa do outro lado da rua.")
	return "
".join(notas)

## Cinco vizinhos sorteados moram nas casas mais perto do lote. Cada um ganha
## uma porta: uma caixa marcada, rente à fachada que dá para a rua. Ela não
## tranca a calçada — fica fora da camada em que o morador esbarra.
func por_os_vizinhos() -> void:
	var casario := mundo.get_node_or_null("Casario")
	if casario == null: return
	var meio_do_lote := Vector2(LOTE.position.x + LOTE.size.x / 2.0, LOTE.position.y + LOTE.size.y / 2.0)
	var casas := []
	for predio in casario.get_children():
		if not (predio is Node3D): continue
		# Só casas: em comércio não se bate na porta para puxar conversa.
		if not String(predio.name).begins_with("casa"): continue
		var caixa = RuaModelo.caixa_mundial(predio, Transform3D())
		if caixa == null: continue
		var c: AABB = caixa
		var meio := Vector2((c.position.x + c.end.x) / 2.0, (c.position.z + c.end.z) / 2.0)
		casas.append({"no": predio, "caixa": c, "longe": meio.distance_to(meio_do_lote)})
	casas.sort_custom(func(a, b): return float(a["longe"]) < float(b["longe"]))
	vizinhos = Vizinho3D.sortear(QUANTOS_VIZINHOS)
	for i in vizinhos.size():
		if i >= casas.size(): break
		var morador: Vizinho3D = vizinhos[i]
		morador.casa = casas[i]["no"]
		morador.porta = porta_de_vizinho(casas[i]["caixa"], i)

## A porta fica na fachada virada para a rua: a face de Z maior nas casas do
## nosso lado, a de Z menor nas de frente.
func porta_de_vizinho(caixa: AABB, qual: int) -> StaticBody3D:
	var do_nosso_lado := (caixa.position.z + caixa.end.z) / 2.0 < RUA_EIXO_Z
	var corpo := StaticBody3D.new()
	corpo.name = "PortaVizinho%d" % (qual + 1)
	corpo.position = Vector3((caixa.position.x + caixa.end.x) / 2.0, 0.0,
			caixa.end.z + 0.12 if do_nosso_lado else caixa.position.z - 0.12)
	corpo.set_meta("vizinho", qual)
	corpo.collision_layer = 16
	corpo.collision_mask = 0
	var forma := CollisionShape3D.new()
	var porta := BoxShape3D.new()
	porta.size = Vector3(1.3, 2.1, 0.24)
	forma.shape = porta
	forma.position.y = 1.05
	corpo.add_child(forma)
	mundo.add_child(corpo)
	return corpo

## Bater na porta de um vizinho: ele atende com o retrato e a fala do dia.
func bater_na_porta(qual: int) -> void:
	if qual < 0 or qual >= vizinhos.size(): return
	var morador: Vizinho3D = vizinhos[qual]
	na_porta = qual
	dica.esconder()
	balao.hide()
	prender_o_jogo(true)
	dialogo.caminho_do_retrato = morador.retrato()
	if morador.conversas == 0: morador.adiado_ate = ciclo.dia + 1
	morador.iniciar(ciclo.dia, noticias.aviso_de_amanha(ciclo.dia))
	mostrar_fala_do_vizinho()

func mostrar_fala_do_vizinho() -> void:
	var morador: Vizinho3D = vizinhos[na_porta]
	if morador.no_atual.is_empty() or morador.no().is_empty():
		encerrar_conversa()
		return
	dialogo.respostas_ao_final = not morador.opcoes().is_empty()
	dialogo.mostrar(morador.nome, morador.falas())

## Acabou a fala. Se ele estava pedindo alguma coisa, agora é a hora de
## responder; senão, o morador volta a andar.
func sair_da_porta(aviso := "") -> void:
	var morador: Vizinho3D = vizinhos[na_porta] if na_porta >= 0 and na_porta < vizinhos.size() else null
	if morador == null:
		encerrar_conversa()
		return
	var opcoes := morador.opcoes()
	if opcoes.is_empty():
		encerrar_conversa()
		return
	escolha = MenuEscolha.new()
	escolha.name = "EscolhaDaPorta"
	escolha.escolheu.connect(responder_ao_vizinho)
	var lista := []
	for opcao: Dictionary in opcoes:
		var custo: Dictionary = opcao.get("custo", {})
		lista.append({"chave": opcao.id, "texto": opcao.texto,
			"abaixo": custo_do_pedido(String(custo.get("item", "")), int(custo.get("quanto", 0)), int(custo.get("acoes", 0))) if not custo.is_empty() else String(opcao.get("abaixo", ""))})
	escolha.perguntar(aviso, lista)
	dialogo.mostrar_respostas(escolha)

func encerrar_conversa() -> void:
	if escolha != null:
		escolha.hide()
		escolha.queue_free()
		escolha = null
	na_porta = -1
	dialogo.fechar()
	prender_o_jogo(false)

## O que se lê embaixo da opção de ajudar.
func custo_do_pedido(item: String, quanto: int, acoes := 1) -> String:
	var tempo := "%d ação%s" % [acoes, "" if acoes == 1 else "s"]
	match item:
		"comida": return "%s · %d de comida" % [tempo, quanto]
		"agua": return "%s · %d de água" % [tempo, quanto]
		"energia": return "%s · %d de energia" % [tempo, Ciclo3D.PILHA * quanto]
		"dinheiro": return "%s · R$ %d" % [tempo, quanto]
	return tempo + " do seu dia"

## A resposta ao pedido: pagar o que foi pedido, ou dizer que hoje não dá.
func responder_ao_vizinho(resposta: String) -> void:
	var morador: Vizinho3D = vizinhos[na_porta] if na_porta >= 0 and na_porta < vizinhos.size() else null
	if escolha != null:
		escolha.hide()
		escolha.queue_free()
		escolha = null
	if morador == null or resposta.is_empty():
		encerrar_conversa()
		return
	var valida := false
	for opcao: Dictionary in morador.opcoes():
		if String(opcao.id) != resposta: continue
		valida = true
		if not ciclo.pagar_escolha(opcao.get("custo", {})):
			sair_da_porta("Sem recursos ou ações. Escolha outra resposta.")
			return
		break
	if not valida or not morador.escolher(resposta):
		encerrar_conversa()
		return
	if morador.pode_passar_numero() and not ciclo.contatos.has(morador.chave):
		ciclo.contatos[morador.chave] = ciclo.dia
		dica.avisar("%s te passou o número." % morador.nome)
	mensagens.caixa(ciclo.dia, ciclo.contatos, "Irmã", vizinhos)
	mostrar_fala_do_vizinho()

## A TV da sala: os programas do artefato com a notícia do dia por dentro, e o
## jogador trocando de canal. Ver TV cansa, então quem cobra é o ciclo.
func ligar_a_tv() -> void:
	if tv != null: return
	if not ciclo.tem_energia_da_rede():
		dica.avisar("Sem luz da rede. A televisão não liga.")
		return
	dica.esconder()
	balao.hide()
	prender_o_jogo(true)
	tv = Tv3D.new()
	tv.name = "Televisao"
	tv.falas_do_dia = noticias.do_dia(ciclo.dia)
	tv.rodape = String(tv.falas_do_dia.get("rodape", ""))
	tv.cobrar = ciclo.assistir_tv
	tv.desligou.connect(desligar_a_tv)
	add_child(tv)

func desligar_a_tv() -> void:
	if tv == null: return
	tv.queue_free()
	tv = null
	prender_o_jogo(false)

# ------------------------------------------------------- o dia e a noite

## Cada ação empurra o relógio da manhã para a noite. Aqui isso vira imagem:
## céu, névoa, sol, lâmpadas de casa, postes da rua, o comércio fechando e a
## calçada esvaziando.
func aplicar_hora_do_dia() -> void:
	var quanto := ciclo.progresso()
	var noite := ciclo.e_noite()
	var ar := cidade.ar_do_estado() if cidade != null else {}
	var ceu := ambiente_do_bairro.sky.sky_material as ProceduralSkyMaterial
	if ceu != null:
		ceu.sky_top_color = (ar.get("ceu_topo", Color("52565f")) as Color).lerp(NOITE_ALTA, quanto)
		ceu.sky_horizon_color = (ar.get("ceu_baixo", Color("c2c3bf")) as Color).lerp(NOITE_BAIXA, quanto * 0.92)
	ambiente_do_bairro.fog_light_color = (ar.get("ar", Color("c9cac6")) as Color).lerp(NOITE_NEVOA, quanto)
	ambiente_do_bairro.ambient_light_energy = lerpf(1.1, 0.34, quanto)
	# A luz do ambiente é a do dia, não a do céu: céu vermelho não quer dizer
	# bairro vermelho.
	ambiente_do_bairro.ambient_light_color = (ar.get("luz", ar.get("ceu_baixo", Color("c2c3bf"))) as Color).lerp(NOITE_BAIXA, quanto)
	var sol := get_node("Tela/Render/Sol") as DirectionalLight3D
	sol.light_energy = lerpf(0.9, 0.05, smoothstep(0.35, 0.9, quanto))
	sol.light_color = Color("fff2da").lerp(Color("c98a74"), smoothstep(0.2, 0.8, quanto))
	# O sol desce: de cima, de manhã, até rente ao horizonte no fim da tarde.
	sol.rotation = Vector3(lerpf(-1.05, -0.06, quanto), lerpf(0.4, 1.5, quanto), 0.0)
	if casa != null: casa.acender_luzes(noite and ciclo.tem_energia_da_rede())
	for poste: OmniLight3D in postes:
		poste.visible = noite and ciclo.tem_energia_da_rede()
	for carro in get_tree().get_nodes_in_group("carros3d"):
		if carro.has_method("acender"): carro.acender(noite)
	# O horizonte acompanha a hora: de noite a cidade se dissolve no próprio ar.
	if cidade != null:
		var ar_agora: Color = (ar.get("ar", Color("c9cac6")) as Color).lerp(NOITE_NEVOA, quanto)
		cidade.ajustar_ar(ar_agora, lerpf(float(ar.get("distancia", 0.45)), 0.75, quanto))
	# O brilho dos poros do caçador só estoura com o glow ligado; nos outros dias
	# ele fica desligado, que é o normal para este jogo.
	ambiente_do_bairro.glow_enabled = quantos_cacadores_hoje() > 0
	esvaziar_a_rua(noite)
	# De noite o comércio fecha; depois do ataque não abre mais, nem de dia.
	var fechar := noite or dia_de_hoje() >= DIA_DO_BREU
	if fechar == comercio_aberto: fechar_comercio(fechar)
	# O breu: um dia inteiro sem luz nenhuma. Nem sol, nem poste, nem lâmpada de
	# casa — só a lanterna de quem teve a ideia de comprar uma.
	if e_dia_de_breu():
		if ceu != null:
			ceu.sky_top_color = BREU_ALTO
			ceu.sky_horizon_color = BREU_BAIXO
		ambiente_do_bairro.fog_light_color = BREU_NEVOA
		ambiente_do_bairro.ambient_light_color = BREU_BAIXO
		ambiente_do_bairro.ambient_light_energy = 0.035
		sol.light_energy = 0.0
		if casa != null: casa.acender_luzes(false)
		for poste: OmniLight3D in postes:
			poste.visible = false
		# No breu até o horizonte some: não há luz nenhuma na cidade.
		if cidade != null: cidade.ajustar_ar(BREU_NEVOA, 0.93)

## É hoje o dia em que a luz acabou?
func e_dia_de_breu() -> bool:
	return dia_de_hoje() == DIA_DO_BREU

## Quanta gente ainda sai de casa hoje. Nos dois primeiros dias a rua é normal;
## quando o estranho começa, some um morador por dia; quando a guerra chega,
## não sai mais ninguém.
func quanta_gente_hoje() -> int:
	if dia_de_hoje() < 3: return QUANTAS_PESSOAS
	# Do breu em diante a calçada fica vazia.
	if dia_de_hoje() < DIA_DO_BREU: return maxi(0, QUANTAS_PESSOAS - (dia_de_hoje() - 2))
	return 0

## Esvazia a calçada conforme o dia — e mais ainda depois que escurece.
func esvaziar_a_rua(noite: bool) -> void:
	var quantos := quanta_gente_hoje()
	if noite: quantos = int(ceil(quantos / 3.0))
	var na_rua := 0
	for alguem in get_tree().get_nodes_in_group("pessoas3d"):
		var quem := alguem as Node3D
		# A irmã é de casa: ela não conta como gente na rua.
		if String(quem.name) == "Irma": continue
		na_rua += 1
		quem.visible = na_rua <= quantos
		quem.set_physics_process(quem.visible)

## Uma lâmpada amarelada sob o braço de cada poste da rua, acesa só à noite.
func acender_a_rua() -> void:
	for trecho in mundo.get_children():
		if not String(trecho.name).begins_with("RuaPenha"): continue
		for peca in trecho.get_children():
			if not String(peca.name).begins_with("poste_braco"): continue
			var caixa = RuaModelo.caixa_mundial(peca, (trecho as Node3D).transform)
			if caixa == null: continue
			var c: AABB = caixa
			var lampada := OmniLight3D.new()
			lampada.position = Vector3((c.position.x + c.end.x) / 2.0, c.position.y - 0.2, (c.position.z + c.end.z) / 2.0)
			lampada.light_color = Color("ffd08a")
			lampada.light_energy = 2.6
			lampada.omni_range = 11.0
			lampada.light_specular = 0.0
			lampada.visible = false
			mundo.add_child(lampada)
			postes.append(lampada)

## Dormir: fecha o dia, aplica as contas da noite e devolve a manhã seguinte.
func dormir() -> void:
	if dormindo or expediente != null: return
	dormindo = true
	dica.esconder()
	prender_o_jogo(true)
	var resumo := ciclo.dormir(casa.portas_abertas_para_a_rua())
	# O resumo da noite vai na tela preta; o recado solto sai da frente.
	dica.recado.modulate.a = 0.0
	await escurecer("Dia %d · Manhã" % ciclo.dia, resumo)
	prender_o_jogo(false)
	dormindo = false

## O dia virou: a cidade no horizonte envelhece com ele.
func virar_o_dia(novo_dia: int) -> void:
	dia = novo_dia
	if cidade != null: cidade.mostrar_o_dia(novo_dia)
	ajustar_helicopteros()
	ajustar_transito()
	ajustar_comboio()
	ajustar_cacadores()
	ajustar_corpos()
	# O céu vem da cidade: trocado o estado, a luz do dia tem de ser refeita
	# agora. Sem isto o dia do ataque amanhecia com o céu da véspera.
	aplicar_hora_do_dia()

## Tela preta com o dia novo e o resumo da noite.
func escurecer(titulo: String, resumo: String) -> void:
	var tela := ColorRect.new()
	tela.color = Color(0.04, 0.04, 0.06, 0.0)
	tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	var camada := CanvasLayer.new()
	camada.layer = 4
	camada.add_child(tela)
	add_child(camada)
	var letras := Label.new()
	letras.set_anchors_preset(Control.PRESET_FULL_RECT)
	letras.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letras.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letras.add_theme_font_size_override("font_size", 22)
	letras.add_theme_color_override("font_color", Color("f3e6c8"))
	letras.modulate.a = 0.0
	letras.text = titulo + ("\n\n" + resumo if not resumo.is_empty() else "")
	camada.add_child(letras)
	var sono := create_tween()
	sono.tween_property(tela, "color:a", 1.0, 0.7)
	sono.tween_property(letras, "modulate:a", 1.0, 0.5)
	sono.tween_interval(1.8)
	sono.tween_property(letras, "modulate:a", 0.0, 0.4)
	sono.tween_property(tela, "color:a", 0.0, 0.8)
	await sono.finished
	camada.queue_free()

# ----------------------------------------------------- sair e voltar do dia

## O menu do ponto: trabalhar, mercado ou ficar. Enquanto ele está aberto o
## jogador não anda nem olha em volta.
func abrir_menu_do_ponto() -> void:
	if menu != null: return
	if not ciclo.onibus_funciona():
		dica.avisar("Os ônibus pararam depois do breu. O ponto está fora de serviço.")
		return
	prender_o_jogo(true)
	menu = MenuPonto.new()
	menu.escolheu.connect(fechar_menu_do_ponto)
	add_child(menu)

func fechar_menu_do_ponto(destino: String) -> void:
	if menu == null: return
	menu.queue_free()
	menu = null
	if destino.is_empty():
		voltar_para_o_mundo()
		return
	# Sair custa o dia: trabalhar ocupa duas ações, o mercado uma.
	var pode := ciclo.trabalhar() if destino == "trabalho" else ciclo.ir_ao_mercado()
	if not pode:
		voltar_para_o_mundo()
		return
	sair_para(destino)

## Guarda o mundo, esconde tudo e toca a ida e a volta.
func sair_para(destino: String) -> void:
	dica.esconder()
	balao.hide()
	status.visible = false
	mundo.visible = false
	mundo.process_mode = Node.PROCESS_MODE_DISABLED
	prender_o_jogo(true)
	(get_node("Tela/Render/Ambiente") as WorldEnvironment).environment = null
	(get_node("Tela/Render/Sol") as DirectionalLight3D).visible = false
	expediente = Expediente3D.new()
	expediente.name = "Expediente"
	expediente.resolucao = RESOLUCAO
	expediente.terminou.connect(voltar_do_expediente)
	expediente.camada_da_interface = self
	expediente.dia = ciclo.dia
	expediente.dinheiro = ciclo.dinheiro
	get_node("Tela/Render").add_child(expediente)
	expediente.comecar(destino)

func voltar_do_expediente() -> void:
	if expediente != null:
		# O que veio do mercado entra na despensa, e o que foi gasto sai da
		# carteira.
		ciclo.guardar(int(expediente.comprou["comida"]), int(expediente.comprou["agua"]), expediente.dinheiro, int(expediente.comprou.get("energia", 0)))
		# A lanterna fica: é compra de uma vez só.
		if int(expediente.comprou.get("lanterna", 0)) > 0: ciclo.tem_lanterna = true
		expediente.queue_free()
		expediente = null
	voltar_para_o_mundo()
	# De volta em casa: o jogador reaparece no ponto, de frente para a rua.
	jogador.global_position = PONTO_LUGAR + Vector3(0.0, 0.3, 1.6)
	jogador.rotation.y = PI

func voltar_para_o_mundo() -> void:
	status.visible = true
	mundo.visible = true
	mundo.process_mode = Node.PROCESS_MODE_INHERIT
	(get_node("Tela/Render/Ambiente") as WorldEnvironment).environment = ambiente_do_bairro
	(get_node("Tela/Render/Sol") as DirectionalLight3D).visible = true
	prender_o_jogo(false)
	camera.make_current()

# ------------------------------------------------------------------- gente

## Os locais e as poses são definidos no arquivo, sem sorteio por dia. Reusar
## o mesmo nó garante que os corpos não troquem de lugar após dormir.
func ajustar_corpos() -> void:
	if corpos != null:
		corpos.visible = dia_de_hoje() >= DIA_DO_BREU
		return
	if dia_de_hoje() < DIA_DO_BREU: return
	var dados = JSON.parse_string(FileAccess.get_file_as_string(CORPOS_DADOS))
	if not (dados is Dictionary): return
	corpos = Node3D.new()
	corpos.name = "CorposNaRua"
	mundo.add_child(corpos)
	for local: Dictionary in dados.get("corpos", []):
		var cena := load(String(local.cena)) as PackedScene
		if cena == null: continue
		var corpo := cena.instantiate() as Node3D
		var p: Array = local.posicao
		corpo.name = "Corpo_" + String(local.id)
		corpo.position = Vector3(p[0], p[1], p[2])
		corpo.rotation.y = deg_to_rad(float(local.get("giro", 0)))
		corpo.resolucao = RESOLUCAO
		corpos.add_child(corpo)
		# Confere as alturas de pista e calçada só na criação, nunca nos dias
		# seguintes. Os valores do JSON servem também para iniciar no breu.
		var de := corpo.global_position + Vector3.UP * 3.0
		var consulta := PhysicsRayQueryParameters3D.create(de, de + Vector3.DOWN * 6.0, 1)
		consulta.exclude = [jogador.get_rid()]
		var piso := mundo.get_world_3d().direct_space_state.intersect_ray(consulta)
		if not piso.is_empty(): corpo.global_position.y = (piso.position as Vector3).y

## Pedestres nas calçadas e a irmã em casa, com o modelo do artefato. A rua fica
## sem carro nenhum: nem os que andavam nem os que o modelo deixa estacionados.
func povoar() -> void:
	var calcadas := [CALCADA_PERTO, CALCADA_LONGE]
	# O elenco embaralhado: cada pedestre é um morador diferente, e quem anda
	# hoje não é quem andava ontem.
	var elenco: Array = Pessoa3D.DA_RUA.duplicate()
	elenco.shuffle()
	for i in QUANTAS_PESSOAS:
		var pessoa := Pessoa3D.new()
		pessoa.quem = elenco[i % elenco.size()]
		pessoa.name = String(pessoa.quem).capitalize().replace(" ", "")
		pessoa.resolucao = RESOLUCAO
		pessoa.linha_z = calcadas[i % 2]
		pessoa.limites = Vector2(RUA_LIMITE.x + 4.0, RUA_LIMITE.y - 4.0)
		pessoa.sentido = 1.0 if i % 2 == 0 else -1.0
		pessoa.position = Vector3(-4.0 + i * 7.5, 0.0, pessoa.linha_z)
		mundo.add_child(pessoa)
	var irma := Pessoa3D.new()
	irma.name = "Irma"
	# Ela tem o modelo dela, que não entra no sorteio da rua.
	irma.quem = "irma"
	irma.resolucao = RESOLUCAO
	irma.parada = true
	irma.conversa_livre = false
	irma.position = inicio + Vector3(1.4, -0.12, 0.6)
	mundo.add_child(irma)

## Carros passando nas duas faixas. Os modelos são os que estavam estacionados
## no modelo da rua: cada um vira um carro andando, e os que faltam para encher
## as faixas são cópias deles. Eles se alternam entre as duas faixas, na nossa
## mão: na de cá anda-se para −X, na de lá para +X.
## Quantos caçadores a rua tem hoje. Eles aparecem no breu, somem no dia em que
## o Exército passa — enquanto há tanque na rua eles não chegam perto — e
## voltam, em maior número, quando não sobra mais ninguém para enfrentá-los.
func quantos_cacadores_hoje() -> int:
	var hoje := dia_de_hoje()
	if hoje == DIA_DO_BREU: return CACADORES_NO_BREU
	if hoje > DIA_DO_ATAQUE: return CACADORES_DEPOIS
	return 0

## Põe e tira caçadores conforme o dia.
func ajustar_cacadores() -> void:
	var quantos := quantos_cacadores_hoje()
	var na_rua: Array = get_tree().get_nodes_in_group("cacadores3d")
	while na_rua.size() > quantos:
		var velho: Node = na_rua.pop_back()
		velho.remove_from_group("cacadores3d")
		velho.queue_free()
	for i in range(na_rua.size(), quantos):
		var bicho := Cacador3D.new()
		bicho.name = "Cacador%d" % (i + 1)
		bicho.resolucao = RESOLUCAO
		# Eles andam pela pista, que é por onde dá para vê-los de longe.
		bicho.linha_z = FAIXA_DE_CA if i % 2 == 0 else FAIXA_DE_LA
		bicho.sentido = 1.0 if i % 2 == 0 else -1.0
		bicho.limites = Vector2(RUA_LIMITE.x + 2.0, RUA_LIMITE.y - 2.0)
		bicho.position = Vector3(RUA_LIMITE.x + 14.0 + float(i) * 26.0, 0.0, bicho.linha_z)
		mundo.add_child(bicho)
		na_rua.append(bicho)

## O comboio do Exército, só no dia do ataque: o blindado abrindo caminho e os
## caminhões de tropa atrás, todos na mesma faixa e devagar.
func ajustar_comboio() -> void:
	var tem_comboio := dia_de_hoje() == DIA_DO_ATAQUE
	var no_comboio: Array = get_tree().get_nodes_in_group("militares3d")
	if not tem_comboio:
		for velho in no_comboio:
			velho.remove_from_group("carros3d")
			velho.remove_from_group("militares3d")
			(velho as Node3D).queue_free()
		return
	if not no_comboio.is_empty(): return
	var vao := Vector2(RUA_LIMITE.x - 74.0, RUA_LIMITE.y + 73.0)
	for i in CAMINHOES_DO_COMBOIO + 1:
		var veiculo := Militar3D.new()
		veiculo.name = "Militar%d" % (i + 1)
		veiculo.tipo = Militar3D.Tipo.TANQUE if i == 0 else Militar3D.Tipo.CAMINHAO
		veiculo.resolucao = RESOLUCAO
		veiculo.altura_da_pista = RUA_ALTURA
		veiculo.linha_z = FAIXA_DE_LA
		veiculo.sentido = 1.0
		veiculo.velocidade = 4.5
		veiculo.velocidade_alvo = 4.5
		veiculo.limites = vao
		# Em fila, com distância de comboio entre um e outro.
		veiculo.position.x = vao.x + 40.0 + i * 11.0
		mundo.add_child(veiculo)

## Quantos carros a rua tem hoje. O trânsito seca junto com a gente na calçada,
## menos dois dias antes do ataque: aí todo mundo pega o carro ao mesmo tempo e
## a rua vira um engarrafamento parado.
func quantos_carros_hoje() -> int:
	var hoje := dia_de_hoje()
	if hoje == DIA_DO_ENGARRAFAMENTO: return CARROS_NO_ENGARRAFAMENTO
	# Do breu em diante ninguém mais sai de carro: no dia seguinte quem passa na
	# rua é o Exército, e depois não passa mais nada.
	if hoje >= DIA_DO_BREU: return 0
	if hoje < 3: return QUANTOS_CARROS
	return maxi(0, QUANTOS_CARROS - (hoje - 2))

## Que dia é hoje. O trânsito é montado antes do ciclo existir, então aqui vale
## o dia que a cena trouxe até o relógio começar a andar.
func dia_de_hoje() -> int:
	return ciclo.dia if ciclo != null else dia

## Está todo mundo fugindo de carro hoje?
func dia_de_engarrafamento() -> bool:
	return dia_de_hoje() == DIA_DO_ENGARRAFAMENTO

## Põe ou tira carros até a rua ter o trânsito do dia, e acerta o passo de cada
## um. Os carros somem muito depois da barreira, no fim da rua esticada, para
## ninguém ver um aparecer do nada.
func ajustar_transito() -> void:
	var vao := Vector2(RUA_LIMITE.x - 74.0, RUA_LIMITE.y + 73.0)
	var quantos := quantos_carros_hoje()
	# Só os civis: o comboio do Exército tem dono próprio e não entra na conta.
	var na_rua: Array = []
	for carro in get_tree().get_nodes_in_group("carros3d"):
		if (carro as Node).is_in_group("militares3d"): continue
		na_rua.append(carro)
	while na_rua.size() > quantos:
		var velho: Node = na_rua.pop_back()
		velho.remove_from_group("carros3d")
		velho.queue_free()
	var garagem: Array = Carro3D.MODELOS.duplicate()
	garagem.shuffle()
	for i in range(na_rua.size(), quantos):
		var carro := Carro3D.new()
		carro.name = "Carro%d" % (i + 1)
		var de_ca := i % 2 == 0
		carro.modelo = String(garagem[i % garagem.size()])
		carro.resolucao = RESOLUCAO
		carro.altura_da_pista = RUA_ALTURA
		carro.linha_z = FAIXA_DE_CA if de_ca else FAIXA_DE_LA
		carro.sentido = -1.0 if de_ca else 1.0
		carro.limites = vao
		# Espalhados pelo trecho, para não andarem em comboio.
		carro.position.x = vao.x + (vao.y - vao.x) * (float(i) + 0.5) / float(maxi(1, quantos))
		mundo.add_child(carro)
		na_rua.append(carro)
	# No engarrafamento eles mal saem do lugar; no resto dos dias, passo de rua.
	# A velocidade de verdade é a que cada um consegue: quem tem alguém na
	# frente anda menos, e ninguém entra dentro de ninguém.
	for carro in na_rua:
		var passo := randf_range(0.25, 0.6) if dia_de_engarrafamento() else randf_range(6.5, 9.5)
		(carro as Carro3D).velocidade_alvo = passo
		(carro as Carro3D).velocidade = passo
	if dia_de_engarrafamento(): enfileirar(na_rua)

## Põe a rua inteira parada em fila, duas colunas, no trecho que se vê da
## calçada. Os que já estavam rodando são recolocados: no dia do engarrafamento
## ninguém está mais no meio da pista sozinho.
func enfileirar(na_rua: Array) -> void:
	for i in na_rua.size():
		var carro := na_rua[i] as Carro3D
		var de_ca := i % 2 == 0
		carro.linha_z = FAIXA_DE_CA if de_ca else FAIXA_DE_LA
		carro.sentido = -1.0 if de_ca else 1.0
		carro.rotation.y = PI / 2.0 if carro.sentido > 0.0 else -PI / 2.0
		carro.position.z = carro.linha_z
		# Uma coluna por faixa, de para-choque em para-choque, com um empurrãozinho
		# de distância diferente em cada um para a fila não ficar de régua.
		carro.position.x = RUA_LIMITE.x + 6.0 + float(i / 2) * PASSO_DA_FILA + randf_range(0.0, 0.6)

## Helicópteros cruzando o céu do bairro enquanto a cidade queima. Somem quando
## a guerra acaba — depois do ataque não sobrou quem voasse.
func ajustar_helicopteros() -> void:
	var em_guerra := cidade != null and cidade.estado == "chamas"
	var voando := get_tree().get_nodes_in_group("helicopteros3d")
	if not em_guerra:
		for velho in voando: (velho as Node3D).queue_free()
		return
	if not voando.is_empty(): return
	for i in QUANTOS_HELICOPTEROS:
		var heli := Helicoptero3D.new()
		heli.name = "Helicoptero%d" % (i + 1)
		heli.resolucao = RESOLUCAO
		# Rumos variados, sempre passando por cima do quarteirão.
		ajeitar_helicoptero(heli, i)
		heli.centro = Vector3(RUA_CENTRO_X, 0.0, RUA_EIXO_Z)
		heli.fase = float(i) / float(QUANTOS_HELICOPTEROS)
		mundo.add_child(heli)

## O rumo e a altura de cada um, para não voarem em formação.
func ajeitar_helicoptero(heli: Helicoptero3D, qual: int) -> void:
	# Rumos quase paralelos à rua: eles passam por cima dela, de ponta a ponta.
	heli.rumo = -0.22 + qual * 0.22
	heli.altura = lerpf(Helicoptero3D.ALTURA.x, Helicoptero3D.ALTURA.y, float(qual) / 2.0)
	heli.velocidade = 22.0 + qual * 6.0

## O HUD e a luz acompanham o estado do dia. Uma função só, ligada ao sinal do
## ciclo: qualquer coisa que mude ação, energia ou despensa cai aqui.
func mostrar_o_estado() -> void:
	mensagens.caixa(ciclo.dia, ciclo.contatos, "Irmã", vizinhos)
	comida = ciclo.comida
	agua = ciclo.agua
	energia = ciclo.energia
	dinheiro = ciclo.dinheiro
	status.mostrar(ciclo.comida, ciclo.agua, ciclo.energia, ciclo.dinheiro, ciclo.acoes, ciclo.periodo())
	status.avisar_modo_deus(ciclo.modo_deus)
	aplicar_hora_do_dia()
	if not ciclo.recado.is_empty():
		if dica != null: dica.avisar(ciclo.recado)
		ciclo.recado = ""
