class_name Configuracoes
extends RefCounted

# As opções do jogador (volume, sensibilidade do mouse, tela cheia), guardadas
# em user://opcoes.cfg e aplicadas ao abrir o jogo e a cada mudança.
const ARQUIVO := "user://opcoes.cfg"
const PADRAO := {"volume": 0.8, "sensibilidade": 0.0022, "tela_cheia": false}

static var valores := {}

static func carregar() -> Dictionary:
	if not valores.is_empty(): return valores
	valores = PADRAO.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(ARQUIVO) == OK:
		for chave: String in PADRAO:
			valores[chave] = cfg.get_value("opcoes", chave, PADRAO[chave])
	return valores

static func guardar() -> void:
	var cfg := ConfigFile.new()
	for chave: String in valores:
		cfg.set_value("opcoes", chave, valores[chave])
	cfg.save(ARQUIVO)

static func mudar(chave: String, valor) -> void:
	carregar()
	valores[chave] = valor
	aplicar()
	guardar()

## Volume no barramento principal; tela cheia na janela. A sensibilidade é lida
## pelo jogador.
static func aplicar() -> void:
	carregar()
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(valores.volume))))
	AudioServer.set_bus_mute(0, float(valores.volume) <= 0.001)
	if DisplayServer.get_name() == "headless": return
	var cheia := bool(valores.tela_cheia)
	var agora := DisplayServer.window_get_mode()
	var esta_cheia := agora in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if cheia != esta_cheia:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if cheia else DisplayServer.WINDOW_MODE_WINDOWED)
