extends Node2D

@export var nome = ""
@export var status = "VIVO"
@export var hp = 10

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

func atualiza_fome():
	quantidade_fome += 0.01
	
func _ready() -> void:
	aposta_nome()
	aposta_necessidade()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	#if necessidades.has("FOME") :
		#atualiza_fome()
	if(quantidade_fome >= 0.2) :
		print("Passageiro " + nome + " está com muita fome!")
		
	pass
