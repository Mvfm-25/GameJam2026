extends Area2D

# Bancada de preparo: o maquinista solta uma tábua vazia aqui, ela vai para
# a bancada, é preparada por alguns segundos e vira comida preparada,
# pronta para ser levada a um passageiro com fome.

@export var tempo_preparo: float = 5.0
# Onde a tábua fica enquanto é preparada. Sem isso, usa o nó "../preparado".
@export var ponto_preparo: Node2D

# Barra de progresso desenhada acima da tábua.
const BARRA_TAMANHO := Vector2(32, 4)
const BARRA_DESLOCAMENTO := Vector2(0, -24)
const COR_FUNDO := Color(0.1, 0.1, 0.12, 0.85)
const COR_PROGRESSO := Color(0.45, 0.85, 0.35)

# Tábua que está ocupando a bancada (preparando ou pronta esperando ser pega).
var _item_na_bancada: Item = null
var _tempo_decorrido := 0.0

func _ready() -> void:
	# Barra de progresso acima dos itens.
	z_index = 10
	body_entered.connect(_ao_entrar_corpo)
	area_entered.connect(_ao_entrar_area)
	if ponto_preparo == null:
		ponto_preparo = get_node_or_null("../preparado")


func _ao_entrar_corpo(body: Node2D) -> void:
	_tentar_preparar(body as Item)


func _ao_entrar_area(area: Area2D) -> void:
	# A Area2D do item é filha do próprio Item.
	_tentar_preparar(area.get_parent() as Item)


func _process(delta: float) -> void:
	if _item_na_bancada != null and not is_instance_valid(_item_na_bancada):
		_item_na_bancada = null

	if _item_na_bancada == null:
		return

	if _item_na_bancada.em_preparo:
		_tempo_decorrido += delta
		# Balança a tábua enquanto corta.
		_item_na_bancada.rotation = sin(_tempo_decorrido * 25.0) * 0.06
		if _tempo_decorrido >= tempo_preparo:
			_item_na_bancada.terminar_preparo()
			print("Comida preparada!")
		queue_redraw()
	elif _item_na_bancada.carregado:
		# Comida pronta foi retirada: libera a bancada e vê se tem outra tábua esperando.
		_item_na_bancada = null
		queue_redraw()
		_procurar_tabua_esperando()


func _tentar_preparar(item: Item) -> void:
	if item == null or not is_instance_valid(item):
		return
	if not item.eh_tabua_vazia() or not item.disponivel():
		return
	if _item_na_bancada != null:
		print("Bancada ocupada, retire a comida pronta primeiro.")
		return

	_item_na_bancada = item
	_tempo_decorrido = 0.0
	var posicao := ponto_preparo.global_position if ponto_preparo != null else global_position
	item.iniciar_preparo(posicao)
	queue_redraw()
	print("Preparando comida...")


# Uma tábua pode ter sido solta aqui enquanto a bancada estava ocupada.
func _procurar_tabua_esperando() -> void:
	for area in get_overlapping_areas():
		_tentar_preparar(area.get_parent() as Item)
		if _item_na_bancada != null:
			return


func _draw() -> void:
	if _item_na_bancada == null or not is_instance_valid(_item_na_bancada):
		return
	if not _item_na_bancada.em_preparo:
		return
	var centro := to_local(_item_na_bancada.global_position) + BARRA_DESLOCAMENTO
	var fundo := Rect2(centro - BARRA_TAMANHO / 2.0, BARRA_TAMANHO)
	draw_rect(fundo.grow(1), COR_FUNDO)
	var progresso := clampf(_tempo_decorrido / tempo_preparo, 0.0, 1.0)
	draw_rect(Rect2(fundo.position, Vector2(BARRA_TAMANHO.x * progresso, BARRA_TAMANHO.y)), COR_PROGRESSO)
