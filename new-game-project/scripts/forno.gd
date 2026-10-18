

extends Area2D

# Fornalha da sala das máquinas: consome o carvão e os cadáveres dos passageiros
# que o maquinista solta na frente dela.
@export var classes_aceitas: Array[String] = ["Carvao", "Cadaver"]

func _ready() -> void:
	body_entered.connect(_ao_entrar_corpo)
	area_entered.connect(_ao_entrar_area)

	print("Forno iniciado: ", name)
	print("Monitoring: ", monitoring)


func _ao_entrar_corpo(body: Node2D) -> void:
	print("Forno detectou corpo: ", body.name)
	_verificar_item(body)


func _ao_entrar_area(area: Area2D) -> void:
	print("Forno detectou área: ", area.name)

	# A Area2D do item é filha do próprio Item.
	var item := area.get_parent() as Item

	if item != null:
		_consumir_item(item)


func _verificar_item(body: Node2D) -> void:
	var item := body as Item

	if item != null:
		_consumir_item(item)


func _consumir_item(item: Item) -> void:
	print("Item detectado: ", item.nome, " | Classe: ", item.classe)

	if not classes_aceitas.has(item.classe):
		print("Classe não aceita pelo forno.")
		return

	if item.carregado:
		print("Item ainda está sendo carregado.")
		return

	print("Fornalha consumiu: ", item.classe)
	item.queue_free()
