extends StaticBody2D
class_name Cadeira

# Cadeira do vagão social.
# O Cadeira.png tem 3 quadros: cadeira inteira, corpo sem o braço e só o braço.
# Vazia mostra a cadeira inteira. Ocupada mostra o corpo atrás do passageiro
# e o braço ($Braco, com z_index maior) por cima dele.

# Marque para o spawner (nó "Passageiros") criar um passageiro sentado aqui ao começar.
@export var com_passageiro := false

# Passageiro dono da cadeira. Continua dono mesmo quando levanta para passear,
# assim ninguém mais pega o lugar dele.
var dono : Node2D = null
# Se o dono está sentado agora.
var ocupada := false

@onready var _corpo : AnimatedSprite2D = $AnimatedSprite2D
@onready var _braco : Sprite2D = $Braco
# Onde o passageiro fica quando senta. Mova o Marker2D "Assento" na cena para ajustar.
@onready var _assento : Marker2D = $Assento

func _enter_tree() -> void:
	# Entra no grupo antes de qualquer _ready, para os passageiros acharem a cadeira.
	add_to_group("cadeiras")

func _ready() -> void:
	# Quem está mais abaixo na tela é desenhado na frente.
	z_index = Cadeira.z_por_y(global_position.y)
	_atualiza_visual()

# Ordem de desenho pela altura na tela (um "y-sort" manual).
# Cada cadeira usa 3 camadas: corpo (z), passageiro (z + 1) e braço (z + 2).
static func z_por_y(y : float) -> int:
	return 1 + 3 * floori(y / 4.0)

func esta_livre() -> bool:
	return dono == null

# Posição global onde o passageiro deve ficar sentado.
func posicao_assento() -> Vector2:
	return _assento.global_position

func reservar(passageiro : Node2D) -> void:
	dono = passageiro

# Dono larga a cadeira de vez (ex.: morreu).
func liberar() -> void:
	dono = null
	levantar()

func sentar() -> void:
	ocupada = true
	_atualiza_visual()

func levantar() -> void:
	ocupada = false
	_atualiza_visual()

func _atualiza_visual() -> void:
	_corpo.play("Ocupada" if ocupada else "Vazia")
	_braco.visible = ocupada
