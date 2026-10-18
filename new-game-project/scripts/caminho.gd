extends Path2D
class_name Caminho

# Caminho que os passageiros percorrem quando levantam para passear.
# Para criar um novo: adicione um Path2D (dentro do nó "Caminhos" da cena principal),
# coloque este script nele e desenhe os pontos da curva no editor.
# O passageiro vai até a ponta mais próxima, anda até a outra ponta, volta
# e então retorna para a cadeira.

# Chance relativa deste caminho ser escolhido (0 desativa).
@export_range(0.0, 10.0, 0.1) var peso := 1.0

func _enter_tree() -> void:
	add_to_group("caminhos")

# Pontos da curva em coordenadas globais, do primeiro ao último.
func pontos_globais() -> PackedVector2Array:
	var pontos := PackedVector2Array()
	if curve == null :
		return pontos
	for p in curve.get_baked_points() :
		pontos.append(global_transform * p)
	return pontos

# Distância de uma posição global até a ponta mais próxima do caminho.
func distancia_ate(pos : Vector2) -> float:
	var pontos := pontos_globais()
	if pontos.is_empty() :
		return INF
	return minf(pos.distance_to(pontos[0]), pos.distance_to(pontos[-1]))
