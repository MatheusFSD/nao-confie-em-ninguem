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
const ATLAS := preload("res://modelos/personagens/atlas3d.webp")
const CASARIO := preload("res://scenes/casario.tscn")
const PONTO := preload("res://modelos/objetos/ponto_de_onibus.glb")
const Pessoa3D := preload("res://scripts/pessoa3d.gd")
const Abrigo3D := preload("res://scripts/abrigo3d.gd")
const Becos := preload("res://scripts/becos3d.gd")
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
const DIA_DO_ATAQUE := Ciclo3D.DIA_DO_ATAQUE
const CORPOS_DADOS := "res://data/corpos3d.json"
## A rua inteira tomada, nas duas faixas, de uma ponta à outra da rua esticada
## (255 m): 37 carros por faixa, um a cada ~6,9 m.
const CARROS_NO_ENGARRAFAMENTO := 74
## O comboio do dia do ataque: um blindado na frente e os caminhões atrás.
const CAMINHOES_DO_COMBOIO := 3
## Quantos caçadores andam pela rua no breu e depois que o Exército passa.
const CACADORES_NO_BREU := 3
const CACADORES_DEPOIS := 6
## Depois do ataque, de noite: poucos. É de noite que dá para sair.
const CACADORES_DEPOIS_DE_NOITE := 2
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
## Até onde o estalo de um arrombamento que dá errado chega aos caçadores.
const RAIO_DO_BARULHO := 45.0
## Os cinco raios da mira: o do meio e quatro em volta.
const DESVIOS := [Vector2.ZERO, Vector2(0.11, 0.0), Vector2(-0.11, 0.0), Vector2(0.0, 0.11), Vector2(0.0, -0.11)]
var malha_cenario := MalhaLowPoly.new()
var rua: Rua3D
var material_ps1: ShaderMaterial
var mundo: Node3D
var jogador: CharacterBody3D
var camera: Camera3D
var rua_modelo: Node3D
var becos: Dictionary = {}
var casa: Casa3D
var cidade: Cidade3D
## Quem decide quando o Observador aparece (data/observador3d.json).
var observadores: Observadores3D
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
## Loja de compras em atendimento (tipo), vazia quando não há.
var na_loja := ""
## Sentado no sofá, escolhendo até quando passar o tempo.
var na_sofa := false
## Na torneira ou no portão da irmã, escolhendo.
var na_torneira := false
var na_irma := false
## Conversando com o PM do posto de embarque.
var na_embarque := false
var posto_de_embarque: Node3D
var pm_do_embarque: StaticBody3D
## A irmã: a pessoa, a casa dela e a porta marcada no portão.
var irma: Pessoa3D
var casa_da_irma: Node3D
var porta_da_irma: StaticBody3D
## Passou do ataque sem ninguém buscá-la: o portão fica aberto e ela não está.
var irma_sumiu := false
## Um caçador já alcançou o jogador nesta partida.
var pego := false
## Testes desligam isto para continuar no mundo depois de um fim de jogo.
var voltar_ao_menu_no_fim := true
## Quantas não lidas já foram avisadas, para só avisar quando chegar mais.
var _novas_avisadas := 0
## O nome do final em que a partida terminou (vazio enquanto joga).
var ultimo_final := ""
## A barricada dos sobreviventes e o portão dela.
var barricada: Node3D
var portao_da_barricada: StaticBody3D
var casa_da_irma_revirada := false
## O comércio que vende, com donos, preços e o que já foi arrombado.
var lojas := Lojas3D.new()
## A porta de cada loja de compras, para mirar e para o barulho sair dali.
var portas_das_lojas := {}
## O minigame de arrombar, enquanto está na tela.
var arrombando: Arrombar3D
var escolha: MenuEscolha
var abrigo: Abrigo3D
var abrigado_em := -1
var _volta_do_abrigo := Transform3D.IDENTITY
var _processo_antes_do_abrigo := Node.PROCESS_MODE_INHERIT
var _mundo_visivel_antes_do_abrigo := true
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
@export var suprimentos := 3
@export var dinheiro := 30
## Guardado para voltar depois da cutscene, que põe o ambiente dela no lugar.
var ambiente_do_bairro: Environment
## Criados uma vez no breu; o horizonte muda, estes corpos não.
var corpos: Node3D
## O que o jogador acabou de fazer, para o tutorial do dia 0 acompanhar:
## "tv", "agua", "trabalhou", "comprou", "trancou", "dormiu".
signal evento(nome: String)
## O dia 0, com a irmã ensinando a casa. Só existe nesse dia.
var tutorial: Tutorial3D
## Para onde o jogador saiu de ônibus (trabalho ou mercado), até voltar.
var saiu_para := ""
## O recado de quando saiu ("Dia de trabalho: +R$ 25"), guardado para depois
## da viagem: durante a cena ele ficava atrás da tarja preta.
var recado_da_volta := ""

## Que dia da história o mundo mostra. Manda na cidade do horizonte e, com ela,
## na cor do céu e da névoa: 1 a 3 normal, 3 a 7 estranha, 7 a 9 em chamas,
## 9 em diante destruída. O jogo 2D troca isto ao virar o dia.
@export var dia := 1
## Modo deus desde o começo, para quem está testando. Em jogo, F10 liga e desliga.
@export var modo_deus := false
var inicio := Vector3(9.75, 0.25, 12.4)

func _ready() -> void:
	mundo = get_node("Tela/Render/Mundo")
	# O mundo é desenhado numa tela interna (SubViewport). Sem isto, todo som
	# com posição no mundo (carros, tiros, cachorros, passos) ficava mudo.
	(get_node("Tela/Render") as SubViewport).audio_listener_enable_3d = true
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
	jogador.abriu_o_celular.connect(pegar_o_celular)
	jogador.mexeu_na_hora.connect(mudar_a_hora)
	jogador.pediu_final.connect(ver_um_final)
	jogador.pediu_mesa_de_som.connect(abrir_mesa_de_som)
	jogador.pediu_pausa.connect(abrir_pausa)

## Quanto o mundo é desenhado pequeno antes de ser esticado de volta. Quem manda
## é o `stretch_shrink` do nó Tela; aqui só se lê o resultado, para os materiais
## usarem a mesma grade que a tela.
func medir_a_tela() -> void:
	var tela := get_node("Tela") as SubViewportContainer
	var encolhe := maxi(1, tela.stretch_shrink)
	var janela := Vector2(get_window().size)
	RESOLUCAO = (janela / float(encolhe)).floor()

func construir() -> void:
	# Mundo novo: o mapa de rotas dos caçadores da partida anterior não vale mais.
	Cacador3D.CAMINHO.esquecer()
	Pessoa3D.CAMINHOS.esquecer()
	construir_terreno()
	construir_fundo()
	aplicar_malha()
	casa = Casa3D.new()
	casa.montar(mundo, CASA_LUGAR, RESOLUCAO)
	# A TV da sala fica desligada: quem liga vê o programa na tela cheia.
	casa.apagar_a_tela(RESOLUCAO)
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
	becos = Becos.construir(mundo, RESOLUCAO)
	por_os_vizinhos()
	por_as_lojas()
	por_a_casa_da_irma()
	construir_limites()
	construir_barricada()
	construir_posto_de_embarque()
	construir_bandido()
	ambiente_sonoro = AmbienteSonoro.new()
	ambiente_sonoro.name = "AmbienteSonoro"
	add_child(ambiente_sonoro)
	ambiente_sonoro.comecar(self)
	# Depois do _ready inteiro: o tutorial usa a caixa de fala e o HUD.
	if dia == 0: call_deferred("comecar_tutorial")
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
	ciclo.suprimentos = suprimentos
	ciclo.dinheiro = dinheiro
	add_child(ciclo)
	ciclo.sortear_a_agua()
	noticias.estado = {"agua_vai_contaminar": ciclo.agua_vai_contaminar}
	ciclo.mudou.connect(mostrar_o_estado)
	ciclo.virou_o_dia.connect(virar_o_dia)
	ciclo.morreu.connect(func(_motivo: String): pass)
	if modo_deus: ciclo.virar_deus(true)
	acender_a_rua()
	mostrar_o_estado()
	ajustar_corpos()
	observadores = Observadores3D.new()
	observadores.jogador = jogador
	observadores.camera = camera
	observadores.ciclo = ciclo
	observadores.casa_lugar = CASA_LUGAR
	observadores.abrigo_do_jogador = LOTE.grow(0.3)
	observadores.alarme.connect(soar_o_alarme)
	observadores.resolucao = RESOLUCAO
	var barreira := mundo.get_node_or_null("FimDaRua") as CollisionObject3D
	if barreira != null: observadores.transparentes.append(barreira.get_rid())
	if becos.get("no") != null:
		for peca in (becos["no"] as Node).get_children():
			if peca is StaticBody3D: observadores.transparentes.append((peca as StaticBody3D).get_rid())
	mundo.add_child(observadores)
	posicionar_a_irma()

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
	# As portas de aço mudam o cenário: os caçadores refazem o mapa de rotas.
	Cacador3D.CAMINHO.esquecer()
	Pessoa3D.CAMINHOS.esquecer()
	var casario := mundo.get_node_or_null("Casario") as Node3D
	if casario == null: return 0
	var trocados := 0
	for predio in casario.get_children():
		if trocar_porta_de_aco(casario, predio, fechado): trocados += 1
	return trocados

## Cada prédio do comércio na hora certa: fechado de noite e, de dia, aberto
## só até o dia em que aquele comércio baixa a porta de vez.
func ajustar_comercio(noite: bool) -> void:
	var casario := mundo.get_node_or_null("Casario") as Node3D
	if casario == null: return
	var mudou := false
	for predio in casario.get_children():
		var nome := String(predio.name)
		if nome.find("_aberto") < 0 and nome.find("_fechado") < 0: continue
		var fechar := noite or dia_de_hoje() >= lojas.dia_que_fecha(nome, DIA_DO_BREU)
		if trocar_porta_de_aco(casario, predio, fechar): mudou = true
	comercio_aberto = not noite and dia_de_hoje() < DIA_DO_BREU
	if mudou:
		Cacador3D.CAMINHO.esquecer()
		Pessoa3D.CAMINHOS.esquecer()

## Troca um prédio do comércio pelo par de porta aberta ou baixada, no mesmo
## lugar. Devolve falso quando ele já está assim ou não é comércio.
func trocar_porta_de_aco(casario: Node3D, predio: Node, fechado: bool) -> bool:
	var nome := String(predio.name)
	var de := "_aberto" if fechado else "_fechado"
	var para := "_fechado" if fechado else "_aberto"
	# O nome pode ter número no fim, quando há mais de um do mesmo modelo.
	var corte := nome.find(de)
	if corte < 0: return false
	var loja := nome.substr(0, corte)
	var cena: PackedScene = load("res://modelos/comercios/%s%s.glb" % [loja, para])
	if cena == null: return false
	var novo: Node3D = cena.instantiate()
	novo.name = loja + para
	novo.transform = (predio as Node3D).transform
	casario.add_child(novo, true)
	preparar_predio(novo)
	casario.remove_child(predio)
	predio.queue_free()
	return true

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
	# Volume de interação, como as portas e pias. O abrigo já tem seus próprios
	# colisores; esta caixa invisível não deve barrar a calçada.
	chamada.collision_layer = 16
	chamada.collision_mask = 0
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
	# Fecha as fachadas, preservando as duas entradas de cada beco.
	for faixa: Vector2 in Becos.segmentos_fechados(RUA_LIMITE, becos.get("entradas", [])):
		barreira(corpo, Vector3((faixa.x + faixa.y) / 2.0, 3.0, RUA_EIXO_Z + 9.4), Vector3(faixa.y - faixa.x, 6.0, 0.4))
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

func _physics_process(delta: float) -> void:
	if dica == null or casa == null: return
	destravar()
	conferir_chegada_da_irma()
	cuidar_da_irma_em_casa()
	conferir_bandido()
	if abrigo != null:
		dica.esconder()
		return
	if fresta != null:
		# Na janela, o que muda é o que se vê: a nota acompanha a rua.
		fresta.notar(o_que_se_ve(de_qual_janela))
		dica.esconder()
		return
	if escolha != null or mochila != null or celular != null:
		dica.esconder()
		return
	if menu != null or arrombando != null or expediente != null or tv != null or (dialogo != null and dialogo.visible):
		dica.esconder()
		return
	var alvo := na_mira()
	dica.apontar(not alvo.is_empty())
	if alvo.is_empty():
		dica.esconder()
		return
	if alvo["o_que"] == "ponto":
		dica.mostrar("Pegar o ônibus" if ciclo.onibus_funciona() else "Ônibus fora de serviço · nem atrasado ele vem")
		return
	if alvo["o_que"] == "torneira":
		dica.mostrar(("Garrafas já cheias hoje" if ciclo.garrafas_cheias_hoje else "Torneira · encher as garrafas") if ciclo.tem_agua_da_rede() else "Torneira · abastecimento cortado")
		return
	if alvo["o_que"] == "irma":
		dica.mostrar(dica_da_irma())
		return
	if alvo["o_que"] == "refugio":
		dica.mostrar(dica_da_barricada())
		return
	if alvo["o_que"] == "embarque":
		dica.mostrar(dica_do_embarque())
		return
	if alvo["o_que"] == "radio":
		dica.mostrar("Ligar o rádio" if ciclo.tem_energia_da_rede() else "Rádio da sala · sem energia")
		return
	if alvo["o_que"] == "cama":
		dica.mostrar("Dormir até amanhã · a noite consome %d suprimento%s" % [ciclo.consumo_da_noite(), "" if ciclo.consumo_da_noite() == 1 else "s"])
		return
	if alvo["o_que"] == "sofa":
		dica.mostrar("Sentar no sofá · passar o tempo" if ciclo.horas > 0 else "Já é tarde. Só resta dormir.")
		return
	if alvo["o_que"] == "pessoa":
		dica.mostrar("Puxar conversa")
		return
	if alvo["o_que"] == "irma_casa":
		dica.mostrar("Sua irmã · conversar")
		return
	if alvo["o_que"] == "tv":
		dica.mostrar("Ver televisão" if ciclo.tem_energia_da_rede() else "Televisão · sem energia")
		return
	if alvo["o_que"] == "janela":
		dica.mostrar("Olhar pela fresta")
		return
	if alvo["o_que"] == "loja":
		dica.mostrar(dica_da_loja(alvo["tipo"]))
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
	if abrigo != null: return
	if menu != null or arrombando != null or expediente != null or tv != null or fresta != null or escolha != null: return
	if mochila != null or celular != null or mesa_de_som != null or pausa != null: return
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
		if colisor.has_meta("ponto") or colisor.has_meta("cama") or colisor.has_meta("sofa") or colisor.has_meta("tv") or colisor.has_meta("torneira") \
			or colisor.has_meta("janela") or colisor.has_meta("vizinho") or colisor.has_meta("loja") or colisor.has_meta("irma") or colisor.has_meta("radio") or colisor.has_meta("refugio") or colisor.has_meta("embarque") or casa.porta_de(colisor) >= 0 \
			or (colisor is Node and (colisor as Node).is_in_group("pessoas3d")):
			break
	if colisor == null: return {}
	if colisor != null and colisor.has_meta("ponto"): return {"o_que": "ponto"}
	if colisor != null and colisor.has_meta("cama"): return {"o_que": "cama"}
	if colisor != null and colisor.has_meta("sofa"): return {"o_que": "sofa"}
	if colisor != null and colisor.has_meta("tv"): return {"o_que": "tv"}
	if colisor != null and colisor.has_meta("torneira"): return {"o_que": "torneira"}
	if colisor != null and colisor.has_meta("irma"): return {"o_que": "irma"}
	if colisor != null and colisor.has_meta("radio"): return {"o_que": "radio"}
	if colisor != null and colisor.has_meta("refugio"): return {"o_que": "refugio"}
	if colisor != null and colisor.has_meta("embarque"): return {"o_que": "embarque"}
	if colisor != null and colisor.has_meta("janela"):
		return {"o_que": "janela", "qual": int(colisor.get_meta("janela"))}
	if colisor != null and colisor.has_meta("vizinho"):
		return {"o_que": "vizinho", "quem": int(colisor.get_meta("vizinho"))}
	if colisor != null and colisor.has_meta("loja"):
		return {"o_que": "loja", "tipo": String(colisor.get_meta("loja"))}
	if colisor == irma and ciclo.irma_em_casa: return {"o_que": "irma_casa"}
	if colisor is Node and (colisor as Node).is_in_group("pessoas3d") and colisor.conversa_livre:
		return {"o_que": "pessoa", "quem": colisor}
	var porta := casa.porta_de(colisor)
	if porta >= 0: return {"o_que": "porta", "qual": porta}
	return {}

## Page Down e Page Up puxam o relógio do dia para trás e para a frente, um período por
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
	if abrigo != null: return
	if menu != null or arrombando != null or expediente != null or tv != null or fresta != null or escolha != null: return
	if mochila != null or celular != null: return
	if dialogo != null and dialogo.visible: return
	var alvo := na_mira()
	if alvo.get("o_que", "") != "porta": return
	var antes := casa.esta_trancada(alvo["qual"])
	dica.avisar(casa.trancar(alvo["qual"]))
	if casa.esta_trancada(alvo["qual"]) != antes:
		Sons3D.tocar_em(mundo, casa.onde_fica_a_porta(alvo["qual"]), Sons3D.trancar(), 15.0, -6.0)
	if casa.esta_trancada(alvo["qual"]): evento.emit("trancou")

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
	if abrigo != null: return
	if menu != null or arrombando != null or expediente != null or tv != null or fresta != null or escolha != null: return
	if mochila != null or celular != null: return
	if dialogo != null and dialogo.visible: return
	var alvo := na_mira()
	match alvo.get("o_que", ""):
		"porta":
			var onde := casa.onde_fica_a_porta(alvo["qual"])
			if casa.esta_trancada(alvo["qual"]) and not casa.esta_aberta(alvo["qual"]):
				dica.avisar("Está trancada. T destranca.")
				Sons3D.tocar_em(mundo, onde, Sons3D.porta_forcada(), 18.0, -6.0)
			else:
				var abriu := casa.acionar(alvo["qual"])
				var som := Sons3D.porta_abrir() if abriu else Sons3D.porta_fechar()
				Sons3D.tocar_em(mundo, onde, som, 20.0, -6.0).pitch_scale = 0.8 if casa.nome_da_porta(alvo["qual"]) == "portão" else 1.0
		"ponto": abrir_menu_do_ponto()
		"cama": dormir()
		"sofa": sentar_no_sofa()
		"pessoa": puxar_conversa(alvo["quem"])
		"irma_casa": conversar_com_a_irma()
		"tv": ligar_a_tv()
		"torneira": abrir_a_torneira()
		"irma": chamar_a_irma()
		"refugio": bater_na_barricada()
		"embarque": falar_com_o_pm()
		"radio": ouvir_o_radio(false)
		"vizinho": bater_na_porta(alvo["quem"])
		"loja": entrar_na_loja(alvo["tipo"])
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
	if abrigo != null: return
	if mochila != null:
		fechar_a_mochila()
		return
	if menu != null or arrombando != null or expediente != null or tv != null or fresta != null or escolha != null or celular != null: return
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
	if ciclo.tem_radio:
		lista.append({"chave": "radio", "texto": "Rádio a pilha", "abaixo": "O da sua irmã. Pega notícia mesmo sem luz."})
	lista.append({"chave": "despensa", "texto": "Despensa", "abaixo": "%d suprimento%s em casa, R$ %d na carteira." % [ciclo.suprimentos, "" if ciclo.suprimentos == 1 else "s", ciclo.dinheiro]})
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
		"radio":
			fechar_a_mochila()
			ouvir_o_radio(true)
		"despensa":
			dica.avisar("%d suprimento%s em casa. Esta noite consome %d." % [ciclo.suprimentos, "" if ciclo.suprimentos == 1 else "s", ciclo.consumo_da_noite()])

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
	dica.avisar("Lanterna acesa. Eles são cegos, mas você não precisa ser." if ciclo.lanterna_acesa else "Lanterna apagada. Economia de pilha, a única que ainda dá pra fazer.")

## O celular: a caixa de entrada do dia, com o que a irmã e os vizinhos que
## confiam em você mandaram.
## Tecla C: o celular direto do bolso, sem passar pela mochila.
func pegar_o_celular() -> void:
	if abrigo != null or celular != null or mochila != null or dormindo: return
	if menu != null or arrombando != null or expediente != null or tv != null or fresta != null or escolha != null: return
	if dialogo != null and dialogo.visible: return
	dica.esconder()
	balao.hide()
	abrir_o_celular()

func abrir_o_celular() -> void:
	if celular != null: return
	prender_o_jogo(true)
	celular = Celular3D.new()
	celular.name = "Celular"
	Sons3D.tocar(self, Sons3D.celular_abrir(), -8.0)
	celular.guardou.connect(guardar_o_celular)
	# Só fica lida a mensagem que foi aberta.
	celular.leu.connect(mensagens.marcar_lida)
	celular.leu.connect(func(_chave: String): avisar_mensagens())
	add_child(celular)
	var caixa := mensagens.caixa(ciclo.dia, ciclo.contatos, "Irmã", vizinhos)
	for m: Dictionary in caixa: m["lida"] = mensagens.ja_lida(String(m["chave"]))
	celular.ligar(caixa, mensagens.novas(ciclo.dia, ciclo.contatos, vizinhos), ciclo.dia, ciclo.texto_da_hora())

func guardar_o_celular() -> void:
	if celular == null: return
	Sons3D.tocar(self, Sons3D.celular_guardar(), -8.0)
	celular.queue_free()
	celular = null
	prender_o_jogo(false)
	avisar_mensagens()

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
	for predio: Node3D in casas_do_casario(casario):
		# A origem de cada casa fica no meio da fachada.
		var frente := predio.global_position
		# Só casa com a frente na calçada: as da segunda fileira ficavam com a
		# porta nos fundos de outra casa, fora da vista da rua.
		var do_nosso_lado := frente.z < RUA_EIXO_Z
		if do_nosso_lado and frente.z < CALCADA_PERTO - 3.0: continue
		if not do_nosso_lado and frente.z > 37.6 + 3.0: continue
		casas.append({"no": predio, "frente": frente, "longe": Vector2(frente.x, frente.z).distance_to(meio_do_lote)})
	casas.sort_custom(func(a, b): return float(a["longe"]) < float(b["longe"]))
	vizinhos = Vizinho3D.sortear(QUANTOS_VIZINHOS)
	for i in vizinhos.size():
		if i >= casas.size(): break
		var morador: Vizinho3D = vizinhos[i]
		morador.casa = casas[i]["no"]
		morador.porta = porta_de_vizinho(casas[i]["frente"], i)

## As casas do casario, inclusive as que foram encaixadas dentro de outra na
## cena (uma casa de frente pendurada numa do nosso lado conta como vizinha).
## Comércio fica de fora: lá não se bate na porta para puxar conversa.
func casas_do_casario(no: Node) -> Array:
	var achadas := []
	for filho in no.get_children():
		# Só peça de cenário inteira (instância), não os pedaços de dentro do modelo.
		if not (filho is Node3D) or filho.scene_file_path.is_empty(): continue
		if String(filho.name).begins_with("casa"): achadas.append(filho)
		achadas.append_array(casas_do_casario(filho))
	return achadas

## A porta fica no meio da fachada, um palmo para fora, do lado da rua.
func porta_de_vizinho(frente: Vector3, qual: int) -> StaticBody3D:
	var do_nosso_lado := frente.z < RUA_EIXO_Z
	var corpo := StaticBody3D.new()
	corpo.name = "PortaVizinho%d" % (qual + 1)
	corpo.position = Vector3(frente.x, 0.0, frente.z + (0.12 if do_nosso_lado else -0.12))
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

# ------------------------------------------------------------------ comércio

## Uma porta marcada em cada loja de compras do nosso lado da rua (mercadinho,
## padaria e bar). As cópias do outro lado e de fora do trecho jogável ficam só
## de cenário.
func por_as_lojas() -> void:
	portas_das_lojas.clear()
	var casario := mundo.get_node_or_null("Casario")
	if casario == null: return
	for predio in casario.get_children():
		if not (predio is Node3D): continue
		var tipo := lojas.tipo_do_predio(String(predio.name))
		if tipo.is_empty() or portas_das_lojas.has(tipo): continue
		var lugar := (predio as Node3D).global_position
		if lugar.x < RUA_LIMITE.x or lugar.x > RUA_LIMITE.y: continue
		var corpo := StaticBody3D.new()
		corpo.name = "PortaDaLoja_" + tipo
		# A fachada fica na origem do modelo; a porta, logo à frente dela.
		corpo.transform = (predio as Node3D).global_transform.translated_local(Vector3(0.0, 0.0, 0.25))
		corpo.set_meta("loja", tipo)
		corpo.collision_layer = 16
		corpo.collision_mask = 0
		var forma := CollisionShape3D.new()
		var porta := BoxShape3D.new()
		porta.size = Vector3(3.4, 2.6, 0.3)
		forma.shape = porta
		forma.position.y = 1.3
		corpo.add_child(forma)
		mundo.add_child(corpo)
		portas_das_lojas[tipo] = corpo

## "o mercadinho" → "no mercadinho"; "a padaria" → "da padaria".
static func contrair(preposicao: String, nome: String) -> String:
	if nome.begins_with("o "): return preposicao + "o " + nome.substr(2)
	if nome.begins_with("a "): return preposicao + "a " + nome.substr(2)
	return preposicao + "e " + nome

## O que a dica diz ao olhar para a porta da loja, conforme a hora e o dia.
func dica_da_loja(tipo: String) -> String:
	var nome := String(lojas.loja(tipo).get("nome", tipo))
	if lojas.aberta(tipo, dia_de_hoje(), ciclo.e_noite()):
		var custo := lojas.custo_visita()
		return "Entrar %s · %dh" % [contrair("n", nome), int(custo.horas)]
	if not lojas.fechada_de_vez(tipo, dia_de_hoje()):
		return "Fechad%s · abre de manhã" % ("a" if nome.begins_with("a ") else "o")
	if lojas.saqueadas.has(tipo): return "Já levaram tudo " + contrair("d", nome)
	if dia_de_hoje() == DIA_DO_ATAQUE: return "Porta baixada · hoje não, tem tropa na rua"
	return "Arrombar a porta %s · faz barulho se errar" % contrair("d", nome)

## Na porta da loja: aberta, o dono atende no balcão; fechada de vez, dá para
## arrombar. De noite (antes de fechar de vez) só resta voltar de manhã.
func entrar_na_loja(tipo: String) -> void:
	if abrigo != null or not lojas.existe(tipo): return
	var dia_agora := dia_de_hoje()
	if lojas.aberta(tipo, dia_agora, ciclo.e_noite()):
		var custo := lojas.custo_visita()
		if not ciclo.gastar(int(custo.horas)):
			dica.avisar(ciclo.recado)
			return
		var loja := lojas.loja(tipo)
		na_loja = tipo
		dica.esconder()
		balao.hide()
		prender_o_jogo(true)
		dialogo.caminho_do_retrato = String(loja.get("retrato", ""))
		dialogo.respostas_ao_final = true
		var falas := lojas.falas(tipo, dia_agora)
		dialogo.mostrar(String(loja.get("dono", "")), falas if not falas.is_empty() else ["Pois não?"])
		return
	if not lojas.fechada_de_vez(tipo, dia_agora) or lojas.saqueadas.has(tipo):
		dica.avisar(dica_da_loja(tipo))
		return
	# No dia do ataque, com blindado passando, ninguém arromba nada.
	if dia_agora == DIA_DO_ATAQUE:
		dica.avisar("Arrombar com tanque passando na rua? Coragem tem limite, e o seu é hoje.")
		return
	# Antes do breu a rua ainda tem dono: o sargento aparece e não deixa.
	if dia_agora < Ciclo3D.DIA_DO_BREU:
		flagrado_pelo_sargento()
		return
	comecar_arrombamento(tipo)

## Pego mexendo na porta de aço antes do breu: o sargento chega por trás.
const FALAS_DO_FLAGRA := [
	"Opa, opa. Mão longe da porta, cidadão.",
	"O mundo tá desmoronando, eu sei. Tá no rádio, tá no céu, tá na cara de todo mundo.",
	"Mas esta rua ainda é minha. Enquanto for, ninguém arromba nada aqui sem a minha autorização.",
	"Vai pra casa. Hoje eu tô de bom humor.",
]

func flagrado_pelo_sargento() -> void:
	dica.esconder()
	balao.hide()
	prender_o_jogo(true)
	dialogo.caminho_do_retrato = RETRATO_DO_SARGENTO
	dialogo.respostas_ao_final = false
	dialogo.mostrar(NOME_DO_SARGENTO, FALAS_DO_FLAGRA)

## O balcão: o que o dono vende hoje, com preço e rendimento, até ir embora.
func abrir_o_balcao(aviso := "") -> void:
	var loja := lojas.loja(na_loja)
	if loja.is_empty():
		encerrar_conversa()
		return
	escolha = MenuEscolha.new()
	escolha.name = "Balcao"
	escolha.escolheu.connect(responder_no_balcao)
	var lista := []
	var restam := lojas.restam_hoje(na_loja, dia_de_hoje())
	for produto: Dictionary in loja.get("produtos", []):
		if restam <= 0 and not ciclo.modo_deus: break
		var vale := String(produto.get("vale", ""))
		if vale == "lanterna" and ciclo.tem_lanterna: continue
		var preco := lojas.preco(produto, dia_de_hoje())
		var abaixo := "Rende " + Lojas3D.rendimento(vale, int(produto.get("rende", 1)))
		if not ciclo.modo_deus and ciclo.dinheiro < preco: abaixo += " · faltam R$ %d" % (preco - ciclo.dinheiro)
		lista.append({"chave": String(produto.get("id", "")), "texto": "%s · R$ %d" % [produto.get("nome", ""), preco], "abaixo": abaixo})
	lista.append({"chave": "", "texto": "Ir embora", "abaixo": "" if restam > 0 else "Hoje ele não vende mais nada para você."})
	var saldo := "Você tem R$ %d. Hoje ele vende mais %d embalage%s por cliente." % [ciclo.dinheiro, restam, "m" if restam == 1 else "ns"]
	escolha.perguntar(aviso + " " + saldo if not aviso.is_empty() else saldo, lista)
	dialogo.mostrar_respostas(escolha)

## Comprar uma embalagem: o dinheiro sai, o que ela rende entra em casa, e o
## balcão volta com o saldo novo.
func responder_no_balcao(chave: String) -> void:
	if escolha != null:
		escolha.hide()
		escolha.queue_free()
		escolha = null
	if chave.is_empty():
		encerrar_conversa()
		return
	var produto := {}
	for item: Dictionary in lojas.loja(na_loja).get("produtos", []):
		if String(item.get("id", "")) == chave: produto = item
	if produto.is_empty():
		encerrar_conversa()
		return
	var preco := lojas.preco(produto, dia_de_hoje())
	if not ciclo.modo_deus and lojas.restam_hoje(na_loja, dia_de_hoje()) <= 0:
		abrir_o_balcao("Hoje não dá mais: tem fila e pouca coisa.")
		return
	if not ciclo.modo_deus and ciclo.dinheiro < preco:
		abrir_o_balcao("Não dá: faltam R$ %d." % (preco - ciclo.dinheiro))
		return
	lojas.registrar_compra(na_loja, dia_de_hoje())
	var rende := int(produto.get("rende", 1))
	var sobra := ciclo.dinheiro - preco
	match String(produto.get("vale", "")):
		"suprimentos": ciclo.guardar(rende, sobra)
		"lanterna":
			ciclo.guardar(0, sobra)
			ciclo.tem_lanterna = true
	abrir_o_balcao("Levou %s. Sobrou R$ %d." % [produto.get("nome", ""), ciclo.dinheiro])
	Sons3D.tocar(self, Sons3D.compra(), -4.0)
	evento.emit("comprou")

## Arrombar custa tempo e força antes do primeiro golpe, dê certo ou não.
func comecar_arrombamento(tipo: String) -> void:
	var custo := lojas.custo_arrombar()
	if not ciclo.gastar(int(custo.horas)):
		dica.avisar(ciclo.recado)
		return
	na_loja = tipo
	dica.esconder()
	balao.hide()
	prender_o_jogo(true)
	arrombando = Arrombar3D.new()
	arrombando.name = "Arrombando"
	arrombando.titulo = ("Arrombando a porta " + contrair("d", String(lojas.loja(tipo).get("nome", tipo)))).to_upper()
	arrombando.terminou.connect(fim_do_arrombamento)
	add_child(arrombando)

func fim_do_arrombamento(resultado: String) -> void:
	var tipo := na_loja
	na_loja = ""
	if arrombando != null:
		arrombando.queue_free()
		arrombando = null
	prender_o_jogo(false)
	match resultado:
		"abriu": saquear(tipo)
		"falhou":
			fazer_barulho(onde_fica_a_porta(tipo))
			dica.avisar("O cadeado estalou alto. A rua inteira ouviu.")
		_: dica.avisar("Você largou o pé de cabra. A porta continua fechada.")

## A porta cedeu: o que sobrou nas prateleiras vai para casa, uma vez só.
func saquear(tipo: String) -> void:
	lojas.saqueadas[tipo] = true
	var saque: Dictionary = lojas.loja(tipo).get("saque", {})
	var achou := lojas.saque_da_partida(tipo)
	ciclo.guardar(achou, ciclo.dinheiro)
	var levou: Array[String] = []
	if achou > 0: levou.append("+%d suprimento%s" % [achou, "" if achou == 1 else "s"])
	if achou > 0 and int(saque.get("lanterna", 0)) > 0 and not ciclo.tem_lanterna:
		ciclo.tem_lanterna = true
		levou.append("uma lanterna")
	if levou.is_empty(): dica.avisar("A porta cedeu. Já tinham levado tudo antes de você.")
	else: dica.avisar("A porta cedeu. Você levou: %s." % ", ".join(levou))

## Calçada em frente à porta da loja: é dali que o barulho sai.
func onde_fica_a_porta(tipo: String) -> Vector3:
	var porta: Node3D = portas_das_lojas.get(tipo)
	if porta == null: return jogador.global_position
	var lugar := porta.global_transform.translated_local(Vector3(0.0, 0.0, 1.2)).origin
	return Vector3(lugar.x, 0.0, lugar.z)

## Um estalo alto em `onde`: todo caçador ao alcance corre para lá procurar.
## Devolve quantos ouviram.
func fazer_barulho(onde: Vector3) -> int:
	var ouviram := 0
	for bicho in get_tree().get_nodes_in_group("cacadores3d"):
		if not bicho.has_method("ouvir"): continue
		if (bicho as Node3D).global_position.distance_to(onde) > RAIO_DO_BARULHO: continue
		bicho.ouvir(onde)
		ouviram += 1
	return ouviram


# ------------------------------------------------------------------ irmã

## A casa dela é fixa: a amarela de telhado colonial do nosso lado, no fim da
## rua, depois do mercadinho. A porta marcada fica no portão.
const CASA_DA_IRMA := "casa_amarela_de_telhado_colonial"
const RETRATO_DA_IRMA := "res://ui/retratos/irma.webp"
## O que ela diz no portão antes do breu, por dia.
const VISITAS_DA_IRMA := [
	[1, ["Ué, veio me ver? Tá tudo bem por aqui.", "Volta antes de escurecer, tá? A rua anda esquisita."]],
	[3, ["Não tô dormindo direito. Tem um barulho no quintal toda noite.", "Se piorar, eu te mando mensagem."]],
	[5, ["Todo mundo indo embora... Eu vou ficar. Não sei pra onde essa fila vai.", "Guarda comida. Guarda água."]],
]
const RESGATE_DA_IRMA := ["Você veio... Você veio mesmo.", "Tem alguma coisa andando no quintal. Devagar. Não faz barulho.", "Eu pego o rádio e vou com você. Me espera."]

func por_a_casa_da_irma() -> void:
	var casario := mundo.get_node_or_null("Casario")
	if casario == null: return
	var casas_de_vizinho := []
	for morador: Vizinho3D in vizinhos: casas_de_vizinho.append(morador.casa)
	var escolhida: Node3D = null
	for predio in casario.get_children():
		if not (predio is Node3D) or predio in casas_de_vizinho: continue
		var lugar := (predio as Node3D).global_position
		if lugar.z > RUA_EIXO_Z or lugar.x < RUA_LIMITE.x or lugar.x > RUA_LIMITE.y: continue
		if String(predio.name) == CASA_DA_IRMA:
			escolhida = predio
			break
	if escolhida == null: return
	casa_da_irma = escolhida
	var caixa = RuaModelo.caixa_mundial(escolhida, Transform3D())
	if caixa == null: return
	var c: AABB = caixa
	porta_da_irma = StaticBody3D.new()
	porta_da_irma.name = "PortaoDaIrma"
	porta_da_irma.position = Vector3((c.position.x + c.end.x) / 2.0, 0.0, c.end.z + 0.12)
	porta_da_irma.set_meta("irma", true)
	porta_da_irma.collision_layer = 16
	porta_da_irma.collision_mask = 0
	var forma := CollisionShape3D.new()
	var portao := BoxShape3D.new()
	portao.size = Vector3(1.6, 2.1, 0.24)
	forma.shape = portao
	forma.position.y = 1.05
	porta_da_irma.add_child(forma)
	mundo.add_child(porta_da_irma)

## Onde ela fica quando mora com você: na sala, perto do sofá.
func lugar_da_irma_em_casa() -> Vector3:
	var sofa: Node3D = casa.raiz.find_child("Movel_Sof", true, false) if casa != null else null
	return (sofa.global_position + Vector3(0.9, -0.1, 1.3)) if sofa != null else CASA_LUGAR

## Antes do resgate ela não está na sua casa; depois, fica na sala.
func posicionar_a_irma() -> void:
	mensagens.irma_em_casa = ciclo.irma_em_casa
	if irma == null: return
	if ciclo.irma_em_casa:
		irma.seguir(null)
		irma.global_position = lugar_da_irma_em_casa()
		irma.aparecer(true)
	elif irma.seguindo == null:
		irma.aparecer(false)

func dica_da_irma() -> String:
	if ciclo.irma_em_casa: return "Casa da sua irmã · ela está com você agora"
	if irma != null and irma.seguindo != null: return "Casa da sua irmã · ela está atrás de você"
	if irma_sumiu: return "Casa da sua irmã · ninguém atende"
	if dia_de_hoje() == Ciclo3D.DIA_DO_BREU: return "Casa da sua irmã · chamar baixinho"
	return "Casa da sua irmã · chamar no portão"

## No portão dela. Antes do breu é visita; no breu, o resgate; depois disso, se
## ninguém veio, a casa está vazia.
func chamar_a_irma() -> void:
	if abrigo != null: return
	if ciclo.irma_em_casa or (irma != null and irma.seguindo != null) or irma_sumiu:
		if irma_sumiu:
			dica.avisar("Você chama pelo nome dela. Ninguém atende.")
			return
		dica.avisar(dica_da_irma())
		return
	na_irma = true
	dica.esconder()
	balao.hide()
	prender_o_jogo(true)
	dialogo.caminho_do_retrato = RETRATO_DA_IRMA
	if dia_de_hoje() >= Ciclo3D.DIA_DO_BREU:
		dialogo.respostas_ao_final = true
		dialogo.mostrar("Irmã", RESGATE_DA_IRMA)
		return
	var falas: Array = VISITAS_DA_IRMA[0][1]
	for par: Array in VISITAS_DA_IRMA:
		if dia_de_hoje() >= int(par[0]): falas = par[1]
	dialogo.respostas_ao_final = false
	dialogo.mostrar("Irmã", falas)

func abrir_resposta_da_irma() -> void:
	if dia_de_hoje() < Ciclo3D.DIA_DO_BREU:
		encerrar_conversa()
		return
	escolha = MenuEscolha.new()
	escolha.name = "RespostaDaIrma"
	escolha.escolheu.connect(responder_a_irma)
	escolha.sem_detalhes = true
	escolha.perguntar("", [
		{"chave": "vem", "texto": "Vem comigo, agora.", "abaixo": "Ela vai atrás de você até em casa. Lá, come 1 suprimento a mais por noite, mas cuida da casa: +2h por dia e ninguém entra de madrugada. Traz o rádio a pilha."},
		{"chave": "", "texto": "Fica trancada. Eu volto.", "abaixo": "Ela continua aqui sozinha."},
	])
	dialogo.mostrar_respostas(escolha)

func responder_a_irma(chave: String) -> void:
	if escolha != null:
		escolha.hide()
		escolha.queue_free()
		escolha = null
	encerrar_conversa()
	if chave != "vem" or irma == null or porta_da_irma == null: return
	irma.global_position = porta_da_irma.global_position + Vector3(0.0, 0.1, 1.0)
	irma.seguir(jogador, camera)
	dica.avisar("Ela fecha o portão devagar e vem atrás de você. Leve ela para casa.")

func comecar_tutorial() -> void:
	tutorial = Tutorial3D.new()
	tutorial.name = "Tutorial"
	add_child(tutorial)
	tutorial.comecar(self)

# ------------------------------------------------------------------ sons

## O som do bairro: camadas gravadas por dia e hora, cachorros e monstros.
var ambiente_sonoro: AmbienteSonoro
var mesa_de_som: MesaDeSom
## O menu do Esc. Aberto, o jogo inteiro para.
var pausa: MenuPausa

func abrir_pausa() -> void:
	if pausa != null or dormindo or expediente != null or abrigo != null: return
	if dialogo.visible or escolha != null or tv != null or menu != null or mochila != null or celular != null or mesa_de_som != null: return
	pausa = MenuPausa.new()
	pausa.name = "Pausa"
	pausa.continuou.connect(fechar_pausa)
	pausa.foi_ao_menu.connect(voltar_ao_menu_inicial)
	add_child(pausa)
	prender_o_jogo(true)
	get_tree().paused = true

func fechar_pausa() -> void:
	if pausa == null: return
	get_tree().paused = false
	pausa.queue_free()
	pausa = null
	jogador.sensibilidade = float(Configuracoes.carregar().sensibilidade)
	prender_o_jogo(false)

func voltar_ao_menu_inicial() -> void:
	get_tree().paused = false
	if is_inside_tree() and get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://scenes/menu_inicial.tscn")

## F9: a mesa de som, com todos os sons do jogo.
func abrir_mesa_de_som() -> void:
	if mesa_de_som != null:
		fechar_mesa_de_som()
		return
	if dialogo.visible or escolha != null or tv != null or expediente != null or menu != null: return
	prender_o_jogo(true)
	mesa_de_som = MesaDeSom.new()
	mesa_de_som.fechou.connect(fechar_mesa_de_som)
	add_child(mesa_de_som)

func fechar_mesa_de_som() -> void:
	if mesa_de_som == null: return
	mesa_de_som.queue_free()
	mesa_de_som = null
	prender_o_jogo(false)

## A irmã falando, no tutorial do dia 0: só fala, sem respostas.
func falar_como_irma(nome: String, falas: Array) -> void:
	# Parada do lado, ela vira o rosto para quem escuta.
	if irma != null and irma.visible:
		var rumo := jogador.global_position - irma.global_position
		irma.rotation.y = atan2(rumo.x, rumo.z)
	dica.esconder()
	balao.hide()
	prender_o_jogo(true)
	dialogo.caminho_do_retrato = RETRATO_DA_IRMA
	dialogo.respostas_ao_final = false
	dialogo.mostrar(nome, falas)

# ------------------------------------------------------------ a que voltou

## Quem não foi buscada no breu volta sozinha, antes do fim: acorda o morador
## gritando atrás da porta e pedindo para entrar. Três vezes ele pode negar, e
## a cada vez ela implora mais. Se ele abre, não é ela: é uma das coisas que
## voltam no lugar dos desaparecidos. É um final.
const DIA_DA_VOLTA := 9
const RETRATO_DA_QUE_VOLTOU := "res://ui/retratos/irma_alterada.webp"
const PEDIDOS_DA_VOLTA := [
	["ABRE! Abre, pelo amor de Deus, sou eu!", "Eu fiquei presa no breu, me escondi num porão, comi farinha crua... eu consegui voltar!", "Abre essa porta, eles tão vindo!"],
	["Por que você não abre? Sou eu, tua irmã!", "Eu tô com frio. Tem coisa andando aqui fora, eu ouço as unhas no asfalto.", "Lembra o que a mãe dizia? Que a gente tinha que cuidar uma da outra. Você prometeu pra ela."],
	["Eu tô machucada. Tô sangrando. Olha pela fresta, olha, sou eu!", "Eu andei a cidade inteira pra chegar aqui. Pra chegar em você.", "Se você não abrir, eu morro aqui na sua porta. É isso que você quer? Me ver morrer do lado de fora?"],
]
const DESPEDIDA_DA_VOLTA := ["...", "Tá bom.", "Eu volto outro dia."]
const ENTRADA_DA_VOLTA := ["Obrigada.", "Eu sabia que você ia abrir. Você sempre abre."]
signal respondeu_a_volta(abrir: bool)
var irma_bateu_na_porta := false
var na_volta := false

func a_irma_vai_voltar() -> bool:
	return irma_sumiu and not irma_bateu_na_porta and not passando_a_noite_fora and dia_de_hoje() >= DIA_DA_VOLTA and dia_de_hoje() <= DIA_FINAL

func a_irma_bate_na_porta() -> void:
	irma_bateu_na_porta = true
	prender_o_jogo(true)
	for rodada: Array in PEDIDOS_DA_VOLTA:
		Sons3D.tocar(self, Sons3D.batidas_na_porta(), 0.0)
		dialogo.caminho_do_retrato = RETRATO_DA_IRMA
		dialogo.respostas_ao_final = true
		na_volta = true
		dialogo.mostrar("Irmã", rodada)
		var abrir: bool = await respondeu_a_volta
		if abrir:
			await ela_entra()
			return
	na_volta = false
	dialogo.respostas_ao_final = false
	dialogo.mostrar("Irmã", DESPEDIDA_DA_VOLTA)
	await dialogo.terminou
	Sons3D.tocar(self, Sons3D.porta_forcada(), -8.0)
	prender_o_jogo(false)

func abrir_resposta_da_volta() -> void:
	escolha = MenuEscolha.new()
	escolha.name = "AVolta"
	escolha.sem_detalhes = true
	escolha.escolheu.connect(func(chave: String):
		if escolha != null:
			escolha.hide()
			escolha.queue_free()
			escolha = null
		dialogo.fechar()
		na_volta = false
		respondeu_a_volta.emit(chave == "abrir"))
	escolha.perguntar("", [
		{"chave": "abrir", "texto": "Abrir a porta."},
		{"chave": "", "texto": "Não abrir."},
	])
	dialogo.mostrar_respostas(escolha)

## Ela entra. O rosto já não é o dela.
func ela_entra() -> void:
	if ciclo.modo_deus:
		dica.avisar("Modo deus: a porta emperrou. Do outro lado, alguém riu e foi embora.")
		prender_o_jogo(false)
		return
	Sons3D.tocar(self, Sons3D.porta_abrir(), -4.0)
	dialogo.caminho_do_retrato = RETRATO_DA_QUE_VOLTOU
	dialogo.respostas_ao_final = false
	dialogo.mostrar("Irmã", ENTRADA_DA_VOLTA)
	await dialogo.terminou
	pego = true
	prender_o_jogo(true)
	gritar(GRITO_DA_QUE_VOLTOU, 0.0, 2.0)
	gritar(GRITO_DE_MORTE, 1.1)
	var camada := CanvasLayer.new()
	camada.layer = 5
	var clarao := ColorRect.new()
	clarao.color = Color(0.55, 0.0, 0.0, 0.85)
	clarao.set_anchors_preset(Control.PRESET_FULL_RECT)
	camada.add_child(clarao)
	add_child(camada)
	var tempo := create_tween()
	tempo.tween_property(clarao, "color", Color(0, 0, 0, 1), 0.9)
	await tempo.finished
	await fim_de_jogo("ELA VOLTOU")

## O que ela diz em casa, depois do resgate: data/irma_em_casa.json.
const IRMA_EM_CASA := "res://data/irma_em_casa.json"
var _falas_da_irma_em_casa: Dictionary = {}
## O dia em que ela já contou o que tinha; depois, só um comentário curto.
var irma_falou_no_dia := -1

func falas_da_irma_em_casa() -> Dictionary:
	if _falas_da_irma_em_casa.is_empty():
		var lido = JSON.parse_string(FileAccess.get_file_as_string(IRMA_EM_CASA))
		_falas_da_irma_em_casa = lido if lido is Dictionary else {}
	return _falas_da_irma_em_casa

## Conversar com ela na sala: a fala do dia uma vez; depois, uma frase no balão.
func conversar_com_a_irma() -> void:
	if abrigo != null or irma == null: return
	var dados := falas_da_irma_em_casa()
	var hoje := dia_de_hoje()
	if irma_falou_no_dia == hoje:
		var curtas: Array = dados.get("repetir", [])
		if not curtas.is_empty():
			irma.conversar(jogador.global_position, 3.5)
			balao.falar_no_mundo(irma, jogador, String(curtas[(hoje + randi()) % curtas.size()]), 3.5)
		return
	irma_falou_no_dia = hoje
	var falas: Array = dados.get("dias", {}).get(str(hoje), dados.get("outro_dia", []))
	falar_como_irma("Irmã", falas)

## O vizinho que nunca virou amigo, depois do ataque: atende diferente, fala
## das criaturas como quem fala de parente e, no fim, grita chamando todas
## elas. Os caçadores vêm atrás de quem bateu. Da segunda vez em diante a porta
## nem abre.
const FALAS_DO_MUDADO := [
	["Ah. É você. Entra não. Fica aí, que eles gostam de quem fica parado.", "De dia eles enxergam tudo. Eu também, agora. Tô vendo você inteiro, cheio de barulho por dentro.", "Você nunca bateu aqui pra saber se eu tava bem. Eles batem. Toda noite."],
	["Psiu. Escuta. Tá ouvindo? Eles cantam baixinho debaixo do asfalto.", "Eu entendi o que eles querem. Não é comer. É lembrar da gente.", "Fica mais um pouquinho. Eles tão quase chegando."],
	["O breu não acabou, vizinho. Ele só entrou nas casas que não trancaram a porta direito.", "Eu deixei a minha aberta. Eles foram tão educados.", "Você tá com medo? Eles sentem o medo antes do passo."],
]
const GRITO_DO_MUDADO := "AQUI! ELE TÁ AQUI FORA! VEM, VEM, VEM!"

func vizinho_mudado(morador: Vizinho3D) -> void:
	if morador.historia.marcas.has("mudou"):
		dica.avisar("Ninguém atende. Lá dentro, alguém ri baixinho.")
		return
	morador.historia.marcas.append("mudou")
	dica.esconder()
	balao.hide()
	prender_o_jogo(true)
	dialogo.caminho_do_retrato = morador.retrato()
	dialogo.respostas_ao_final = false
	var falas: Array = (FALAS_DO_MUDADO[abs(morador.chave.hash()) % FALAS_DO_MUDADO.size()] as Array).duplicate()
	falas.append(GRITO_DO_MUDADO)
	dialogo.mostrar(morador.nome, falas)
	await dialogo.terminou
	# O grito sai da porta dele e chama todo caçador da rua.
	var onde: Vector3 = morador.porta.global_position if morador.porta != null else jogador.global_position
	Sons3D.tocar_em(mundo, onde + Vector3.UP * 1.6, Sons3D.grito(), 90.0, 6.0)
	for bicho in get_tree().get_nodes_in_group("cacadores3d"):
		if bicho.has_method("ouvir"): bicho.ouvir(jogador.global_position)
		if bicho.has_method("cacar"): bicho.cacar(14.0)
	dica.avisar("%s está chamando aquelas coisas. Corre." % morador.nome)

## Os dois dentro do lote de casa: ela fica.
func conferir_chegada_da_irma() -> void:
	if irma == null or irma.seguindo != jogador: return
	# No dia 0 ela só está passando o dia junto; não é resgate.
	if dia_de_hoje() == 0 or passando_a_noite_fora: return
	# Conta quando ELA atravessa a porta de casa (está dentro das paredes, no
	# térreo). Daí ela vai andando até o lugar dela, na sala, e fica.
	var dentro := irma.global_position - CASA_LUGAR
	if absf(dentro.x) > 5.0 or absf(dentro.z) > 6.0 or dentro.y > 2.0: return
	receber_a_irma()
	if _lugar_da_irma == null:
		_lugar_da_irma = Node3D.new()
		_lugar_da_irma.name = "LugarDaIrma"
		mundo.add_child(_lugar_da_irma)
	_lugar_da_irma.global_position = lugar_da_irma_em_casa()
	irma.seguir(_lugar_da_irma, null)
	irma_indo_pro_lugar = true
	entrega_do_radio_pendente = true

## A irmã indo para o lugar dela, e o rádio entregue quando ele estiver perto
## e livre.
var _lugar_da_irma: Node3D
var irma_indo_pro_lugar := false
var entrega_do_radio_pendente := false

func cuidar_da_irma_em_casa() -> void:
	if irma == null: return
	if irma_indo_pro_lugar and irma.global_position.distance_to(_lugar_da_irma.global_position) < Pessoa3D.COLADA + 0.3:
		irma_indo_pro_lugar = false
		irma.seguir(null)
		var rumo := jogador.global_position - irma.global_position
		irma.rotation.y = atan2(rumo.x, rumo.z)
	if not entrega_do_radio_pendente: return
	if dialogo.visible or escolha != null or tv != null or menu != null or mochila != null or celular != null or dormindo: return
	if irma.global_position.distance_to(jogador.global_position) > 6.0: return
	entrega_do_radio_pendente = false
	falar_como_irma("Irmã", falas_da_irma_em_casa().get("chegada", []))

## A irmã passa a morar com ele: para onde está (sem pular para o sofá; no dia
## seguinte ela amanhece na sala) e traz o rádio a pilha.
func receber_a_irma() -> void:
	ciclo.irma_em_casa = true
	ciclo.tem_radio = true
	mensagens.irma_em_casa = true
	ciclo.mudou.emit()

## Um ponto na calçada, logo depois do portão da casa: por onde quem sai vai.
func saida_de_casa() -> Vector3:
	for i in casa.portas.size():
		if String(casa.portas[i].nome) == "portao":
			return casa.onde_fica_a_porta(i) + Vector3(0.0, -1.0, 2.5)
	return Vector3(CASA_LUGAR.x, 0.1, CALCADA_PERTO)

## Ouvir o rádio: o da sala precisa de luz; o da irmã é a pilha.
func ouvir_o_radio(a_pilha: bool) -> void:
	if abrigo != null: return
	if not a_pilha and not ciclo.tem_energia_da_rede():
		dica.avisar("Sem energia. O rádio da sala virou peça de decoração." + (" Ainda bem que o da sua irmã é a pilha." if ciclo.tem_radio else ""))
		return
	var linhas: Array = []
	for fala: Array in noticias.radio_do_dia(dia_de_hoje()):
		linhas.append("%s — %s" % [fala[0], fala[1]] if not String(fala[0]).is_empty() else String(fala[1]))
	if linhas.is_empty(): linhas = ["Só chiado. Ninguém transmitindo agora."]
	dica.esconder()
	balao.hide()
	prender_o_jogo(true)
	dialogo.caminho_do_retrato = ""
	dialogo.respostas_ao_final = false
	dialogo.mostrar("Rádio a pilha" if a_pilha else "Rádio da sala", linhas)
	# O chiado de fundo enquanto a notícia passa; some quando a fala acaba.
	var chiado := AudioStreamPlayer.new()
	var estatica := AmbienteSonoro.carregar("radio_chiado.ogg")
	if "loop" in estatica: estatica.set("loop", true)
	chiado.stream = estatica
	chiado.volume_db = -13.0
	add_child(chiado)
	chiado.play()
	dialogo.terminou.connect(chiado.queue_free, CONNECT_ONE_SHOT)

## A torneira: encher rápido ou ferver antes. Ninguém diz se a água está boa —
## quem diz é o noticiário, e nem toda fonte acerta.
func abrir_a_torneira() -> void:
	if abrigo != null: return
	if not ciclo.tem_agua_da_rede():
		dica.avisar("Abastecimento cortado. A torneira só solta um assobio — e a conta, essa, vai chegar.")
		return
	if ciclo.garrafas_cheias_hoje:
		dica.avisar("As garrafas já estão cheias. Mais que isso só se você beber direto do cano.")
		return
	na_torneira = true
	dica.esconder()
	balao.hide()
	prender_o_jogo(true)
	dialogo.caminho_do_retrato = ""
	dialogo.respostas_ao_final = true
	var frase := "A água sai normal." if dia_de_hoje() < Ciclo3D.DIA_DA_CONTAMINACAO else "A água sai fraca, meio turva. Pode ser só o encanamento."
	dialogo.mostrar("Torneira · %s" % ciclo.texto_da_hora(), [frase])

func abrir_menu_da_torneira() -> void:
	escolha = MenuEscolha.new()
	escolha.name = "Torneira"
	escolha.escolheu.connect(responder_na_torneira)
	escolha.perguntar("", [
		{"chave": "encher", "texto": "Encher as garrafas", "abaixo": "1h · +1 suprimento"},
		{"chave": "ferver", "texto": "Ferver e encher", "abaixo": "2h · +1 suprimento · se a água estiver ruim, ferver evita passar mal"},
		{"chave": "", "texto": "Deixar", "abaixo": ""},
	])
	dialogo.mostrar_respostas(escolha)

func responder_na_torneira(chave: String) -> void:
	if escolha != null:
		escolha.hide()
		escolha.queue_free()
		escolha = null
	encerrar_conversa()
	if not chave.is_empty() and ciclo.guardar_agua(chave == "ferver"): evento.emit("agua")

## Bater na porta de um vizinho: ele atende com o retrato e a fala do dia.
func bater_na_porta(qual: int) -> void:
	if abrigo != null: return
	if qual < 0 or qual >= vizinhos.size(): return
	var morador: Vizinho3D = vizinhos[qual]
	# Depois do ataque, quem nunca virou amigo não é mais o mesmo.
	if dia_de_hoje() > DIA_DO_ATAQUE and not morador.pode_passar_numero():
		vizinho_mudado(morador)
		return
	na_porta = qual
	dica.esconder()
	balao.hide()
	prender_o_jogo(true)
	dialogo.caminho_do_retrato = morador.retrato()
	if morador.conversas == 0: morador.adiado_ate = ciclo.dia + 1
	morador.iniciar(maxi(1, ciclo.dia), noticias.aviso_de_amanha(ciclo.dia))
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
	if passando_a_noite_fora: return
	if na_volta:
		abrir_resposta_da_volta()
		return
	if na_embarque:
		abrir_resposta_do_embarque()
		return
	if na_torneira:
		abrir_menu_da_torneira()
		return
	if na_irma:
		abrir_resposta_da_irma()
		return
	if na_sofa:
		abrir_o_sofa()
		return
	if not na_loja.is_empty():
		abrir_o_balcao(aviso)
		return
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
			"abaixo": custo_do_pedido(String(custo.get("item", "")), int(custo.get("quanto", 0)), int(custo.get("horas", custo.get("acoes", 0)))) if not custo.is_empty() else String(opcao.get("abaixo", ""))})
	if morador.pode_abrigar():
		lista.append({"chave": "__abrigo", "texto": morador.convite_de_abrigo(),
			"abaixo": "Passar a noite aqui: a noite consome %d suprimento%s; faltas enfraquecem." % [ciclo.consumo_da_noite(), "" if ciclo.consumo_da_noite() == 1 else "s"]})
	escolha.sem_detalhes = true
	escolha.perguntar(aviso, lista)
	dialogo.mostrar_respostas(escolha)

func encerrar_conversa() -> void:
	if escolha != null:
		escolha.hide()
		escolha.queue_free()
		escolha = null
	na_porta = -1
	na_loja = ""
	na_sofa = false
	na_torneira = false
	na_irma = false
	na_embarque = false
	dialogo.fechar()
	prender_o_jogo(false)

## O que se lê embaixo da opção de ajudar.
func custo_do_pedido(item: String, quanto: int, horas := 1) -> String:
	var tempo := "%dh" % horas
	match item:
		"suprimentos", "comida", "agua", "energia": return "%s · %d suprimento%s" % [tempo, quanto, "" if quanto == 1 else "s"]
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
	if resposta == "__abrigo":
		# A amizade pode mudar enquanto a opção está na tela: confirme de novo.
		if not morador.pode_abrigar():
			sair_da_porta("Só um amigo que você ajudou pode oferecer abrigo.")
			return
		entrar_no_abrigo(na_porta)
		return
	var valida := false
	for opcao: Dictionary in morador.opcoes():
		if String(opcao.id) != resposta: continue
		valida = true
		if not ciclo.pagar_escolha(opcao.get("custo", {})):
			sair_da_porta("Sem recursos ou sem tempo. Escolha outra resposta.")
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

## Pedir abrigo a um amigo: ele confirma, a noite passa na casa dele e o
## jogador acorda na mesma porta, no dia seguinte. Sem menu de espera. Se a
## irmã vinha junto, ela entra também: entrega o rádio lá dentro e, dali em
## diante, mora na casa dele.
var passando_a_noite_fora := false

func entrar_no_abrigo(qual: int) -> void:
	if passando_a_noite_fora or abrigo != null or qual < 0 or qual >= vizinhos.size(): return
	var morador: Vizinho3D = vizinhos[qual]
	if not morador.pode_abrigar(): return
	var com_a_irma := irma != null and irma.seguindo == jogador
	var porta := jogador.global_transform
	passando_a_noite_fora = true
	abrigado_em = qual
	encerrar_conversa()
	prender_o_jogo(true)
	dica.esconder()
	balao.hide()
	dialogo.caminho_do_retrato = morador.retrato()
	dialogo.respostas_ao_final = false
	var falas: Array = [morador.confirmacao_de_abrigo()]
	if com_a_irma: falas.append("A moça também? Entra, entra. Cabe todo mundo, desde que ninguém ronque.")
	dialogo.mostrar(morador.nome, falas)
	await dialogo.terminou
	if com_a_irma:
		receber_a_irma()
		posicionar_a_irma()
		falar_como_irma("Irmã", falas_da_irma_em_casa().get("chegada", []))
		await dialogo.terminou
	prender_o_jogo(true)
	dormindo = true
	evento.emit("dormiu")
	var resumo := ciclo.dormir([])
	dica.calar_recado()
	if await conferir_o_fim_da_noite():
		passando_a_noite_fora = false
		return
	await escurecer("Dia %d · %s" % [ciclo.dia, ciclo.texto_da_hora()], "Você passou a noite na casa de %s.\n%s" % [morador.nome, resumo])
	jogador.global_transform = porta
	jogador.velocity = Vector3.ZERO
	abrigado_em = -1
	passando_a_noite_fora = false
	dormindo = false
	prender_o_jogo(false)

func sair_do_abrigo() -> void:
	if abrigo == null: return
	abrigo.hide()
	abrigo.queue_free()
	abrigo = null
	abrigado_em = -1
	mundo.process_mode = _processo_antes_do_abrigo
	mundo.visible = _mundo_visivel_antes_do_abrigo
	jogador.global_transform = _volta_do_abrigo
	jogador.velocity = Vector3.ZERO
	camera.make_current()
	prender_o_jogo(false)

## A TV da sala: os programas do artefato com a notícia do dia por dentro, e o
## jogador trocando de canal. Ver TV cansa, então quem cobra é o ciclo.
func ligar_a_tv() -> void:
	if tv != null: return
	if not ciclo.tem_energia_da_rede():
		dica.avisar("Sem energia. A TV ia dizer que estava tudo sob controle mesmo.")
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
	evento.emit("tv")

func desligar_a_tv() -> void:
	if tv == null: return
	Sons3D.tocar_trecho(self, AmbienteSonoro.carregar("tv_desligar.ogg"), 0.0, 0.8, -2.0)
	tv.queue_free()
	tv = null
	prender_o_jogo(false)

# ------------------------------------------------------- o dia e a noite

## Cada hora gasta empurra o relógio da manhã para a noite. Aqui isso vira imagem:
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
	# Postes e lâmpadas acendem já no fim de tarde, antes de escurecer de vez.
	var luzes := ciclo.indice_do_periodo() >= 2 and ciclo.tem_energia_da_rede()
	if casa != null: casa.acender_luzes(luzes)
	if dia_de_hoje() > DIA_DO_ATAQUE: ajustar_cacadores()
	for poste: OmniLight3D in postes:
		poste.visible = luzes
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
	# De noite o comércio fecha; cada loja de compras baixa a porta de vez no
	# seu dia (data/lojas3d.json), o resto do comércio no breu.
	ajustar_comercio(noite)
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
		quem.aparecer(na_rua <= quantos)

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
	if abrigo != null: return
	if dormindo or expediente != null: return
	# No dia 0, deitar antes da hora: a irmã fala primeiro e vai embora.
	if tutorial != null and tutorial.segurar_o_sono(): return
	dormindo = true
	evento.emit("dormiu")
	dica.esconder()
	prender_o_jogo(true)
	var resumo := ciclo.dormir(casa.portas_abertas_para_a_rua())
	# O resumo da noite vai na tela preta; o recado solto sai da frente.
	dica.recado.modulate.a = 0.0
	if await conferir_o_fim_da_noite(): return
	await escurecer("Dia %d · %s" % [ciclo.dia, ciclo.texto_da_hora()], resumo)
	dormindo = false
	if a_irma_vai_voltar():
		await a_irma_bate_na_porta()
		return
	prender_o_jogo(false)


# ------------------------------------------------------------------ finais

## Último dia da história: quem passa a noite dele vivo, em casa, chega ao fim.
const DIA_FINAL := 10
## A barricada dos sobreviventes: aparece no dia 9, no fim da rua, e o portão
## abre pela última vez no dia 10, até escurecer.
const DIA_DA_BARRICADA := 9
const BARRICADA_X := 60.6

## O que a tela de final escreve embaixo: como a partida terminou.
func resumo_da_partida() -> String:
	var irma_txt := "com você" if ciclo.irma_em_casa else ("ficou para trás" if irma_sumiu or dia_de_hoje() >= Ciclo3D.DIA_DO_BREU else "na casa dela")
	return "Dia %d · %d suprimento%s · R$ %d · Irmã: %s" % [dia_de_hoje(), ciclo.suprimentos, "" if ciclo.suprimentos == 1 else "s", ciclo.dinheiro, irma_txt]

func texto_do_pego() -> String:
	return "Ele não te viu chegando. Te ouviu.\nNo jornal de amanhã, se tiver jornal, vão dizer que foi caso isolado — e que a culpa é sua por estar na rua."

## Atalho de teste (modo deus): as quatro animações de finais/.
## F1 morte (Só mais um), F2 sobrevivência (Até quando?), F3 abrigo, F4 confiar.
func ver_um_final(qual: int) -> void:
	if not ciclo.modo_deus:
		dica.avisar("Atalho de teste: liga o modo deus (F10) antes. Final não se pede, se merece.")
		return
	match qual:
		0: await fim_de_jogo("PEGO NO ESCURO")
		1: await fim_de_jogo("EM CASA")
		2: await fim_de_jogo("O ABRIGO")
		3: await fim_de_jogo("SOBREVIVENTES")

func texto_do_ultimo_dia() -> String:
	var texto := "A despensa acabou antes da coragem de sair. Você dormiu esperando o governo resolver. O governo também dormiu."
	if ciclo.irma_em_casa: texto += "\nSua irmã segurou sua mão até o fim. Ela também estava com fome."
	return texto

func texto_em_casa() -> String:
	var texto := ""
	if ciclo.irma_em_casa:
		texto = "Vocês dois trancaram o portão, contaram as garrafas e ficaram longe da janela. No rádio a pilha, a voz da barricada contou até três e desistiu."
	else:
		texto = "Você ficou. Trancou o portão, contou as garrafas, aprendeu a andar sem fazer barulho dentro da própria casa."
	texto += "\nNos dias seguintes, as criaturas foram rareando na rua. Ninguém sabe dizer se isso é bom."
	if ciclo.suprimentos < ciclo.consumo_da_noite() * 3:
		texto += "\nA despensa, essa, já avisou que não vai durar muito."
	return texto

func texto_dos_sobreviventes() -> String:
	var texto := "O portão de lata abriu um palmo, o suficiente. Lá dentro: umas vinte pessoas, um gerador que tosse e uma panela grande no fogo de lenha. Ninguém perguntou seu nome antes de te dar água."
	if ciclo.irma_em_casa: texto += "\nVocê voltou correndo para buscar sua irmã. Ela entrou abraçada ao rádio, como quem carrega um troféu."
	texto += "\nOs portões fecharam ao anoitecer. Se aqui é seguro, ninguém garante. Mas, pela primeira vez em dias, alguém está acordado vigiando por você."
	return texto

## Qual cena animada de finais/ (do pacote finais_godot) toca para cada final
## do jogo. Os textos das cenas ficam em data/finais.json.
const CENA_DO_FINAL := {
	"PEGO NO ESCURO": "res://finais/final_morte.tscn",
	"O ÚLTIMO DIA": "res://finais/final_morte.tscn",
	"EM CASA": "res://finais/final_sobrevivencia.tscn",
	"SOBREVIVENTES": "res://finais/final_confiar.tscn",
	"O ABRIGO": "res://finais/final_abrigo.tscn",
	"MORTO NO BECO": "res://finais/final_morte.tscn",
	"ELA VOLTOU": "res://finais/final_morte.tscn",
}

## A partida acabou: troca para a cena animada do final, que volta ao menu
## quando o jogador confirma na última tela.
func fim_de_jogo(titulo: String, _texto := "") -> void:
	dica.esconder()
	prender_o_jogo(true)
	ultimo_final = titulo
	if not voltar_ao_menu_no_fim: return
	# Na tela preta, o último grito termina antes de a cena do final começar.
	var falta := (grito_ate_ms - Time.get_ticks_msec()) / 1000.0
	if falta > 0.0 and is_inside_tree(): await get_tree().create_timer(falta).timeout
	if not is_inside_tree() or get_tree().current_scene != self: return
	get_tree().change_scene_to_file(String(CENA_DO_FINAL.get(titulo, "res://finais/final_morte.tscn")))

## Gritos gravados das mortes (sons/CREDITOS.md): o do morador e o da irmã que
## voltou.
const GRITO_DE_MORTE := "res://sons/grito_protagonista.ogg"
const GRITO_DA_QUE_VOLTOU := "res://sons/grito_irma.ogg"
## Até quando o último grito ainda está soando (Time.get_ticks_msec).
var grito_ate_ms := 0

## Toca um grito depois de `atraso` segundos e marca até quando ele soa.
func gritar(caminho: String, atraso := 0.0, volume := 0.0) -> void:
	var som := AudioStreamPlayer.new()
	som.stream = load(caminho)
	som.volume_db = volume
	add_child(som)
	som.finished.connect(som.queue_free)
	grito_ate_ms = maxi(grito_ate_ms, Time.get_ticks_msec() + int((atraso + som.stream.get_length()) * 1000.0))
	if atraso <= 0.0: som.play()
	else: get_tree().create_timer(atraso).timeout.connect(som.play)

## Depois de uma noite: morreu, chegou ao fim da história, ou segue.
## Devolve verdadeiro quando a partida acabou.
func conferir_o_fim_da_noite() -> bool:
	if ciclo.morto:
		await fim_de_jogo("O ÚLTIMO DIA", texto_do_ultimo_dia())
		return true
	if ciclo.dia > DIA_FINAL:
		await fim_de_jogo("EM CASA", texto_em_casa())
		return true
	return false

## A barricada de lata dos sobreviventes, de uma calçada à outra no fim da rua.
## Fica escondida até o dia 9.
func construir_barricada() -> void:
	barricada = Node3D.new()
	barricada.name = "Barricada"
	mundo.add_child(barricada)
	var malha := MalhaLowPoly.new()
	var sorte := RandomNumberGenerator.new()
	sorte.seed = 9
	var z := RUA_EIXO_Z - 9.0
	while z < RUA_EIXO_Z + 9.0:
		var largura := sorte.randf_range(0.9, 1.4)
		var altura := sorte.randf_range(2.2, 2.9)
		var porta := absf(z + largura / 2.0 - RUA_EIXO_Z) < 0.8
		var cor := Color("9a7458").lerp(Color("b4b8b2"), sorte.randf()) if not porta else Color("6a5444")
		malha.caixa(Vector3(BARRICADA_X + sorte.randf_range(-0.12, 0.12), 0.0, z), Vector3(0.12, altura if not porta else 2.4, largura + 0.05), cor, cor.darkened(0.15), MalhaLowPoly.Peca.METAL, MalhaLowPoly.Peca.METAL)
		z += largura
	var visual := MeshInstance3D.new()
	visual.mesh = malha.gerar()
	visual.material_override = material_ps1
	barricada.add_child(visual)
	var corpo := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(0.4, 3.0, 18.0)
	forma.shape = caixa
	forma.position = Vector3(BARRICADA_X, 1.5, RUA_EIXO_Z)
	corpo.add_child(forma)
	barricada.add_child(corpo)
	portao_da_barricada = StaticBody3D.new()
	portao_da_barricada.name = "PortaoDaBarricada"
	portao_da_barricada.position = Vector3(BARRICADA_X - 0.3, 0.0, RUA_EIXO_Z)
	portao_da_barricada.set_meta("refugio", true)
	portao_da_barricada.collision_layer = 16
	portao_da_barricada.collision_mask = 0
	var marca := CollisionShape3D.new()
	var vao := BoxShape3D.new()
	vao.size = Vector3(0.3, 2.4, 2.0)
	marca.shape = vao
	marca.position.y = 1.2
	portao_da_barricada.add_child(marca)
	barricada.add_child(portao_da_barricada)
	ajustar_barricada()

func ajustar_barricada() -> void:
	if barricada == null: return
	var de_pe := dia_de_hoje() >= DIA_DA_BARRICADA
	barricada.visible = de_pe
	barricada.process_mode = Node.PROCESS_MODE_INHERIT if de_pe else Node.PROCESS_MODE_DISABLED

func dica_da_barricada() -> String:
	if dia_de_hoje() < DIA_FINAL: return "Barricada de lata · tem gente do outro lado"
	if not ciclo.e_noite(): return "Portão da barricada · bater"
	return "Portão da barricada · fechado"

func bater_na_barricada() -> void:
	if dia_de_hoje() < DIA_FINAL:
		dica.avisar("Uma voz do outro lado: \"Amanhã, antes de escurecer. Hoje não abre nem pro Papa.\"")
		return
	if ciclo.e_noite():
		dica.avisar("Ninguém responde. Do outro lado, alguém contou até três e desistiu.")
		return
	await fim_de_jogo("SOBREVIVENTES", texto_dos_sobreviventes())

# ------------------------------------------------------------------ o bote

## Um caçador alcançou o jogador. No modo deus ele só cheira e vai embora.
func ser_pego(bicho: Node) -> void:
	if pego or ciclo.morto: return
	if ciclo.modo_deus:
		dica.avisar("Modo deus: o bicho te cheirou, fez careta e foi embora.")
		if bicho.has_method("soltar"): bicho.soltar()
		return
	pego = true
	dica.esconder()
	prender_o_jogo(true)
	var som := AudioStreamPlayer.new()
	som.stream = Sons3D.bote()
	som.volume_db = 4.0
	add_child(som)
	som.play()
	gritar(GRITO_DE_MORTE, 0.12)
	# Um clarão vermelho e o escuro: sem mostrar demais.
	var camada := CanvasLayer.new()
	camada.layer = 5
	var clarao := ColorRect.new()
	clarao.color = Color(0.55, 0.0, 0.0, 0.85)
	clarao.set_anchors_preset(Control.PRESET_FULL_RECT)
	camada.add_child(clarao)
	add_child(camada)
	var tempo := create_tween()
	tempo.tween_property(clarao, "color", Color(0, 0, 0, 1), 0.7)
	await tempo.finished
	await fim_de_jogo("PEGO NO ESCURO", texto_do_pego())
	camada.queue_free()

## O Observador gritou: todo caçador da rua sabe onde o jogador está.
func soar_o_alarme(_onde: Vector3) -> void:
	for bicho in get_tree().get_nodes_in_group("cacadores3d"):
		if bicho.has_method("cacar"): bicho.cacar(12.0)
	dica.avisar("Um grito no fim da rua. Agora todo mundo sabe onde você está — e não é a vizinhança.")

# ------------------------------------------------------------------ embarque

## O Sargento Holanda, "o Juiz", responsável pela área: fica na calçada perto
## do ponto em alguns dias e, a cada visita, conta um pouco mais do que vê (e
## do que sonha). No dia do ataque é ele quem oferece a vaga no caminhão do
## Exército, com um caçador morto aos pés como prova de segurança. Subir no
## caminhão é o final O ABRIGO — a armadilha que o governo chama de evacuação.
const CAMINHAO_DO_EMBARQUE := "res://modelos/veiculos/caminhao.tscn"
const PM := "res://modelos/pm/pm.tscn"
const CACADOR_MORTO := "res://modelos/cacador/cacador_morto.glb"
const RETRATO_DO_SARGENTO := "res://ui/retratos/lojas/sargento.webp"
const NOME_DO_SARGENTO := "Sargento Holanda"
const POSTO_X := -5.0
## O que ele diz em cada dia em que aparece. No dia do ataque, a vaga.
const FALAS_DO_SARGENTO := {
	2: [
		"Bom dia, cidadão. Sargento Holanda, responsável por esta área. A tropa me chama de Juiz. Não pergunta por quê.",
		"Pergunta de rotina: você viu alguém alto demais por aí? Magro, comprido, com um olho que brilha no escuro.",
		"Ontem à noite dei voz de prisão a um meliante desses. Não obedeceu. Dei três tiros e acertei os três.",
		"Ele correu de um jeito que joelho nenhum dobra, gritando feito chaleira. Nada neste bairro existe sem a minha autorização. Ele não pediu.",
	],
	4: [
		"Cidadão. Dormiu bem? Eu não durmo mais. Eu sonho, que é diferente.",
		"Toda noite a mesma coisa: uma luz descendo devagar sobre a cidade e uma voz que sabe o meu nome sem eu ter falado.",
		"Diz que vem coisa grande. Que o povo vai ser separado entre quem vai e quem fica.",
		"Não estou pedindo opinião. Estou te avisando antes da imprensa, que é o que a imprensa deveria fazer.",
	],
	5: [
		"Cortaram a água, eu sei. Deixa o povo reclamar, reclamar hidrata a alma.",
		"Mas ouve de quem sabe: o governo não abandonou ninguém. Tem saída, tem plano, tem lista.",
		"Quando chegar a hora, passa um caminhão. Quem está na lista sobe. Quem não está, a gente coloca.",
		"Guarda essa cara de dúvida. Dúvida é luxo de quem ainda tem luz em casa. Amanhã você vê se tem.",
	],
	7: [
		"Olha aí no chão. Cinco tiros e uma coronhada. Eu disse que nada aqui existe sem a minha autorização.",
		"Embarque pro abrigo, ordem do Presidente: hoje vai todo mundo, cadastrado ou não.",
		"Lá tem luz, água e comida quente. Não precisa levar nada. Só o nome. O resto a gente providencia.",
	],
}
## No primeiro encontro ele espera resposta sobre o "meliante".
const RESPOSTAS_AO_SARGENTO := {
	"vi": "Viu. Dá pra ver na sua cara. Guarda isso pra você: testemunha é coisa rara num fim de mundo, e coisa rara some.",
	"nao": "Vai ver. Todo mundo vê, uma hora. A diferença é quem vê primeiro, e quem vê por último.",
}

var sargento: Node3D
var radio_da_tropa: AudioStreamPlayer3D
## Dia em que ele já falou tudo; depois disso, só o olhar.
var sargento_falou_no_dia := 0

func construir_posto_de_embarque() -> void:
	# O sargento: o PM do pacote, com o retrato dele na conversa.
	sargento = Node3D.new()
	sargento.name = "Sargento"
	mundo.add_child(sargento)
	var onde := Vector3(POSTO_X + 1.6, 0.14, CALCADA_PERTO + 0.8)
	por_um_pm(sargento, onde)
	pm_do_embarque = StaticBody3D.new()
	pm_do_embarque.name = "PMDoEmbarque"
	pm_do_embarque.set_meta("embarque", true)
	pm_do_embarque.collision_layer = 16
	pm_do_embarque.collision_mask = 0
	var marca := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = Vector3(1.0, 2.0, 1.0)
	marca.shape = volume
	marca.position = onde + Vector3(0, 1.0, 0)
	pm_do_embarque.add_child(marca)
	sargento.add_child(pm_do_embarque)

	# O posto do dia do ataque: caminhão, outro PM e o caçador abatido.
	posto_de_embarque = Node3D.new()
	posto_de_embarque.name = "PostoDeEmbarque"
	mundo.add_child(posto_de_embarque)
	var caminhao: Node3D = (load(CAMINHAO_DO_EMBARQUE) as PackedScene).instantiate()
	caminhao.position = Vector3(POSTO_X - 3.0, RUA_ALTURA, FAIXA_DE_CA)
	caminhao.rotation.y = -PI / 2.0
	posto_de_embarque.add_child(caminhao)
	RuaModelo.aplicar_ps1(caminhao, RESOLUCAO)
	# O caminhão parado é parede: ninguém atravessa a carroceria.
	var bloqueio := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(7.2, 3.0, 2.6)
	forma.shape = caixa
	forma.position = Vector3(POSTO_X - 3.0, 1.5, FAIXA_DE_CA)
	bloqueio.add_child(forma)
	posto_de_embarque.add_child(bloqueio)
	por_um_pm(posto_de_embarque, Vector3(POSTO_X - 2.6, 0.14, CALCADA_PERTO + 0.8))
	# O rádio da tropa, chiando na boleia do caminhão.
	radio_da_tropa = AudioStreamPlayer3D.new()
	radio_da_tropa.name = "RadioDaTropa"
	var transmissao := AmbienteSonoro.carregar("radio_militar.ogg")
	if "loop" in transmissao: transmissao.set("loop", true)
	radio_da_tropa.stream = transmissao
	radio_da_tropa.volume_db = 6.5
	radio_da_tropa.unit_size = 3.0
	radio_da_tropa.max_distance = 26.0
	radio_da_tropa.position = Vector3(POSTO_X - 1.2, 1.6, FAIXA_DE_CA)
	posto_de_embarque.add_child(radio_da_tropa)
	por_o_cacador_morto(Vector3(POSTO_X + 3.6, 0.14, CALCADA_PERTO + 0.3))
	ajustar_posto_de_embarque()

## Um PM parado na calçada, de frente para as casas, que não se atravessa.
func por_um_pm(pai: Node3D, onde: Vector3) -> void:
	var pm: Node3D = (load(PM) as PackedScene).instantiate()
	pm.set("resolucao", RESOLUCAO)
	pm.position = onde
	pm.rotation.y = PI
	pai.add_child(pm)
	var corpo := StaticBody3D.new()
	var capsula := CollisionShape3D.new()
	var forma_pm := CapsuleShape3D.new()
	forma_pm.radius = 0.3
	forma_pm.height = 1.8
	capsula.shape = forma_pm
	capsula.position = onde + Vector3(0, 0.9, 0)
	corpo.add_child(capsula)
	pai.add_child(corpo)

## O troféu do sargento: um caçador tombado de lado, com as patas caídas no
## chão, numa poça escura. Malha parada (modelos/cacador_morto.glb, posada no
## Blender a partir do cacador.glb), sem o cérebro de caçador.
func por_o_cacador_morto(onde: Vector3) -> void:
	var bicho: Node3D = (load(CACADOR_MORTO) as PackedScene).instantiate()
	bicho.name = "CacadorMorto"
	bicho.position = onde
	bicho.rotation.y = PI * 0.5
	posto_de_embarque.add_child(bicho)
	RuaModelo.aplicar_ps1(bicho, RESOLUCAO)
	var poca := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 1.1
	disco.bottom_radius = 1.1
	disco.height = 0.01
	disco.radial_segments = 9
	poca.mesh = disco
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = Color(0.09, 0.07, 0.04)
	tinta.roughness = 0.2
	poca.material_override = RuaModelo.converter(tinta, RESOLUCAO)
	poca.position = onde + Vector3(0, 0.012, 0)
	poca.scale = Vector3(1.3, 1.0, 0.8)
	posto_de_embarque.add_child(poca)

## O sargento aparece nos dias que têm fala; o posto, só no dia do ataque.
func ajustar_posto_de_embarque() -> void:
	if posto_de_embarque == null: return
	var hoje := dia_de_hoje()
	for parte: Node3D in [sargento, posto_de_embarque]:
		var esta := (FALAS_DO_SARGENTO.has(hoje) or tem_devolucao()) if parte == sargento else hoje == DIA_DO_ATAQUE
		parte.visible = esta
		parte.process_mode = Node.PROCESS_MODE_INHERIT if esta else Node.PROCESS_MODE_DISABLED
	if radio_da_tropa != null:
		if posto_de_embarque.visible and not radio_da_tropa.playing: radio_da_tropa.play()
		elif not posto_de_embarque.visible: radio_da_tropa.stop()

func dica_do_embarque() -> String:
	if dia_de_hoje() != DIA_DO_ATAQUE: return "%s · responsável pela área" % NOME_DO_SARGENTO
	if ciclo.e_noite(): return "Caminhão do Exército · lotado"
	return "%s · embarque para o abrigo" % NOME_DO_SARGENTO

func falar_com_o_pm() -> void:
	if abrigo != null: return
	var hoje := dia_de_hoje()
	if hoje == DIA_DO_ATAQUE and ciclo.e_noite():
		dica.avisar("O caminhão já está lotado. O próximo, dizem, passa amanhã. Ninguém diz amanhã do quê.")
		return
	if hoje != DIA_DO_ATAQUE and sargento_falou_no_dia == hoje:
		dica.avisar("“Já falei o que tinha pra falar, cidadão. Circulando.”")
		return
	sargento_falou_no_dia = hoje
	var devolucao := devolver_o_roubado()
	na_embarque = hoje == DIA_DO_ATAQUE or hoje == 2 or pode_denunciar()
	dica.esconder()
	balao.hide()
	prender_o_jogo(true)
	dialogo.caminho_do_retrato = RETRATO_DO_SARGENTO
	dialogo.respostas_ao_final = na_embarque
	var falas: Array = devolucao + (FALAS_DO_SARGENTO.get(hoje, []) as Array)
	if hoje == DIA_DO_ATAQUE and ciclo.irma_em_casa:
		falas.append("A moça que mora com você também? Traz. Quanto mais nome na lista, melhor.")
	dialogo.mostrar(NOME_DO_SARGENTO, falas)

func abrir_resposta_do_embarque() -> void:
	escolha = MenuEscolha.new()
	escolha.name = "Embarque"
	escolha.escolheu.connect(responder_ao_embarque)
	var lista: Array
	if dia_de_hoje() == DIA_DO_ATAQUE:
		lista = [
			{"chave": "embarcar", "texto": "Subir no caminhão.", "abaixo": "Deixar o bairro para trás. Não tem volta."},
			{"chave": "", "texto": "Vou pensar.", "abaixo": "O caminhão sai antes de escurecer."},
		]
	elif dia_de_hoje() == 2:
		lista = [
			{"chave": "vi", "texto": "Vi uma coisa assim, sim.", "abaixo": ""},
			{"chave": "nao", "texto": "Não vi nada, não senhor.", "abaixo": ""},
		]
	else:
		lista = [{"chave": "", "texto": "Tá bom, sargento.", "abaixo": ""}]
	if pode_denunciar():
		lista.append({"chave": "denunciar", "texto": "Denunciar o cara do beco.", "abaixo": "Ele te roubou. O sargento resolve do jeito dele."})
	escolha.sem_detalhes = true
	escolha.perguntar("", lista)
	dialogo.mostrar_respostas(escolha)

## Dá para denunciar o bandido quem já foi roubado por ele e ele ainda está lá.
## No dia do ataque o sargento só pensa no caminhão.
func pode_denunciar() -> bool:
	return bandido_roubou_no_dia > 0 and not bandido_morto and denuncia_no_dia == 0 \
		and bandido != null and bandido.visible and dia_de_hoje() != DIA_DO_ATAQUE

## Denunciou ontem (ou antes) e ainda não pegou de volta.
func tem_devolucao() -> bool:
	return denuncia_no_dia > 0 and dia_de_hoje() > denuncia_no_dia and not devolvido

## Na primeira conversa depois da denúncia: o caso está resolvido e o que foi
## levado volta. Devolve as falas.
func devolver_o_roubado() -> Array:
	if not tem_devolucao(): return []
	devolvido = true
	var quanto := suprimentos_roubados
	ciclo.suprimentos += quanto
	suprimentos_roubados = 0
	ciclo.mudou.emit()
	return [
		"Ô, cidadão. Aquele teu problema do beco? Resolvido. Não vai mais incomodar ninguém.",
		"Toma, o que ele te tirou. Conferi, tá tudo aí." if quanto > 0 else "Ele não tinha nada teu. Tinha um monte de coisa dos outros.",
		"Viu como funciona? Nada nesta rua existe sem a minha autorização.",
	]

func responder_ao_embarque(chave: String) -> void:
	if escolha != null:
		escolha.hide()
		escolha.queue_free()
		escolha = null
	encerrar_conversa()
	if chave == "embarcar":
		await fim_de_jogo("O ABRIGO")
		return
	if chave == "denunciar":
		denunciar_o_bandido()
		return
	if RESPOSTAS_AO_SARGENTO.has(chave):
		prender_o_jogo(true)
		dialogo.caminho_do_retrato = RETRATO_DO_SARGENTO
		dialogo.respostas_ao_final = false
		dialogo.mostrar(NOME_DO_SARGENTO, [RESPOSTAS_AO_SARGENTO[chave]])

# ------------------------------------------------------------------ bandido do beco

## Um cara de jaqueta e corrente escondido no fundo dos becos, desde o primeiro
## dia. Quem acha ele paga pedágio (1 suprimento) e é mandado vazar; quem
## insiste no mesmo dia leva tiro. Denunciado ao sargento, some na madrugada
## seguinte (fica um saco preto no lugar) e o sargento devolve o que foi levado
## na próxima conversa.
const BANDIDO := "res://modelos/personagens/bandido.glb"
const RETRATO_DO_BANDIDO := "res://ui/retratos/lojas/bandido.webp"
const NOME_DO_BANDIDO := "Cara no beco"
## Num corredor de dentro dos becos do lado oeste, a uns 50 m de caminhada da
## boca mais perto e sem linha de vista da calçada: só acha quem procura.
const BANDIDO_ONDE := Vector3(-26.6, 0.0, 49.8)
const RAIO_DA_ABORDAGEM := 4.5
## Até que dia ele fica de pé no beco. Vivo no breu, não passa da noite:
## do breu em diante está caído onde ficava, com a mesma pose dos mortos da rua.
const ULTIMO_DIA_DO_BANDIDO := DIA_DO_BREU - 1
var bandido: Node3D
var saco_preto: Node3D
var corpo_do_bandido: Node3D
## Dia do último assalto: no mesmo dia, chegar perto de novo é tiro.
var bandido_roubou_no_dia := 0
var suprimentos_roubados := 0
var bandido_morto := false
## Dia em que o jogador contou ao sargento; na madrugada seguinte, ele some.
var denuncia_no_dia := 0
var devolvido := false
## Quanto o jogador pode chegar depois de roubado, e se já levou o último aviso.
var bandido_limite := 0.0
var bandido_avisou := false

func construir_bandido() -> void:
	bandido = Node3D.new()
	bandido.name = "Bandido"
	bandido.position = BANDIDO_ONDE
	mundo.add_child(bandido)
	var modelo: Node3D = (load(BANDIDO) as PackedScene).instantiate()
	bandido.add_child(modelo)
	RuaModelo.aplicar_ps1(modelo, RESOLUCAO)
	for anim: AnimationPlayer in modelo.find_children("*", "AnimationPlayer", true, false):
		if anim.has_animation("parado"):
			anim.get_animation("parado").loop_mode = Animation.LOOP_LINEAR
			anim.play("parado")
	var corpo := StaticBody3D.new()
	var capsula := CollisionShape3D.new()
	var forma := CapsuleShape3D.new()
	forma.radius = 0.3
	forma.height = 1.8
	capsula.shape = forma
	capsula.position = Vector3(0, 0.9, 0)
	corpo.add_child(capsula)
	bandido.add_child(corpo)
	# O que sobra dele: saco preto de lixo, amarrado, numa poça.
	saco_preto = Node3D.new()
	saco_preto.name = "SacoPreto"
	saco_preto.position = BANDIDO_ONDE
	mundo.add_child(saco_preto)
	var saco := MeshInstance3D.new()
	var capsula_saco := CapsuleMesh.new()
	capsula_saco.radius = 0.32
	capsula_saco.height = 1.75
	capsula_saco.radial_segments = 7
	capsula_saco.rings = 2
	saco.mesh = capsula_saco
	var plastico := StandardMaterial3D.new()
	plastico.albedo_color = Color(0.1, 0.1, 0.12)
	plastico.roughness = 0.25
	plastico.metallic_specular = 0.9
	saco.material_override = RuaModelo.converter(plastico, RESOLUCAO)
	saco.rotation = Vector3(PI / 2.0, 0.3, 0)
	saco.scale = Vector3(1.0, 1.0, 0.7)
	saco.position = Vector3(0, 0.2, 0)
	saco_preto.add_child(saco)
	var no := MeshInstance3D.new()
	var bola := SphereMesh.new()
	bola.radius = 0.09
	bola.height = 0.16
	bola.radial_segments = 5
	bola.rings = 3
	no.mesh = bola
	no.material_override = saco.material_override
	no.position = Vector3(sin(0.3) * 0.95, 0.2, cos(0.3) * 0.95)
	saco_preto.add_child(no)
	var poca := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 0.9
	disco.bottom_radius = 0.9
	disco.height = 0.01
	disco.radial_segments = 8
	poca.mesh = disco
	var sangue := StandardMaterial3D.new()
	sangue.albedo_color = Color(0.22, 0.02, 0.02)
	sangue.roughness = 0.15
	poca.material_override = RuaModelo.converter(sangue, RESOLUCAO)
	poca.position = Vector3(0.25, 0.012, -0.3)
	poca.scale = Vector3(1.2, 1.0, 0.75)
	saco_preto.add_child(poca)
	ajustar_bandido()

func ajustar_bandido() -> void:
	if bandido == null: return
	if denuncia_no_dia > 0 and dia_de_hoje() > denuncia_no_dia: bandido_morto = true
	var esta := not bandido_morto and dia_de_hoje() >= 1 and dia_de_hoje() <= ULTIMO_DIA_DO_BANDIDO
	bandido.visible = esta
	bandido.process_mode = Node.PROCESS_MODE_INHERIT if esta else Node.PROCESS_MODE_DISABLED
	saco_preto.visible = bandido_morto
	# Ninguém o denunciou e o breu chegou: ele ficou ali mesmo.
	var caido := not bandido_morto and dia_de_hoje() > ULTIMO_DIA_DO_BANDIDO
	if caido and corpo_do_bandido == null:
		corpo_do_bandido = (load("res://scripts/corpo3d.gd") as GDScript).new()
		corpo_do_bandido.name = "CorpoDoBandido"
		corpo_do_bandido.set("personagem", "bandido")
		corpo_do_bandido.set("pose", "costas")
		corpo_do_bandido.set("resolucao", RESOLUCAO)
		corpo_do_bandido.position = BANDIDO_ONDE
		corpo_do_bandido.rotation.y = 0.15
		mundo.add_child(corpo_do_bandido)
	if corpo_do_bandido != null: corpo_do_bandido.visible = caido

## A cada quadro: ele vira o rosto para quem chega, aborda, avisa ou atira.
func conferir_bandido() -> void:
	if bandido == null or not bandido.visible or pego or ciclo.morto: return
	if dialogo.visible or not jogador.is_physics_processing(): return
	var de_lado := jogador.global_position - bandido.global_position
	de_lado.y = 0.0
	var distancia := de_lado.length()
	if distancia > 12.0: return
	bandido.rotation.y = atan2(de_lado.x, de_lado.z)
	var hoje := dia_de_hoje()
	if bandido_roubou_no_dia != hoje:
		if distancia < RAIO_DA_ABORDAGEM: abordar_no_beco(distancia)
		return
	if distancia < bandido_limite:
		atirar_no_jogador()
	elif distancia < bandido_limite + 1.2 and not bandido_avisou:
		bandido_avisou = true
		prender_o_jogo(true)
		dialogo.caminho_do_retrato = RETRATO_DO_BANDIDO
		dialogo.respostas_ao_final = false
		dialogo.mostrar(NOME_DO_BANDIDO, ["Tá surdo, parceiro? Eu falei vaza. Não vou falar de novo."])

func abordar_no_beco(distancia: float) -> void:
	bandido_roubou_no_dia = dia_de_hoje()
	bandido_avisou = false
	bandido_limite = maxf(1.6, distancia - 0.9)
	var levou := mini(1, ciclo.suprimentos)
	ciclo.suprimentos -= levou
	suprimentos_roubados += levou
	ciclo.mudou.emit()
	dica.esconder()
	balao.hide()
	prender_o_jogo(true)
	dialogo.caminho_do_retrato = RETRATO_DO_BANDIDO
	dialogo.respostas_ao_final = false
	var falas := ["Ô, ô, ô. Devagar aí, parceiro. Mão onde eu possa ver."]
	if levou > 0:
		falas.append("Pedágio do beco: um suprimento. Não faz essa cara, tá tudo caro, até assalto teve reajuste.")
		falas.append("Agora vaza. Se eu te ver chegando de novo hoje, não vou pedir com educação.")
	else:
		falas.append("Nada? Nem uma bolachinha? Tá mais liso que eu, parceiro.")
		falas.append("Vaza. Se eu te ver chegando de novo hoje, não vou perguntar o que tem na mochila.")
	dialogo.mostrar(NOME_DO_BANDIDO, falas)

func atirar_no_jogador() -> void:
	if ciclo.modo_deus:
		bandido_roubou_no_dia = 0
		dica.avisar("Modo deus: ele puxou o revólver, a arma engasgou e ele achou melhor ir embora.")
		return
	pego = true
	dica.esconder()
	prender_o_jogo(true)
	var som := AudioStreamPlayer.new()
	som.stream = Sons3D.tiro()
	som.volume_db = 6.0
	add_child(som)
	som.play()
	gritar(GRITO_DE_MORTE, 0.25)
	var camada := CanvasLayer.new()
	camada.layer = 5
	var clarao := ColorRect.new()
	clarao.color = Color(1.0, 0.95, 0.8, 0.9)
	clarao.set_anchors_preset(Control.PRESET_FULL_RECT)
	camada.add_child(clarao)
	add_child(camada)
	var tempo := create_tween()
	tempo.tween_property(clarao, "color", Color(0, 0, 0, 1), 0.5)
	await tempo.finished
	await fim_de_jogo("MORTO NO BECO")

## O sargento promete resolver. Na madrugada o bandido vira saco preto, e o
## suprimento volta na próxima conversa com ele.
func denunciar_o_bandido() -> void:
	denuncia_no_dia = dia_de_hoje()
	prender_o_jogo(true)
	dialogo.caminho_do_retrato = RETRATO_DO_SARGENTO
	dialogo.respostas_ao_final = false
	dialogo.mostrar(NOME_DO_SARGENTO, [
		"Jaqueta preta, corrente de ouro, escondido lá no fundo? Sei quem é.",
		"Deixa comigo. Vai pra casa e não sai de noite, hoje menos ainda.",
		"Amanhã você me procura aqui.",
	])

# ------------------------------------------------------------------ sofá

## Frases de quem senta no sofá, conforme o dia: a casa vai ficando outra.
const FRASES_DO_SOFA := [
	[1, "O sofá range do jeito de sempre. Lá fora, a rua faz o barulho de sempre."],
	[3, "Dá para ouvir a rua daqui. Tem menos carro e mais silêncio do que devia."],
	[5, "Lá fora, buzinas. Aqui dentro, o relógio parece andar mais devagar."],
	[6, "No escuro, até a sala parece outro lugar. Melhor não fazer barulho."],
	[8, "Sentado, quieto, ouvindo. Às vezes passa alguma coisa na rua."],
]

## Sentar no sofá: escolher até quando deixar o tempo correr.
func sentar_no_sofa() -> void:
	if abrigo != null: return
	if ciclo.horas <= 0:
		dica.avisar("Já é tarde. A cama é a única coisa que ainda funciona neste país.")
		return
	na_sofa = true
	dica.esconder()
	balao.hide()
	prender_o_jogo(true)
	var frase := String(FRASES_DO_SOFA[0][1])
	for par: Array in FRASES_DO_SOFA:
		if dia_de_hoje() >= int(par[0]): frase = String(par[1])
	dialogo.caminho_do_retrato = ""
	dialogo.respostas_ao_final = true
	dialogo.mostrar("Sofá · %s" % ciclo.texto_da_hora(), [frase])

func abrir_o_sofa() -> void:
	escolha = MenuEscolha.new()
	escolha.name = "Sofa"
	escolha.escolheu.connect(responder_no_sofa)
	var lista := []
	var proximos := ciclo.proximos_periodos()
	if ciclo.hora() < Ciclo3D.DORME: proximos.append({"hora": Ciclo3D.DORME, "periodo": "Hora de dormir"})
	for alvo: Dictionary in proximos:
		var horas := int(alvo.hora) - ciclo.hora()
		lista.append({"chave": str(alvo.hora), "texto": "Até %02d:00 · %s" % [int(alvo.hora), String(alvo.periodo).to_lower()],
			"abaixo": "%dh sentado. Nada se gasta além do tempo." % horas})
	lista.append({"chave": "", "texto": "Levantar", "abaixo": ""})
	escolha.perguntar("Agora são %s." % ciclo.texto_da_hora(), lista)
	dialogo.mostrar_respostas(escolha)

func responder_no_sofa(chave: String) -> void:
	if escolha != null:
		escolha.hide()
		escolha.queue_free()
		escolha = null
	if not chave.is_empty(): ciclo.passar_ate(int(chave))
	encerrar_conversa()

## O dia virou: a cidade no horizonte envelhece com ele.
func virar_o_dia(novo_dia: int) -> void:
	if observadores != null: observadores.limpar()
	# Passou o breu e ninguém foi buscá-la: ela some.
	if novo_dia > Ciclo3D.DIA_DO_BREU and not ciclo.irma_em_casa and (irma == null or irma.seguindo == null): irma_sumiu = true
	dia = novo_dia
	# O tutorial é só do dia 0: passada a noite, ele sai de cena.
	if tutorial != null and novo_dia > 0:
		if tutorial.ativo: tutorial._encerrar()
		tutorial.queue_free()
		tutorial = null
	if cidade != null: cidade.mostrar_o_dia(novo_dia)
	ajustar_helicopteros()
	ajustar_transito()
	ajustar_comboio()
	ajustar_cacadores()
	ajustar_corpos()
	ajustar_barricada()
	ajustar_posto_de_embarque()
	ajustar_bandido()
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
	# Com margem dos lados e quebra de linha: o resumo da noite pode ser longo.
	letras.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	letras.offset_left = 90
	letras.offset_right = -90
	letras.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	# Dá tempo de ler: mais texto, mais tempo na tela.
	sono.tween_interval(1.8 + resumo.length() / 45.0)
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
		dica.avisar("Ônibus fora de serviço. Pela primeira vez, ninguém reclamou do atraso.")
		return
	prender_o_jogo(true)
	menu = MenuPonto.new()
	menu.configurar(ciclo)
	menu.escolheu.connect(fechar_menu_do_ponto)
	add_child(menu)

func fechar_menu_do_ponto(destino: String) -> void:
	if menu == null: return
	menu.queue_free()
	menu = null
	if destino.is_empty():
		voltar_para_o_mundo()
		return
	# Sair custa o dia: trabalhar ocupa oito horas.
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
	saiu_para = destino
	recado_da_volta = dica.recado.text if dica.recado_na_tela() else ""
	dica.calar_recado()

func voltar_do_expediente() -> void:
	if expediente != null:
		# O que veio do mercado entra na despensa, e o que foi gasto sai da
		# carteira.
		ciclo.guardar(int(expediente.comprou["comida"]) + int(expediente.comprou["agua"]) + int(expediente.comprou.get("energia", 0)) / 20, expediente.dinheiro)
		# A lanterna fica: é compra de uma vez só.
		if int(expediente.comprou.get("lanterna", 0)) > 0: ciclo.tem_lanterna = true
		expediente.queue_free()
		expediente = null
	voltar_para_o_mundo()
	# De volta em casa: o jogador reaparece no ponto, de frente para a rua.
	jogador.global_position = PONTO_LUGAR + Vector3(0.0, 0.3, 1.6)
	jogador.rotation.y = PI
	if not recado_da_volta.is_empty(): dica.avisar(recado_da_volta)
	recado_da_volta = ""
	if saiu_para == "trabalho": evento.emit("trabalhou")
	saiu_para = ""

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
	self.irma = irma

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
	if hoje > DIA_DO_ATAQUE: return CACADORES_DEPOIS_DE_NOITE if ciclo != null and ciclo.e_noite() else CACADORES_DEPOIS
	return 0

## Põe e tira caçadores conforme o dia.
func ajustar_cacadores() -> void:
	var quantos := quantos_cacadores_hoje()
	var na_rua: Array = get_tree().get_nodes_in_group("cacadores3d")
	# Sobrando bicho, saem primeiro os mais longe de quem joga.
	if jogador != null:
		na_rua.sort_custom(func(a, b): return (a as Node3D).global_position.distance_to(jogador.global_position) < (b as Node3D).global_position.distance_to(jogador.global_position))
	while na_rua.size() > quantos:
		var velho: Node = na_rua.pop_back()
		velho.remove_from_group("cacadores3d")
		velho.queue_free()
	for i in range(na_rua.size(), quantos):
		var bicho := Cacador3D.new()
		bicho.name = "Cacador%d" % (i + 1)
		bicho.resolucao = RESOLUCAO
		bicho.jogador = jogador
		bicho.pegou.connect(ser_pego.bind(bicho))
		bicho.area_caminhada = Rect2(RUA_LIMITE.x, 19.0, RUA_LIMITE.y - RUA_LIMITE.x, 50.0)
		# Nascem na pista, mas vagam pelo piso livre da rua e dos becos.
		bicho.linha_z = FAIXA_DE_CA if i % 2 == 0 else FAIXA_DE_LA
		bicho.sentido = 1.0 if i % 2 == 0 else -1.0
		bicho.limites = Vector2(RUA_LIMITE.x + 2.0, RUA_LIMITE.y - 2.0)
		# Espalhados pela rua inteira, sem passar do fim dela.
		var faixa := RUA_LIMITE.y - RUA_LIMITE.x - 28.0
		bicho.position = Vector3(RUA_LIMITE.x + 17.0 + fmod(float(i) * 26.0, maxf(faixa, 1.0)), 0.0, bicho.linha_z)
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
		var passo := randf_range(0.9, 1.3) if dia_de_engarrafamento() else randf_range(6.5, 9.5)
		(carro as Carro3D).velocidade_alvo = passo
		(carro as Carro3D).velocidade = 0.0 if dia_de_engarrafamento() else passo
	if dia_de_engarrafamento(): enfileirar(na_rua, vao)

## Põe a rua inteira em fila, nas duas faixas, de uma ponta à outra da rua
## esticada: cada faixa vira um laço de carros colados que anda devagar. Os que
## já estavam rodando são recolocados.
func enfileirar(na_rua: Array, vao: Vector2) -> void:
	var faixas := [[], []]
	for i in na_rua.size(): faixas[i % 2].append(na_rua[i])
	var volta := vao.y - vao.x
	for f in faixas.size():
		var fila: Array = faixas[f]
		var de_ca := f == 0
		var passo_da_fila := volta / float(maxi(1, fila.size()))
		for k in fila.size():
			var carro := fila[k] as Carro3D
			carro.linha_z = FAIXA_DE_CA if de_ca else FAIXA_DE_LA
			carro.sentido = -1.0 if de_ca else 1.0
			carro.rotation.y = PI / 2.0 if carro.sentido > 0.0 else -PI / 2.0
			carro.position.z = carro.linha_z
			# k = 0 vai na ponta da fila; cada um, um carro atrás do anterior, com
			# um empurrãozinho para a fila não ficar de régua.
			var atras := (float(k) + randf_range(-0.06, 0.06)) * passo_da_fila
			carro.position.x = (vao.y - 1.0 - atras) if carro.sentido > 0.0 else (vao.x + 1.0 + atras)
			# O da frente do primeiro é o último: a faixa é um laço.
			var na_frente: Node3D = fila[(k - 1 + fila.size()) % fila.size()]
			carro.entrar_no_engarrafamento(na_frente, jogador, k % 2 == 0, k % 4 == 0)

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
## ciclo: qualquer coisa que mude a hora, a carteira ou a despensa cai aqui.
## O envelope do HUD e, quando chega coisa nova, o aviso do celular vibrando.
func avisar_mensagens() -> void:
	if status == null or ciclo == null: return
	var novas := mensagens.novas(ciclo.dia, ciclo.contatos, vizinhos)
	status.mostrar_mensagens(novas)
	if novas > _novas_avisadas and dica != null and celular == null:
		Sons3D.tocar(self, Sons3D.celular_vibrar(), -6.0)
		get_tree().create_timer(0.3).timeout.connect(func(): if is_inside_tree(): Sons3D.tocar(self, Sons3D.celular_mensagem(), -12.0))
		dica.avisar("O celular vibrou: %d mensage%s não lida%s. C pra ler — não é promoção de operadora." % [novas, "m" if novas == 1 else "ns", "" if novas == 1 else "s"])
	_novas_avisadas = novas

func mostrar_o_estado() -> void:
	mensagens.caixa(ciclo.dia, ciclo.contatos, "Irmã", vizinhos)
	avisar_mensagens()
	suprimentos = ciclo.suprimentos
	dinheiro = ciclo.dinheiro
	status.mostrar(ciclo.suprimentos, ciclo.dinheiro, ciclo.texto_da_hora(), ciclo.periodo())
	status.avisar_modo_deus(ciclo.modo_deus)
	status.mostrar_fraqueza(ciclo.fraqueza)
	aplicar_hora_do_dia()
	if not ciclo.recado.is_empty():
		if dica != null: dica.avisar(ciclo.recado)
		ciclo.recado = ""
