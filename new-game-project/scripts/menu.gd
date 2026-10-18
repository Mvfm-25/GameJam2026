extends Control
class_name Menu

# Tela de início: logo à esquerda, botões Início e Créditos à direita.
# Início carrega a cena principal; Créditos ainda não faz nada.

const CENA_PRINCIPAL := "res://cenas/principal.tscn"

@onready var _inicio: Button = %Inicio
@onready var _creditos: Button = %Creditos


func _ready() -> void:
	_inicio.pressed.connect(_ao_apertar_inicio)
	_inicio.grab_focus()


func _ao_apertar_inicio() -> void:
	get_tree().change_scene_to_file(CENA_PRINCIPAL)
