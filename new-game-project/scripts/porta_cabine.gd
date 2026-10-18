@tool
extends Node2D
class_name PortaCabine

# Porta da frente de uma cabine do banheiro (vagão de serviço).
# No tileset_v1.png, o tile (20, 4) é a porta fechada e o (20, 5) a mesma porta aberta,
# vista de lado e encostada no batente direito. A porta fechada é esticada para cobrir a
# frente inteira da cabine; as bordas (com a maçaneta) não esticam.
# Fica aberta com a cabine livre, fecha quando o passageiro chega ao vaso e abre quando
# ele sai. Fechada, ninguém passa. Não fecha com o maquinista lá dentro.

const TILESET := preload("res://assets/tileset/tileset_v1.png")
const TAMANHO_TILE := 32
const TAMANHO_TILE_ATLAS := 64
const FECHADA := Rect2(1280, 256, 64, 64)
# Só o desenho da porta aberta, dentro do tile (20, 5).
const ABERTA := Rect2(1324, 336, 20, 48)
# Px do atlas, de cada lado da porta fechada, que não são esticados.
const BORDA := 16

var fechada := false

var _largura := 0.0
var _fechada : Node2D
var _aberta : Sprite2D
var _colisao : CollisionShape2D
var _dentro : Area2D
# Pediram para fechar, mas a porta espera o maquinista sair da cabine.
var _quer_fechar := false


# O Vagão chama logo após criar a porta. A origem é o canto de cima, à esquerda, da linha
# de tiles da porta; "fundo" é a altura (px) da cabine acima dela.
func configurar(largura_tiles : int, fundo : float) -> void:
	_largura = largura_tiles * TAMANHO_TILE
	var escala := float(TAMANHO_TILE) / TAMANHO_TILE_ATLAS

	# Porta fechada: borda esquerda, meio esticado e borda direita.
	_fechada = Node2D.new()
	var meio_atlas := FECHADA.size.x - 2 * BORDA
	var meio_tela := _largura - 2 * BORDA * escala
	var o := FECHADA.position
	var h := FECHADA.size.y
	var partes := [
		[Rect2(o, Vector2(BORDA, h)), 0.0, escala],
		[Rect2(o + Vector2(BORDA, 0), Vector2(meio_atlas, h)), BORDA * escala, meio_tela / meio_atlas],
		[Rect2(o + Vector2(FECHADA.size.x - BORDA, 0), Vector2(BORDA, h)), _largura - BORDA * escala, escala],
	]
	for parte in partes:
		var sprite := Sprite2D.new()
		sprite.texture = TILESET
		sprite.region_enabled = true
		sprite.region_rect = parte[0]
		sprite.region_filter_clip_enabled = true
		sprite.centered = false
		sprite.scale = Vector2(parte[2], escala)
		sprite.position = Vector2(parte[1], 0)
		_fechada.add_child(sprite)
	add_child(_fechada)

	# Porta aberta: fica no último tile, encostada na divisória da direita.
	_aberta = Sprite2D.new()
	_aberta.texture = TILESET
	_aberta.region_enabled = true
	_aberta.region_rect = ABERTA
	_aberta.centered = false
	_aberta.scale = Vector2.ONE * escala
	_aberta.region_filter_clip_enabled = true
	_aberta.position = Vector2(_largura - TAMANHO_TILE, 0) + (ABERTA.position - Vector2(1280, 320)) * escala
	add_child(_aberta)

	var corpo := StaticBody2D.new()
	_colisao = CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = Vector2(_largura, TAMANHO_TILE)
	_colisao.shape = forma
	_colisao.position = Vector2(_largura, TAMANHO_TILE) / 2.0
	corpo.add_child(_colisao)
	add_child(corpo)

	if not Engine.is_editor_hint():
		# Cabine inteira (com a linha da porta), para saber se o maquinista está lá dentro.
		_dentro = Area2D.new()
		var forma_dentro := RectangleShape2D.new()
		forma_dentro.size = Vector2(_largura, fundo + TAMANHO_TILE)
		var colisao_dentro := CollisionShape2D.new()
		colisao_dentro.shape = forma_dentro
		colisao_dentro.position = Vector2(_largura / 2.0, (TAMANHO_TILE - fundo) / 2.0)
		_dentro.add_child(colisao_dentro)
		add_child(_dentro)
	_aplica(false)


# Fecha assim que o maquinista não estiver mais na cabine.
func fechar() -> void:
	_quer_fechar = true
	while _quer_fechar and _maquinista_dentro():
		await get_tree().create_timer(0.2).timeout
		if not is_inside_tree():
			return
	if _quer_fechar:
		_aplica(true)


func abrir() -> void:
	_quer_fechar = false
	_aplica(false)


func _maquinista_dentro() -> bool:
	if _dentro == null:
		return false
	for corpo in _dentro.get_overlapping_bodies():
		if corpo is Maquinista:
			return true
	return false


func _aplica(valor : bool) -> void:
	fechada = valor
	_fechada.visible = valor
	_aberta.visible = not valor
	_colisao.set_deferred("disabled", not valor)
