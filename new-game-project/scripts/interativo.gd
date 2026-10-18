extends Node2D
class_name Interativo

# Objeto fixo com que o maquinista interage (tecla "interagir") quando está perto,
# como a pilha de carvão e o apito. A folha do Sprite2D tem duas células de 192 px
# lado a lado: a normal e a com contorno, que aparece com o jogador ao alcance.
# Cada tipo de objeto sobrescreve interage().

const CELULA := 192

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _area: Area2D = $Area2D


func _ready() -> void:
	_area.body_entered.connect(_ao_entrar_area)
	_area.body_exited.connect(_ao_sair_area)
	_destaca(false)


func interage() -> void:
	pass


func _ao_entrar_area(body: Node2D) -> void:
	if body is Maquinista and not body.interativos_proximos.has(self):
		body.interativos_proximos.append(self)
		_destaca(true)


func _ao_sair_area(body: Node2D) -> void:
	if body is Maquinista:
		body.interativos_proximos.erase(self)
		_destaca(false)


func _destaca(ligado: bool) -> void:
	_sprite.region_rect.position.x = CELULA if ligado else 0
