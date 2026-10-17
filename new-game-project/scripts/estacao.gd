@tool
extends Node2D
class_name Estacao

# Emitido quando o jogador clica na estação pelo mapa.
signal selecionada(estacao: Estacao)

@export var nome = "":
	set(valor):
		nome = valor
		queue_redraw()
# Cor do círculo que representa a estação no mapa.
@export var cor := Color.CORNFLOWER_BLUE:
	set(valor):
		cor = valor
		queue_redraw()
@export var raio := 20.0:
	set(valor):
		raio = valor
		queue_redraw()
# Quanto tempo (segundos) o trem leva para chegar nesta estação após escolhida.
@export var tempo_viagem = 500.0

var selecionado = false
# Mouse em cima do círculo.
var hover = false

# Recompensa jogador quantidade pequena de pontos ao chegar na estação.
var pontos_por_chegada = 10.0

func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("estacoes")

func _draw() -> void:
	if selecionado:
		draw_circle(Vector2.ZERO, raio + 5.0, Color.WHITE)
	draw_circle(Vector2.ZERO, raio, cor.lightened(0.3) if hover else cor)
	var fonte = ThemeDB.fallback_font
	draw_string(fonte, Vector2(-raio * 4.0, raio + 20.0), nome, HORIZONTAL_ALIGNMENT_CENTER, raio * 8.0, 14)

func _mouse_em_cima(event: InputEvent) -> bool:
	return make_input_local(event).position.length() <= raio

# Jogador clica na estação para escolhê-la como destino.
# Só responde enquanto o mapa estiver visível.
func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree():
		return
	if event is InputEventMouseMotion:
		var novo_hover = _mouse_em_cima(event)
		if novo_hover != hover:
			hover = novo_hover
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _mouse_em_cima(event):
			get_viewport().set_input_as_handled()
			selecionada.emit(self)

# Marca/desmarca a estação como destino, destacando visualmente.
func define_selecionado(valor: bool) -> void:
	selecionado = valor
	queue_redraw()
