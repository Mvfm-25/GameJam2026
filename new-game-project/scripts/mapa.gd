extends CanvasLayer
class_name Mapa

# Tudo que aparece no mapa fica dentro de Conteudo, que é escondido/mostrado.
@onready var conteudo : Control = $Conteudo

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

func abre() -> void:
	conteudo.visible = true

func fecha() -> void:
	conteudo.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("abrir_mapa"):
		conteudo.visible = not conteudo.visible
		get_viewport().set_input_as_handled()
