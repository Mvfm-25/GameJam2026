extends StaticBody2D
class_name Item

@export var nome = ""

# Diferenciar entre comidas, ferramentas por enquanto.
@export var classe = ""

# Se o item está nas mãos do maquinista (some do chão).
var carregado := false

@onready var _colisao: CollisionShape2D = $CollisionShape2D
@onready var _area: Area2D = $Area2D

func _ready() -> void:
	_area.body_entered.connect(_ao_entrar_area)
	_area.body_exited.connect(_ao_sair_area)

# Maquinista chegou perto, pode pegar este item
func _ao_entrar_area(body: Node2D) -> void:
	if body is Maquinista and not body.itens_proximos.has(self):
		body.itens_proximos.append(self)

func _ao_sair_area(body: Node2D) -> void:
	if body is Maquinista:
		body.itens_proximos.erase(self)
		# Só volta a ser sólido depois que o jogador se afastou de onde o soltou.
		if not carregado:
			_colisao.set_deferred("disabled", false)

# Some do chão enquanto está sendo carregado
func ser_pego() -> void:
	carregado = true
	visible = false
	_colisao.set_deferred("disabled", true)

# Volta para o chão na posição indicada
func ser_solto(posicao: Vector2) -> void:
	global_position = posicao
	carregado = false
	visible = true
	# Colisão continua desligada até o jogador sair da área, senão ele fica preso.
	
func criar_item(posicao: Vector2) -> void:
	global_position = posicao
	visible = true
	carregado = false
	$CollisionShape2D.set_deferred("disabled", false)
	
