@tool
extends Node2D
class_name Porta

# Porta do vagão: o jogador chega perto (aparece o contorno) e aperta "interagir".
# Ela abre tocando a animação, fica aberta por um tempo e fecha tocando a animação ao contrário.

# Segundos que a porta fica aberta antes de começar a fechar.
@export var tempo_aberta := 3.0

const TAMANHO_TILE := 32
const TAMANHO_TILE_ATLAS := 64
const TILESET := preload("res://assets/tileset/tileset_v1.png")
# Tile do tileset que desenha o vão da porta (coluna 1, linha 3, tiles de 64 px).
const REGIAO_VAO := Rect2(64, 192, 64, 64)

# Folha de animação: grade 3x3 de células de 192 px, com 8 quadros.
# Em cada célula, a porta ocupa 64 x 128 px a partir de (64, 16).
const FOLHA := preload("res://assets/Outros/Porta_ani.png")
const CONTORNO := preload("res://assets/Outros/Porta_seleção.png")
const CELULA := 192
const QUADROS := 8
const COLUNAS := 3
const VELOCIDADE_ANIMACAO := 12.0
# A partir deste quadro da abertura a porta já deixa o jogador passar.
const QUADRO_LIVRE := 4
# Até este quadro o resto do vão (abaixo da animação) vai recolhendo para cima.
const QUADRO_RECOLHIDO := 3

# A outra porta da mesma parede: as duas selecionam e abrem juntas.
var parceira: Porta
# Porta da parede direita: o trem anda para a esquerda, então ela dá para trás do trem.
# Só existe fechada no último vagão; por ela o maquinista pode jogar caveiras fora.
var traseira := false

var aberta := false
var _ocupada := false
var _perto := 0
var _espelhar := false
var _tamanho := 1 # Altura do vão, em tiles.
var _extra: Node2D

var _sprite: AnimatedSprite2D
var _contorno: Sprite2D
var _colisao_vao: CollisionShape2D
var _passagem: Area2D


# O Vagão chama logo após criar a porta. A origem fica no canto de cima da porta,
# que cobre 2 tiles (o topo da moldura e o vão); o resto do vão (se houver) é recolhido
# para cima junto com a animação.
func configurar(x: int, inicio: int, tamanho: int, espelhar: bool) -> void:
	_tamanho = tamanho
	_espelhar = espelhar
	traseira = espelhar
	position = Vector2(x, inicio - 1) * TAMANHO_TILE
	_construir()


func _construir() -> void:
	var altura_vao := TAMANHO_TILE * _tamanho

	_sprite = AnimatedSprite2D.new()
	_sprite.centered = false
	_sprite.scale = Vector2.ONE * TAMANHO_TILE / TAMANHO_TILE_ATLAS
	_sprite.flip_h = _espelhar
	_sprite.sprite_frames = _monta_quadros()
	_sprite.animation = &"abrir"
	_sprite.frame = 0
	_sprite.frame_changed.connect(_ao_mudar_quadro)
	add_child(_sprite)

	# O resto do vão fica sob a animação e encolhe em direção ao topo.
	_extra = Node2D.new()
	_extra.position = Vector2(0, 2 * TAMANHO_TILE)
	for i in _tamanho - 1:
		var parte := Sprite2D.new()
		parte.texture = TILESET
		parte.region_enabled = true
		parte.region_rect = REGIAO_VAO
		parte.centered = false
		parte.flip_h = _espelhar
		parte.scale = _sprite.scale
		parte.position = Vector2(0, i * TAMANHO_TILE)
		_extra.add_child(parte)
	_extra.visible = _tamanho > 1
	add_child(_extra)

	_contorno = Sprite2D.new()
	_contorno.texture = CONTORNO
	_contorno.centered = false
	_contorno.scale = _sprite.scale
	_contorno.flip_h = _espelhar
	_contorno.visible = false
	add_child(_contorno)

	# Parede sólida: o topo da moldura nunca abre; o vão só some com a porta aberta.
	var corpo := StaticBody2D.new()
	add_child(corpo)
	var topo := CollisionShape2D.new()
	topo.shape = _retangulo(Vector2(TAMANHO_TILE, TAMANHO_TILE))
	topo.position = Vector2(TAMANHO_TILE, TAMANHO_TILE) / 2.0
	corpo.add_child(topo)
	_colisao_vao = CollisionShape2D.new()
	_colisao_vao.shape = _retangulo(Vector2(TAMANHO_TILE, altura_vao))
	_colisao_vao.position = Vector2(TAMANHO_TILE / 2.0, TAMANHO_TILE + altura_vao / 2.0)
	corpo.add_child(_colisao_vao)

	if Engine.is_editor_hint():
		return

	# Mede se o jogador está perto o bastante para interagir.
	var alcance := Area2D.new()
	var forma_alcance := CollisionShape2D.new()
	forma_alcance.shape = _retangulo(Vector2(TAMANHO_TILE * 3, TAMANHO_TILE + altura_vao + TAMANHO_TILE))
	forma_alcance.position = Vector2(TAMANHO_TILE / 2.0, (TAMANHO_TILE + altura_vao) / 2.0 + TAMANHO_TILE / 2.0)
	alcance.add_child(forma_alcance)
	alcance.body_entered.connect(_ao_entrar)
	alcance.body_exited.connect(_ao_sair)
	add_child(alcance)

	# Impede a porta de fechar com alguém parado no vão.
	_passagem = Area2D.new()
	var forma_passagem := CollisionShape2D.new()
	forma_passagem.shape = _retangulo(Vector2(TAMANHO_TILE, altura_vao))
	forma_passagem.position = _colisao_vao.position
	_passagem.add_child(forma_passagem)
	add_child(_passagem)


# Ponto do lado de fora da porta, na altura do meio do vão (para onde as coisas são jogadas).
func ponto_fora() -> Vector2:
	var direcao := 1.0 if _espelhar else -1.0
	var altura_vao := TAMANHO_TILE * _tamanho
	return to_global(Vector2(TAMANHO_TILE / 2.0 + direcao * TAMANHO_TILE * 4, TAMANHO_TILE + altura_vao / 2.0))


func _retangulo(tamanho: Vector2) -> RectangleShape2D:
	var forma := RectangleShape2D.new()
	forma.size = tamanho
	return forma


func _monta_quadros() -> SpriteFrames:
	var quadros := SpriteFrames.new()
	quadros.add_animation(&"abrir")
	quadros.set_animation_loop(&"abrir", false)
	quadros.set_animation_speed(&"abrir", VELOCIDADE_ANIMACAO)
	for i in QUADROS:
		var atlas := AtlasTexture.new()
		atlas.atlas = FOLHA
		atlas.region = Rect2((i % COLUNAS) * CELULA + 64, (i / COLUNAS) * CELULA + 16, 64, 128)
		quadros.add_frame(&"abrir", atlas)
	return quadros


func _ao_entrar(corpo: Node2D) -> void:
	if corpo is Maquinista:
		corpo.portas_proximas.append(self)
		_perto += 1
		_atualiza_contorno()
		if parceira:
			parceira._atualiza_contorno()


func _ao_sair(corpo: Node2D) -> void:
	if corpo is Maquinista:
		corpo.portas_proximas.erase(self)
		_perto -= 1
		_atualiza_contorno()
		if parceira:
			parceira._atualiza_contorno()


func _atualiza_contorno() -> void:
	var perto := _perto > 0 or (parceira != null and parceira._perto > 0)
	_contorno.visible = perto and not _ocupada


func _ao_mudar_quadro() -> void:
	# O resto do vão sobe e some nos primeiros quadros (ao contrário, desce ao fechar).
	_extra.scale.y = 1.0 - clampf(float(_sprite.frame) / QUADRO_RECOLHIDO, 0.0, 1.0)
	# Abrindo: libera a passagem na metade da animação. Fechando: só fecha ao terminar.
	if _sprite.frame >= QUADRO_LIVRE and aberta:
		_colisao_vao.set_deferred("disabled", true)


func _alguem_no_vao() -> bool:
	for corpo in _passagem.get_overlapping_bodies():
		if corpo is CharacterBody2D:
			return true
	return false


# As duas portas da parede abrem juntas.
func interage() -> void:
	if parceira != null:
		parceira._ciclo()
	_ciclo()


# Abre, espera e fecha sozinha tocando a animação de trás para frente.
func _ciclo() -> void:
	if _ocupada:
		return
	_ocupada = true
	aberta = true
	_atualiza_contorno()
	_sprite.play(&"abrir")
	await _sprite.animation_finished

	await get_tree().create_timer(tempo_aberta).timeout
	while _alguem_no_vao():
		await get_tree().create_timer(0.2).timeout

	_sprite.play_backwards(&"abrir")
	await _sprite.animation_finished
	_colisao_vao.set_deferred("disabled", false)
	aberta = false
	_ocupada = false
	_atualiza_contorno()
	if parceira:
		parceira._atualiza_contorno()
