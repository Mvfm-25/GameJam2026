@tool
extends Node2D
class_name Trilhos

# Primeira camada do cenário: os trilhos que correm por baixo do trem, para a direita, em looping.
# Têm a altura do trem: trilhoSuperior (trilho de cima), trilho (dormentes) repetido
# no meio e trilhoInferior (trilho de baixo). Ficam atrás dos vagões.

const SUPERIOR := preload("res://assets/tileset/trilhoSuperior.png")
const MEIO := preload("res://assets/tileset/trilho.png")
const INFERIOR := preload("res://assets/tileset/trilhoInferior.png")
const TAMANHO_TILE := 32
const TAMANHO_TILE_ATLAS := 64

# Velocidade com que os trilhos correm para a direita, em px por segundo.
@export var velocidade := 160.0
@export var ativo := true
# Quantos tiles os trilhos passam além do primeiro e do último vagão.
@export var margem_tiles := 40
# Quantos tiles a menos de altura os trilhos têm em relação ao trem, tirados de cima
# (o trilho de cima desce junto). Útil para testes.
@export var linhas_a_menos_em_cima := 1

var _deslocamento := 0.0
var _base_x := 0.0


func _ready() -> void:
	_construir()


func _process(delta: float) -> void:
	if not ativo or Engine.is_editor_hint():
		return
	# O desenho se repete a cada tile: ao andar um tile, volta ao início sem salto visível.
	_deslocamento = fposmod(_deslocamento + velocidade * delta, TAMANHO_TILE)
	position.x = _base_x + _deslocamento


func _construir() -> void:
	# Só as faixas dos trilhos (o chão, filho Chao, se reconstrói sozinho).
	for filho in get_children():
		if filho is Sprite2D:
			filho.queue_free()
	var vagoes := _vagoes()
	if vagoes.is_empty():
		return
	var esquerda := INF
	var direita := -INF
	for vagao in vagoes:
		esquerda = minf(esquerda, vagao.position.x)
		direita = maxf(direita, vagao.position.x + vagao.largura_tiles * TAMANHO_TILE)

	# Um tile a mais de cada lado, já que o desenho anda até um tile para a direita.
	var primeira : int = int(floor(esquerda / TAMANHO_TILE)) - margem_tiles - 1
	var ultima : int = int(ceil(direita / TAMANHO_TILE)) + margem_tiles
	var colunas : int = ultima - primeira
	# O vagão tem altura_tiles linhas, mais a lateral externa embaixo.
	var linhas : int = vagoes[0].altura_tiles + 1 - linhas_a_menos_em_cima

	_base_x = primeira * TAMANHO_TILE
	position = Vector2(_base_x, vagoes[0].position.y + linhas_a_menos_em_cima * TAMANHO_TILE)
	_deslocamento = 0.0

	_camada(SUPERIOR, 0, 1, colunas)
	_camada(MEIO, 1, linhas - 2, colunas)
	_camada(INFERIOR, linhas - 1, 1, colunas)

	# O chão fica atrás dos trilhos, do topo da tela até abaixo deles, e anda junto com eles.
	var chao := get_node_or_null("Chao") as Chao
	if chao != null:
		chao.construir(colunas * TAMANHO_TILE, linhas * TAMANHO_TILE)


# Uma faixa de `linhas` tiles de altura, repetindo a imagem pela largura toda.
func _camada(textura: Texture2D, linha: int, linhas: int, colunas: int) -> void:
	if linhas <= 0:
		return
	var sprite := Sprite2D.new()
	sprite.texture = textura
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, colunas * TAMANHO_TILE_ATLAS, linhas * TAMANHO_TILE_ATLAS)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * TAMANHO_TILE / TAMANHO_TILE_ATLAS
	sprite.position = Vector2(0, linha * TAMANHO_TILE)
	add_child(sprite)


# Os vagões são os irmãos que têm largura_tiles (o script trem.gd).
func _vagoes() -> Array:
	var lista := []
	var pai := get_parent()
	if pai == null:
		return lista
	for filho in pai.get_children():
		if filho is Node2D and "largura_tiles" in filho:
			lista.append(filho)
	return lista
