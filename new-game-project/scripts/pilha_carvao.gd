extends Interativo
class_name PilhaCarvao

# Pilha de carvão infinita ao lado da fornalha: cada interação joga uma pá de
# carvão na fornalha mais próxima.

# Segundos de combustível que cada pá acrescenta.
@export var segundos_por_pa := 60.0

var _escala_base := Vector2.ONE


func _ready() -> void:
	super()
	_escala_base = _sprite.scale


func interage() -> void:
	var fornalha := _fornalha_mais_proxima()
	if fornalha == null:
		print("Nenhuma fornalha perto da pilha de carvão.")
		return
	fornalha.abastece(segundos_por_pa)
	# Pulinho da pilha para mostrar que a pá foi tirada.
	_sprite.scale = _escala_base
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", _escala_base * Vector2(1.1, 0.9), 0.06)
	tween.tween_property(_sprite, "scale", _escala_base, 0.1)


func _fornalha_mais_proxima() -> Fornalha:
	var melhor: Fornalha = null
	for f in get_tree().get_nodes_in_group(Fornalha.GRUPO):
		if melhor == null or global_position.distance_to(f.global_position) < global_position.distance_to(melhor.global_position):
			melhor = f
	return melhor
