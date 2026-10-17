extends CharacterBody2D
class_name Maquinista

@export var velocidade := 200.0

# Item atualmente carregado pelo jogador, um único item.
@export var itemAtual = null

# Jogador pega um item do chão e o carrega
func pega_item(item : Area2D):
	

func _physics_process(_delta: float) -> void:
	var direcao := Input.get_vector("mover_esquerda", "mover_direita", "mover_cima", "mover_baixo")
	velocity = direcao * velocidade
	move_and_slide()
