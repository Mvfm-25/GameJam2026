extends StaticBody2D

# Forno da cozinha: o maquinista solta uma tábua vazia na AreaPreparo,
# ela entra no forno, é preparada por alguns segundos e sai pronta
# na frente do forno (marcador Saida), pronta para ir a um passageiro.

@export var tempo_preparo: float = 5.0

# Barra de progresso desenhada acima do forno.
const BARRA_TAMANHO := Vector2(32, 4)
const BARRA_POSICAO := Vector2(0, -36)
const COR_FUNDO := Color(0.1, 0.1, 0.12, 0.85)
const COR_PROGRESSO := Color(0.45, 0.85, 0.35)

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _area_preparo: Area2D = $AreaPreparo
@onready var _saida: Marker2D = $Saida

# Tábua dentro do forno sendo preparada.
var _item_no_forno: Item = null
# Comida pronta esperando na frente do forno.
var _item_na_saida: Item = null
var _tempo_decorrido := 0.0

func _ready() -> void:
	_area_preparo.body_entered.connect(_ao_entrar_corpo)
	_area_preparo.area_entered.connect(_ao_entrar_area)
	_sprite.play("parado")


func _ao_entrar_corpo(body: Node2D) -> void:
	_tentar_preparar(body as Item)


func _ao_entrar_area(area: Area2D) -> void:
	# A Area2D do item é filha do próprio Item.
	_tentar_preparar(area.get_parent() as Item)


func _process(delta: float) -> void:
	if _item_no_forno != null and not is_instance_valid(_item_no_forno):
		_item_no_forno = null
		_sprite.play("parado")
	if _item_na_saida != null and (not is_instance_valid(_item_na_saida) or _item_na_saida.carregado):
		# Comida pronta foi retirada: libera a saída e vê se tem outra tábua esperando.
		_item_na_saida = null
		_procurar_tabua_esperando()

	if _item_no_forno == null:
		return

	_tempo_decorrido += delta
	if _tempo_decorrido >= tempo_preparo and _item_na_saida == null:
		_item_na_saida = _item_no_forno
		_item_no_forno = null
		_item_na_saida.terminar_preparo(_saida.global_position)
		_sprite.play("parado")
		print("Comida preparada!")
		_procurar_tabua_esperando()
	queue_redraw()


func _forno_livre() -> bool:
	return _item_no_forno == null


func _tentar_preparar(item: Item) -> void:
	if item == null or not is_instance_valid(item):
		return
	if not item.eh_tabua_vazia() or not item.disponivel():
		return
	if not _forno_livre():
		print("Forno ocupado, espere a comida ficar pronta.")
		return

	_item_no_forno = item
	_tempo_decorrido = 0.0
	item.iniciar_preparo()
	_sprite.play("preparando")
	queue_redraw()
	print("Preparando comida...")


# Uma tábua pode ter sido solta na área enquanto o forno estava ocupado.
func _procurar_tabua_esperando() -> void:
	for area in _area_preparo.get_overlapping_areas():
		if not _forno_livre():
			return
		_tentar_preparar(area.get_parent() as Item)


func _draw() -> void:
	if _item_no_forno == null:
		return
	var fundo := Rect2(BARRA_POSICAO - BARRA_TAMANHO / 2.0, BARRA_TAMANHO)
	draw_rect(fundo.grow(1), COR_FUNDO)
	var progresso := clampf(_tempo_decorrido / tempo_preparo, 0.0, 1.0)
	draw_rect(Rect2(fundo.position, Vector2(BARRA_TAMANHO.x * progresso, BARRA_TAMANHO.y)), COR_PROGRESSO)
