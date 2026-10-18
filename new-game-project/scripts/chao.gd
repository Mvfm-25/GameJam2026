@tool
extends Node2D
class_name Chao

# Chão logo abaixo dos trilhos. Filho do nó Trilhos: anda junto com eles, para a direita.
# chao.png tem 4 tiles de 16 px, de cima para baixo: bloco padrão, borda inferior,
# o que fica logo abaixo da borda e o preenchimento de tudo que vem depois.

const TEXTURA := preload("res://assets/tileset/chao.png")
const TILE_ARTE := 16

# Cada tile da imagem como textura própria: a repetição de uma região maior que a imagem
# repetiria a imagem inteira (os 4 tiles), não só o tile da faixa.
var _tiles : Array[Texture2D] = []

# Tamanho em que o chão é desenhado (1 = pixel da arte). Precisa dividir 32 (o tile dos
# trilhos), senão a repetição ao andar mostra um salto.
@export var escala := 2.0
# Quantas linhas de bloco padrão ficam abaixo dos trilhos, antes da borda.
@export var linhas_bloco_padrao := 1
# Quantas linhas de bloco padrão sobem acima dos trilhos, para o chão chegar ao topo da tela.
@export var linhas_acima := 20
# Quantas linhas de preenchimento descem abaixo da borda (cobrem o resto da tela).
@export var linhas_fundo := 40


# O nó Trilhos chama com a largura (px) e a altura (px) dos trilhos. O chão é desenhado atrás
# deles: o bloco padrão começa linhas_acima acima do topo dos trilhos (y = 0 neste nó)
# e desce por trás dos trilhos até a borda, que fica logo abaixo deles.
func construir(largura: float, altura_trilhos: float) -> void:
	for filho in get_children():
		filho.queue_free()
	var largura_arte := largura / escala
	var tile := TILE_ARTE * escala
	var linhas_trilhos := int(round(altura_trilhos / tile))
	var y := -linhas_acima * tile
	y = _faixa(0, linhas_acima + linhas_trilhos + linhas_bloco_padrao, largura_arte, y)
	y = _faixa(1, 1, largura_arte, y)
	y = _faixa(2, 1, largura_arte, y)
	_faixa(3, linhas_fundo, largura_arte, y)


func _tile(indice: int) -> Texture2D:
	if _tiles.is_empty():
		var imagem := TEXTURA.get_image()
		for i in imagem.get_height() / TILE_ARTE:
			_tiles.append(ImageTexture.create_from_image(imagem.get_region(Rect2i(0, i * TILE_ARTE, TILE_ARTE, TILE_ARTE))))
	return _tiles[indice]


# Uma faixa de `linhas` tiles do tile `indice` da imagem; devolve o y logo abaixo dela.
func _faixa(indice: int, linhas: int, largura_arte: float, y: float) -> float:
	if linhas <= 0:
		return y
	var sprite := Sprite2D.new()
	sprite.texture = _tile(indice)
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, largura_arte, linhas * TILE_ARTE)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * escala
	sprite.position = Vector2(0, y)
	add_child(sprite)
	return y + linhas * TILE_ARTE * escala
