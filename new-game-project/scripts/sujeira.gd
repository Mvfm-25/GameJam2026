extends Area2D
class_name Sujeira

const TEXTURA := preload("res://assets/Outros/Sujeiras.png")
const TAMANHO_QUADRO := 64
# Sujeiras.png tem 4 colunas x 4 linhas. Cada sujeira ocupa duas colunas lado a lado:
# a normal e, ao lado, a mesma com o contorno branco (mostrado quando dá para limpar).
const COLUNAS_SUJEIRA := 2
const SUJEIRAS_POR_LINHA := 2
const LINHAS := 4
# Desenhada na metade do tamanho, igual aos tiles do vagão.
const ESCALA := 0.5
# Raio em que o maquinista consegue limpar.
const RAIO_LIMPEZA := 20.0

# Maquinista que está perto (para destacar a sujeira que ele vai limpar).
var _maquinista : Maquinista = null
var _atlas : AtlasTexture
var _coluna := 0
var _linha := 0
var _destacada := false

func _ready() -> void:
	var tipo := randi() % (SUJEIRAS_POR_LINHA * LINHAS)
	_coluna = (tipo % SUJEIRAS_POR_LINHA) * COLUNAS_SUJEIRA
	_linha = tipo / SUJEIRAS_POR_LINHA
	_atlas = AtlasTexture.new()
	_atlas.atlas = TEXTURA
	_atualiza_quadro()
	var sprite := Sprite2D.new()
	sprite.texture = _atlas
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

func _atualiza_quadro() -> void:
	var coluna := _coluna + (1 if _destacada else 0)
	_atlas.region = Rect2(coluna * TAMANHO_QUADRO, _linha * TAMANHO_QUADRO, TAMANHO_QUADRO, TAMANHO_QUADRO)

# Maquinista chegou perto, pode limpar esta sujeira
func _ao_entrar_area(body: Node2D) -> void:
	if body is Maquinista:
		_maquinista = body
		if not body.sujeiras_proximas.has(self):
			body.sujeiras_proximas.append(self)

func _ao_sair_area(body: Node2D) -> void:
	if body is Maquinista:
		body.sujeiras_proximas.erase(self)
		_maquinista = null
		_define_destaque(false)

# Só a sujeira mais próxima ganha o contorno, que é a que a tecla de limpar remove.
func _process(_delta: float) -> void:
	if _maquinista == null:
		return
	var mais_proxima := true
	var distancia := global_position.distance_to(_maquinista.global_position)
	for outra in _maquinista.sujeiras_proximas:
		if outra != self and outra.global_position.distance_to(_maquinista.global_position) < distancia:
			mais_proxima = false
			break
	_define_destaque(mais_proxima)

func _define_destaque(valor: bool) -> void:
	if valor != _destacada:
		_destacada = valor
		_atualiza_quadro()

# Remove a sujeira do mapa
func limpar() -> void:
	var diretor := get_tree().current_scene as Diretor
	if diretor != null :
		diretor.sujeiras.erase(self)
	for body in get_overlapping_bodies() :
		if body is Maquinista :
			body.sujeiras_proximas.erase(self)
	queue_free()
