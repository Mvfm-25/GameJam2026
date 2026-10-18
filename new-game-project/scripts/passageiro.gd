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

# O passageiro é montado em camadas, sorteando cada peça: corpo, cabeça, olhos, boca e chapéu.
# Todas as folhas foram desenhadas em células de 192 px (a boca em 48 px e o chapéu em 64 px),
# com o dobro da resolução do passageiro antigo, então o conjunto é reduzido pela metade.
const ESCALA_VISUAL := 0.5
const CELULA := 192
const CORPOS_NORMAIS := preload("res://assets/characters/corpos_normais_mas.png")
const CORPOS_MAGROS := preload("res://assets/characters/corpos_magro_mas.png")
const CABECAS := preload("res://assets/characters/cabeças_masculinas.png")
const OLHOS := preload("res://assets/characters/olhos_masculinos.png")
const BOCAS := preload("res://assets/characters/bocas_masculinas.png")
const CHAPEUS := preload("res://assets/characters/chapeus_mas.png")

# Cabeças, olhos e bocas vêm em grupos de 3 poses (olhando em direções diferentes);
# a mesma pose é usada nas três peças para o rosto combinar.
const POSES := 3
const CORES_CORPO := 4
const ESTILOS_CABECA := 4
const ESTILOS_OLHOS := 5
const ESTILOS_BOCA := 5
const MODELOS_CHAPEU := 6
const CHANCE_CHAPEU := 0.5

# Cores de cabelo sorteadas no lugar do verde da folha de cabeças.
const TROCA_CABELO := preload("res://shaders/troca_cabelo.gdshader")
const CORES_CABELO := [
	Color("f4ea37"),
	Color("663931"),
	Color("8f563b"),
	Color("db7129"),
	Color("222034"),
]

# Onde cada peça fica dentro da célula de 192 px da cabeça.
const POSICAO_BOCA := Vector2(74, 71)
const POSICAO_CHAPEU := Vector2(64, 8)
const TAMANHO_BOCA := 48
const TAMANHO_CHAPEU := 64

var corpo = "Normal"
var tem_chapeu = false
var cor_cabelo : Color

func _camada(textura: Texture2D, indice: int, tamanho: int, posicao := Vector2.ZERO) -> Sprite2D:
	var colunas := textura.get_width() / tamanho
	var atlas := AtlasTexture.new()
	atlas.atlas = textura
	atlas.region = Rect2((indice % colunas) * tamanho, (indice / colunas) * tamanho, tamanho, tamanho)
	var camada := Sprite2D.new()
	camada.texture = atlas
	camada.centered = false
	camada.position = posicao
	return camada

func aposta_aparencia() :
	$AnimatedSprite2D.visible = false
	var visual := Node2D.new()
	visual.name = "Visual"
	visual.scale = Vector2.ONE * ESCALA_VISUAL
	# Sem suavização: o pixel art fica nítido e a troca de cor do cabelo não deixa franja verde.
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.position = Vector2(-CELULA, -CELULA) / 2.0 * ESCALA_VISUAL
	add_child(visual)
	move_child(visual, $AnimatedSprite2D.get_index() + 1)

	var pose := randi() % POSES
	corpo = ["Normal", "Magro"].pick_random()
	var folha_corpo := CORPOS_NORMAIS if corpo == "Normal" else CORPOS_MAGROS
	visual.add_child(_camada(folha_corpo, randi() % CORES_CORPO, CELULA))
	var cabeca := _camada(CABECAS, (randi() % ESTILOS_CABECA) * POSES + pose, CELULA)
	cor_cabelo = CORES_CABELO.pick_random()
	cabeca.material = ShaderMaterial.new()
	cabeca.material.shader = TROCA_CABELO
	cabeca.material.set_shader_parameter("cor_cabelo", cor_cabelo)
	visual.add_child(cabeca)
	visual.add_child(_camada(OLHOS, (randi() % ESTILOS_OLHOS) * POSES + pose, CELULA))
	visual.add_child(_camada(BOCAS, (randi() % ESTILOS_BOCA) * POSES + pose, TAMANHO_BOCA, POSICAO_BOCA))
	tem_chapeu = randf() < CHANCE_CHAPEU
	if tem_chapeu :
		visual.add_child(_camada(CHAPEUS, randi() % MODELOS_CHAPEU, TAMANHO_CHAPEU, POSICAO_CHAPEU))

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
	aposta_aparencia()
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
