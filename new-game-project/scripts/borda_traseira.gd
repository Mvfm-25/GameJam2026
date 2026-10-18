@tool
extends Area2D
class_name BordaTraseira

# Chão da plataforma no fim do trem (criada pelo trem.gd). Com uma caveira nas mãos,
# o maquinista que está aqui joga a caveira por cima da grade, para fora do trem.

# Até onde a caveira voa depois da grade, em px.
const DISTANCIA_ARREMESSO := 128.0

var _retangulo := Rect2()


# O vagão chama logo após criar a área, com o retângulo (local ao vagão) do chão da plataforma.
func configurar(retangulo: Rect2) -> void:
	_retangulo = retangulo
	var forma := RectangleShape2D.new()
	forma.size = retangulo.size
	var colisao := CollisionShape2D.new()
	colisao.shape = forma
	colisao.position = retangulo.get_center()
	add_child(colisao)
	if Engine.is_editor_hint():
		return
	body_entered.connect(_ao_entrar)
	body_exited.connect(_ao_sair)


func _ao_entrar(body: Node2D) -> void:
	if body is Maquinista:
		body.borda_traseira = self


func _ao_sair(body: Node2D) -> void:
	if body is Maquinista and body.borda_traseira == self:
		body.borda_traseira = null


# Para onde a caveira voa: além da grade, na altura de quem a joga.
func ponto_fora(de: Vector2) -> Vector2:
	var fim := to_global(Vector2(_retangulo.end.x, 0)).x
	return Vector2(fim + DISTANCIA_ARREMESSO, de.y)
