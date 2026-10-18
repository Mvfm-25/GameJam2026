extends Control
class_name FundoAnimado

# Fundo das telas de início e créditos: céu de entardecer, poeira atravessando a tela
# e trilhos correndo embaixo, como se o trem estivesse sempre em movimento.

const POEIRAS := preload("res://assets/Outros/poeiras.png")
const TRILHO_SUPERIOR := preload("res://assets/tileset/trilhoSuperior.png")
const TRILHO_MEIO := preload("res://assets/tileset/trilho.png")
const TRILHO_INFERIOR := preload("res://assets/tileset/trilhoInferior.png")
const TAMANHO_TILE := 32
const TAMANHO_TILE_ATLAS := 64
# Largura (em tiles) do desenho dos trilhos: precisa cobrir qualquer largura de tela.
const COLUNAS_TRILHOS := 160

const CORES_CEU := [Color("14111c"), Color("2b1a30"), Color("7a3d2c"), Color("d98a3d")]
const COR_CHAO := Color("2a1a18")

@export var velocidade_trilhos := 140.0
# Altura dos trilhos em tiles (cima, meio repetido e baixo) e distância até a borda de baixo.
@export var linhas_trilhos := 3
@export var margem_baixo := 56.0

var _trilhos := Node2D.new()
var _chao := ColorRect.new()
var _poeira := CPUParticles2D.new()
var _deslocamento := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cria_ceu()
	_cria_poeira()
	_cria_trilhos()
	resized.connect(_ajusta)
	_ajusta()


func _process(delta: float) -> void:
	_deslocamento = fposmod(_deslocamento + velocidade_trilhos * delta, TAMANHO_TILE)
	_trilhos.position.x = _deslocamento - TAMANHO_TILE * 2


func _cria_ceu() -> void:
	var gradiente := Gradient.new()
	gradiente.offsets = PackedFloat32Array([0.0, 0.45, 0.8, 1.0])
	gradiente.colors = PackedColorArray(CORES_CEU)
	var textura := GradientTexture2D.new()
	textura.gradient = gradiente
	textura.fill_from = Vector2(0.0, 0.0)
	textura.fill_to = Vector2(0.0, 1.0)
	var ceu := TextureRect.new()
	ceu.texture = textura
	ceu.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ceu.stretch_mode = TextureRect.STRETCH_SCALE
	ceu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ceu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ceu)


# Grãos de poeira nascendo à esquerda e indo para a direita, com pré-processamento
# para a tela já começar cheia.
func _cria_poeira() -> void:
	var material := CanvasItemMaterial.new()
	material.particles_animation = true
	material.particles_anim_h_frames = 2
	material.particles_anim_v_frames = 2
	material.particles_anim_loop = false
	_poeira.material = material
	_poeira.texture = POEIRAS
	_poeira.amount = 70
	_poeira.lifetime = 14.0
	_poeira.preprocess = 14.0
	_poeira.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_poeira.direction = Vector2(1.0, -0.05)
	_poeira.spread = 28.0
	_poeira.gravity = Vector2.ZERO
	_poeira.initial_velocity_min = 70.0
	_poeira.initial_velocity_max = 190.0
	_poeira.angular_velocity_min = -30.0
	_poeira.angular_velocity_max = 30.0
	_poeira.scale_amount_min = 0.5
	_poeira.scale_amount_max = 1.1
	_poeira.anim_offset_max = 1.0
	var transparencia := Gradient.new()
	transparencia.offsets = PackedFloat32Array([0.0, 0.1, 0.85, 1.0])
	transparencia.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	_poeira.color_ramp = transparencia
	add_child(_poeira)


# Chão escuro com os trilhos por cima, passando sem parar para a direita.
func _cria_trilhos() -> void:
	_chao.color = COR_CHAO
	_chao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chao)
	add_child(_trilhos)
	_faixa(TRILHO_SUPERIOR, 0, 1)
	_faixa(TRILHO_MEIO, 1, linhas_trilhos - 2)
	_faixa(TRILHO_INFERIOR, linhas_trilhos - 1, 1)


# Uma faixa de `linhas` tiles, repetindo a imagem pela largura toda.
func _faixa(textura: Texture2D, linha: int, linhas: int) -> void:
	if linhas <= 0:
		return
	var sprite := Sprite2D.new()
	sprite.texture = textura
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, COLUNAS_TRILHOS * TAMANHO_TILE_ATLAS, linhas * TAMANHO_TILE_ATLAS)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * TAMANHO_TILE / TAMANHO_TILE_ATLAS
	sprite.position = Vector2(0, linha * TAMANHO_TILE)
	_trilhos.add_child(sprite)


func _ajusta() -> void:
	var y := size.y - margem_baixo - linhas_trilhos * TAMANHO_TILE
	_trilhos.position.y = y
	_chao.position = Vector2(0, y + TAMANHO_TILE)
	_chao.size = Vector2(size.x, maxf(0.0, size.y - y - TAMANHO_TILE))
	_poeira.position = Vector2(-40.0, y * 0.5)
	_poeira.emission_rect_extents = Vector2(10.0, y * 0.5)
