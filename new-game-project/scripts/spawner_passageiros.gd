extends Node2D
class_name SpawnerPassageiros

# Fica no nó "Passageiros" da cena principal.
# Ao começar, cria um passageiro em cada cadeira com "com_passageiro" marcado no inspetor.
# Os passageiros viram filhos deste nó, então o Diretor continua achando todos eles.

const CENA_PASSAGEIRO := preload("res://cenas/passageiro.tscn")
const SCRIPT_PASSAGEIRO := preload("res://scripts/passageiro.gd")


func _ready() -> void:
	# Cadeiras que já têm um passageiro colocado à mão não ganham outro.
	var ja_ocupadas := []
	for p in get_children():
		if p is Passageiro and p.cadeira != null:
			ja_ocupadas.append(p.cadeira)

	for c in get_tree().get_nodes_in_group("cadeiras"):
		if c.com_passageiro and not ja_ocupadas.has(c):
			_cria_passageiro(c)


func _cria_passageiro(c: Cadeira) -> void:
	var p := CENA_PASSAGEIRO.instantiate()
	p.set_script(SCRIPT_PASSAGEIRO)
	p.cadeira = c
	p.global_position = c.global_position
	add_child(p)
