extends Node2D
class_name IndicadorTrem

# Ícone da locomotiva no mapa, na posição atual da viagem.
# Desenho montado na cena indicador_trem.tscn (Halo + peças da Locomotiva).

# Tom aplicado à locomotiva enquanto o trem está no túnel.
@export var cor_tunel := Color(0.5, 0.5, 0.5)

@onready var _locomotiva : Node2D = $Locomotiva

var no_tunel := false:
	set(valor):
		no_tunel = valor
		if is_node_ready():
			_locomotiva.modulate = cor_tunel if valor else Color.WHITE
