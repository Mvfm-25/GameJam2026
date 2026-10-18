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
	
func atualiza_raiva() : 
	var chance = randi_range(0, 100)
	if(chance > 85) :
		nivel_raiva += 0.002
		

func atualiza_fome():
	quantidade_fome = (quantidade_fome + 0.02) * nivel_raiva
	
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
		
	atualiza_raiva()
	
	if(quantidade_fome >= 0.6) :
		$fome.visible = true
		
	if(nivel_raiva >= 0.9) :
		$puto.visible = false
		$muito_puto.visible = true
	elif(nivel_raiva >= 0.5) :
		$puto.visible = true
	pass
