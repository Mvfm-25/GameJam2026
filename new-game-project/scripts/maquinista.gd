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
# Sujeiras perto o bastante para serem limpas (as sujeiras se registram aqui).
var sujeiras_proximas : Array[Sujeira] = []
# Passageiros cuja área de interação o jogador está dentro (eles se registram aqui).
var passageiros_proximos : Array[Passageiro] = []

# Jogador pega um item do chão e o carrega
func pega_item(item : Item):
	if carregando or item == null :
		return
	itemAtual = item
	carregando = true
	item.ser_pego()
	_atualiza_sprite()
	print("Carregando item " + item.nome)

# Ele solta o item no chão, onde está parado.
# Se for alimento e houver passageiro faminto por perto, o passageiro come.
func solta_item():
	if not carregando :
		return
	var item := itemAtual
	itemAtual = null
	carregando = false
	_atualiza_sprite()

	if item.classe == "Alimento" and alimenta(item) :
		return
	print("Deixando de carregar " + item.nome + "!")
	item.ser_solto(global_position)

# Entrega o alimento ao passageiro faminto mais próximo.
# Retorna false se não há ninguém com fome por perto.
func alimenta(item : Item) -> bool:
	var melhor : Passageiro = null
	for p in passageiros_proximos :
		if not p.esta_faminto() :
			continue
		if melhor == null or global_position.distance_to(p.global_position) < global_position.distance_to(melhor.global_position) :
			melhor = p
	if melhor == null :
		return false
	itens_proximos.erase(item)
	melhor.alimenta(item)
	return true

# Limpa a sujeira mais próxima
func limpa():
	var melhor : Sujeira = null
	for s in sujeiras_proximas :
		if melhor == null or global_position.distance_to(s.global_position) < global_position.distance_to(melhor.global_position) :
			melhor = s
	if melhor == null :
		print("Nada para limpar aqui!")
		return
	melhor.limpar()
	print("Sujeira limpa!")

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
	elif event.is_action_pressed("limpar"):
		limpa()

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
	
	# Chance pequena (~0,5% por quadro, uma sujeira a cada ~3 s em média)
	if randf() < 0.001 :
		inicializa_sujeira(global_position)

	_atualiza_direcao(direcao)

# Cria uma sujeira no chão na posição dada.
func inicializa_sujeira(pos : Vector2) -> void :
	var sujeira := Sujeira.new()
	# Entra na cena logo antes do Maquinista: fica acima dos vagões e abaixo do jogador.
	get_parent().add_child(sujeira)
	get_parent().move_child(sujeira, get_index())
	sujeira.global_position = pos  # define depois de entrar na árvore

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
