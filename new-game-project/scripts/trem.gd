@tool
extends Node2D

# Diferenciar entre "SOCIAL", "MAQUINAS", 'COZINHA
@export var classe = ""

@export var porta_esquerda_aberta := false:
	set(valor):
		porta_esquerda_aberta = valor
		_atualizar_portas()

@export var porta_direita_aberta := false:
	set(valor):
		porta_direita_aberta = valor
		_atualizar_portas()


func _ready() -> void:
	_atualizar_portas()

func _atualizar_portas() -> void:
	if not is_node_ready():
		return
	_definir_porta($PortaEsquerda, porta_esquerda_aberta)
	_definir_porta($PortaDireita, porta_direita_aberta)


func _definir_porta(porta: StaticBody2D, aberta: bool) -> void:
	porta.visible = not aberta
	porta.collision_layer = 0 if aberta else 1
