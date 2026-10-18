
extends Area2D

@export var classe_aceita: String = "Comida"
@export var tempo_devolucao: float = 5.0

var itens_em_preparo: Array[Item] = []

func _ready() -> void:
	body_entered.connect(_ao_entrar_corpo)
	area_entered.connect(_ao_entrar_area)

	print("Forno iniciado: ", name)
	print("Monitoring: ", monitoring)


func _ao_entrar_corpo(body: Node2D) -> void:
	var item := body as Item
	if item != null:
		_preparar_item(item)


func _ao_entrar_area(area: Area2D) -> void:
	# A Area2D do item é filha do próprio Item.
	var item := area.get_parent() as Item
	if item != null:
		_preparar_item(item)


func _preparar_item(item: Item) -> void:
	if not is_instance_valid(item):
		return

	if item in itens_em_preparo:
		return

	print("Item detectado: ", item.nome, " | Classe: ", item.classe)

	if item.classe != classe_aceita:
		print("Classe não aceita pelo forno.")
		return

	if item.carregado:
		print("Item ainda está sendo carregado.")
		return

	itens_em_preparo.append(item)

	print("Carvão colocado no forno!")

	# Esconde o item enquanto ele está no forno.
	item.carregado = true
	item.visible = false
	item.get_node("CollisionShape2D").set_deferred("disabled", true)

	_devolve_tempo(item)


func _devolve_tempo(item: Item) -> void:
	await get_tree().create_timer(tempo_devolucao).timeout

	if not is_instance_valid(item):
		return

	itens_em_preparo.erase(item)

	# Devolve o item original à geladeira.
	item.ser_solto($"../geladeira".global_position)

	# Cria ou posiciona outro item no preparo
	item.criar_item($"../preparado".global_position)
	print("Carvão devolvido pelo forno!")
