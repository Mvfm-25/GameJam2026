extends Node2D
class_name ObjetosChao

# Objetos de cenário (pedras, gramas...) que passam de vez em quando pelo chão, na parte de
# cima do trem, correndo para a direita junto com o chão e os trilhos. Ficam atrás dos
# vagões e à frente do chão. Use um nó destes por folha de imagem.
#
# A folha é uma fileira de objetos, cada um numa coluna de largura_arte x altura_arte px.

@export var textura : Texture2D
@export var largura_arte := 64
@export var altura_arte := 128
# Quantos objetos diferentes a folha tem (colunas lado a lado).
@export var quantidade := 3
# Arte no dobro da resolução, igual ao resto do jogo.
@export var escala := 0.5
# Chance de cada objeto nascer espelhado.
@export_range(0.0, 1.0) var chance_espelhar := 0.5

# Tempo, em segundos, entre um objeto e o próximo (sorteado a cada vez).
@export var intervalo_min := 2.0
@export var intervalo_max := 7.0
# Distância (px) entre o topo do trem e a base do objeto, sorteada nesta faixa.
@export var distancia_min := 24.0
@export var distancia_max := 220.0
# Usada só se não houver um nó Trilhos irmão (senão segue a velocidade dos trilhos).
@export var velocidade := 160.0
@export var ativo := true

var _espera := 0.0
var _trilhos : Trilhos


func _ready() -> void:
	_trilhos = get_parent().get_node_or_null("Trilhos") as Trilhos
	_espera = randf_range(0.0, intervalo_min)


func _process(delta: float) -> void:
	if not ativo or Engine.is_editor_hint() or textura == null:
		return
	var v := _velocidade()
	var vista := _vista()
	for objeto in get_children():
		objeto.position.x += v * delta
		if objeto.position.x > vista.end.x + largura_arte * escala:
			objeto.queue_free()
	_espera -= delta
	if _espera <= 0.0:
		_espera = randf_range(intervalo_min, intervalo_max)
		_cria_objeto(vista)


# Mesma velocidade do chão, para os objetos parecerem parados nele.
func _velocidade() -> float:
	if _trilhos != null:
		return _trilhos.velocidade if _trilhos.ativo else 0.0
	return velocidade


# Área do mundo que a câmera está mostrando agora.
func _vista() -> Rect2:
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()


# Nasce logo fora da tela, à esquerda, acima do trem.
func _cria_objeto(vista: Rect2) -> void:
	var topo := _topo_do_trem()
	if is_nan(topo):
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = textura
	atlas.region = Rect2(randi() % quantidade * largura_arte, 0, largura_arte, altura_arte)
	var objeto := Sprite2D.new()
	objeto.texture = atlas
	objeto.centered = false
	objeto.scale = Vector2.ONE * escala
	objeto.flip_h = randf() < chance_espelhar
	objeto.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	objeto.position = Vector2(
		vista.position.x - largura_arte * escala - 8.0,
		topo - randf_range(distancia_min, distancia_max) - altura_arte * escala)
	add_child(objeto)


# y do topo do trem (os vagões são os irmãos que têm largura_tiles).
func _topo_do_trem() -> float:
	for filho in get_parent().get_children():
		if filho is Node2D and "largura_tiles" in filho:
			return filho.global_position.y
	return NAN
