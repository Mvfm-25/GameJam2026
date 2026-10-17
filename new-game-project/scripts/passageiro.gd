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
	print("Escolhendo o que incomoda tal passageiro")
	necessidades.append(["FOME", "SUJO", "DESCONFORTO", "FURIA"].pick_random())
	timer.start()

func aposta_nome():
	nome = ["Durandal", "Tycho", "Leela", "Dynamo", "Abrams", "Casius Cleiton", "Misha"].pick_random()
	print("Nome escolhido : %s" % nome)
	
func enfurece():
	# Multiplica raiva pela quantidade de fome desde que foi adicionada.
	nivel_raiva = nivel_raiva * quantidade_fome

func atualiza_fome():
	print("Passageiro %s está ficando com mais fome!" % nome)
	quantidade_fome += 0.5
	
func _ready() -> void:
	aposta_nome()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
