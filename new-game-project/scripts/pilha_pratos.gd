extends Interativo
class_name PilhaPratos

# Pilha infinita de pratos (tábuas vazias) na cozinha: com as mãos livres, o
# interagir põe um prato novo nas mãos do maquinista. O prato some quando o
# passageiro come, então nada se acumula no trem.

@export var cena_item: PackedScene = preload("res://cenas/item.tscn")

# pilhaPratos.png não tem a célula com contorno: o destaque clareia o sprite.
const COR_DESTAQUE := Color(1.35, 1.35, 1.35)

static var _contador := 0

var _escala_base := Vector2.ONE


func _ready() -> void:
	super()
	_escala_base = _sprite.scale


func interage() -> void:
	var maquinista := _maquinista_proximo()
	if maquinista == null or maquinista.carregando:
		return
	_contador += 1
	var prato := cena_item.instantiate() as Item
	prato.nome = "prato_%d" % _contador
	prato.classe = Item.CLASSE_TABUA_VAZIA
	prato.volta_para_origem = false
	get_parent().add_child(prato)
	prato.global_position = global_position
	maquinista.pega_item(prato)
	# Pulinho da pilha para mostrar que um prato saiu.
	_sprite.scale = _escala_base
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", _escala_base * Vector2(1.1, 0.9), 0.06)
	tween.tween_property(_sprite, "scale", _escala_base, 0.1)


func _maquinista_proximo() -> Maquinista:
	for corpo in _area.get_overlapping_bodies():
		if corpo is Maquinista:
			return corpo
	return null


func _destaca(ligado: bool) -> void:
	_sprite.modulate = COR_DESTAQUE if ligado else Color.WHITE
