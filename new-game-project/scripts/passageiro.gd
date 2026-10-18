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
	visible = false
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
	aposta_nome()
	aposta_necessidade()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
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
