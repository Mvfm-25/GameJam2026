extends Node2D
class_name Passageiro

@export var nome = ""
@export var status = "VIVO"
@export var hp = 10

# Variável de felicidade do passageiro.
var contente = false
# Quantos pontos o jogador é recompensado por atender o passageiro
var pontos_atendimento = 2.0
var timer = Timer.new()

# Nível de raiva entre 0.0 & 1.0.
var nivel_raiva = 0.0
var quantidade_fome = 0.0

# Com fome, convivendo em ambiente sujo, ou ambos.
var necessidades = []

# --- Cadeira & passeio ---------------------------------------------------
# Cadeira onde o passageiro senta. Se ficar vazio, pega a cadeira livre
# mais próxima dentro de raio_busca_cadeira.
@export var cadeira : Cadeira = null
@export var raio_busca_cadeira := 60.0
# Caminhos que ele pode passear. Vazio = qualquer Caminho da cena que tenha
# uma ponta a até alcance_caminho px da cadeira.
@export var caminhos : Array[Caminho] = []
@export var alcance_caminho := 400.0
# De quanto em quanto tempo ele pensa em levantar, e a chance de levantar.
@export var intervalo_passeio_min := 10.0
@export var intervalo_passeio_max := 30.0
@export_range(0.0, 1.0) var chance_passeio := 0.4
@export var velocidade_caminhada := 60.0

enum Estado { SENTADO, ANDANDO }
var estado = Estado.SENTADO
# Pontos (globais) que faltam percorrer no passeio atual.
var _rota := PackedVector2Array()
var _timer_passeio := Timer.new()
# Corpos disponíveis (animações do AnimatedSprite2D) e a escala de cada um.
# Forte e Fraco foram desenhados com o dobro da resolução do Base,
# então são reduzidos pela metade para ficarem do mesmo tamanho do passageiro padrão.
const CORPOS = {
	"Base": 1.0,
	"Forte": 0.5,
	"Fraco": 0.5,
}
var corpo = "Base"

func aposta_corpo() :
	corpo = CORPOS.keys().pick_random()
	$AnimatedSprite2D.animation = corpo
	$AnimatedSprite2D.scale = Vector2.ONE * CORPOS[corpo]

func aposta_necessidade() :
	var sorteado = ["FAMINTO", "IMUNDO", "DESACONCHEGADO", "IRADO"].pick_random()
	necessidades.append(sorteado)
	print("Passageiro " + nome + " está : " + sorteado)
	timer.start()

func aposta_nome():
	nome = ["Durandal", "Tycho", "Leela", "Dynamo", "Abrams", "Casius Cleiton", "Misha"].pick_random()
	print("Nome escolhido : %s" % nome)
	
func enfurece():
	# Multiplica raiva pela quantidade de fome desde que foi adicionada.
	nivel_raiva = nivel_raiva * quantidade_fome
	
# Raiva sobe com o tempo, igual em qualquer FPS.
# Cada passageiro tem seu próprio ritmo: leva de ~35 s a ~100 s para chegar ao máximo.
var taxa_raiva = randf_range(0.01, 0.03)

func atualiza_raiva(delta : float) :
	nivel_raiva = minf(1.0, nivel_raiva + taxa_raiva * delta)

func atualiza_fome():
	quantidade_fome = (quantidade_fome + 0.02) * nivel_raiva
	
func esta_vivo() -> bool:
	return status != "MORTO"

# Morto no túnel: some do assento e para de reagir.
func morre() -> void:
	status = "MORTO"
	contente = false
	necessidades.clear()
	timer.stop()
	set_process(false)
	_timer_passeio.stop()
	_rota.clear()
	visible = false
	if cadeira != null :
		cadeira.liberar()
	$CollisionShape2D.set_deferred("disabled", true)
	$Area2D.set_deferred("monitoring", false)
	# A área desligada não avisa a saída, então tira o passageiro da lista do maquinista aqui.
	for body in $Area2D.get_overlapping_bodies() :
		if body is Maquinista :
			body.passageiros_proximos.erase(self)
	print("Passageiro " + nome + " morreu!")

func esta_faminto() -> bool:
	return status != "MORTO" and necessidades.has("FAMINTO")

# Come o alimento entregue pelo maquinista
func alimenta(item : Item) -> void:
	necessidades.erase("FAMINTO")
	quantidade_fome = 0.0
	contente = necessidades.is_empty()
	item.queue_free()
	print("Passageiro " + nome + " deixou de estar com fome!")
	$fome.visible = false

# Maquinista entra/sai da área de interação do passageiro
func _on_body_entered(body : Node2D) -> void:
	if body is Maquinista and not body.passageiros_proximos.has(self) :
		body.passageiros_proximos.append(self)
		print("Maquinista entrou na área do passageiro " + nome + "!")

func _on_body_exited(body : Node2D) -> void:
	if body is Maquinista :
		body.passageiros_proximos.erase(self)

func _ready() -> void:
	add_child(timer)
	$Area2D.body_entered.connect(_on_body_entered)
	$Area2D.body_exited.connect(_on_body_exited)
	aposta_corpo()
	aposta_nome()
	aposta_necessidade()

	_timer_passeio.one_shot = true
	_timer_passeio.timeout.connect(_pensa_em_passear)
	add_child(_timer_passeio)
	# Espera todas as cadeiras estarem prontas antes de sentar.
	_senta_na_cadeira_inicial.call_deferred()

func _senta_na_cadeira_inicial() -> void:
	if cadeira == null :
		cadeira = _cadeira_livre_mais_proxima()
	if cadeira == null :
		return
	cadeira.reservar(self)
	_senta()

func _cadeira_livre_mais_proxima() -> Cadeira :
	var melhor : Cadeira = null
	var melhor_dist := raio_busca_cadeira
	for c in get_tree().get_nodes_in_group("cadeiras") :
		if not c.esta_livre() :
			continue
		var d = global_position.distance_to(c.posicao_assento())
		if d <= melhor_dist :
			melhor = c
			melhor_dist = d
	return melhor

func _senta() -> void:
	estado = Estado.SENTADO
	global_position = cadeira.posicao_assento()
	# Entre o corpo e o braço da cadeira.
	z_index = cadeira.z_index + 1
	cadeira.sentar()
	_timer_passeio.start(randf_range(intervalo_passeio_min, intervalo_passeio_max))

# Hora de decidir: levanta para passear ou continua sentado.
func _pensa_em_passear() -> void:
	if not esta_vivo() or estado != Estado.SENTADO :
		return
	var caminho : Caminho = null
	if randf() < chance_passeio :
		caminho = _escolhe_caminho()
	if caminho == null :
		_timer_passeio.start(randf_range(intervalo_passeio_min, intervalo_passeio_max))
		return
	_inicia_passeio(caminho)

# Sorteia um caminho (respeitando o peso de cada um).
func _escolhe_caminho() -> Caminho :
	var opcoes : Array = caminhos.filter(func(c): return is_instance_valid(c))
	if opcoes.is_empty() :
		var origem = cadeira.posicao_assento() if cadeira != null else global_position
		opcoes = get_tree().get_nodes_in_group("caminhos").filter(
			func(c): return c.distancia_ate(origem) <= alcance_caminho)
	opcoes = opcoes.filter(func(c): return c.peso > 0.0)
	if opcoes.is_empty() :
		return null
	var total := 0.0
	for c in opcoes :
		total += c.peso
	var sorteio := randf() * total
	for c in opcoes :
		sorteio -= c.peso
		if sorteio <= 0.0 :
			return c
	return opcoes.back()

# Monta a rota: ponta mais próxima -> outra ponta -> volta -> cadeira.
func _inicia_passeio(caminho : Caminho) -> void:
	var pontos := caminho.pontos_globais()
	if pontos.size() < 2 :
		_timer_passeio.start(randf_range(intervalo_passeio_min, intervalo_passeio_max))
		return
	if global_position.distance_to(pontos[-1]) < global_position.distance_to(pontos[0]) :
		pontos.reverse()
	var volta := pontos.duplicate()
	volta.reverse()
	_rota = pontos + volta
	if cadeira != null :
		_rota.append(cadeira.posicao_assento())
		cadeira.levantar()
	estado = Estado.ANDANDO
	# Andando não bloqueia o maquinista (o corpo é estático e só se teletransporta).
	$CollisionShape2D.set_deferred("disabled", true)
	print("Passageiro " + nome + " levantou para dar uma volta.")

func _anda(delta : float) -> void:
	var passo := velocidade_caminhada * delta
	while passo > 0.0 and not _rota.is_empty() :
		var alvo := _rota[0]
		var dist := global_position.distance_to(alvo)
		if dist <= passo :
			global_position = alvo
			passo -= dist
			_rota.remove_at(0)
		else :
			global_position = global_position.move_toward(alvo, passo)
			passo = 0.0
	z_index = Cadeira.z_por_y(global_position.y) + 1
	if _rota.is_empty() :
		$CollisionShape2D.set_deferred("disabled", false)
		_senta()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if estado == Estado.ANDANDO :
		_anda(delta)

	if necessidades.has("FAMINTO") :
		atualiza_fome()
		
	atualiza_raiva(delta)
	
	if(quantidade_fome >= 0.6) :
		$fome.visible = true
		
	if(nivel_raiva >= 0.9) :
		$puto.visible = false
		$muito_puto.visible = true
	elif(nivel_raiva >= 0.5) :
		$puto.visible = true
	pass
