extends CanvasLayer
class_name TelaFinal

# Tela cheia mostrada quando o jogador decide o destino das caveiras:
# FELIZ = jogou fora pela traseira (recusou o trem), TRISTE = alimentou a fornalha.
enum Tipo { FELIZ, TRISTE }

# Folha com as artes dos finais, em células de 96 px; a ordem segue o enum Tipo.
const FOLHA := preload("res://assets/Outros/finais.png")
const TAMANHO_CELULA := 96
const ESCALA_ARTE := 3.0

const TITULOS := {
	Tipo.FELIZ: "FIM DA LINHA",
	Tipo.TRISTE: "PASSAGEM SÓ DE IDA",
}
const TEXTOS := {
	Tipo.FELIZ: "Você recusou o banquete.\nO trem esfriou, os túneis acabaram, e o sol entrou pelas janelas.\nÀs vezes, ser maquinista é saber quando parar.",
	Tipo.TRISTE: "O fogo comeu os ossos e pediu mais.\nVocê atendeu, como um bom maquinista atende os passageiros.\nO trem segue viagem para sempre, e o cardápio é você.",
}
const CORES := {
	Tipo.FELIZ: Color(0.55, 0.9, 0.45),
	Tipo.TRISTE: Color(1.0, 0.4, 0.2),
}

const DURACAO_FADE := 1.5
# Tempo antes de aceitar teclas, para o jogador não pular a tela sem querer.
const ESPERA_ENTRADA := 2.0

var tipo := Tipo.FELIZ
var _pode_sair := false
var _dica : Label

func _init(tipo_final := Tipo.FELIZ) -> void:
	tipo = tipo_final
	layer = 100
	# Continua rodando com o jogo pausado atrás.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.modulate.a = 0.0
	add_child(raiz)

	var fundo := ColorRect.new()
	fundo.color = Color(0.04, 0.03, 0.05)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(fundo)

	var coluna := VBoxContainer.new()
	coluna.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_theme_constant_override("separation", 16)
	raiz.add_child(coluna)

	var arte := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = FOLHA
	atlas.region = Rect2(int(tipo) * TAMANHO_CELULA, 0, TAMANHO_CELULA, TAMANHO_CELULA)
	arte.texture = atlas
	arte.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arte.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arte.custom_minimum_size = Vector2.ONE * TAMANHO_CELULA * ESCALA_ARTE
	coluna.add_child(arte)

	var titulo := _cria_label(TITULOS[tipo], 48)
	titulo.add_theme_color_override("font_color", CORES[tipo])
	coluna.add_child(titulo)

	coluna.add_child(_cria_label(TEXTOS[tipo], 20))

	_dica = _cria_label("Enter para jogar de novo  ·  Esc para sair", 16)
	_dica.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	_dica.modulate.a = 0.0
	coluna.add_child(_dica)

	var fade := create_tween()
	fade.tween_property(raiz, "modulate:a", 1.0, DURACAO_FADE)
	fade.tween_interval(ESPERA_ENTRADA)
	fade.tween_callback(func(): _pode_sair = true)
	fade.tween_property(_dica, "modulate:a", 1.0, 0.5)

func _cria_label(texto : String, tamanho : int) -> Label :
	var label := Label.new()
	label.text = texto
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", tamanho)
	return label

func _unhandled_input(event: InputEvent) -> void:
	if not _pode_sair :
		return
	if event.is_action_pressed("ui_cancel") :
		get_tree().quit()
	elif event.is_action_pressed("ui_accept") :
		get_tree().paused = false
		get_tree().reload_current_scene()
