extends Control
class_name Menu

# Tela de início: logo e título LOCO-MOTIVA à esquerda, botões Início e Créditos à direita,
# sobre um fundo animado. Início carrega a cena principal; Créditos abre a tela de créditos.

const CENA_PRINCIPAL := "res://cenas/principal.tscn"
const CENA_CREDITOS := "res://cenas/creditos.tscn"

# Logo balançando de leve, título pulsando e botões crescendo sob o mouse.
const LOGO_BALANCO := 0.05 # radianos
const LOGO_PERIODO := 2.6 # segundos para ir e voltar
const LOGO_PULSO := 1.05
const TITULO_PULSO := 1.04
const TITULO_PERIODO := 1.8
const BOTAO_AUMENTO := 1.08
const ENTRADA_DURACAO := 0.9

@onready var _inicio: Button = %Inicio
@onready var _creditos: Button = %Creditos
@onready var _logo: Control = %Logo
@onready var _titulo: Control = %Titulo
@onready var _conteudo: Control = $Margem


func _ready() -> void:
	_inicio.pressed.connect(_ao_apertar_inicio)
	_creditos.pressed.connect(_ao_apertar_creditos)
	_inicio.grab_focus()
	for botao in [_inicio, _creditos]:
		_prepara_botao(botao)
	# Espera o layout para o pivô ficar no meio de cada peça.
	await get_tree().process_frame
	_centraliza_pivo(_logo)
	_centraliza_pivo(_titulo)
	_anima_entrada()
	_anima_logo()
	_anima_titulo()


func _centraliza_pivo(no: Control) -> void:
	no.pivot_offset = no.size / 2.0


# Tudo surge com um fade e o título "cai" no lugar com um quique.
func _anima_entrada() -> void:
	_conteudo.modulate.a = 0.0
	_titulo.scale = Vector2.ONE * 0.4
	var entrada := create_tween().set_parallel(true)
	entrada.tween_property(_conteudo, "modulate:a", 1.0, ENTRADA_DURACAO)
	entrada.tween_property(_titulo, "scale", Vector2.ONE, ENTRADA_DURACAO) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _anima_logo() -> void:
	var balanco := create_tween().set_loops()
	balanco.tween_property(_logo, "rotation", LOGO_BALANCO, LOGO_PERIODO / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	balanco.tween_property(_logo, "rotation", -LOGO_BALANCO, LOGO_PERIODO / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var pulso := create_tween().set_loops()
	pulso.tween_property(_logo, "scale", Vector2.ONE * LOGO_PULSO, LOGO_PERIODO / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulso.tween_property(_logo, "scale", Vector2.ONE, LOGO_PERIODO / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# Depois da entrada, o título respira de leve.
func _anima_titulo() -> void:
	await get_tree().create_timer(ENTRADA_DURACAO).timeout
	var pulso := create_tween().set_loops()
	pulso.tween_property(_titulo, "scale", Vector2.ONE * TITULO_PULSO, TITULO_PERIODO / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulso.tween_property(_titulo, "scale", Vector2.ONE, TITULO_PERIODO / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# O botão cresce quando o mouse (ou o foco do teclado) chega nele e volta ao sair.
func _prepara_botao(botao: Button) -> void:
	botao.resized.connect(func(): botao.pivot_offset = botao.size / 2.0)
	botao.pivot_offset = botao.size / 2.0
	for sinal in [botao.mouse_entered, botao.focus_entered]:
		sinal.connect(_cresce_botao.bind(botao, BOTAO_AUMENTO))
	for sinal in [botao.mouse_exited, botao.focus_exited]:
		sinal.connect(_cresce_botao.bind(botao, 1.0))


func _cresce_botao(botao: Button, escala: float) -> void:
	create_tween().tween_property(botao, "scale", Vector2.ONE * escala, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ao_apertar_inicio() -> void:
	get_tree().change_scene_to_file(CENA_PRINCIPAL)


func _ao_apertar_creditos() -> void:
	get_tree().change_scene_to_file(CENA_CREDITOS)
