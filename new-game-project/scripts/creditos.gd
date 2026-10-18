extends Control
class_name Creditos

# Tela de créditos: título GCM e os nomes da equipe com suas funções.
# Voltar (ou Esc) retorna ao menu.

const CENA_MENU := "res://cenas/menu.tscn"

@onready var _voltar: Button = %Voltar


func _ready() -> void:
	_voltar.pressed.connect(_volta_ao_menu)
	_voltar.grab_focus()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		_volta_ao_menu()


func _volta_ao_menu() -> void:
	get_tree().change_scene_to_file(CENA_MENU)
