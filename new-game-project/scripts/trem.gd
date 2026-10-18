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
# 23 x 13 tiles = 736 x 416 px: vagão mais largo que alto.
@export_range(5, 60) var largura_tiles := 23:
	set(valor):
		largura_tiles = valor
		_construir()

@export_range(5, 40) var altura_tiles := 13:
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

# Passarela entre vagões (bloco cinza do tileset, colunas 12 a 16, linhas 1 a 6).
# Colunas 12-13: plataforma presa ao lado direito de um vagão (13 é a borda externa).
# Coluna 14: ponte. Colunas 15-16: plataforma presa ao lado esquerdo (15 é a borda externa).
const PLAT_DIR_INTERNA := 12
const PLAT_DIR_BORDA := 13
const PONTE := 14
const PLAT_ESQ_BORDA := 15
const PLAT_ESQ_INTERNA := 16
# Linhas do atlas da plataforma.
const PLAT_GRADE_SUP := 1
const PLAT_BORDA_FIM := 2 # Borda que termina logo acima da abertura.
const PLAT_ABERTURA := 3 # Linha da abertura para a ponte (desenhada esticada).
const PLAT_BORDA_INICIO := 4 # Borda que começa logo abaixo da abertura.
const PLAT_BORDA := 5
const PLAT_GRADE_INF := 6
# A ponte tem 1 tile no atlas; é esticada para a altura do bloco entre as portas,
# repetindo a faixa do meio. Valores em px do atlas, dentro do tile.
const PONTE_TOPO := 16
const PONTE_BASE := 16
# Espessura (px na tela) das grades de cima e de baixo da ponte, que colidem.
const PONTE_GRADE := 8
# Largura da passarela entre dois vagões: 2 tiles de plataforma + ponte + 2 tiles de plataforma.
# Os vagões da cena principal devem ficar a (largura_tiles + VAO_PASSARELA) tiles um do outro.
const VAO_PASSARELA := 5

# Distância (em tiles) entre as janelas da parede de baixo.
const ESPACO_JANELAS := 4

const TILESET := preload("res://assets/tileset/tileset_v1.png")

# Portas fechadas do vagão; cada uma abre com a tecla de interagir.
var _portas : Array[Porta] = []
# Partes da passarela que não cabem no TileMap (abertura e ponte esticadas, colisão da ponte).
var _passarela : Node2D


func _ready() -> void:
	_construir()


func _construir() -> void:
	if not is_node_ready():
		return
	for porta in _portas:
		if is_instance_valid(porta):
			porta.queue_free()
	_portas.clear()
	if is_instance_valid(_passarela):
		_passarela.queue_free()
	_passarela = null
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

	# Lado com porta aberta = ligado a outro vagão: ganha a plataforma do lado de fora.
	# O lado direito também desenha a ponte até a plataforma do próximo vagão.
	if porta_esquerda_aberta:
		_colocar_plataforma(paredes, -1, -1)
	if porta_direita_aberta:
		_colocar_plataforma(paredes, ultima_col + 1, 1)

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
	var tamanho := _tamanho_porta()
	var primeira := _topo_portas()
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


# Altura do vão de cada porta, em tiles (limitada pelo tamanho do vagão).
func _tamanho_porta() -> int:
	var interno := altura_tiles - 2
	return clampi(altura_porta_tiles, 1, maxi(1, (interno - 3) / 2))


# Linha da moldura de cima da primeira porta. As duas portas (moldura + vão cada)
# e o bloco entre elas ficam centralizados na parede lateral.
func _topo_portas() -> int:
	var interno := altura_tiles - 2
	var total := 2 * (1 + _tamanho_porta()) + 1
	return 1 + maxi(0, interno - total) / 2


# Plataforma de 2 tiles do lado de fora de uma parede lateral, cobrindo as duas portas,
# com grade em cima e embaixo. A abertura para a ponte fica na altura do bloco entre as portas.
# lado = -1: plataforma à esquerda, x é a coluna colada ao vagão.
# lado = 1: plataforma à direita, x é a coluna colada ao vagão; também desenha a ponte.
func _colocar_plataforma(paredes: TileMapLayer, x: int, lado: int) -> void:
	var tamanho := _tamanho_porta()
	var grade_sup := _topo_portas()
	var abertura := grade_sup + tamanho + 1 # Mesmas linhas do bloco entre as portas.
	var grade_inf := abertura + 2 + tamanho
	var borda_x := x + lado
	var interna := PLAT_DIR_INTERNA if lado > 0 else PLAT_ESQ_INTERNA
	var borda := PLAT_DIR_BORDA if lado > 0 else PLAT_ESQ_BORDA

	for y in range(grade_sup, grade_inf + 1):
		var linha := PLAT_BORDA
		if y == grade_sup:
			linha = PLAT_GRADE_SUP
		elif y == grade_inf:
			linha = PLAT_GRADE_INF
		elif y == abertura - 1:
			linha = PLAT_BORDA_FIM
		elif y == abertura + 2:
			linha = PLAT_BORDA_INICIO
		_colocar(paredes, x, y, Vector2i(interna, linha), false)
		if y == abertura or y == abertura + 1:
			paredes.erase_cell(Vector2i(borda_x, y))
		else:
			_colocar(paredes, borda_x, y, Vector2i(borda, linha), false)

	if _passarela == null:
		_passarela = Node2D.new()
		_passarela.name = "Passarela"
		add_child(_passarela)
	# A abertura e a ponte têm 1 tile no atlas; aqui ocupam 2 tiles de altura.
	_coluna_esticada(borda, borda_x, abertura, 2)
	if lado < 0:
		return
	var ponte_x := borda_x + 1
	_coluna_esticada(PONTE, ponte_x, abertura, 2)
	# Grades da ponte: só dá para atravessar pelo meio.
	var corpo := StaticBody2D.new()
	_passarela.add_child(corpo)
	var topo := Vector2(ponte_x, abertura) * TAMANHO_TILE
	var altura := 2 * TAMANHO_TILE
	for dy in [PONTE_GRADE / 2.0, altura - PONTE_GRADE / 2.0]:
		var forma := RectangleShape2D.new()
		forma.size = Vector2(TAMANHO_TILE, PONTE_GRADE)
		var colisao := CollisionShape2D.new()
		colisao.shape = forma
		colisao.position = topo + Vector2(TAMANHO_TILE / 2.0, dy)
		corpo.add_child(colisao)


# Desenha uma coluna da linha PLAT_ABERTURA do atlas esticada para "linhas" tiles:
# topo do tile, a faixa do meio repetida e a base do tile.
func _coluna_esticada(coluna_atlas: int, x: int, y: int, linhas: int) -> void:
	var origem := Vector2(coluna_atlas, PLAT_ABERTURA) * TAMANHO_TILE_ATLAS
	var meio := TAMANHO_TILE_ATLAS - PONTE_TOPO - PONTE_BASE
	var repeticoes := (linhas * TAMANHO_TILE_ATLAS - PONTE_TOPO - PONTE_BASE) / meio
	var fatias := [Rect2(origem, Vector2(TAMANHO_TILE_ATLAS, PONTE_TOPO))]
	for i in repeticoes:
		fatias.append(Rect2(origem + Vector2(0, PONTE_TOPO), Vector2(TAMANHO_TILE_ATLAS, meio)))
	fatias.append(Rect2(origem + Vector2(0, TAMANHO_TILE_ATLAS - PONTE_BASE), Vector2(TAMANHO_TILE_ATLAS, PONTE_BASE)))
	var escala := float(TAMANHO_TILE) / TAMANHO_TILE_ATLAS
	var pos := Vector2(x, y) * TAMANHO_TILE
	for fatia in fatias:
		var parte := Sprite2D.new()
		parte.texture = TILESET
		parte.region_enabled = true
		parte.region_rect = fatia
		# Sem isso aparecem linhas nas emendas entre as fatias.
		parte.region_filter_clip_enabled = true
		parte.centered = false
		parte.scale = Vector2.ONE * escala
		parte.position = pos
		_passarela.add_child(parte)
		pos.y += fatia.size.y * escala


func _colocar(camada: TileMapLayer, x: int, y: int, atlas: Vector2i, espelhar: bool) -> void:
	camada.set_cell(Vector2i(x, y), FONTE, atlas, ESPELHADO if espelhar else 0)
