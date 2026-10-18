@tool
extends Node2D
class_name Banheiro

# Banheiros do vagão de serviço: guarda os vasos das cabines e a fila de passageiros.
# Criado pelo trem.gd (classe SERVICO). A fila em si anda pela linha da RedeCaminhos:
# a frente da fila é o último ponto da linha (cabeca).

# Passageiros na fila, na ordem de chegada. O primeiro é o próximo a usar um vaso.
var fila : Array = []
var vasos : Array[Vaso] = []
# Frente da fila, em coordenadas locais (o Banheiro fica na origem do vagão).
var cabeca := Vector2.ZERO
# Altura (local) do corredor logo abaixo das cabines, por onde se entra em cada uma.
var entrada_y := 0.0


func _enter_tree() -> void:
	add_to_group("banheiros")


func cabeca_global() -> Vector2:
	return to_global(cabeca)


# Ponto do corredor bem na frente da cabine do vaso.
func entrada_global(vaso : Vaso) -> Vector2:
	return to_global(Vector2(vaso.position.x, entrada_y))


# Primeiro vaso destrancado e desentupido, ou null se todos estão em uso.
func vaso_livre() -> Vaso:
	for v in vasos:
		if is_instance_valid(v) and v.esta_livre():
			return v
	return null
