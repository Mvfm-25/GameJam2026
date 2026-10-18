@tool
extends StaticBody2D
class_name Vaso

# Vaso sanitário das cabines do banheiro (vagão de serviço).
# sanitarios.png tem 5 quadros de 64 px: vaso limpo, (vazio), entupido, (vazio)
# e entupido com contorno branco, mostrado quando o maquinista pode desentupir.
# Enquanto um passageiro usa o vaso a cabine fica trancada (plaquinha vermelha)
# e, com ele lá dentro, a porta da cabine (PortaCabine) fica fechada.
# Ao sair, ele pode deixar o vaso entupido; entupido ninguém usa até o maquinista
# desentupir (tecla de limpar, perto do vaso).

const TEXTURA := preload("res://assets/decorations/sanitarios.png")
const TAMANHO_QUADRO := 64
const QUADRO_LIMPO := 0
const QUADRO_ENTUPIDO := 2
const QUADRO_ENTUPIDO_DESTACADO := 4
# Desenhado na metade do tamanho, igual aos tiles do vagão.
const ESCALA := 0.5
const TAMANHO := TAMANHO_QUADRO * ESCALA
# Distância do centro do vaso em que o maquinista consegue desentupir.
const RAIO_INTERACAO := 40.0
const COR_CONTORNO := Color("222034")
const COR_TRANCADO := Color("d33a3a")

# Chance de o vaso entupir cada vez que um passageiro o usa.
@export_range(0.0, 1.0) var chance_entupir := 0.5

# Passageiro usando o vaso (ou a caminho dele). Com ocupante, a cabine está trancada.
var ocupante : Node2D = null
var entupido := false
# Porta da frente da cabine (criada pelo trem.gd).
var porta : PortaCabine = null

var _atlas : AtlasTexture
var _maquinista : Maquinista = null


func _ready() -> void:
	z_index = 1
	_atlas = AtlasTexture.new()
	_atlas.atlas = TEXTURA
	var sprite := Sprite2D.new()
	sprite.texture = _atlas
	sprite.scale = Vector2.ONE * ESCALA
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	var forma := RectangleShape2D.new()
	forma.size = Vector2(TAMANHO - 4, TAMANHO - 4)
	var colisao := CollisionShape2D.new()
	colisao.shape = forma
	add_child(colisao)

	if not Engine.is_editor_hint():
		var area := Area2D.new()
		var circulo := CircleShape2D.new()
		circulo.radius = RAIO_INTERACAO
		var colisao_area := CollisionShape2D.new()
		colisao_area.shape = circulo
		area.add_child(colisao_area)
		area.body_entered.connect(_ao_entrar_area)
		area.body_exited.connect(_ao_sair_area)
		add_child(area)
	_atualiza()


func esta_livre() -> bool:
	return ocupante == null and not entupido


# Dá para desentupir agora (entupido e ninguém lá dentro).
func pode_desentupir() -> bool:
	return entupido and ocupante == null


# Passageiro tranca a cabine (já ao sair da fila, antes de chegar).
func ocupar(passageiro : Node2D) -> void:
	ocupante = passageiro
	_atualiza()


# Passageiro chegou ao vaso: fecha a porta da cabine.
func entrar(passageiro : Node2D) -> void:
	if ocupante == passageiro and is_instance_valid(porta):
		porta.fechar()


# Passageiro destranca a cabine (a porta abre); pode deixar o vaso entupido.
func liberar(passageiro : Node2D, pode_entupir := true) -> void:
	if ocupante != passageiro:
		return
	ocupante = null
	if is_instance_valid(porta):
		porta.abrir()
	if pode_entupir and randf() < chance_entupir:
		entupido = true
		print("Um vaso entupiu!")
	_atualiza()


# Chamado pelo maquinista ao terminar de desentupir.
func limpar() -> void:
	if not entupido:
		return
	entupido = false
	print("Vaso desentupido!")
	var diretor := get_tree().current_scene as Diretor
	if diretor != null:
		diretor.alivio_limpeza(global_position)
	_atualiza()


func _ao_entrar_area(body : Node2D) -> void:
	if body is Maquinista:
		_maquinista = body
		if not body.vasos_proximos.has(self):
			body.vasos_proximos.append(self)
		_atualiza()


func _ao_sair_area(body : Node2D) -> void:
	if body is Maquinista:
		body.vasos_proximos.erase(self)
		_maquinista = null
		_atualiza()


func _atualiza() -> void:
	var quadro := QUADRO_LIMPO
	if entupido:
		quadro = QUADRO_ENTUPIDO_DESTACADO if _maquinista != null and pode_desentupir() else QUADRO_ENTUPIDO
	_atlas.region = Rect2(quadro * TAMANHO_QUADRO, 0, TAMANHO_QUADRO, TAMANHO_QUADRO)
	queue_redraw()


# Plaquinha de "ocupado" na parede, acima do vaso, enquanto a cabine está trancada.
func _draw() -> void:
	if ocupante == null:
		return
	var placa := Rect2(-6, -TAMANHO / 2.0 - 9, 12, 6)
	draw_rect(placa.grow(1), COR_CONTORNO)
	draw_rect(placa, COR_TRANCADO)
