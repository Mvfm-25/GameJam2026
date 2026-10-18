extends Control
class_name Menu

# Tela de início: logo à esquerda, botões Início e Créditos à direita.
# Início carrega a cena principal; Créditos abre a tela de créditos.

const CENA_PRINCIPAL := "res://cenas/principal.tscn"
const CENA_CREDITOS := "res://cenas/creditos.tscn"

@onready var _inicio: Button = %Inicio
@onready var _creditos: Button = %Creditos


func _ready() -> void:
	_inicio.pressed.connect(_ao_apertar_inicio)
	_creditos.pressed.connect(_ao_apertar_creditos)
	_inicio.grab_focus()


func _ao_apertar_inicio() -> void:
	get_tree().change_scene_to_file(CENA_PRINCIPAL)


func _ao_apertar_creditos() -> void:
	get_tree().change_scene_to_file(CENA_CREDITOS)
