
extends Area2D

@export var classe_aceita: String = "Carvao"

var jogador_perto: Maquinista = null
var quantidade_carvao: int = 0


func _ready() -> void:
	body_entered.connect(_ao_entrar)
	body_exited.connect(_ao_sair)


func _ao_entrar(body: Node2D) -> void:
	if body is Maquinista:
		jogador_perto = body


func _ao_sair(body: Node2D) -> void:
	if body == jogador_perto:
		jogador_perto = null


func _process(_delta: float) -> void:
	if jogador_perto == null:
		return

	if not jogador_perto.carregando:
		return

	var item: Item = jogador_perto.itemAtual

	if item == null:
		return

	if item.classe != classe_aceita:
		return

	# O forno reconhece que o jogador está carregando carvão.
	# A tecla de interação ainda é tratada pelo Maquinista.
	if Input.is_action_just_pressed("interagir"):
		_receber_carvao(item)


func _receber_carvao(item: Item) -> void:
	# Confirma que o item ainda é o que o jogador está carregando.
	if jogador_perto == null:
		return

	if jogador_perto.itemAtual != item:
		return

	jogador_perto.itemAtual = null
	jogador_perto.carregando = false
	jogador_perto._atualiza_sprite()

	item.queue_free()

	quantidade_carvao += 1
	print("Carvão colocado no forno: ", quantidade_carvao)
