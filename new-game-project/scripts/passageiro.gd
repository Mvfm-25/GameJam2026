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

# Necessidade sorteada ao embarcar (FAMINTO ou DESACONCHEGADO).
var necessidades = []

# --- Raiva -----------------------------------------------------------------
# A raiva sobe pela soma das fontes abaixo (valores por segundo).
# Tédio: sobe devagar mesmo sem motivo. Cada passageiro tem seu ritmo.
var taxa_raiva_base = randf_range(0.0015, 0.0025)
@export var raiva_fome := 0.008
# Por sujeira próxima (sangue conta como duas), até sujeiras_max_raiva.
@export var raiva_por_sujeira := 0.005
@export var sujeiras_max_raiva := 3.0
@export var raio_sujeira := 120.0
# IMUNDO multiplica a taxa total.
@export var multiplicador_imundo := 1.5
# Fome cresce até mostrar o balão (0.6) em ~30 s.
@export var taxa_fome := 0.02
# Comer acalma.
@export var alivio_comida := 0.3

# Acima disso vira IRADO e passa a contagiar; acima de LIMIAR_PUTO mostra o balão.
const LIMIAR_IRADO := 0.9
const LIMIAR_PUTO := 0.5

# --- Imundo ----------------------------------------------------------------
# Exposição à sujeira acumula (peso das sujeiras próximas * taxa); em 1.0 vira IMUNDO.
# Só o maquinista limpando por perto tira o IMUNDO.
@export var taxa_exposicao := 0.1
var exposicao := 0.0
var imundo := false
# Imundo suja mais nos passeios.
@export_range(0.0, 1.0) var chance_sujeira_imundo := 0.5

# --- Contágio --------------------------------------------------------------
# Um IRADO "explode" a cada intervalo_contagio, podendo irritar quem está perto.
var irado := false
@export var intervalo_contagio := 3.0
@export var raio_contagio := 135.0
@export_range(0.0, 1.0) var chance_contagio := 0.35
@export var raiva_contagio := 0.15
# Depois de ser contagiado, fica um tempo sem ser atingido de novo.
@export var recarga_contagio := 5.0
var _tempo_pulso := 0.0
var _recarga := 0.0

# --- Sacrificial -----------------------------------------------------------
# Vendo uma caveira por perto (no chão ou nas mãos do maquinista), o passageiro
# pede que ela seja jogada na fornalha: mostra o balão de fogo e vai ficando bravo.
# Queimar a caveira acalma quem pedia; jogá-la pela porta traseira os enfurece.
var sacrificial := false
@export var raio_caveira := 220.0
@export var raiva_sacrificio := 0.01
@export var alivio_sacrificio := 0.3
@export var raiva_descarte := 0.25

# --- Cadeira & passeio ---------------------------------------------------
# Cadeira onde o passageiro senta. Se ficar vazio, pega a cadeira livre
# mais próxima dentro de raio_busca_cadeira.
@export var cadeira : Cadeira = null
@export var raio_busca_cadeira := 60.0
# Caminhos que ele pode passear. Vazio = qualquer Caminho da cena que tenha
# uma ponta a até alcance_caminho px da cadeira.
@export var caminhos : Array[Caminho] = []
@export var alcance_caminho := 400.0
# De quanto em quanto tempo ele pensa em levantar, e a chance de levantar.
@export var intervalo_passeio_min := 10.0
@export var intervalo_passeio_max := 30.0
@export_range(0.0, 1.0) var chance_passeio := 0.4
@export var velocidade_caminhada := 60.0
# Chance de um passeio deixar sujeira (no máximo uma por passeio),
# num ponto sorteado do trajeto.
@export_range(0.0, 1.0) var chance_sujeira_passeio := 0.25
# Distância que ainda falta andar até sujar; negativa = este passeio não suja.
var _distancia_ate_sujar := -1.0

enum Estado { SENTADO, ANDANDO, NA_FILA, NO_VASO }
var estado = Estado.SENTADO
# Pontos (globais) que faltam percorrer no passeio atual.
var _rota := PackedVector2Array()
# O que fazer ao terminar a rota; vazio = sentar na cadeira.
var _ao_fim_rota := Callable()
var _timer_passeio := Timer.new()

# --- Banheiro ------------------------------------------------------------
# Quando pensa em levantar, chance de ir ao banheiro (antes de pensar em passear).
@export_range(0.0, 1.0) var chance_banheiro := 0.04
@export var tempo_banheiro_min := 7.0
@export var tempo_banheiro_max := 11.0
# Raiva por segundo parado na fila.
@export var raiva_fila := 0.006
# Distância entre quem está na fila.
const ESPACO_FILA := 30.0
var _banheiro : Banheiro = null
var _vaso : Vaso = null
# Posição na linha da RedeCaminhos (a fila anda por ela) e onde ele entrou nela.
var _s := 0.0
var _s_entrada := 0.0
var _esperando := false

# O passageiro é montado em camadas, sorteando cada peça: corpo, cabeça, olhos, boca e chapéu.
# Todas as folhas foram desenhadas em células de 192 px (só o chapéu é de 64 px),
# com o dobro da resolução do passageiro antigo, então o conjunto é reduzido pela metade.
const ESCALA_VISUAL := 0.5
const CELULA := 192
# Tipos de corpo: folha de cores e quantas cores ela tem.
const CORPOS := {
	"Normal": { "folha": preload("res://assets/characters/corpos_normais_mas.png"), "cores": 4 },
	"Magro": { "folha": preload("res://assets/characters/corpos_magro_mas.png"), "cores": 4 },
	"Forte": { "folha": preload("res://assets/characters/corpos_forte_mas.png"), "cores": 6 },
}
const CABECAS := preload("res://assets/characters/cabeças_masculinas.png")
const OLHOS := preload("res://assets/characters/olhos_masculinos.png")
const BOCAS := preload("res://assets/characters/bocas_masculinas.png")
const CHAPEUS := preload("res://assets/characters/chapeus_mas.png")

# Cabeças, olhos e bocas vêm em grupos de 3 poses (olhando em direções diferentes);
# a mesma pose é usada nas três peças para o rosto combinar.
const POSES := 3
const ESTILOS_CABECA := 4
const ESTILOS_OLHOS := 5
const ESTILOS_BOCA := 5
const MODELOS_CHAPEU := 6
const CHANCE_CHAPEU := 0.0 # Chapéus desligados por enquanto (era 0.5).

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
const POSICAO_CHAPEU := Vector2(64, 8)
const TAMANHO_CHAPEU := 64

# Mesma animação de andar do maquinista: inclina, pula de leve e amassa a cada passo.
const BALANCO_ANGULO := 0.09 # radianos (~5 graus)
const BALANCO_VELOCIDADE := 22.0
const PULINHO := 1.5 # pixels
const AMASSADA := 0.04
const SUAVIZACAO := 18.0
# IRADO anda mais agitado: balança, pula e amassa mais, com passos mais rápidos.
const IRADO_BALANCO := 2.2
const IRADO_PULINHO := 3.0
const IRADO_VELOCIDADE := 1.4
# Parado, o passageiro agitado (IRADO ou IMUNDO) tem chiliques de tempos em tempos:
# treme o corpo rápido e dá pulinhos por um instante.
const CHILIQUE_INTERVALO_MIN := 1.5
const CHILIQUE_INTERVALO_MAX := 3.5
const CHILIQUE_DURACAO := 0.45
const CHILIQUE_ANGULO := 0.16 # radianos (~9 graus)
const CHILIQUE_VELOCIDADE := 55.0
const CHILIQUE_PULINHO := 3.0
var _espera_chilique := 0.0
var _tempo_chilique := 0.0
var _visual : Node2D
var _fase_passo := 0.0

# Rosto (cabeça, olhos e boca) e o estilo de cada peça, para trocar de pose ao andar.
# Poses da folha: 0 = de frente, 1 = olhando para a esquerda, 2 = olhando para a direita.
var _rosto : Array[Sprite2D] = []
var _estilos_rosto : Array[int] = []
var _texturas_rosto : Array[Texture2D] = []
var _pose_sentado := 0
var _pose := -1
var _posicao_anterior := Vector2.ZERO

var corpo = "Normal"
var tem_chapeu = false
var cor_cabelo : Color

func _regiao(textura: Texture2D, indice: int, tamanho: int) -> Rect2:
	var colunas := textura.get_width() / tamanho
	return Rect2((indice % colunas) * tamanho, (indice / colunas) * tamanho, tamanho, tamanho)

func _camada(textura: Texture2D, indice: int, tamanho: int, posicao := Vector2.ZERO) -> Sprite2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = textura
	atlas.region = _regiao(textura, indice, tamanho)
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
	add_child(visual)
	move_child(visual, $AnimatedSprite2D.get_index() + 1)
	_visual = visual
	# As peças ficam num nó deslocado para o centro da célula ser a origem do visual;
	# assim a inclinação de andar gira em torno do meio do corpo.
	var camadas := Node2D.new()
	camadas.name = "Camadas"
	camadas.position = Vector2(-CELULA, -CELULA) / 2.0
	visual.add_child(camadas)

	var pose := randi() % POSES
	_pose_sentado = pose
	_pose = pose
	corpo = CORPOS.keys().pick_random()
	var dados : Dictionary = CORPOS[corpo]
	camadas.add_child(_camada(dados["folha"], randi() % int(dados["cores"]), CELULA))
	var estilo_cabeca := randi() % ESTILOS_CABECA
	var cabeca := _camada(CABECAS, estilo_cabeca * POSES + pose, CELULA)
	cor_cabelo = CORES_CABELO.pick_random()
	cabeca.material = ShaderMaterial.new()
	cabeca.material.shader = TROCA_CABELO
	cabeca.material.set_shader_parameter("cor_cabelo", cor_cabelo)
	camadas.add_child(cabeca)
	var estilo_olhos := randi() % ESTILOS_OLHOS
	var olhos := _camada(OLHOS, estilo_olhos * POSES + pose, CELULA)
	camadas.add_child(olhos)
	var estilo_boca := randi() % ESTILOS_BOCA
	var boca := _camada(BOCAS, estilo_boca * POSES + pose, CELULA)
	camadas.add_child(boca)
	_rosto = [cabeca, olhos, boca]
	_estilos_rosto = [estilo_cabeca, estilo_olhos, estilo_boca]
	_texturas_rosto = [CABECAS, OLHOS, BOCAS]
	tem_chapeu = randf() < CHANCE_CHAPEU
	if tem_chapeu :
		camadas.add_child(_camada(CHAPEUS, randi() % MODELOS_CHAPEU, TAMANHO_CHAPEU, POSICAO_CHAPEU))

# Vira o rosto para onde está indo: esquerda/direita pelo lado, de frente subindo ou descendo.
# Parado (sentado ou esperando na fila), volta à pose sorteada ao sentar.
func _atualiza_pose() -> void:
	var movimento := global_position - _posicao_anterior
	_posicao_anterior = global_position
	var nova := _pose_sentado
	if estado == Estado.ANDANDO or estado == Estado.NA_FILA :
		if movimento.length_squared() > 0.0001 :
			if absf(movimento.x) > absf(movimento.y) :
				nova = 1 if movimento.x < 0.0 else 2
			else :
				nova = 0
		else :
			nova = _pose
	if nova == _pose or _rosto.is_empty() :
		return
	_pose = nova
	for i in _rosto.size() :
		var atlas := _rosto[i].texture as AtlasTexture
		atlas.region = _regiao(_texturas_rosto[i], _estilos_rosto[i] * POSES + nova, CELULA)

# Inclina o corpo enquanto anda; sentado, volta suavemente à posição normal.
func _anima_andar(delta : float) -> void:
	if _visual == null :
		return
	var angulo := 0.0
	var pulo := 0.0
	var amassada := 0.0
	var agitado := esta_vivo() and (irado or imundo)
	var direto := false
	if estado == Estado.ANDANDO or (estado == Estado.NA_FILA and not _esperando) :
		var balanco := IRADO_BALANCO if agitado else 1.0
		var pulinho := IRADO_PULINHO if agitado else 1.0
		_fase_passo += delta * BALANCO_VELOCIDADE * (IRADO_VELOCIDADE if agitado else 1.0)
		angulo = sin(_fase_passo) * BALANCO_ANGULO * balanco
		var passo := absf(sin(_fase_passo))
		pulo = -passo * PULINHO * pulinho
		amassada = (0.5 - passo) * AMASSADA * balanco
	elif agitado :
		var chilique := _anima_chilique(delta)
		angulo = chilique.x
		direto = _tempo_chilique > 0.0
		pulo = chilique.y
		amassada = -chilique.y / CHILIQUE_PULINHO * AMASSADA * IRADO_BALANCO
	var peso := 1.0 - exp(-SUAVIZACAO * delta)
	# O chilique é rápido demais para a suavização: aplica direto.
	if direto :
		peso = 1.0
	_visual.rotation = lerp_angle(_visual.rotation, angulo, peso)
	_visual.position = _visual.position.lerp(Vector2(0, pulo), peso)
	var escala := Vector2.ONE * ESCALA_VISUAL
	_visual.scale = _visual.scale.lerp(escala * Vector2(1.0 - amassada, 1.0 + amassada), peso)

# Chilique do passageiro agitado parado: espera um tempo e treme por CHILIQUE_DURACAO.
# Retorna (ângulo, pulo) do momento.
func _anima_chilique(delta : float) -> Vector2:
	if _tempo_chilique <= 0.0 :
		_espera_chilique -= delta
		if _espera_chilique > 0.0 :
			return Vector2.ZERO
		_tempo_chilique = CHILIQUE_DURACAO
		_espera_chilique = randf_range(CHILIQUE_INTERVALO_MIN, CHILIQUE_INTERVALO_MAX)
	_tempo_chilique -= delta
	var t := CHILIQUE_DURACAO - _tempo_chilique
	# Treme forte no começo e vai parando.
	var forca := clampf(_tempo_chilique / CHILIQUE_DURACAO, 0.0, 1.0)
	var angulo := sin(t * CHILIQUE_VELOCIDADE) * CHILIQUE_ANGULO * forca
	var pulo := -absf(sin(t * CHILIQUE_VELOCIDADE * 0.5)) * CHILIQUE_PULINHO * forca
	return Vector2(angulo, pulo)

# IRADO e IMUNDO não são mais sorteados: surgem da raiva e da sujeira.
# Mantém 1 em 4 com fome, como antes.
func aposta_necessidade() :
	var sorteado = "FAMINTO" if randf() < 0.25 else "DESACONCHEGADO"
	necessidades.append(sorteado)
	print("Passageiro " + nome + " está : " + sorteado)
	timer.start()

func aposta_nome():
	nome = ["Durandal", "Tycho", "Leela", "Dynamo", "Abrams", "Casius Cleiton", "Misha"].pick_random()
	print("Nome escolhido : %s" % nome)
	
# Soma as fontes de raiva do momento (por segundo).
func taxa_raiva(diretor : Diretor) -> float:
	var taxa = taxa_raiva_base
	if necessidades.has("FAMINTO") :
		taxa += raiva_fome
	if estado == Estado.NA_FILA and _esperando :
		taxa += raiva_fila
	if diretor != null :
		var sujeira := minf(diretor.peso_sujeiras_perto(global_position, raio_sujeira), sujeiras_max_raiva)
		taxa += raiva_por_sujeira * sujeira
	if sacrificial :
		taxa += raiva_sacrificio
	if imundo :
		taxa *= multiplicador_imundo
	return taxa

func atualiza_raiva(delta : float, diretor : Diretor) :
	nivel_raiva = minf(1.0, nivel_raiva + taxa_raiva(diretor) * delta)

func atualiza_fome(delta : float):
	quantidade_fome = minf(1.0, quantidade_fome + taxa_fome * delta)

# Sujeira por perto vai deixando o passageiro IMUNDO.
func atualiza_exposicao(delta : float, diretor : Diretor) -> void:
	if imundo or diretor == null :
		return
	exposicao += diretor.peso_sujeiras_perto(global_position, raio_sujeira) * taxa_exposicao * delta
	if exposicao >= 1.0 :
		imundo = true
		print("Passageiro " + nome + " ficou IMUNDO!")
		_atualiza_contente()

# O maquinista limpou por perto.
func limpa_imundo() -> void:
	exposicao = 0.0
	if not imundo :
		return
	imundo = false
	print("Passageiro " + nome + " não está mais imundo.")
	_atualiza_contente()

# Baixa a raiva (comida, limpeza).
func acalma(valor : float) -> void:
	if not esta_vivo() :
		return
	nivel_raiva = maxf(0.0, nivel_raiva - valor)
	_atualiza_irado()

# Recebe a fúria de um vizinho IRADO.
func contagia(valor : float) -> bool:
	if not esta_vivo() or irado or _recarga > 0.0 :
		return false
	_recarga = recarga_contagio
	nivel_raiva = minf(1.0, nivel_raiva + valor)
	return true

func _atualiza_irado() -> void:
	var agora : bool = nivel_raiva >= LIMIAR_IRADO
	if agora == irado :
		return
	irado = agora
	_tempo_pulso = 0.0
	print("Passageiro " + nome + (" ficou IRADO!" if irado else " se acalmou."))
	_atualiza_contente()

# IRADO espalha a fúria para quem está perto, de tempos em tempos.
func _pulso_contagio(delta : float, diretor : Diretor) -> void:
	if not irado or diretor == null :
		return
	_tempo_pulso += delta
	if _tempo_pulso < intervalo_contagio :
		return
	_tempo_pulso = 0.0
	for p in diretor.passageiros_perto(global_position, raio_contagio) :
		if p != self and randf() < chance_contagio and p.contagia(raiva_contagio) :
			print(nome + " contagiou " + p.nome + " com sua fúria!")

# Liga o modo sacrificial enquanto houver uma caveira à vista, e marca cada caveira
# vista para reagir ao destino dela depois.
func _atualiza_sacrificial(diretor : Diretor) -> void:
	var vistas : Array[Item] = diretor.caveiras_perto(global_position, raio_caveira) if diretor != null else []
	for c in vistas :
		if not c.testemunhas.has(self) :
			c.testemunhas.append(self)
	var agora := not vistas.is_empty()
	if agora == sacrificial :
		return
	sacrificial = agora
	if sacrificial :
		print("Passageiro " + nome + " quer a caveira na fornalha!")
	_atualiza_contente()

# A caveira que ele via foi queimada: ficou satisfeito.
func ve_caveira_queimada() -> void:
	acalma(alivio_sacrificio)

# A caveira que ele via foi jogada para fora do trem.
func ve_caveira_descartada() -> void:
	if not esta_vivo() :
		return
	nivel_raiva = minf(1.0, nivel_raiva + raiva_descarte)
	_atualiza_irado()

# Contente = sem necessidades, nem bravo nem sujo, e sem caveira à vista.
func _atualiza_contente() -> void:
	contente = necessidades.is_empty() and not imundo and not irado and not sacrificial

# Um balão por vez: sacrifício > irado > fome > puto (raiva alta ou desconforto por estar imundo).
func _atualiza_baloes() -> void:
	var com_fome = necessidades.has("FAMINTO") and quantidade_fome >= 0.6
	$sacrificio.visible = sacrificial
	$muito_puto.visible = not sacrificial and irado
	$fome.visible = not sacrificial and not irado and com_fome
	$puto.visible = not sacrificial and not irado and not com_fome and (nivel_raiva >= LIMIAR_PUTO or imundo)

# Enquanto houver uma caveira no trem (no chão ou nas mãos do maquinista), ninguém tem olhos.
func _atualiza_olhos() -> void:
	if _rosto.size() > 1 :
		_rosto[1].visible = get_tree().get_nodes_in_group(Item.GRUPO_CAVEIRAS).is_empty()

func esta_vivo() -> bool:
	return status != "MORTO"

# Morto no túnel: some do assento e para de reagir.
func morre() -> void:
	status = "MORTO"
	contente = false
	irado = false
	imundo = false
	sacrificial = false
	necessidades.clear()
	timer.stop()
	set_process(false)
	_timer_passeio.stop()
	_rota.clear()
	_sai_do_banheiro()
	visible = false
	if cadeira != null :
		cadeira.liberar()
	$CollisionShape2D.set_deferred("disabled", true)
	$Area2D.set_deferred("monitoring", false)
	# A área desligada não avisa a saída, então tira o passageiro da lista do maquinista aqui.
	for body in $Area2D.get_overlapping_bodies() :
		if body is Maquinista :
			body.passageiros_proximos.erase(self)
	print("Passageiro " + nome + " morreu!")

func esta_faminto() -> bool:
	return status != "MORTO" and necessidades.has("FAMINTO")

# Come o alimento entregue pelo maquinista
func alimenta(item : Item) -> void:
	necessidades.erase("FAMINTO")
	quantidade_fome = 0.0
	_atualiza_contente()
	acalma(alivio_comida)
	# A tábua volta vazia para a geladeira.
	item.consumir()
	print("Passageiro " + nome + " deixou de estar com fome!")

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

	_timer_passeio.one_shot = true
	_timer_passeio.timeout.connect(_pensa_em_passear)
	add_child(_timer_passeio)
	# Espera todas as cadeiras estarem prontas antes de sentar.
	_senta_na_cadeira_inicial.call_deferred()

func _senta_na_cadeira_inicial() -> void:
	if cadeira == null :
		cadeira = _cadeira_livre_mais_proxima()
	if cadeira == null :
		return
	cadeira.reservar(self)
	_senta()

func _cadeira_livre_mais_proxima() -> Cadeira :
	var melhor : Cadeira = null
	var melhor_dist := raio_busca_cadeira
	for c in get_tree().get_nodes_in_group("cadeiras") :
		if not c.esta_livre() :
			continue
		var d = global_position.distance_to(c.posicao_assento())
		if d <= melhor_dist :
			melhor = c
			melhor_dist = d
	return melhor

func _senta() -> void:
	estado = Estado.SENTADO
	global_position = cadeira.posicao_assento()
	# Entre o corpo e o braço da cadeira.
	z_index = cadeira.z_index + 1
	cadeira.sentar()
	_timer_passeio.start(randf_range(intervalo_passeio_min, intervalo_passeio_max))

# Hora de decidir: levanta para passear ou continua sentado.
func _pensa_em_passear() -> void:
	if not esta_vivo() or estado != Estado.SENTADO :
		return
	if randf() < chance_banheiro and _vai_ao_banheiro() :
		return
	var caminho : Caminho = null
	if randf() < chance_passeio :
		caminho = _escolhe_caminho()
	if caminho == null :
		_timer_passeio.start(randf_range(intervalo_passeio_min, intervalo_passeio_max))
		return
	_inicia_passeio(caminho)

# Sorteia um caminho (respeitando o peso de cada um).
func _escolhe_caminho() -> Caminho :
	var opcoes : Array = caminhos.filter(func(c): return is_instance_valid(c))
	if opcoes.is_empty() :
		var origem = cadeira.posicao_assento() if cadeira != null else global_position
		opcoes = get_tree().get_nodes_in_group("caminhos").filter(
			func(c): return c.distancia_ate(origem) <= alcance_caminho)
	opcoes = opcoes.filter(func(c): return c.peso > 0.0)
	if opcoes.is_empty() :
		return null
	var total := 0.0
	for c in opcoes :
		total += c.peso
	var sorteio := randf() * total
	for c in opcoes :
		sorteio -= c.peso
		if sorteio <= 0.0 :
			return c
	return opcoes.back()

# Monta a rota: ponta mais próxima -> outra ponta -> volta -> cadeira.
# Se o caminho está na linha da RedeCaminhos, vai e volta da cadeira pelo corredor
# (e pelas portas, se a ponta estiver em outro vagão) em vez de cortar em linha reta.
func _inicia_passeio(caminho : Caminho) -> void:
	var pontos := caminho.pontos_globais()
	if pontos.size() < 2 :
		_timer_passeio.start(randf_range(intervalo_passeio_min, intervalo_passeio_max))
		return
	var origem := global_position
	var rede := _rede()
	var s_origem := rede.s_entrada(origem) if rede != null else -1.0
	var na_linha := s_origem >= 0.0 and rede.projeta(pontos[0]).y < 2.0 and rede.projeta(pontos[-1]).y < 2.0
	if na_linha :
		if absf(rede.projeta(pontos[-1]).x - s_origem) < absf(rede.projeta(pontos[0]).x - s_origem) :
			pontos.reverse()
	elif origem.distance_to(pontos[-1]) < origem.distance_to(pontos[0]) :
		pontos.reverse()
	var volta := pontos.duplicate()
	volta.reverse()
	_rota = pontos + volta
	if na_linha :
		var s_ponta := rede.projeta(pontos[0]).x
		_rota = rede.trecho(s_origem, s_ponta) + _rota + rede.trecho(s_ponta, s_origem)
	if cadeira != null :
		_rota.append(cadeira.posicao_assento())
		cadeira.levantar()
	_distancia_ate_sujar = -1.0
	if randf() < (chance_sujeira_imundo if imundo else chance_sujeira_passeio) :
		var comprimento := 0.0
		var anterior := global_position
		for ponto in _rota :
			comprimento += anterior.distance_to(ponto)
			anterior = ponto
		_distancia_ate_sujar = randf() * comprimento
	estado = Estado.ANDANDO
	# Andando não bloqueia o maquinista (o corpo é estático e só se teletransporta).
	$CollisionShape2D.set_deferred("disabled", true)
	print("Passageiro " + nome + " levantou para dar uma volta.")

func _anda(delta : float) -> void:
	var passo := velocidade_caminhada * delta
	_avanca_sujeira(passo)
	while passo > 0.0 and not _rota.is_empty() :
		var alvo := _rota[0]
		var dist := global_position.distance_to(alvo)
		if dist <= passo :
			global_position = alvo
			passo -= dist
			_rota.remove_at(0)
		else :
			global_position = global_position.move_toward(alvo, passo)
			passo = 0.0
	z_index = Cadeira.z_por_y(global_position.y) + 1
	if _rota.is_empty() :
		var acao := _ao_fim_rota
		_ao_fim_rota = Callable()
		if acao.is_valid() :
			acao.call()
		elif cadeira != null :
			$CollisionShape2D.set_deferred("disabled", false)
			_senta()
		else :
			estado = Estado.SENTADO

func _rede() -> RedeCaminhos :
	var rede := get_tree().get_first_node_in_group("rede_caminhos") as RedeCaminhos
	return rede if rede != null and rede.tem_linha() else null

# --- Banheiro ----------------------------------------------------------------
# Levanta, vai até o corredor e entra na fila, que anda pela linha da RedeCaminhos
# até a frente (perto das cabines). Lá espera um vaso destrancado e desentupido.
func _vai_ao_banheiro() -> bool :
	var rede := _rede()
	if rede == null or rede.banheiro == null :
		return false
	var s := rede.s_entrada(global_position)
	if s < 0.0 :
		return false
	_banheiro = rede.banheiro
	_s_entrada = s
	_s = s
	_rota = PackedVector2Array([rede.ponto_em(s)])
	_ao_fim_rota = _entra_na_fila
	_distancia_ate_sujar = -1.0
	if cadeira != null :
		cadeira.levantar()
	estado = Estado.ANDANDO
	$CollisionShape2D.set_deferred("disabled", true)
	print("Passageiro " + nome + " foi ao banheiro.")
	return true

func _entra_na_fila() -> void :
	estado = Estado.NA_FILA
	_esperando = false
	_banheiro.fila.append(self)

# Anda pela linha até ESPACO_FILA atrás de quem está na frente na fila
# (ordem de chegada). O primeiro vai até a frente e espera um vaso livre.
func _anda_na_fila(delta : float) -> void :
	var rede := _rede()
	if rede == null or not is_instance_valid(_banheiro) :
		return
	var fim := rede.comprimento()
	var limite := fim
	var posicao := _banheiro.fila.find(self)
	if posicao > 0 :
		limite = _banheiro.fila[posicao - 1]._s - ESPACO_FILA
	var passo := velocidade_caminhada * delta
	var antes := _s
	if limite > _s :
		_s = minf(_s + passo, limite)
	_esperando = _s - antes < passo * 0.5
	global_position = rede.ponto_em(_s)
	z_index = Cadeira.z_por_y(global_position.y) + 1
	if posicao == 0 and _s >= fim - 0.5 :
		var vaso := _banheiro.vaso_livre()
		if vaso != null :
			_vai_ao_vaso(vaso)

# Sai da fila e tranca a cabine já no caminho.
func _vai_ao_vaso(vaso : Vaso) -> void :
	_banheiro.fila.erase(self)
	_vaso = vaso
	vaso.ocupar(self)
	_rota = PackedVector2Array([_banheiro.entrada_global(vaso), vaso.global_position + Vector2(0, 6)])
	_ao_fim_rota = _usa_vaso
	estado = Estado.ANDANDO

func _usa_vaso() -> void :
	estado = Estado.NO_VASO
	z_index = Cadeira.z_por_y(global_position.y) + 1
	if is_instance_valid(_vaso) :
		_vaso.entrar(self)
	get_tree().create_timer(randf_range(tempo_banheiro_min, tempo_banheiro_max)).timeout.connect(_sai_do_vaso)

# Destranca (o vaso pode entupir) e volta pela linha até a cadeira.
func _sai_do_vaso() -> void :
	if estado != Estado.NO_VASO or not esta_vivo() :
		return
	var vaso := _vaso
	_vaso = null
	var rede := _rede()
	_rota = PackedVector2Array([_banheiro.entrada_global(vaso)])
	vaso.liberar(self)
	if rede != null :
		_rota.append_array(rede.trecho(rede.comprimento(), _s_entrada))
	if cadeira != null :
		_rota.append(cadeira.posicao_assento())
	_banheiro = null
	_ao_fim_rota = Callable()
	estado = Estado.ANDANDO
	print("Passageiro " + nome + " saiu do banheiro.")

# Larga a fila e destranca o vaso (ex.: morreu).
func _sai_do_banheiro() -> void :
	if is_instance_valid(_banheiro) :
		_banheiro.fila.erase(self)
	if is_instance_valid(_vaso) :
		_vaso.liberar(self, false)
	_banheiro = null
	_vaso = null
	_ao_fim_rota = Callable()
	estado = Estado.SENTADO

# Desconta a distância andada e suja o chão ao chegar no ponto sorteado.
func _avanca_sujeira(andado : float) -> void:
	if _distancia_ate_sujar < 0.0 :
		return
	_distancia_ate_sujar -= andado
	if _distancia_ate_sujar > 0.0 :
		return
	_distancia_ate_sujar = -1.0
	var diretor := get_tree().current_scene as Diretor
	if diretor != null :
		diretor.cria_sujeira(global_position)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if estado == Estado.ANDANDO :
		_anda(delta)
	elif estado == Estado.NA_FILA :
		_anda_na_fila(delta)
	_atualiza_pose()
	_anima_andar(delta)
	if not esta_vivo() :
		return

	var diretor := get_tree().current_scene as Diretor
	_recarga = maxf(0.0, _recarga - delta)
	_atualiza_sacrificial(diretor)
	atualiza_exposicao(delta, diretor)
	# Parado na estação (dentro da paciência), ninguém fica com fome, bravo
	# nem espalha a fúria.
	if diretor == null or diretor.passageiros_impacientes() :
		if necessidades.has("FAMINTO") :
			atualiza_fome(delta)
		atualiza_raiva(delta, diretor)
		_pulso_contagio(delta, diretor)
	_atualiza_irado()
	_atualiza_baloes()
	_atualiza_olhos()
