extends Node2D
class_name Diretor

# Quantas visitas são necessárias para completar a viagem.
const VISITAS_NECESSARIAS = 5
# Por quantos segundos o aviso fica na tela.
const DURACAO_AVISO = 3.0

# Túnel: começa entre 30% e 60% da viagem e dura de 3 a 4 s (no máximo 30% da viagem).
const INICIO_TUNEL_MIN = 0.3
const INICIO_TUNEL_MAX = 0.6
const DURACAO_TUNEL_MIN = 3.0
const DURACAO_TUNEL_MAX = 4.0
const DURACAO_TUNEL_MAX_RELATIVA = 0.3
# Tempo para escurecer/clarear ao entrar/sair do túnel.
const TRANSICAO_TUNEL = 0.6
const COR_TUNEL = Color(0.08, 0.08, 0.12)
# Mesmo os passageiros calmos têm alguma chance de morrer.
const PESO_BASE_MORTE = 0.2
# Caveira deixada em cima da poça de sangue de quem morreu.
const CENA_CAVEIRA := preload("res://cenas/caveira.tscn")
# Quem morre sentado deixa a poça no chão ao lado esquerdo da cadeira (no corredor),
# fora do desenho dela; senão a cadeira cobriria a poça e a caveira.
# A cadeira desenhada vai de x -25 a +24 do centro; a poça tem ~24 px de cada lado.
const DESLOCAMENTO_POCA_CADEIRA := Vector2(-50, -6)

const SOM_TUNEL := preload("res://audios/suspence2.wav")
const SOM_SEGUINTE := preload("res://audios/suspence1.wav")
# Duração do fade-out da música de suspense ao chegar na estação.
const DURACAO_FADE_MUSICA = 2.0
# Quanto tempo o jogador pode ficar parado na estação sem escolher destino
# antes dos passageiros começarem a ficar impacientes (fome e raiva).
const PACIENCIA_ESTACAO = 30.0
# Etapas do loop: parado na estação -> viajando -> túnel -> viajando -> chega na estação.
enum Etapa { NA_ESTACAO, VIAJANDO, TUNEL }
var etapa = Etapa.NA_ESTACAO
# Quem são os passageiros sendo transportados.
var lista_passageiros = []
# Jogador, recebe os pontos.
var maquinista : Maquinista = null
var musica_morte_ativa := false
# Status de transito
var em_tunel = false
# Fim de jogo (venceu ou perdeu): não aceita novos destinos.
var jogo_acabou = false

# Mostrando aviso genérico na tela
# Funciona tanto para mostrar anuncio de mortes, quanto para aviso de final viagem
var aviso_tela : Label = null
var timer_aviso = Timer.new()

# Tempo total e tempo já percorrido da viagem atual.
var tempo_viagem_total = 0.0
var tempo_decorrido = 0.0
# Quanto tempo o trem está parado na estação atual.
var tempo_parado = 0.0
# Quando o túnel começa e termina, em segundos desde a partida.
var inicio_tunel = 0.0
var fim_tunel = 0.0
var passou_tunel = false
# Morte já sorteada neste túnel, e quem morreu (anunciado quando a luz volta).
var morte_sorteada = false
var vitima_tunel : Passageiro = null

# Escurece a cena no túnel; o mapa e os avisos ficam em CanvasLayer e não são afetados.
var escuridao : CanvasModulate = null
# Luz fraca em volta do maquinista, acesa só no túnel.
var lanterna : PointLight2D = null
var som_tunel : AudioStreamPlayer = null
var _tween_tunel : Tween
var _tween_musica : Tween

# Estação de destino selecionada
var estacao_selecionada : Estacao = null
# Estação onde o trem está (ou de onde partiu). Só pode ir para vizinhas dela.
var estacao_atual : Estacao = null

# Por quantas estações o jogador passou
var quantidade_visitas = 0

# Sujeiras spawnadas no mapa
@export var sujeiras = []

# Trilho atual & se o trem está numa área onde é possível trocar de trilho.
var trilho_atual = 0
var em_area_troca = false

# Fornalha da sala de máquinas; sem combustível o trem para no caminho.
var fornalha : Fornalha = null
var trilhos : Trilhos = null
var _avisou_fornalha_apagada := false

func em_transito() -> bool :
	return etapa != Etapa.NA_ESTACAO

# Fração da viagem atual já percorrida (0 parado na estação, 1 chegando).
func progresso_viagem() -> float :
	if not em_transito() or tempo_viagem_total <= 0.0 :
		return 0.0
	return clampf(tempo_decorrido / tempo_viagem_total, 0.0, 1.0)

# Passageiros só sentem fome/raiva com o trem andando,
# ou se o jogador demorar demais para escolher o próximo destino.
func passageiros_impacientes() -> bool :
	if jogo_acabou :
		return false
	return em_transito() or tempo_parado >= PACIENCIA_ESTACAO

func tempo_restante() -> float :
	if not em_transito() :
		return 0.0
	return maxf(0.0, tempo_viagem_total - tempo_decorrido)

# Passando pelo tunel: sorteia um passageiro vivo para morrer.
# Quanto maior a raiva, maior a chance de ser o escolhido.
func aposta_morte() -> Passageiro :
	var vivos = lista_passageiros.filter(func(p): return p.esta_vivo())
	if vivos.is_empty() :
		return null
	var pesos = vivos.map(func(p): return PESO_BASE_MORTE + p.nivel_raiva)
	var total = 0.0
	for peso in pesos :
		total += peso
	var sorteio = randf() * total
	var vitima : Passageiro = vivos.back()
	for i in vivos.size() :
		sorteio -= pesos[i]
		if sorteio <= 0.0 :
			vitima = vivos[i]
			break
	# Guarda a cadeira antes de morrer, porque morre() a libera.
	var cadeira : Cadeira = vitima.cadeira if vitima.cadeira != null and vitima.cadeira.ocupada else null
	vitima.morre()
	marca_morte(vitima, cadeira)
	return vitima

# Deixa uma poça de sangue com a caveira por cima onde o passageiro morreu.
# Se estava sentado, a poça vai para o lado da cadeira para não ficar escondida.
func marca_morte(p : Passageiro, cadeira : Cadeira = null) :
	var pos := p.global_position
	if cadeira != null :
		pos = cadeira.global_position + DESLOCAMENTO_POCA_CADEIRA
	coloca_sujeira(Sujeira.nova_sangue(), pos)
	var caveira : Item = CENA_CAVEIRA.instantiate()
	add_child(caveira)
	# Por cima da poça (que acabou de entrar antes do maquinista) e abaixo do maquinista.
	if maquinista != null :
		move_child(caveira, maquinista.get_index())
	caveira.global_position = pos

# Cria uma sujeira comum no chão (os passageiros sujam o trem).
func cria_sujeira(pos : Vector2) -> void :
	coloca_sujeira(Sujeira.new(), pos)

func coloca_sujeira(sujeira : Sujeira, pos : Vector2) -> void :
	add_child(sujeira)
	# Fica acima dos vagões e abaixo do maquinista.
	if maquinista != null :
		move_child(sujeira, maquinista.get_index())
	sujeira.global_position = pos  # define depois de entrar na árvore

# Limpar uma sujeira acalma quem está perto (forte) e o resto do trem (fraco),
# e tira o IMUNDO de quem está perto.
const RAIO_ALIVIO_LIMPEZA = 160.0
const ALIVIO_LIMPEZA_PERTO = 0.2
const ALIVIO_LIMPEZA_GERAL = 0.05

# Passageiros vivos a até 'raio' de 'pos'.
func passageiros_perto(pos : Vector2, raio : float) -> Array :
	return lista_passageiros.filter(func(p): return p.esta_vivo() and p.global_position.distance_to(pos) <= raio)

# Quanto de sujeira há perto de 'pos' (sangue pesa 2).
func peso_sujeiras_perto(pos : Vector2, raio : float) -> float :
	var peso := 0.0
	for s in sujeiras :
		if is_instance_valid(s) and s.global_position.distance_to(pos) <= raio :
			peso += 2.0 if s.sangue else 1.0
	return peso

# Chamado pela sujeira quando o maquinista termina de limpá-la.
func alivio_limpeza(pos : Vector2) -> void :
	for p in lista_passageiros :
		if not p.esta_vivo() :
			continue
		if p.global_position.distance_to(pos) <= RAIO_ALIVIO_LIMPEZA :
			p.acalma(ALIVIO_LIMPEZA_PERTO)
			p.limpa_imundo()
		else :
			p.acalma(ALIVIO_LIMPEZA_GERAL)

# Verifica se todos passageiros estão mortos
func verifica_morte_geral() -> bool :
	if lista_passageiros.is_empty() :
		return false
	for p in lista_passageiros :
		if p.esta_vivo() :
			return false
	print("Todo mundo morreu!")
	return true

# Todos os passageiros morreram.
func game_over() :
	jogo_acabou = true
	print("Você perdeu!")
	mostra_aviso("Todos os passageiros morreram! Você perdeu!")

# Mostra um aviso genérico na tela por alguns segundos.
func mostra_aviso(texto : String) :
	aviso_tela.text = texto
	aviso_tela.visible = true
	timer_aviso.start(DURACAO_AVISO)

# Escurece o vagão e acende a lanterna do maquinista.
func entra_tunel():
	etapa = Etapa.TUNEL
	em_tunel = true
	passou_tunel = true

	print("Entrando no túnel!")

	_toca_musica(SOM_TUNEL)

	_anima_tunel(COR_TUNEL, 1.0)

# Toca uma música de suspense do zero, cancelando um fade-out em andamento.
func _toca_musica(musica : AudioStream) -> void:
	if _tween_musica :
		_tween_musica.kill()
	som_tunel.volume_db = 0.0
	som_tunel.stream = musica
	som_tunel.play()

# A música do túnel toca uma vez só. Se alguém morreu nesta viagem,
# a música de morte entra depois dela e repete até a chegada na estação.
func _ao_som_tunel_terminar() -> void:
	if not musica_morte_ativa :
		return
	if som_tunel.stream != SOM_SEGUINTE :
		_toca_musica(SOM_SEGUINTE)
	else :
		som_tunel.play()

func tocar_musica_morte() -> void:
	if not em_tunel:
		return

	musica_morte_ativa = true
	_toca_musica(SOM_SEGUINTE)

# Chegou na estação: a música de suspense (túnel ou morte) some aos poucos.
func _fade_out_musica() -> void:
	musica_morte_ativa = false

	if not is_instance_valid(som_tunel):
		return

	if _tween_musica and _tween_musica.is_running():
		_tween_musica.kill()

	if not som_tunel.playing:
		return

	_tween_musica = create_tween()
	_tween_musica.tween_property(
		som_tunel,
		"volume_db",
		-40.0,
		DURACAO_FADE_MUSICA
	)
	_tween_musica.tween_callback(som_tunel.stop)
	_tween_musica.tween_property(som_tunel, "volume_db", 0.0, 0.0)
	
func sai_tunel():
	
	etapa = Etapa.VIAJANDO
	em_tunel = false

	#som_tunel.stop()

	print("Saindo do túnel!")
	_anima_tunel(Color.WHITE, 0.0)

	if vitima_tunel != null:
		mostra_aviso("%s foi encontrado morto!" % vitima_tunel.nome)
		vitima_tunel = null

	if verifica_morte_geral():
		game_over()

func _anima_tunel(cor : Color, energia_lanterna : float) :
	if _tween_tunel :
		_tween_tunel.kill()
	_tween_tunel = create_tween().set_parallel()
	_tween_tunel.tween_property(escuridao, "color", cor, TRANSICAO_TUNEL)
	_tween_tunel.tween_property(lanterna, "energy", energia_lanterna, TRANSICAO_TUNEL)

# Trem chegou na estação de destino
# Parando, passageiros "pagam" suas recompensas pelo bom atendimento do jogador
func chega_destino() :
	if estacao_selecionada == null :
		return

	_fade_out_musica()

	etapa = Etapa.NA_ESTACAO
	tempo_parado = 0.0
	quantidade_visitas += 1

	var pontos = estacao_selecionada.pontos_por_chegada
	for p in lista_passageiros :
		if p.esta_vivo() and p.contente :
			pontos += p.pontos_atendimento
	if maquinista != null :
		maquinista.pontos_acumulados += pontos

	print("Chegou na estação " + estacao_selecionada.nome + "! +" + str(pontos) + " pontos")
	if quantidade_visitas >= VISITAS_NECESSARIAS :
		jogo_acabou = true
		mostra_aviso("Fim da viagem! Você visitou %d estações." % quantidade_visitas)
	else :
		mostra_aviso("Chegou em %s! +%d pontos" % [estacao_selecionada.nome, pontos])

	estacao_selecionada.define_selecionado(false)
	estacao_atual = estacao_selecionada
	estacao_selecionada = null

# Troca de estação de destino
# Jogador abre mapa & escolhe nodo da estação por ali
func troca_destino(estacao : Estacao) :
	if jogo_acabou :
		return
	# Não dá para mudar de destino no meio da viagem (nem fugir do túnel).
	if em_transito() :
		mostra_aviso("O trem já está a caminho de " + estacao_selecionada.nome + "!")
		return
	if estacao_atual != null and not estacao_atual.viagem_possivel(estacao) :
		mostra_aviso("Destino inválido! Escolha uma estação vizinha a " + estacao_atual.nome + ".")
		return
	estacao_selecionada = estacao
	estacao.define_selecionado(true)
	inicia_viagem(estacao.tempo_viagem)
	print("Novo destino : " + estacao.nome)
	mostra_aviso("Destino : " + estacao.nome)

# Parte da estação e sorteia em que momento o trem passa pelo túnel.
func inicia_viagem(duracao : float) :
	etapa = Etapa.VIAJANDO
	tempo_parado = 0.0
	tempo_viagem_total = duracao
	tempo_decorrido = 0.0
	passou_tunel = false
	morte_sorteada = false
	vitima_tunel = null
	inicio_tunel = duracao * randf_range(INICIO_TUNEL_MIN, INICIO_TUNEL_MAX)
	var duracao_tunel = minf(randf_range(DURACAO_TUNEL_MIN, DURACAO_TUNEL_MAX), duracao * DURACAO_TUNEL_MAX_RELATIVA)
	fim_tunel = inicio_tunel + duracao_tunel

# Troca de trilhos
# Troca de trilhos apenas em área para trocar de trilhos.
func troca_trilho() -> bool :
	if not em_area_troca :
		print("Não é possível trocar de trilho aqui!")
		return false
	trilho_atual = 1 - trilho_atual
	print("Trocou para o trilho " + str(trilho_atual))
	return true

func _ready() -> void:
	maquinista = get_node_or_null("Maquinista")

	var passageiros = get_node_or_null("Passageiros")
	if passageiros != null :
		lista_passageiros = passageiros.get_children()

	# Estações se registram no grupo "estacoes" no próprio _ready.
	# A estação marcada como originária é o ponto de partida.
	for e in get_tree().get_nodes_in_group("estacoes") :
		e.selecionada.connect(troca_destino)
		if e.originaria :
			estacao_atual = e

	# Aviso na tela, numa camada acima do jogo.
	var camada = CanvasLayer.new()
	add_child(camada)
	aviso_tela = Label.new()
	aviso_tela.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	aviso_tela.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso_tela.visible = false
	camada.add_child(aviso_tela)

	timer_aviso.one_shot = true
	timer_aviso.timeout.connect(func(): aviso_tela.visible = false)
	add_child(timer_aviso)

	_cria_efeitos_tunel()

	fornalha = get_tree().get_first_node_in_group(Fornalha.GRUPO)
	trilhos = get_node_or_null("Trilhos")


func _cria_efeitos_tunel() :
	escuridao = CanvasModulate.new()
	escuridao.color = Color.WHITE
	add_child(escuridao)

	lanterna = PointLight2D.new()
	lanterna.texture = _textura_lanterna()
	lanterna.color = Color(1.0, 0.85, 0.6)
	lanterna.energy = 0.0
	if maquinista != null :
		maquinista.add_child(lanterna)

	som_tunel = AudioStreamPlayer.new()
	som_tunel.stream = SOM_TUNEL
	add_child(som_tunel)

	som_tunel.finished.connect(_ao_som_tunel_terminar)

# Círculo que vai do branco ao transparente, usado como luz da lanterna.
func _textura_lanterna() -> GradientTexture2D :
	var gradiente := Gradient.new()
	gradiente.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var textura := GradientTexture2D.new()
	textura.gradient = gradiente
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(0.5, 0.0)
	textura.width = 256
	textura.height = 256
	return textura

func _process(delta: float) -> void:
	if not em_transito() :
		tempo_parado += delta
		return
	if _trem_parado_sem_carvao() :
		return
	tempo_decorrido += delta

	if etapa == Etapa.VIAJANDO and not passou_tunel and tempo_decorrido >= inicio_tunel :
		entra_tunel()
	elif etapa == Etapa.TUNEL :
		# Morte acontece no meio do túnel, com tudo já escuro.
		if not morte_sorteada and tempo_decorrido >= (inicio_tunel + fim_tunel) / 2.0 :
			morte_sorteada = true
			vitima_tunel = aposta_morte()
			if vitima_tunel != null :
				musica_morte_ativa = true
		if tempo_decorrido >= fim_tunel :
			sai_tunel()
	elif etapa == Etapa.VIAJANDO and tempo_decorrido >= tempo_viagem_total :
		chega_destino()

# Com a fornalha apagada a viagem não avança e os trilhos param de correr.
func _trem_parado_sem_carvao() -> bool :
	var apagada := fornalha != null and fornalha.apagada()
	if trilhos != null :
		trilhos.ativo = not apagada
	if apagada and not _avisou_fornalha_apagada :
		mostra_aviso("A fornalha apagou! O trem parou. Abasteça com carvão!")
	_avisou_fornalha_apagada = apagada
	return apagada

# Esc fecha o jogo
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
