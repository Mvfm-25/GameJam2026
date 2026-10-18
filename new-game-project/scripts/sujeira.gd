extends Area2D
class_name Sujeira

const TEXTURA := preload("res://assets/Outros/Sujeiras.png")
const TAMANHO_QUADRO := 64
# Linha de cima do Sujeiras.png: gosma, casca de banana, migalhas e mancha.
const QUANTIDADE_TIPOS := 4
# Desenhada na metade do tamanho, igual aos tiles do vagão.
const ESCALA := 0.5
# Raio em que o maquinista consegue limpar.
const RAIO_LIMPEZA := 20.0

func _ready() -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = TEXTURA
	atlas.region = Rect2(randi() % QUANTIDADE_TIPOS * TAMANHO_QUADRO, 0, TAMANHO_QUADRO, TAMANHO_QUADRO)
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.scale = Vector2.ONE * ESCALA
	add_child(sprite)

	var forma := CircleShape2D.new()
	forma.radius = RAIO_LIMPEZA
	var colisao := CollisionShape2D.new()
	colisao.shape = forma
	add_child(colisao)

	body_entered.connect(_ao_entrar_area)
	body_exited.connect(_ao_sair_area)

	var diretor := get_tree().current_scene as Diretor
	if diretor != null :
		diretor.sujeiras.append(self)

# Maquinista chegou perto, pode limpar esta sujeira
func _ao_entrar_area(body: Node2D) -> void:
	if body is Maquinista and not body.sujeiras_proximas.has(self):
		body.sujeiras_proximas.append(self)

func _ao_sair_area(body: Node2D) -> void:
	if body is Maquinista:
		body.sujeiras_proximas.erase(self)

# Remove a sujeira do mapa
func limpar() -> void:
	var diretor := get_tree().current_scene as Diretor
	if diretor != null :
		diretor.sujeiras.erase(self)
	for body in get_overlapping_bodies() :
		if body is Maquinista :
			body.sujeiras_proximas.erase(self)
	queue_free()
