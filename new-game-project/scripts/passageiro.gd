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
var taxa_raiva_base = randf_range(0.003, 0.005)
@export var raiva_fome := 0.015
# Por sujeira próxima (sangue conta como duas), até sujeiras_max_raiva.
@export var raiva_por_sujeira := 0.008
@export var sujeiras_max_raiva := 3.0
@export var raio_sujeira := 120.0
# IMUNDO multiplica a taxa total.
@export var multiplicador_imundo := 1.5
# Fome cresce até mostrar o balão (0.6) em ~12 s.
@export var taxa_fome := 0.05
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
const COR_IMUNDO := Color(0.72, 0.6, 0.45)

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
var _tween_flash : Tween

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

enum Estado { SENTADO, ANDANDO }
var estado = Estado.SENTADO
# Pontos (globais) que faltam percorrer no passeio atual.
var _rota := PackedVector2Array()
var _timer_passeio := Timer.new()

# O passageiro é montado em camadas, sorteando cada peça: corpo, cabeça, olhos, boca e chapéu.
# Todas as folhas foram desenhadas em células de 192 px (só o chapéu é de 64 px),
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
var _visual : Node2D
var _fase_passo := 0.0

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
	corpo = ["Normal", "Magro"].pick_random()
	var folha_corpo := CORPOS_NORMAIS if corpo == "Normal" else CORPOS_MAGROS
	camadas.add_child(_camada(folha_corpo, randi() % CORES_CORPO, CELULA))
	var cabeca := _camada(CABECAS, (randi() % ESTILOS_CABECA) * POSES + pose, CELULA)
	cor_cabelo = CORES_CABELO.pick_random()
	cabeca.material = ShaderMaterial.new()
	cabeca.material.shader = TROCA_CABELO
	cabeca.material.set_shader_parameter("cor_cabelo", cor_cabelo)
	camadas.add_child(cabeca)
	camadas.add_child(_camada(OLHOS, (randi() % ESTILOS_OLHOS) * POSES + pose, CELULA))
	camadas.add_child(_camada(BOCAS, (randi() % ESTILOS_BOCA) * POSES + pose, CELULA))
	tem_chapeu = randf() < CHANCE_CHAPEU
	if tem_chapeu :
		camadas.add_child(_camada(CHAPEUS, randi() % MODELOS_CHAPEU, TAMANHO_CHAPEU, POSICAO_CHAPEU))

# Inclina o corpo enquanto anda; sentado, volta suavemente à posição normal.
func _anima_andar(delta : float) -> void:
	if _visual == null :
		return
	var angulo := 0.0
	var pulo := 0.0
	var amassada := 0.0
	if estado == Estado.ANDANDO :
		_fase_passo += delta * BALANCO_VELOCIDADE
		angulo = sin(_fase_passo) * BALANCO_ANGULO
		var passo := absf(sin(_fase_passo))
		pulo = -passo * PULINHO
		amassada = (0.5 - passo) * AMASSADA
	var peso := 1.0 - exp(-SUAVIZACAO * delta)
	_visual.rotation = lerp_angle(_visual.rotation, angulo, peso)
	_visual.position = _visual.position.lerp(Vector2(0, pulo), peso)
	var escala := Vector2.ONE * ESCALA_VISUAL
	_visual.scale = _visual.scale.lerp(escala * Vector2(1.0 - amassada, 1.0 + amassada), peso)

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
	if diretor != null :
		var sujeira := minf(diretor.peso_sujeiras_perto(global_position, raio_sujeira), sujeiras_max_raiva)
		taxa += raiva_por_sujeira * sujeira
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
		_aplica_cor()

# O maquinista limpou por perto.
func limpa_imundo() -> void:
	exposicao = 0.0
	if not imundo :
		return
	imundo = false
	print("Passageiro " + nome + " não está mais imundo.")
	_atualiza_contente()
	_aplica_cor()

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
	_flash_raiva()
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

# Contente = sem necessidades e nem bravo nem sujo.
func _atualiza_contente() -> void:
	contente = necessidades.is_empty() and not imundo and not irado

func _aplica_cor() -> void:
	if _visual != null :
		_visual.modulate = COR_IMUNDO if imundo else Color.WHITE

# Pisca vermelho ao ser contagiado.
func _flash_raiva() -> void:
	if _tween_flash :
		_tween_flash.kill()
	modulate = Color(1.6, 0.5, 0.5)
	_tween_flash = create_tween()
	_tween_flash.tween_property(self, "modulate", Color.WHITE, 0.6)

# Um balão por vez: irado > fome > puto.
func _atualiza_baloes() -> void:
	var com_fome = necessidades.has("FAMINTO") and quantidade_fome >= 0.6
	$muito_puto.visible = irado
	$fome.visible = not irado and com_fome
	$puto.visible = not irado and not com_fome and nivel_raiva >= LIMIAR_PUTO

func esta_vivo() -> bool:
	return status != "MORTO"

# Morto no túnel: some do assento e para de reagir.
func morre() -> void:
	status = "MORTO"
	contente = false
	irado = false
	imundo = false
	necessidades.clear()
	timer.stop()
	set_process(false)
	_timer_passeio.stop()
	_rota.clear()
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
func _inicia_passeio(caminho : Caminho) -> void:
	var pontos := caminho.pontos_globais()
	if pontos.size() < 2 :
		_timer_passeio.start(randf_range(intervalo_passeio_min, intervalo_passeio_max))
		return
	if global_position.distance_to(pontos[-1]) < global_position.distance_to(pontos[0]) :
		pontos.reverse()
	var volta := pontos.duplicate()
	volta.reverse()
	_rota = pontos + volta
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
		$CollisionShape2D.set_deferred("disabled", false)
		_senta()

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
	_anima_andar(delta)
	if not esta_vivo() :
		return

	var diretor := get_tree().current_scene as Diretor
	if necessidades.has("FAMINTO") :
		atualiza_fome(delta)
	_recarga = maxf(0.0, _recarga - delta)
	atualiza_exposicao(delta, diretor)
	atualiza_raiva(delta, diretor)
	_atualiza_irado()
	_pulso_contagio(delta, diretor)
	_atualiza_baloes()
