extends Node2D

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
	
func atualiza_raiva() : 
	nivel_raiva += 0.02

func atualiza_fome():
	quantidade_fome = (quantidade_fome + 0.02) * nivel_raiva
	
func _on_body_entered(body : Node2D) -> void:
	if body is Maquinista :
		print("Maquinista entrou na área do passageiro " + nome + "!")
	
func _ready() -> void:
	add_child(timer)
	$Area2D.body_entered.connect(_on_body_entered)
	aposta_nome()
	aposta_necessidade()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	if necessidades.has("FOME") :
		atualiza_fome()
		
	atualiza_raiva()
	
	#if(quantidade_fome >= 0.2) :
	#	print("Passageiro " + nome + " está com muita fome!")
		
	#if(nivel_raiva >= 0.5) :
	#	print("Passageiro " + nome + " está muito irado!")
	pass
