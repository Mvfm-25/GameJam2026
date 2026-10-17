extends CanvasLayer
class_name Mapa

# Tudo que aparece no mapa fica dentro de Conteudo, que é escondido/mostrado.
@onready var conteudo : Control = $Conteudo

func _ready() -> void:
	conteudo.visible = false
	# Trilhos ligam as estações na ordem em que aparecem na cena.
	var trilhos : Line2D = $Conteudo/Painel/Trilhos
	trilhos.clear_points()
	for e in $Conteudo/Painel/Estacoes.get_children():
		trilhos.add_point(e.position)
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
