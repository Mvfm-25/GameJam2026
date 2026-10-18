extends CharacterBody2D
class_name Maquinista

@export var velocidade := 400.0
@export var pontos_acumulados = 10.0

# Item atualmente carregado pelo jogador, um único item.
@export var itemAtual : Item = null
# Se o jogador está carregando algo nas mãos.
var carregando := false
# Itens no chão perto o bastante para serem pegos (os itens se registram aqui).
var itens_proximos : Array[Item] = []
# Sujeiras perto o bastante para serem limpas (as sujeiras se registram aqui).
var sujeiras_proximas : Array[Sujeira] = []
# Vasos perto o bastante para serem desentupidos (os vasos se registram aqui).
var vasos_proximos : Array[Vaso] = []
# Passageiros cuja área de interação o jogador está dentro (eles se registram aqui).
var passageiros_proximos : Array[Passageiro] = []

# Portas cuja área de interação o jogador está dentro (elas se registram aqui).
var portas_proximas : Array[Porta] = []
# Objetos fixos ao alcance, como a pilha de carvão e o apito (eles se registram aqui).
var interativos_proximos : Array[Interativo] = []

# Se o jogador está parado varrendo uma sujeira.
var limpando := false
# Sujeira ou vaso entupido sendo limpo (os dois têm limpar()).
var _alvo_limpeza : Node2D = null

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

	if (item.classe == "Alimento" or item.eh_comida_preparada()) and alimenta(item) :
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

# Começa a varrer a sujeira (ou desentupir o vaso) mais próximo. O jogador fica parado
# com a vassoura até o TimerLimpeza acabar (2 s).
func limpa():
	if limpando :
		return
	if carregando :
		print("Solte o item antes de limpar!")
		return
	var alvos : Array[Node2D] = []
	alvos.append_array(sujeiras_proximas)
	alvos.append_array(vasos_proximos.filter(func(v): return v.pode_desentupir()))
	var melhor : Node2D = null
	for s in alvos :
		if melhor == null or global_position.distance_to(s.global_position) < global_position.distance_to(melhor.global_position) :
			melhor = s
	if melhor == null :
		print("Nada para limpar aqui!")
		return
	limpando = true
	_alvo_limpeza = melhor
	_direcao_sprite = "frente"
	_atualiza_sprite()
	_vassoura.show()
	_vassoura.play("varrer")
	_timer_limpeza.start()

# Fim da limpeza: remove a sujeira (ou desentope o vaso) e libera o jogador.
func _ao_terminar_limpeza() -> void:
	limpando = false
	_vassoura.stop()
	_vassoura.hide()
	if is_instance_valid(_alvo_limpeza) :
		_alvo_limpeza.limpar()
		if _alvo_limpeza is Sujeira :
			print("Sujeira limpa!")
	_alvo_limpeza = null

# Item mais próximo que ainda está no chão
func _item_mais_proximo() -> Item :
	var melhor : Item = null
	for item in itens_proximos :
		if not item.disponivel() :
			continue
		if melhor == null or global_position.distance_to(item.global_position) < global_position.distance_to(melhor.global_position) :
			melhor = item
	return melhor

# Porta mais próxima do jogador entre as que estão ao alcance
func _porta_mais_proxima() -> Porta :
	var melhor : Porta = null
	for porta in portas_proximas :
		if porta.aberta :
			continue
		if melhor == null or global_position.distance_to(porta.global_position) < global_position.distance_to(melhor.global_position) :
			melhor = porta
	return melhor

# Porta fechada ou objeto fixo (pilha de carvão, apito) mais próximo do jogador
func _alvo_interacao() -> Node2D :
	var melhor : Node2D = _porta_mais_proxima()
	for alvo in interativos_proximos :
		if melhor == null or global_position.distance_to(alvo.global_position) < global_position.distance_to(melhor.global_position) :
			melhor = alvo
	return melhor

# Tecla de interagir pega o item mais próximo ou solta o que está carregando
func _unhandled_input(event: InputEvent) -> void:
	# Enquanto varre, o jogador não faz mais nada.
	if limpando :
		return
	if event.is_action_pressed("interagir"):
		if carregando :
			solta_item()
		elif _item_mais_proximo() != null :
			pega_item(_item_mais_proximo())
		else :
			var alvo := _alvo_interacao()
			if alvo != null :
				alvo.interage()
	elif event.is_action_pressed("limpar"):
		limpa()

# Direção atual do sprite: "frente", "de_costas", "direita" ou "esquerda"
var _direcao_sprite := "frente"
var _piscando := false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _timer_piscada: Timer = $TimerPiscada
@onready var _timer_olho_fechado: Timer = $TimerOlhoFechado
@onready var _vassoura: AnimatedSprite2D = $Vassoura
@onready var _timer_limpeza: Timer = $TimerLimpeza

# Animação de andar, feita por código: o corpo inclina para um lado e para o outro
# bem rápido, com um pulinho a cada passo e uma leve amassada ao pisar.
const BALANCO_ANGULO := 0.09 # radianos (~5 graus)
const BALANCO_VELOCIDADE := 22.0 # passos por segundo, em radianos
const PULINHO := 1.5 # pixels
const AMASSADA := 0.04 # variação da escala
const SUAVIZACAO := 18.0

var _fase_passo := 0.0
var _sprite_posicao := Vector2.ZERO
var _sprite_escala := Vector2.ONE

# Itens sem sprite próprio do maquinista (ex.: caveira) aparecem nas mãos dele.
const ITEM_NA_MAO_POSICAO := Vector2(0, 6)
var _item_na_mao := Sprite2D.new()

func _ready() -> void:
	_item_na_mao.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_item_na_mao.position = ITEM_NA_MAO_POSICAO
	_item_na_mao.visible = false
	add_child(_item_na_mao)
	_timer_piscada.wait_time = randf_range(5.0, 8.0)
	_sprite_posicao = _sprite.position
	_sprite_escala = _sprite.scale

func _physics_process(delta: float) -> void:
	var direcao := Input.get_vector("mover_esquerda", "mover_direita", "mover_cima", "mover_baixo")
	# Parado enquanto varre.
	if limpando :
		direcao = Vector2.ZERO
	velocity = direcao * velocidade
	move_and_slide()

	_atualiza_direcao(direcao)
	_anima_andar(direcao, delta)

# Inclina o corpo enquanto anda; ao parar, volta suavemente à posição normal.
func _anima_andar(direcao: Vector2, delta: float) -> void:
	var andando := direcao.length() > 0.1
	var angulo := 0.0
	var pulo := 0.0
	var amassada := 0.0
	if andando:
		_fase_passo += delta * BALANCO_VELOCIDADE
		angulo = sin(_fase_passo) * BALANCO_ANGULO
		var passo := absf(sin(_fase_passo))
		pulo = -passo * PULINHO
		amassada = (0.5 - passo) * AMASSADA
	var peso := 1.0 - exp(-SUAVIZACAO * delta)
	_sprite.rotation = lerp_angle(_sprite.rotation, angulo, peso)
	_sprite.position = _sprite.position.lerp(_sprite_posicao + Vector2(0, pulo), peso)
	_sprite.scale = _sprite.scale.lerp(_sprite_escala * Vector2(1.0 - amassada, 1.0 + amassada), peso)

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
	_atualiza_item_na_mao()
	# De costas não há quadros piscando nem com a tábua.
	if _direcao_sprite == "de_costas" :
		_sprite.play("de_costas")
	# Não há quadros piscando com a tábua, então carregando ignora a piscada.
	elif carregando and itemAtual.eh_tabua() :
		_sprite.play(_direcao_sprite + "_tabua")
	else :
		_sprite.play(_direcao_sprite + ("_piscando" if _piscando else ""))

# Mostra o item carregado na frente do corpo; de costas ele fica escondido atrás.
func _atualiza_item_na_mao() -> void:
	var mostra := carregando and itemAtual != null and not itemAtual.eh_tabua()
	_item_na_mao.visible = mostra and _direcao_sprite != "de_costas"
	if mostra :
		_item_na_mao.texture = itemAtual.textura_atual()

# A cada 5 a 8 s fecha os olhos por um instante
func _ao_piscar() -> void:
	_timer_piscada.wait_time = randf_range(5.0, 8.0)
	_piscando = true
	_atualiza_sprite()
	_timer_olho_fechado.start()

func _ao_abrir_olhos() -> void:
	_piscando = false
	_atualiza_sprite()
