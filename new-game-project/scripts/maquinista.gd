extends CharacterBody2D
class_name Maquinista

@export var velocidade := 200.0
@export var pontos_acumulados = 10.0

# Item atualmente carregado pelo jogador, um único item.
@export var itemAtual = null

# Jogador pega um item do chão e o carrega
func pega_item(item : Node2D):
	if item is Item :
		itemAtual = item
		add_child(item)
		print("Carrengando item " + item.nome)

# Ele solta o item no chão
func solta_item():
	remove_child(itemAtual)
	print("Deixando de carregar " + itemAtual.nome + "!")

# Jogador come o alimento dos passageiros
func alimenta():
	if itemAtual == null :
		print("Você não está carregando nada!")
	else :
		if(itemAtual.classe == "Alimento"):
			itemAtual = null
	

func _physics_process(_delta: float) -> void:
	var direcao := Input.get_vector("mover_esquerda", "mover_direita", "mover_cima", "mover_baixo")
	velocity = direcao * velocidade
	move_and_slide()
