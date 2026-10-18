@tool
extends Node2D

# Tipo do vagão; define o piso (ver PISOS).
# SOCIAL carrega os passageiros, tendo os decos como cadeiras.
# MAQUINAS é onde o jogador deve re-abastecer o 'forno' do trem com carvão encontrado no trem ou ganho das estações.
# COZINHA é onde o jogador guarda as comidas recompensadas da estação para futura entrega para os passageiros.
# BANHEIRO é o banheiro dos passageiros.
# SERVICO junta as duas coisas: banheiros (cabines com vaso) na parte de cima
# à esquerda e a cozinha no lado direito, cada sala com o seu piso.
@export_enum("SOCIAL", "COZINHA", "BANHEIRO", "MAQUINAS", "SERVICO") var classe := "SOCIAL":
	set(valor):
		classe = valor
		_construir()

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
# Rodas: cada tile tem 4 quadros de animação lado a lado na imagem (colunas 1 a 4),
# configurados no tileset. A base do vagão usa RODA_MEIO no meio, RODA_ESQ no fim
# esquerdo e RODA_DIR no fim direito.
const RODA_MEIO := Vector2i(1, 10)
const RODA_ESQ := Vector2i(1, 12)
const RODA_DIR := Vector2i(1, 14)
const EXTERNO := Vector2i(3, 6)
# Piso de cada classe de vagão (coordenadas no atlas).
const PISOS := {
	"SOCIAL": Vector2i(7, 2), # Tijolo
	"COZINHA": Vector2i(9, 2), # Xadrez
	"BANHEIRO": Vector2i(9, 4), # Bege com losango
	"MAQUINAS": Vector2i(7, 4), # Cinza escuro
	"SERVICO": Vector2i(7, 2), # Corredor do vagão de serviço: tijolo
}

# Vagão de serviço (ver _construir_servico).
const VASOS := 3
const LARGURA_CABINE := 3 # Tiles livres dentro de cada cabine.
const PROFUNDIDADE_CABINE := 4 # Tiles, a partir da parede de cima.
# Peça de parede vertical do atlas (2 tiles de altura, em px do atlas), usada nas divisórias.
# É esticada: borda de cima, faixa do meio e a base (frente da parede).
const DIVISORIA := Rect2(1344, 192, 64, 128)
const DIVISORIA_TOPO := 4
const DIVISORIA_BASE := 32

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
# Divisórias e vasos do vagão de serviço (o nó também cuida da fila do banheiro).
var _interior : Banheiro


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
	if is_instance_valid(_interior):
		_interior.queue_free()
	_interior = null
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
	var piso : Vector2i = PISOS.get(classe, PISOS["SOCIAL"])
	for x in largura_tiles:
		for y in altura_tiles:
			solo.set_cell(Vector2i(x, y), FONTE, piso)
	if classe == "SERVICO":
		_construir_servico(solo)

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
	# A base inteira do vagão são as rodas: fim esquerdo, meio e fim direito.
	_colocar(paredes, 0, altura_tiles, RODA_ESQ, false)
	_colocar(paredes, ultima_col, altura_tiles, RODA_DIR, false)
	for x in range(1, ultima_col):
		var distancia := posmod(x - centro, ESPACO_JANELAS)
		_colocar(paredes, x, ultima_lin, JANELA if distancia == 0 else PAREDE_INF, false)
		_colocar(paredes, x, altura_tiles, RODA_MEIO, false)


# Banheiro deste vagão (só o de serviço tem), ou null.
func banheiro() -> Banheiro:
	return _interior if is_instance_valid(_interior) else null


# Alturas (locais, em px) usadas pela RedeCaminhos para atravessar o vagão:
# corredor do meio, vão da porta de cima e a ponte da passarela.
func y_corredor() -> float:
	return altura_tiles * TAMANHO_TILE / 2.0


func y_porta() -> float:
	return (_topo_portas() + 1 + _tamanho_porta() / 2.0) * TAMANHO_TILE


func y_ponte() -> float:
	return (_topo_portas() + _tamanho_porta() + 2) * TAMANHO_TILE


# Vagão de serviço: na parte de cima, à esquerda, uma fileira de cabines de banheiro
# (um vaso em cada, separadas por divisórias e com uma porta na frente que fecha
# enquanto alguém usa); o lado direito inteiro é a cozinha.
# O resto (embaixo dos banheiros) é o corredor que liga a porta à cozinha.
func _construir_servico(solo: TileMapLayer) -> void:
	_interior = Banheiro.new()
	_interior.name = "Banheiro"
	add_child(_interior)

	# Última coluna dos banheiros é a divisória que separa a última cabine da cozinha.
	var fim_banheiros := VASOS * (LARGURA_CABINE + 1)
	for x in range(1, fim_banheiros + 1):
		for y in range(1, PROFUNDIDADE_CABINE + 1):
			solo.set_cell(Vector2i(x, y), FONTE, PISOS["BANHEIRO"])
	for x in range(fim_banheiros + 1, largura_tiles - 1):
		for y in range(1, altura_tiles - 1):
			solo.set_cell(Vector2i(x, y), FONTE, PISOS["COZINHA"])

	for i in VASOS:
		var inicio := 1 + i * (LARGURA_CABINE + 1)
		_colocar_divisoria(inicio + LARGURA_CABINE, 1, PROFUNDIDADE_CABINE)
		var vaso := Vaso.new()
		vaso.name = "Vaso%d" % (i + 1)
		# Encostado na parede de cima, no meio da cabine.
		vaso.position = Vector2((inicio + LARGURA_CABINE / 2.0) * TAMANHO_TILE, TAMANHO_TILE + Vaso.TAMANHO / 2.0)
		_interior.add_child(vaso)
		_interior.vasos.append(vaso)
		# Porta na frente da cabine, na última linha dela (alinhada à base das divisórias).
		var porta := PortaCabine.new()
		porta.name = "Porta%d" % (i + 1)
		porta.position = Vector2(inicio, PROFUNDIDADE_CABINE) * TAMANHO_TILE
		_interior.add_child(porta)
		porta.configurar(LARGURA_CABINE, (PROFUNDIDADE_CABINE - 1) * TAMANHO_TILE)
		vaso.porta = porta
	# Fila: começa no corredor, embaixo da última cabine, e cresce em direção à porta.
	_interior.cabeca = Vector2((fim_banheiros - 0.5) * TAMANHO_TILE, y_corredor())
	_interior.entrada_y = (PROFUNDIDADE_CABINE + 1.5) * TAMANHO_TILE


# Parede vertical de "linhas" tiles na coluna x, começando na linha y, com colisão.
func _colocar_divisoria(x: int, y: int, linhas: int) -> void:
	var escala := float(TAMANHO_TILE) / TAMANHO_TILE_ATLAS
	var topo := Vector2(x, y) * TAMANHO_TILE
	var altura := linhas * TAMANHO_TILE
	var meio_atlas := DIVISORIA.size.y - DIVISORIA_TOPO - DIVISORIA_BASE
	var meio_tela := altura - (DIVISORIA_TOPO + DIVISORIA_BASE) * escala
	var o := DIVISORIA.position
	var w := DIVISORIA.size.x
	var partes := [
		[Rect2(o, Vector2(w, DIVISORIA_TOPO)), 0.0, escala],
		[Rect2(o + Vector2(0, DIVISORIA_TOPO), Vector2(w, meio_atlas)), DIVISORIA_TOPO * escala, meio_tela / meio_atlas],
		[Rect2(o + Vector2(0, DIVISORIA.size.y - DIVISORIA_BASE), Vector2(w, DIVISORIA_BASE)), altura - DIVISORIA_BASE * escala, escala],
	]
	for parte in partes:
		var sprite := Sprite2D.new()
		sprite.texture = TILESET
		sprite.region_enabled = true
		sprite.region_rect = parte[0]
		sprite.region_filter_clip_enabled = true
		sprite.centered = false
		sprite.scale = Vector2(escala, parte[2])
		sprite.position = topo + Vector2(0, parte[1])
		_interior.add_child(sprite)

	var corpo := StaticBody2D.new()
	var forma := RectangleShape2D.new()
	forma.size = Vector2(TAMANHO_TILE, altura)
	var colisao := CollisionShape2D.new()
	colisao.shape = forma
	colisao.position = topo + Vector2(TAMANHO_TILE, altura) / 2.0
	corpo.add_child(colisao)
	_interior.add_child(corpo)


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
