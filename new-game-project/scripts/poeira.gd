extends Node2D
class_name Poeira

# Grãos de poeira que atravessam a tela da esquerda para a direita, por fora do trem
# (ficam atrás dos vagões). Passam devagar com o trem parado e rápido com ele correndo,
# e vão subindo e descendo enquanto passam.
#
# A folha é uma grade de células de tamanho_celula px, uma partícula em cada.

@export var textura : Texture2D
@export var tamanho_celula := 64
@export var colunas_folha := 2
@export var linhas_folha := 2
# Arte no dobro da resolução, igual ao resto do jogo; cada grão sorteia um múltiplo disto.
@export var escala := 0.5
@export var variacao_escala := Vector2(1.0, 2.0)
@export var opacidade := Vector2(0.6, 1.0)

# Velocidade (px/s) parado e correndo. Correndo é um múltiplo da velocidade dos trilhos.
@export var velocidade_parado := 30.0
@export var multiplicador_correndo := 1.6
# Quão rápido a velocidade muda ao partir ou parar (maior = mais brusco).
@export var aceleracao := 1.5
# Cada grão anda numa fração aleatória da velocidade, para não ficarem em bloco.
@export var variacao_velocidade := Vector2(0.6, 1.4)

# Movimento vertical: ondula (amplitude em px, ciclos por segundo) e ainda deriva devagar.
@export var amplitude_vertical := Vector2(6.0, 22.0)
@export var frequencia_vertical := Vector2(0.3, 0.9)
@export var deriva_vertical := 12.0

# Grãos por segundo na tela em velocidade correndo; parado nascem na mesma proporção
# da velocidade (menos grãos).
@export var graos_por_segundo := 6.0
@export var ativo := true

# Folga entre o grão e o começo da parte escura do chão.
const MARGEM_CHAO_ESCURO := 8.0

var _trilhos : Trilhos
var _velocidade := 0.0
var _espera := 0.0
var _povoou := false

# Dados de cada grão (parado no Sprite2D como metadados): fase, frequência, amplitude etc.
const META_VARIACAO := &"variacao"
const META_BASE_Y := &"base_y"
const META_FASE := &"fase"
const META_FREQUENCIA := &"frequencia"
const META_AMPLITUDE := &"amplitude"
const META_DERIVA := &"deriva"
const META_TEMPO := &"tempo"


func _ready() -> void:
	_trilhos = get_parent().get_node_or_null("Trilhos") as Trilhos
	_velocidade = velocidade_parado


func _process(delta: float) -> void:
	if not ativo or Engine.is_editor_hint() or textura == null:
		return
	var vista := _vista()
	if not _povoou:
		_povoou = true
		_povoa(vista)
	var alvo := _velocidade_alvo()
	_velocidade = lerpf(_velocidade, alvo, 1.0 - exp(-aceleracao * delta))
	for grao in get_children():
		_move(grao as Sprite2D, delta)
		if grao.position.x > vista.end.x + tamanho_celula * escala * variacao_escala.y:
			grao.queue_free()
	# Menos grãos com o trem parado: o intervalo cresce quando a velocidade cai.
	var cheia := _velocidade_correndo()
	var ritmo := graos_por_segundo * clampf(_velocidade / cheia, 0.15, 1.0)
	_espera -= delta
	if _espera <= 0.0:
		_espera = randf_range(0.5, 1.5) / ritmo
		_cria_grao(vista, vista.position.x - tamanho_celula * escala * variacao_escala.y)


func _velocidade_correndo() -> float:
	var base := _trilhos.velocidade if _trilhos != null else 160.0
	return base * multiplicador_correndo


# O Diretor liga e desliga os trilhos conforme o trem anda ou para.
func _velocidade_alvo() -> float:
	var correndo := _trilhos == null or _trilhos.ativo
	return _velocidade_correndo() if correndo else velocidade_parado


func _move(grao: Sprite2D, delta: float) -> void:
	grao.position.x += _velocidade * grao.get_meta(META_VARIACAO) * delta
	var t : float = grao.get_meta(META_TEMPO) + delta
	grao.set_meta(META_TEMPO, t)
	var base : float = grao.get_meta(META_BASE_Y) + grao.get_meta(META_DERIVA) * t
	var y : float = base + sin(t * TAU * grao.get_meta(META_FREQUENCIA) + grao.get_meta(META_FASE)) \
		* grao.get_meta(META_AMPLITUDE)
	# A ondulação e a deriva não podem levar o grão para a parte escura do chão.
	grao.position.y = minf(y, _limite_inferior())


# Área do mundo que a câmera está mostrando agora.
func _vista() -> Rect2:
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()


# No começo a tela já tem poeira, em vez de esperar os primeiros grãos chegarem.
func _povoa(vista: Rect2) -> void:
	var quantidade := int(graos_por_segundo * 4.0)
	for i in quantidade:
		_cria_grao(vista, randf_range(vista.position.x, vista.end.x))


func _cria_grao(vista: Rect2, x: float) -> void:
	var celula := randi() % (colunas_folha * linhas_folha)
	var atlas := AtlasTexture.new()
	atlas.atlas = textura
	atlas.region = Rect2((celula % colunas_folha) * tamanho_celula, (celula / colunas_folha) * tamanho_celula,
		tamanho_celula, tamanho_celula)
	var grao := Sprite2D.new()
	grao.texture = atlas
	grao.scale = Vector2.ONE * escala * randf_range(variacao_escala.x, variacao_escala.y)
	grao.modulate.a = randf_range(opacidade.x, opacidade.y)
	grao.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var y := randf_range(vista.position.y, minf(vista.end.y, _limite_inferior()))
	grao.set_meta(META_BASE_Y, y)
	grao.set_meta(META_VARIACAO, randf_range(variacao_velocidade.x, variacao_velocidade.y))
	grao.set_meta(META_FASE, randf() * TAU)
	grao.set_meta(META_FREQUENCIA, randf_range(frequencia_vertical.x, frequencia_vertical.y))
	grao.set_meta(META_AMPLITUDE, randf_range(amplitude_vertical.x, amplitude_vertical.y))
	grao.set_meta(META_DERIVA, randf_range(-deriva_vertical, deriva_vertical))
	grao.set_meta(META_TEMPO, 0.0)
	grao.position = Vector2(x, y)
	add_child(grao)


# y onde começa a parte escura do chão: logo abaixo da faixa clara que fica colada nos
# trilhos (o vagão tem altura_tiles linhas mais a das rodas; a faixa é o bloco padrão do Chao).
func _limite_inferior() -> float:
	for filho in get_parent().get_children():
		if filho is Node2D and "largura_tiles" in filho:
			var faixa := 32.0
			var chao := get_parent().get_node_or_null("Trilhos/Chao") as Chao
			if chao != null:
				faixa = chao.linhas_bloco_padrao * Chao.TILE_ARTE * chao.escala
			return filho.global_position.y + (filho.altura_tiles + 1) * 32.0 + faixa - MARGEM_CHAO_ESCURO
	return INF
