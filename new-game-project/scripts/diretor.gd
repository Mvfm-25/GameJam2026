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

const SOM_TUNEL := preload("res://audios/suspence.wav")

# Etapas do loop: parado na estação -> viajando -> túnel -> viajando -> chega na estação.
enum Etapa { NA_ESTACAO, VIAJANDO, TUNEL }
var etapa = Etapa.NA_ESTACAO

# Quem são os passageiros sendo transportados.
var lista_passageiros = []
# Jogador, recebe os pontos.
var maquinista : Maquinista = null

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

func em_transito() -> bool :
	return etapa != Etapa.NA_ESTACAO

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
	vitima.morre()
	marca_assento(vitima)
	return vitima

# Deixa uma mancha de sangue onde o passageiro estava sentado.
func marca_assento(p : Passageiro) :
	var sangue := Sujeira.nova_sangue()
	add_child(sangue)
	# Fica acima dos vagões e abaixo do maquinista, como as outras sujeiras.
	if maquinista != null :
		move_child(sangue, maquinista.get_index())
	sangue.global_position = p.global_position

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
func entra_tunel() :
	etapa = Etapa.TUNEL
	em_tunel = true
	passou_tunel = true
	print("Entrando no túnel!")
	som_tunel.play()
	_anima_tunel(COR_TUNEL, 1.0)

# A luz volta e a morte (se houve) é revelada.
func sai_tunel() :
	etapa = Etapa.VIAJANDO
	em_tunel = false
	print("Saindo do túnel!")
	_anima_tunel(Color.WHITE, 0.0)
	if vitima_tunel != null :
		mostra_aviso("%s foi encontrado morto!" % vitima_tunel.nome)
		vitima_tunel = null
	if verifica_morte_geral() :
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
	etapa = Etapa.NA_ESTACAO
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
		return
	tempo_decorrido += delta

	if etapa == Etapa.VIAJANDO and not passou_tunel and tempo_decorrido >= inicio_tunel :
		entra_tunel()
	elif etapa == Etapa.TUNEL :
		# Morte acontece no meio do túnel, com tudo já escuro.
		if not morte_sorteada and tempo_decorrido >= (inicio_tunel + fim_tunel) / 2.0 :
			morte_sorteada = true
			vitima_tunel = aposta_morte()
		if tempo_decorrido >= fim_tunel :
			sai_tunel()
	elif etapa == Etapa.VIAJANDO and tempo_decorrido >= tempo_viagem_total :
		chega_destino()

# Esc fecha o jogo
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
