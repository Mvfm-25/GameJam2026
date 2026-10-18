extends Node2D

# Ponto de respawn infinito de tábuas vazias: sempre mantém uma tábua aqui.
# Quando o maquinista pega a tábua, outra aparece depois de tempo_respawn.

@export var cena_item: PackedScene = preload("res://cenas/item.tscn")
@export var tempo_respawn: float = 1.0

var _tabua: Item = null
var _contador := 0

func _ready() -> void:
	_criar_tabua.call_deferred()


func _process(_delta: float) -> void:
	if _tabua == null:
		return
	# A tábua saiu do lugar (foi pega ou sumiu): agenda outra.
	if not is_instance_valid(_tabua) or _tabua.carregado or not _tabua.eh_tabua_vazia():
		_tabua = null
		get_tree().create_timer(tempo_respawn).timeout.connect(_criar_tabua)


func _criar_tabua() -> void:
	_contador += 1
	var tabua := cena_item.instantiate() as Item
	tabua.nome = "tabua_%d" % _contador
	tabua.classe = Item.CLASSE_TABUA_VAZIA
	# Tábuas do respawn somem quando a comida é consumida, para não acumularem.
	tabua.volta_para_origem = false
	get_parent().add_child(tabua)
	tabua.global_position = global_position
	_tabua = tabua
