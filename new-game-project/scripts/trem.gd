@tool
extends Node2D

# Diferenciar entre "SOCIAL", "MAQUINAS", 'COZINHA
# SOCIAL carrega os passageiros, tendo os decos como cadeiras.
# MAQUINAS é onde o jogador deve re-abastecer o 'forno' do trem com carvão encontrado no trem ou ganho das estações.
# COZINHA é onde o jogador guarda as comidas recompensadas da estação para futura entrega para os passageiros.
@export var classe = ""

@export var porta_esquerda_aberta := false:
	set(valor):
		porta_esquerda_aberta = valor
		_construir()

@export var porta_direita_aberta := false:
	set(valor):
		porta_direita_aberta = valor
		_construir()

# Tamanho do vagão em tiles (cada tile ocupa TAMANHO_TILE px na tela).
# 15 x 9 tiles = 480 x 288 px, próximo do vagão antigo (480 x 300).
@export_range(5, 60) var largura_tiles := 15:
	set(valor):
		largura_tiles = valor
		_construir()

@export_range(5, 40) var altura_tiles := 9:
	set(valor):
		altura_tiles = valor
		_construir()

# Altura do vão de cada uma das duas portas, em tiles.
@export_range(1, 20) var altura_porta_tiles := 2:
	set(valor):
		altura_porta_tiles = valor
		_construir()

# Os tiles do tileset_v1.png têm 64 px; são desenhados na metade do tamanho.
const TAMANHO_TILE := 32
const TAMANHO_TILE_ATLAS := 64
const FONTE := 0
const ESPELHADO := TileSetAtlasSource.TRANSFORM_FLIP_H

# Coordenadas no atlas. O desenho original tem a porta à esquerda,
# então o lado direito usa os mesmos tiles espelhados.
const CANTO_SUP := Vector2i(1, 1)
const PAREDE_SUP := Vector2i(2, 1)
const PAREDE_LATERAL := Vector2i(5, 2) # Parede direita sem porta.
const PORTA_TOPO := Vector2i(1, 2)
const PORTA := Vector2i(1, 3)
const PORTA_BASE := Vector2i(1, 4)
const CANTO_INF := Vector2i(1, 5)
const PAREDE_INF := Vector2i(2, 5)
const JANELA := Vector2i(3, 5)
const EXTERNO_CANTO := Vector2i(1, 6)
const EXTERNO_ENFEITES := [Vector2i(2, 6), Vector2i(4, 6)]
const EXTERNO := Vector2i(3, 6)
const PISO := Vector2i(7, 2)

# Distância (em tiles) entre as janelas da parede de baixo.
const ESPACO_JANELAS := 4

# Portas fechadas do vagão; cada uma abre com a tecla de interagir.
var _portas : Array[Porta] = []


func _ready() -> void:
	_construir()


func _construir() -> void:
	if not is_node_ready():
		return
	for porta in _portas:
		if is_instance_valid(porta):
			porta.queue_free()
	_portas.clear()
	var solo := get_node_or_null("Solo") as TileMapLayer
	var paredes := get_node_or_null("Paredes") as TileMapLayer
	if solo == null or paredes == null:
		return

	var escala := Vector2.ONE * TAMANHO_TILE / TAMANHO_TILE_ATLAS
	solo.scale = escala
	paredes.scale = escala
	solo.clear()
	paredes.clear()

	var ultima_col := largura_tiles - 1
	var ultima_lin := altura_tiles - 1

	# Chão
	for x in largura_tiles:
		for y in altura_tiles:
			solo.set_cell(Vector2i(x, y), FONTE, PISO)

	# Parede de cima
	_colocar(paredes, 0, 0, CANTO_SUP, false)
	_colocar(paredes, ultima_col, 0, CANTO_SUP, true)
	for x in range(1, ultima_col):
		_colocar(paredes, x, 0, PAREDE_SUP, false)

	# Paredes laterais (com portas)
	for y in range(1, ultima_lin):
		_colocar(paredes, 0, y, PAREDE_LATERAL, true)
		_colocar(paredes, ultima_col, y, PAREDE_LATERAL, false)
	_colocar_porta(paredes, 0, porta_esquerda_aberta, false)
	_colocar_porta(paredes, ultima_col, porta_direita_aberta, true)

	# Parede de baixo (com janelas) e lateral externa do vagão
	var centro := largura_tiles / 2
	_colocar(paredes, 0, ultima_lin, CANTO_INF, false)
	_colocar(paredes, ultima_col, ultima_lin, CANTO_INF, true)
	_colocar(paredes, 0, altura_tiles, EXTERNO_CANTO, false)
	_colocar(paredes, ultima_col, altura_tiles, EXTERNO_CANTO, true)
	for x in range(1, ultima_col):
		var distancia := posmod(x - centro, ESPACO_JANELAS)
		_colocar(paredes, x, ultima_lin, JANELA if distancia == 0 else PAREDE_INF, false)
		var externo := EXTERNO
		if distancia == ESPACO_JANELAS / 2:
			externo = EXTERNO_ENFEITES[posmod(x / ESPACO_JANELAS, EXTERNO_ENFEITES.size())]
		_colocar(paredes, x, altura_tiles, externo, false)


# Duas portas por parede lateral, com um bloco de parede entre elas.
# Aberta = vão livre, sem colisão. Fechada = Porta animada, que o jogador abre com a tecla de interagir.
func _colocar_porta(paredes: TileMapLayer, x: int, aberta: bool, espelhar: bool) -> void:
	var interno := altura_tiles - 2
	# Cada porta usa a moldura de cima + o vão; mais o bloco no meio.
	var tamanho := clampi(altura_porta_tiles, 1, maxi(1, (interno - 3) / 2))
	var total := 2 * (1 + tamanho) + 1
	var primeira := 1 + maxi(0, interno - total) / 2
	for k in 2:
		var topo := primeira + k * (tamanho + 2)
		var inicio := topo + 1
		for y in range(inicio, inicio + tamanho):
			paredes.erase_cell(Vector2i(x, y))
		# Bloco de parede logo abaixo do vão (no meio das duas portas, ou antes da quina).
		var base := inicio + tamanho
		if base < altura_tiles - 1:
			_colocar(paredes, x, base, PORTA_BASE, espelhar)
		if aberta:
			continue
		# A moldura de cima e o vão passam a ser desenhados pela Porta.
		paredes.erase_cell(Vector2i(x, topo))
		var porta := Porta.new()
		add_child(porta)
		porta.configurar(x, inicio, tamanho, espelhar)
		_portas.append(porta)
	if _portas.size() >= 2:
		_portas[-1].parceira = _portas[-2]
		_portas[-2].parceira = _portas[-1]


func _colocar(camada: TileMapLayer, x: int, y: int, atlas: Vector2i, espelhar: bool) -> void:
	camada.set_cell(Vector2i(x, y), FONTE, atlas, ESPELHADO if espelhar else 0)
