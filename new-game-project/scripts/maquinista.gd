extends CharacterBody2D
class_name Maquinista

@export var velocidade := 200.0
@export var pontos_acumulados = 10.0

# Item atualmente carregado pelo jogador, um único item.
@export var itemAtual : Item = null
# Se o jogador está carregando algo nas mãos.
var carregando := false
# Itens no chão perto o bastante para serem pegos (os itens se registram aqui).
var itens_proximos : Array[Item] = []

# Jogador pega um item do chão e o carrega
func pega_item(item : Item):
	if carregando or item == null :
		return
	itemAtual = item
	carregando = true
	item.ser_pego()
	_atualiza_sprite()
	print("Carregando item " + item.nome)

# Ele solta o item no chão, onde está parado
func solta_item():
	if not carregando :
		return
	print("Deixando de carregar " + itemAtual.nome + "!")
	itemAtual.ser_solto(global_position)
	itemAtual = null
	carregando = false
	_atualiza_sprite()

# Jogador come o alimento dos passageiros
func alimenta():
	if itemAtual == null :
		print("Você não está carregando nada!")
	else :
		if(itemAtual.classe == "Alimento"):
			itemAtual = null
			carregando = false
			_atualiza_sprite()

# Item mais próximo que ainda está no chão
func _item_mais_proximo() -> Item :
	var melhor : Item = null
	for item in itens_proximos :
		if item.carregado :
			continue
		if melhor == null or global_position.distance_to(item.global_position) < global_position.distance_to(melhor.global_position) :
			melhor = item
	return melhor

# Tecla de interagir pega o item mais próximo ou solta o que está carregando
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interagir"):
		if carregando :
			solta_item()
		else :
			pega_item(_item_mais_proximo())

# Direção atual do sprite: "frente", "de_costas", "direita" ou "esquerda"
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
		nova = "direita"
	elif direcao.x < -0.1:
		nova = "esquerda"
	elif direcao.y < -0.1:
		nova = "de_costas"
	else:
		nova = "frente"
	if nova != _direcao_sprite:
		_direcao_sprite = nova
		_atualiza_sprite()

func _atualiza_sprite() -> void:
	# De costas não há quadros piscando nem com a tábua.
	if _direcao_sprite == "de_costas" :
		_sprite.play("de_costas")
	# Não há quadros piscando com a tábua, então carregando ignora a piscada.
	elif carregando :
		_sprite.play(_direcao_sprite + "_tabua")
	else :
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
