class_name RuaModelo
extends RefCounted

# Encaixa a rua do artefato (modelos/rua_penha.glb) no mundo e aplica nela o
# shader de PS1 que veio junto, mantendo as texturas originais.
#
# Medidas lidas do arquivo: a rua corre no eixo Z local, com 124 m de extensão.
# Na seção, o eixo local X vale: pista de 8 m (-4 a 4), meio-fio de 15 cm,
# calçadas de 4,95 m (4,25 a 9,2) e as fachadas de 8,88 até 15,04.
const MODELO := preload("res://modelos/rua_penha.glb")
const SHADER := preload("res://shaders/ps1_artefato.gdshader")
const MEIA_PISTA := 4.0
const MEIO_FIO := 4.25
const CALCADA_FIM := 9.2
const FACHADA := 8.88
## Peças que fazem parte do casario (o que precisa sair para o lote caber).
const CASARIO := ["construcao", "caixa_dagua", "mesa_bar", "orelhao", "objeto"]
## O tremor de vértice e a textura afim são a assinatura do PS1, mas os dois
## desestabilizam a imagem: o tremor mexe na posição da tela sem mexer na
## profundidade, e aí superfícies rentes brigam pelo pixel a cada quadro; a
## textura afim entorta o desenho nas peças grandes. Ficam desligados; quem
## quiser o efeito de volta troca aqui.
const TREMOR := false
const TEXTURA_AFIM := false
## Shaders e materiais já montados, para não refazer os mesmos a cada peça.
static var _variantes := {}
static var _materiais := {}

## Comprimento do trecho que o modelo traz, em metros.
const COMPRIMENTO := 124.0
## Peças que só fazem sentido perto: nas cópias de continuação elas saem.
const MIUDEZAS := ["lixo", "mesa_bar", "orelhao", "objeto", "carro", "pipa"]
## Peças que saem de toda cópia da rua, inclusive a principal. Os carros parados
## do modelo saem: quem anda na rua são os do pacote (res://carros).
const FORA := ["carro"]

## Coloca a rua com o eixo da pista em `z_do_eixo`, correndo no eixo X do mundo.
## `x_central` é o meio do trecho e `altura` sobe ou desce a rua inteira — com
## -0,15 o topo da calçada fica no nível 0, igual ao chão do lote.
static func instanciar(pai: Node3D, z_do_eixo: float, x_central: float, altura: float, resolucao: Vector2) -> Node3D:
	var rua := MODELO.instantiate()
	rua.name = "RuaPenha"
	# Girar -90° põe o comprimento do modelo (Z local) no eixo X do mundo:
	# mundo.z = eixo + local.x e mundo.x = central - local.z.
	rua.rotation.y = -PI / 2.0
	rua.position = Vector3(x_central, altura, z_do_eixo)
	pai.add_child(rua)
	varrer(rua, FORA)
	aplicar_ps1(rua, resolucao)
	liberar_meio_fio(rua)
	return rua

## Tira do trecho as peças cujo nome comece por um dos prefixos.
static func varrer(rua: Node3D, prefixos: Array) -> int:
	var tirados := 0
	for no in rua.get_children():
		var base := String(no.name).rstrip("0123456789_")
		if not prefixos.has(base): continue
		no.queue_free()
		tirados += 1
	return tirados

## Continuação da rua: outra cópia do trecho, emendada na ponta da principal.
## Serve para a rua sumir na névoa em vez de acabar numa parede. Vem sem as
## miudezas, sem colisão e sem o que estiver longe demais para ser visto.
static func continuar(pai: Node3D, principal: Node3D, lado: int, alcance: float, resolucao: Vector2) -> Node3D:
	var copia := instanciar(pai, principal.position.z, principal.position.x + COMPRIMENTO * float(lado), principal.position.y, resolucao)
	copia.name = "RuaPenhaContinua%d" % lado
	# A tampa virada para a rua principal sai: é a emenda entre as duas.
	tirar_tampas(copia, -lado)
	var limite: float = principal.position.x + COMPRIMENTO * 0.5 * float(lado) + alcance * float(lado)
	for no in copia.get_children():
		if not (no is Node3D): continue
		var base := String(no.name).rstrip("0123456789_")
		var fora := false
		if MIUDEZAS.has(base): fora = true
		else:
			var caixa = caixa_mundial(no, copia.transform)
			if caixa != null:
				var meio: float = ((caixa as AABB).position.x + (caixa as AABB).end.x) * 0.5
				fora = (meio - limite) * float(lado) > 0.0
		if fora:
			no.queue_free()
			continue
		for corpo in colisores(no):
			corpo.get_parent().remove_child(corpo)
			corpo.queue_free()
	return copia

## Tira as paredes com que o modelo fecha as pontas do trecho. `lado` diz qual:
## -1 a do lado de menor X, 1 a do lado de maior X, 0 as duas.
static func tirar_tampas(rua: Node3D, lado: int) -> int:
	var removidas := 0
	for no in rua.get_children():
		if not String(no.name).begins_with("construcao"): continue
		var caixa = caixa_mundial(no, rua.transform)
		if caixa == null: continue
		var c: AABB = caixa
		# Só a tampa atravessa a rua inteira; casa nenhuma tem 14 m de frente.
		if c.size.z < 14.0: continue
		var deste_lado := 1 if (c.position.x + c.end.x) * 0.5 > rua.position.x else -1
		if lado == 0 or deste_lado == lado:
			no.queue_free()
			removidas += 1
	return removidas

## Tira a colisão das faces verticais do meio-fio. Elas continuam aparecendo,
## mas como parede de 15 cm travavam a passagem entre a pista e a calçada; sem
## elas o jogador sobe pela borda da calçada, que o motor trata como piso.
static func liberar_meio_fio(rua: Node3D) -> int:
	var soltos := 0
	for no in rua.get_children():
		if not String(no.name).begins_with("chao"): continue
		var caixa = caixa_mundial(no, Transform3D())
		if caixa == null: continue
		# O piso é plano; só as faces do meio-fio têm altura.
		if (caixa as AABB).size.y < 0.01: continue
		for corpo in colisores(no):
			corpo.get_parent().remove_child(corpo)
			corpo.queue_free()
			soltos += 1
	return soltos

## Tira o casario simples do modelo num trecho, para as casas e os comércios
## do artefato entrarem no lugar. As caixas-d'água vão junto: elas ficam em
## cima dessas construções e sozinhas boiariam no ar.
static func tirar_casario(rua: Node3D, faixa_x: Vector2) -> int:
	var removidos := 0
	for no in rua.get_children():
		if not (no is Node3D): continue
		var base := String(no.name).rstrip("0123456789_")
		if base != "construcao" and base != "caixa_dagua": continue
		var caixa = caixa_mundial(no, rua.transform)
		if caixa == null: continue
		var c: AABB = caixa
		if c.position.x < faixa_x.y and c.end.x > faixa_x.x:
			no.queue_free()
			removidos += 1
	return removidos

## Tira do modelo o casario que cairia em cima do lote da casa, do lado de cá da
## pista. `faixa_x` é o trecho do mundo que o lote ocupa.
static func abrir_espaco(rua: Node3D, faixa_x: Vector2, z_do_eixo: float) -> int:
	var removidos := 0
	for no in rua.get_children():
		if not (no is Node3D): continue
		var base := String(no.name).rstrip("0123456789_")
		if not CASARIO.has(base): continue
		var caixa = caixa_mundial(no, rua.transform)
		if caixa == null: continue
		var c: AABB = caixa
		var do_lado_da_casa := (c.position.z + c.end.z) * 0.5 < z_do_eixo
		var no_lote := c.position.x < faixa_x.y and c.end.x > faixa_x.x
		if do_lado_da_casa and no_lote:
			no.queue_free()
			removidos += 1
	return removidos

static func colisores(no: Node) -> Array:
	var lista := []
	if no is StaticBody3D: lista.append(no)
	for f in no.get_children(): lista.append_array(colisores(f))
	return lista

## Caixa envolvente de uma peça já no espaço do mundo (sem depender da árvore).
static func caixa_mundial(no: Node, base: Transform3D) -> Variant:
	var t := base
	if no is Node3D: t = base * (no as Node3D).transform
	var total = null
	if no is MeshInstance3D and (no as MeshInstance3D).mesh:
		total = t * (no as MeshInstance3D).mesh.get_aabb()
	for f in no.get_children():
		var b = caixa_mundial(f, t)
		if b == null: continue
		total = b if total == null else (total as AABB).merge(b)
	return total

## Troca os materiais importados pelo shader de PS1 (tremor de vértice e textura
## sem correção de perspectiva), preservando a textura de cada peça.
## `afim` liga a textura sem correção de perspectiva. Nos móveis ela fica
## desligada: eles usam um atlas apertado, e o escorregamento da UV puxava o
## texel vizinho — às vezes um transparente, o que enchia a peça de chuvisco.
static func aplicar_ps1(no: Node, resolucao: Vector2, afim := TEXTURA_AFIM, tremido := TREMOR) -> void:
	for m in no.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null: continue
		for i in mi.mesh.get_surface_count():
			var origem := mi.get_active_material(i)
			if origem is BaseMaterial3D:
				mi.set_surface_override_material(i, converter(origem as BaseMaterial3D, resolucao, afim, tremido))
	if no is MeshInstance3D and (no as MeshInstance3D).mesh:
		var raiz := no as MeshInstance3D
		for i in raiz.mesh.get_surface_count():
			var origem := raiz.get_active_material(i)
			if origem is BaseMaterial3D:
				raiz.set_surface_override_material(i, converter(origem as BaseMaterial3D, resolucao, afim, tremido))

## Variantes do mesmo shader, montadas trocando o modo de desenho no código:
## peça sem luz (letreiro, céu) e peça de dupla face (fio, pipa, folhagem).
static func variante(sem_luz: bool, dupla_face: bool) -> Shader:
	var chave := "%s|%s" % [sem_luz, dupla_face]
	if _variantes.has(chave): return _variantes[chave]
	var codigo: String = SHADER.code
	var modos := "unshaded" if sem_luz else "diffuse_lambert, specular_disabled"
	modos += ", cull_disabled" if dupla_face else ", cull_back"
	codigo = codigo.replace("diffuse_lambert, specular_disabled, cull_back", modos)
	if sem_luz: codigo = codigo.replace("ROUGHNESS = 1.0;", "")
	var novo := Shader.new()
	novo.code = codigo
	_variantes[chave] = novo
	return novo

static func converter(origem: BaseMaterial3D, resolucao: Vector2, afim := TEXTURA_AFIM, tremido := TREMOR) -> ShaderMaterial:
	var chave := "%d|%s|%s|%s" % [origem.get_instance_id(), afim, tremido, resolucao]
	if _materiais.has(chave): return _materiais[chave]
	var material := ShaderMaterial.new()
	material.shader = variante(origem.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, origem.cull_mode == BaseMaterial3D.CULL_DISABLED)
	material.set_shader_parameter("albedo_tex", origem.albedo_texture)
	# O importador de glTF converte a cor de sRGB para linear, mas a cor que o
	# modelo exportou já era sRGB: sem desfazer isso, peça sem textura sai
	# desbotada. Quem tem textura entra com branco, e a cor vem dela.
	material.set_shader_parameter("tint", origem.albedo_color.srgb_to_linear() if origem.albedo_texture == null else Color.WHITE)
	material.set_shader_parameter("snap_resolution", resolucao)
	material.set_shader_parameter("affine", afim)
	material.set_shader_parameter("jitter", tremido)
	_materiais[chave] = material
	return material

## Deixa um personagem inteiro em silhueta: cor chapada, sem luz. É assim que o
## supervisor do call center aparece, vindo do fundo do corredor.
static func silhueta(no: Node, cor: Color) -> void:
	var material := ShaderMaterial.new()
	material.shader = variante(true, false)
	material.set_shader_parameter("tint", cor)
	material.set_shader_parameter("jitter", TREMOR)
	material.set_shader_parameter("affine", TEXTURA_AFIM)
	for m in no.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = material
