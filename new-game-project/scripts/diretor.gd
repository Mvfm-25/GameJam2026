extends Node2D
class_name Diretor

# Quem são os passageiros sendo transportados.
var lista_passageiros = []

var em_transito = false
var em_tunel = false

# Passando pelo tunel, matar passageiros 
func aposta_morte():
	var mortes = 0
	for p in lista_passageiros :
		if( p.nivel_raiva > 0.75 ):
			p.status = "MORTO"
			mortes += 1
			print("Passageiro " + p.nome + " foi morto!")
			pass
	print("Quantidade de mortes : " + mortes)

# Trem chegou na estação de destino
#func chega_destino() :
	

# Troca de estação de destino
#func troca_destino() :
	

# Troca de trilhos
#func troca_trilho() : 
	

func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	pass

# Esc fecha o jogo
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
