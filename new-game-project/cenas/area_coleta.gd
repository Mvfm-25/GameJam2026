
extends Area2D

@export var cena_carvao: PackedScene
@export var tempo_reaparecer := 5.0

var carvao_atual: Item = null
var jogador_perto: Maquinista = null
var timer: Timer


func _ready() -> void:
	body_entered.connect(_ao_entrar)
	body_exited.connect(_ao_sair)

	timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = tempo_reaparecer
	timer.timeout.connect(_criar_carvao)
	add_child(timer)

	_criar_carvao()


func _ao_entrar(body: Node2D) -> void:
	if body is Maquinista:
		jogador_perto = body


func _ao_sair(body: Node2D) -> void:
	if body == jogador_perto:
		jogador_perto = null


func _criar_carvao() -> void:
	if is_instance_valid(carvao_atual):
		return

	if cena_carvao == null:
		push_warning("Configure a cena do carvão no Inspector.")
		return

	carvao_atual = cena_carvao.instantiate() as Item

	if carvao_atual == null:
		push_error("A cena precisa conter um objeto da classe Item.")
		return

	get_tree().current_scene.add_child(carvao_atual)
	carvao_atual.global_position = global_position


func _process(_delta: float) -> void:
	if not is_instance_valid(carvao_atual):
		return

	if jogador_perto == null:
		return

	if carvao_atual.carregado:
		return

	if not jogador_perto.itens_proximos.has(carvao_atual):
		jogador_perto.itens_proximos.append(carvao_atual)

	# O jogador existente já trata a tecla "interagir".
	# A coleta é feita pelo Maquinista.
	if jogador_perto.itemAtual == carvao_atual:
		carvao_atual = null
		timer.start()
