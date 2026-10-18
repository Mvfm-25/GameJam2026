extends Node2D
class_name Diretor

# Quantas visitas são necessárias para completar a viagem.
const VISITAS_NECESSARIAS = 5
# Por quantos segundos o aviso fica na tela.
const DURACAO_AVISO = 3.0

# Quem são os passageiros sendo transportados.
var lista_passageiros = []
# Jogador, recebe os pontos.
var maquinista : Maquinista = null

# Status de transito
var em_transito = false
var em_tunel = false

# Mostrando aviso genérico na tela
# Funciona tanto para mostrar anuncio de mortes, quanto para aviso de final viagem
var aviso_tela : Label = null
var timer_aviso = Timer.new()

# Quanto tempo para a estação selecionada
var tempo_estacao = 0.0
# Estação de destino selecionada
var estacao_selecionada : Estacao = null
# Estação onde o trem está (ou de onde partiu). Só pode ir para vizinhas dela.
var estacao_atual : Estacao = null

# Por quantas estações o jogador passou
var quantidade_visitas = 0

# Trilho atual & se o trem está numa área onde é possível trocar de trilho.
var trilho_atual = 0
var em_area_troca = false

# Passando pelo tunel, matar passageiros
func aposta_morte():
	var mortes = 0
	for p in lista_passageiros :
		if p.status != "MORTO" and p.nivel_raiva > 0.75 :
			p.status = "MORTO"
			mortes += 1
			print("Passageiro " + p.nome + " foi morto!")
	print("Quantidade de mortes : " + str(mortes))
	if mortes > 0 :
		mostra_aviso("%d passageiro(s) morreram no túnel!" % mortes)
	if verifica_morte_geral() :
		game_over()

# Verifica se todos passageiros estão mortos
func verifica_morte_geral() -> bool :
	if lista_passageiros.is_empty() :
		return false
	var cont = 0
	for p in lista_passageiros :
		if(p.status == "MORTO"):
			cont += 1
	if(cont == lista_passageiros.size()) :
		print("Todo mundo morreu!")
		return true
	else :
		print("Ainda tem gente viva!")
		return false

func game_over() :
	if(quantidade_visitas < VISITAS_NECESSARIAS || verifica_morte_geral()):
		print("Você perdeu!")
		mostra_aviso("Você perdeu!")

# Mostra um aviso genérico na tela por alguns segundos.
func mostra_aviso(texto : String) :
	aviso_tela.text = texto
	aviso_tela.visible = true
	timer_aviso.start(DURACAO_AVISO)

# Trem chegou na estação de destino
# Parando, passageiros "pagam" suas recompensas pelo bom atendimento do jogador
func chega_destino() :
	if estacao_selecionada == null :
		return
	em_transito = false
	tempo_estacao = 0.0
	quantidade_visitas += 1

	var pontos = estacao_selecionada.pontos_por_chegada
	for p in lista_passageiros :
		if p.status != "MORTO" and p.contente :
			pontos += p.pontos_atendimento
	if maquinista != null :
		maquinista.pontos_acumulados += pontos

	print("Chegou na estação " + estacao_selecionada.nome + "! +" + str(pontos) + " pontos")
	if quantidade_visitas >= VISITAS_NECESSARIAS :
		mostra_aviso("Fim da viagem! Você visitou %d estações." % quantidade_visitas)
	else :
		mostra_aviso("Chegou em %s! +%d pontos" % [estacao_selecionada.nome, pontos])

	estacao_selecionada.define_selecionado(false)
	estacao_atual = estacao_selecionada
	estacao_selecionada = null

# Troca de estação de destino
# Jogador abre mapa & escolhe nodo da estação por ali
func troca_destino(estacao : Estacao) :
	if estacao == estacao_selecionada :
		return
	if estacao_atual != null and not estacao_atual.viagem_possivel(estacao) :
		mostra_aviso("Destino inválido! Escolha uma estação vizinha a " + estacao_atual.nome + ".")
		return
	if estacao_selecionada != null :
		estacao_selecionada.define_selecionado(false)
	estacao_selecionada = estacao
	estacao.define_selecionado(true)
	tempo_estacao = estacao.tempo_viagem
	em_transito = true
	print("Novo destino : " + estacao.nome)
	mostra_aviso("Destino : " + estacao.nome)

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

func _process(delta: float) -> void:
	if em_transito :
		tempo_estacao -= delta
		if tempo_estacao <= 0.0 :
			chega_destino()

# Esc fecha o jogo
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
