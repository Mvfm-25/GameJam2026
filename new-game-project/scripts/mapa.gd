extends CanvasLayer
class_name Mapa

# Tudo que aparece no mapa fica dentro de Conteudo, que é escondido/mostrado.
@onready var conteudo : Control = $Conteudo
@onready var painel : Control = $Conteudo/Painel

var _tween : Tween
var _aberto := false

func _ready() -> void:
	conteudo.visible = false
	# Trilhos ligam as estações na ordem em que aparecem na cena.
	# Estações vizinhas são as ligadas por trilho (anterior e próxima na ordem).
	var trilhos : Line2D = $Conteudo/Painel/Trilhos
	trilhos.clear_points()
	var estacoes = $Conteudo/Painel/Estacoes.get_children()
	for i in estacoes.size():
		var e : Estacao = estacoes[i]
		trilhos.add_point(e.position)
		e.estacoes_vizinhas.clear()
		if i > 0:
			e.estacoes_vizinhas.append(estacoes[i - 1])
		if i < estacoes.size() - 1:
			e.estacoes_vizinhas.append(estacoes[i + 1])
	# Fecha o mapa assim que o jogador escolhe uma estação.
	for e in get_tree().get_nodes_in_group("estacoes"):
		if is_ancestor_of(e):
			e.selecionada.connect(func(_estacao): fecha())

# O papel do mapa sobe de baixo da tela até o centro.
func abre() -> void:
	if _aberto:
		return
	_aberto = true
	conteudo.visible = true
	var alvo := (get_viewport().get_visible_rect().size - painel.size) / 2.0
	painel.position = Vector2(alvo.x, get_viewport().get_visible_rect().size.y)
	_anima(alvo.y)

# O papel desce de volta para fora da tela.
func fecha() -> void:
	if not _aberto:
		return
	_aberto = false
	_anima(get_viewport().get_visible_rect().size.y, true)

func _anima(y_final: float, esconder := false) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(painel, "position:y", y_final, 0.5) \
		.set_trans(Tween.TRANS_BACK if not esconder else Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT if not esconder else Tween.EASE_IN)
	if esconder:
		_tween.tween_callback(func(): conteudo.visible = false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("abrir_mapa"):
		if _aberto:
			fecha()
		else:
			abre()
		get_viewport().set_input_as_handled()
