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

# Marcada como ponto de origem
@export var originaria = false

# Nome desenhado acima do círculo (para estações na fileira de cima, longe dos trilhos).
@export var rotulo_acima = false:
	set(valor):
		rotulo_acima = valor
		queue_redraw()

const TAMANHO_FONTE := 17
const COR_TEXTO := Color(0.13, 0.125, 0.2)
# Contorno da cor do papel, para o nome não se misturar com os trilhos.
const COR_PAPEL := Color(0.95, 0.92, 0.66)
const CONTORNO_TEXTO := 6

# Estações vizinhas (ligadas por trilho no mapa). Preenchidas pelo Mapa.
var estacoes_vizinhas : Array[Estacao] = []

var selecionado = false
# Mouse em cima do círculo.
var hover = false

# Recompensa jogador quantidade pequena de pontos ao chegar na estação.
var pontos_por_chegada = 10.0

# Só é possível viajar para estações vizinhas.
func viagem_possivel(destino : Estacao) -> bool:
	if not estacoes_vizinhas.has(destino) :
		print("Viajar para estações não vizinhas não é possível!")
		return false
	print("Viagem possível!")
	return true

func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("estacoes")

func _draw() -> void:
	if selecionado:
		draw_circle(Vector2.ZERO, raio + 5.0, Color.WHITE)
	draw_circle(Vector2.ZERO, raio, cor.lightened(0.3) if hover else cor)
	var fonte = ThemeDB.fallback_font
	var largura = raio * 10.0
	var y = -raio - 10.0 if rotulo_acima else raio + TAMANHO_FONTE + 6.0
	var pos = Vector2(-largura / 2.0, y)
	draw_string_outline(fonte, pos, nome, HORIZONTAL_ALIGNMENT_CENTER, largura, TAMANHO_FONTE, CONTORNO_TEXTO, COR_PAPEL)
	draw_string(fonte, pos, nome, HORIZONTAL_ALIGNMENT_CENTER, largura, TAMANHO_FONTE, COR_TEXTO)

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
