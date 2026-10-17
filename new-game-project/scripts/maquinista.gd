extends CharacterBody2D
class_name Maquinista

@export var velocidade := 200.0

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
	

# Direção atual do sprite: "frente", "direita" ou "esquerda"
var _direcao_sprite := "frente"
var _piscando := false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _timer_piscada: Timer = $TimerPiscada
@onready var _timer_olho_fechado: Timer = $TimerOlhoFechado

func _ready() -> void:
	_timer_piscada.wait_time = randf_range(5.0, 8.0)

func _physics_process(_delta: float) -> void:
	var direcao := Input.get_vector("mover_esquerda", "mover_direita", "mover_cima", "mover_baixo")
	velocity = direcao * velocidade
	move_and_slide()
	_atualiza_direcao(direcao)

func _atualiza_direcao(direcao: Vector2) -> void:
	var nova := _direcao_sprite
	if direcao.x > 0.1:
		nova = "esquerda"
	elif direcao.x < -0.1:
		nova = "direita"
	else:
		nova = "frente"
	if nova != _direcao_sprite:
		_direcao_sprite = nova
		_atualiza_sprite()

func _atualiza_sprite() -> void:
	_sprite.play(_direcao_sprite + ("_piscando" if _piscando else ""))

# A cada 5 a 8 s fecha os olhos por um instante
func _ao_piscar() -> void:
	_timer_piscada.wait_time = randf_range(5.0, 8.0)
	_piscando = true
	_atualiza_sprite()
	_timer_olho_fechado.start()

func _ao_abrir_olhos() -> void:
	_piscando = false
	_atualiza_sprite()
