extends SceneTree

var falhas := 0
var verificacoes := 0
var mercado: Mercado3D

func _initialize() -> void:
	call_deferred("rodar")

func checar(ok: bool, texto: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		printerr("FAIL: ", texto)

func visitar(tipo: String, chave := "") -> void:
	for ponto: Dictionary in mercado._pontos:
		if String(ponto.kind) != tipo: continue
		if tipo == "item" and String(ponto.key) != chave: continue
		mercado._jogador.position = Vector3(float(ponto.x), 0, float(ponto.z))
		mercado.usar()
		return
	checar(false, "ponto encontrado: " + tipo + chave)

func rodar() -> void:
	mercado = Mercado3D.new()
	mercado.dinheiro = 300
	root.add_child(mercado)
	await process_frame
	for chave in ["arroz", "arroz", "feijao", "macarrao", "agua", "pilhas", "lanterna"]:
		visitar("item", chave)
	checar(mercado.itens_na_cesta() == 7, "sete embalagens na cesta")
	checar(mercado.total_da_cesta() == 101, "preço cobrado por embalagem, não por unidade de comida")
	checar(mercado.comprou.comida == 0 and mercado.dinheiro == 300, "pegar itens não entrega comida antes de pagar")
	visitar("caixa")
	checar(mercado.comprou.comida == 13, "duas embalagens de arroz mais feijão e macarrão rendem treze comidas")
	checar(mercado.comprou.agua == 1 and mercado.comprou.energia == 20 and mercado.comprou.lanterna == 1, "água, pilhas e lanterna conservam seus rendimentos")
	checar(mercado.dinheiro == 199 and mercado._cesta.is_empty(), "caixa desconta exatamente a conta e limpa cesta")
	visitar("caixa")
	checar(mercado.comprou.comida == 13 and mercado.dinheiro == 199, "confirmar caixa vazio não duplica compras")
	visitar("item", "cafe")
	visitar("caixa")
	checar(mercado.comprou.comida == 15 and mercado.dinheiro == 187, "café aplica seu rendimento próprio ao pagar")
	var arroz := {"kind": "item", "key": "arroz"}
	checar(mercado.rotulo(arroz).contains("R$ 22") and mercado.rotulo(arroz).contains("+5 de comida"), "preço e rendimento visíveis antes de pegar arroz")
	mercado.dia = 5
	checar(mercado.preco("arroz") > 22 and mercado.rendimento("arroz") == 5, "inflação altera preço sem alterar rendimento")
	mercado.queue_free()
	await process_frame
	print("MERCADO: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
