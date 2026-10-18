extends CanvasLayer
class_name Mapa

# Tudo que aparece no mapa fica dentro de Conteudo, que é escondido/mostrado.
@onready var conteudo : Control = $Conteudo
@onready var painel : Control = $Conteudo/Painel

@onready var status : Label = $Conteudo/Painel/Status

var _tween : Tween
var _aberto := false
# Diretor (cena principal) diz onde o trem está e quanto falta.
var _diretor : Diretor
var _trem : IndicadorTrem

const CENA_TREM := preload("res://cenas/indicador_trem.tscn")

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

	_diretor = get_parent() as Diretor
	# Adicionado por último no painel: fica acima dos trilhos e das estações.
	_trem = CENA_TREM.instantiate()
	painel.add_child(_trem)
	_atualiza_viagem()

func _process(_delta: float) -> void:
	if conteudo.visible:
		_atualiza_viagem()

# Move o trem pelo trilho entre origem e destino e atualiza o texto de status.
func _atualiza_viagem() -> void:
	# O Diretor define a estação de origem no próprio _ready, que roda depois deste.
	if _diretor == null or _diretor.estacao_atual == null:
		_trem.visible = false
		status.text = ""
		return
	var origem := _diretor.estacao_atual
	var destino := _diretor.estacao_selecionada
	_trem.visible = true
	_trem.no_tunel = _diretor.em_tunel

	if destino == null:
		_trem.position = origem.position
		_trem.scale.x = 1.0
		if _diretor.jogo_acabou:
			status.text = "Viagem encerrada em " + origem.nome
		else:
			status.text = "Parado em " + origem.nome + "  ·  escolha o próximo destino"
		return

	_trem.position = origem.position.lerp(destino.position, _diretor.progresso_viagem())
	# Balança um pouco para parecer que está andando.
	_trem.position.y += sin(Time.get_ticks_msec() / 90.0) * 1.2
	# Locomotiva virada para o lado do destino.
	_trem.scale.x = -1.0 if destino.position.x < origem.position.x else 1.0
	var texto := "%s → %s  ·  faltam %d s" % [origem.nome, destino.nome, ceili(_diretor.tempo_restante())]
	if _diretor.em_tunel:
		texto = "No túnel...  ·  " + texto
	status.text = texto

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
