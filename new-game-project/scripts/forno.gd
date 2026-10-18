extends Area2D
class_name Fornalha

# Fornalha da sala das máquinas: é o que move o trem. O combustível dura cerca
# de 5 minutos e só queima enquanto o trem viaja; o jogador reabastece com a
# pilha de carvão ao lado (PilhaCarvao) ou soltando carvão e cadáveres na frente dela.
# Sem combustível o trem para no meio do caminho até alguém reabastecer.

const GRUPO := "fornalha"

# Duração do tanque cheio, em segundos de viagem.
const COMBUSTIVEL_MAXIMO := 300.0
# Abaixo desta fração a barra fica vermelha.
const FRACAO_ALERTA := 0.2
# Quanto cada item solto na frente da fornalha rende, em segundos.
const RENDIMENTO := {"Carvao": 60.0, "Cadaver": 30.0}

# Barra de combustível desenhada acima da fornalha.
const BARRA_TAMANHO := Vector2(44, 5)
const BARRA_POSICAO := Vector2(0, -50)
const COR_FUNDO := Color(0.1, 0.1, 0.12, 0.85)
const COR_CHEIO := Color(1.0, 0.6, 0.15)
const COR_ALERTA := Color(0.9, 0.2, 0.15)

@export var classes_aceitas: Array[String] = ["Carvao", "Cadaver"]

var combustivel := COMBUSTIVEL_MAXIMO

var _diretor: Diretor
@onready var _visual: Sprite2D = $Visual
var _escala_visual := Vector2.ONE


func _ready() -> void:
	add_to_group(GRUPO)
	body_entered.connect(_ao_entrar_corpo)
	area_entered.connect(_ao_entrar_area)
	_escala_visual = _visual.scale
	# O Diretor é a raiz da cena principal, algum ancestral da fornalha.
	var no := get_parent()
	while no != null and not no is Diretor:
		no = no.get_parent()
	_diretor = no


func _process(delta: float) -> void:
	if _diretor != null and _diretor.em_transito() and combustivel > 0.0:
		combustivel = maxf(combustivel - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var fundo := Rect2(BARRA_POSICAO - BARRA_TAMANHO / 2.0, BARRA_TAMANHO)
	draw_rect(fundo.grow(1), COR_FUNDO)
	var fracao := fracao_combustivel()
	var cor := COR_ALERTA if fracao < FRACAO_ALERTA else COR_CHEIO
	# Pisca quando está quase acabando.
	if fracao < FRACAO_ALERTA and int(Time.get_ticks_msec() / 300) % 2 == 0:
		cor = cor.darkened(0.5)
	draw_rect(Rect2(fundo.position, Vector2(BARRA_TAMANHO.x * fracao, BARRA_TAMANHO.y)), cor)


func fracao_combustivel() -> float:
	return combustivel / COMBUSTIVEL_MAXIMO


func apagada() -> bool:
	return combustivel <= 0.0


# Põe mais combustível (em segundos), até o máximo.
func abastece(segundos: float) -> void:
	combustivel = minf(combustivel + segundos, COMBUSTIVEL_MAXIMO)
	# A fornalha "engole" o carvão.
	_visual.scale = _escala_visual
	var tween := create_tween()
	tween.tween_property(_visual, "scale", _escala_visual * Vector2(1.08, 0.94), 0.07)
	tween.tween_property(_visual, "scale", _escala_visual, 0.12)


func _ao_entrar_corpo(body: Node2D) -> void:
	var item := body as Item
	if item != null:
		_consumir_item(item)


func _ao_entrar_area(area: Area2D) -> void:
	# A Area2D do item é filha do próprio Item.
	var item := area.get_parent() as Item
	if item != null:
		_consumir_item(item)


func _consumir_item(item: Item) -> void:
	if not classes_aceitas.has(item.classe) or item.carregado:
		return
	print("Fornalha consumiu: ", item.classe)
	abastece(RENDIMENTO.get(item.classe, 0.0))
	item.queue_free()
