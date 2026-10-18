@tool
extends Node2D
class_name RedeCaminhos

# Fica no nó "Caminhos" da cena principal e monta, a partir dos vagões, a linha por onde
# os passageiros atravessam o trem: corredor do meio de cada vagão -> porta de cima ->
# plataforma -> ponte -> plataforma -> porta do próximo vagão -> corredor ... até a frente
# da fila do banheiro (vagão de serviço). Só entram vagões ligados por portas abertas.
#
# A partir da linha são gerados (e redesenhados se os vagões mudarem no editor) os Caminhos:
# - CorredorVagaoN: o corredor de cada vagão (passeio);
# - VagaoN_VagaoM: do meio de um vagão ao meio do próximo (passeio);
# - BanheiroDoVagaoN: do meio do vagão até a fila do banheiro (peso 0, não é sorteado
#   para passeio; mostra a rota que os passageiros fazem até o banheiro).
# Os gerados não são salvos na cena. Caminhos desenhados à mão neste nó continuam valendo.

const T := 32 # Tamanho do tile na tela (igual ao trem.gd).

@export_range(0.0, 10.0, 0.1) var peso_corredor := 1.0
@export_range(0.0, 10.0, 0.1) var peso_entre_vagoes := 0.5

# Banheiro no fim da linha (null se nenhum vagão tem).
var banheiro : Banheiro = null

# Pontos globais da linha e o comprimento acumulado até cada um.
var _pontos := PackedVector2Array()
var _dist := PackedFloat32Array()
# Vagões na ordem da linha e, para cada um, a distância (na linha) das pontas do corredor.
var _vagoes : Array = []
var _s_esq : Array[float] = []
var _s_dir : Array[float] = []
var _gerados : Array[Node] = []
var _assinatura := ""


func _enter_tree() -> void:
	add_to_group("rede_caminhos")


func _ready() -> void:
	# Os vagões montam o interior (e o Banheiro) no próprio _ready; espera todos.
	_construir.call_deferred()
	set_process(Engine.is_editor_hint())


# No editor, refaz a rede quando um vagão é movido ou muda de tamanho/classe/portas.
func _process(_delta: float) -> void:
	if _gerar_assinatura() != _assinatura:
		_construir()


# --- Consultas usadas pelos passageiros ---------------------------------------

func comprimento() -> float:
	return _dist[-1] if not _dist.is_empty() else 0.0


func tem_linha() -> bool:
	return _pontos.size() >= 2


# Ponto da linha a uma distância s do começo.
func ponto_em(s: float) -> Vector2:
	if _pontos.is_empty():
		return Vector2.ZERO
	s = clampf(s, 0.0, comprimento())
	for i in range(1, _pontos.size()):
		if s <= _dist[i]:
			var trecho := _dist[i] - _dist[i - 1]
			var t := 0.0 if trecho <= 0.0 else (s - _dist[i - 1]) / trecho
			return _pontos[i - 1].lerp(_pontos[i], t)
	return _pontos[-1]


# Pontos para andar pela linha de s_de até s_ate (em qualquer sentido), com as duas pontas.
func trecho(s_de: float, s_ate: float) -> PackedVector2Array:
	var saida := PackedVector2Array([ponto_em(s_de)])
	if s_ate >= s_de:
		for i in _pontos.size():
			if _dist[i] > s_de and _dist[i] < s_ate:
				saida.append(_pontos[i])
	else:
		for i in range(_pontos.size() - 1, -1, -1):
			if _dist[i] < s_de and _dist[i] > s_ate:
				saida.append(_pontos[i])
	saida.append(ponto_em(s_ate))
	return saida


# Distância (na linha) do ponto do corredor mais perto de pos, no vagão em que pos está.
# É por onde alguém sentado entra na linha. -1 se pos não está num vagão da linha.
func s_entrada(pos: Vector2) -> float:
	for i in _vagoes.size():
		var v : Node2D = _vagoes[i]
		var x0 : float = v.global_position.x
		if pos.x < x0 or pos.x >= x0 + v.largura_tiles * T:
			continue
		var esq := ponto_em(_s_esq[i]).x
		var dir := ponto_em(_s_dir[i]).x
		return _s_esq[i] + clampf(pos.x, esq, dir) - esq
	return -1.0


# Distância (na linha) do ponto da linha mais perto de pos, e quão longe pos está dela.
func projeta(pos: Vector2) -> Vector2:
	var melhor_s := 0.0
	var melhor_d := INF
	for i in range(1, _pontos.size()):
		var a := _pontos[i - 1]
		var b := _pontos[i]
		var p := Geometry2D.get_closest_point_to_segment(pos, a, b)
		var d := pos.distance_to(p)
		if d < melhor_d:
			melhor_d = d
			melhor_s = _dist[i - 1] + a.distance_to(p)
	return Vector2(melhor_s, melhor_d)


# --- Montagem -------------------------------------------------------------------

func _vagoes_da_cena() -> Array:
	var lista := []
	var pai := get_parent()
	if pai == null:
		return lista
	for filho in pai.get_children():
		if filho is Node2D and filho.has_method("y_corredor"):
			lista.append(filho)
	lista.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	return lista


func _gerar_assinatura() -> String:
	var partes := []
	for v in _vagoes_da_cena():
		partes.append([v.global_position, v.largura_tiles, v.altura_tiles, v.classe,
			v.porta_esquerda_aberta, v.porta_direita_aberta, v.banheiro() != null])
	return str(partes)


func _construir() -> void:
	_assinatura = _gerar_assinatura()
	for c in _gerados:
		if is_instance_valid(c):
			c.queue_free()
	_gerados.clear()
	_pontos.clear()
	_dist.clear()
	_vagoes.clear()
	_s_esq.clear()
	_s_dir.clear()
	banheiro = null

	var todos := _vagoes_da_cena()
	if todos.is_empty():
		return
	# A linha termina no vagão do banheiro; começa no vagão mais à esquerda ligado a ele.
	var fim := todos.size() - 1
	for i in todos.size():
		if todos[i].banheiro() != null:
			fim = i
			banheiro = todos[i].banheiro()
			break
	var inicio := fim
	while inicio > 0 and todos[inicio - 1].porta_direita_aberta and todos[inicio].porta_esquerda_aberta:
		inicio -= 1
	_vagoes = todos.slice(inicio, fim + 1)

	for i in _vagoes.size():
		var v : Node2D = _vagoes[i]
		var o := v.global_position
		var yc : float = o.y + v.y_corredor()
		var esq : float = o.x + 1.5 * T
		var dir : float = o.x + (v.largura_tiles - 1.5) * T
		if i > 0:
			# Chega pela ponte, sobe na plataforma até a porta de cima e entra.
			_adiciona(Vector2(o.x - T / 2.0, o.y + v.y_ponte()))
			_adiciona(Vector2(o.x - T / 2.0, o.y + v.y_porta()))
			_adiciona(Vector2(esq, o.y + v.y_porta()))
		_adiciona(Vector2(esq, yc))
		_s_esq.append(comprimento())
		var ultimo := i == _vagoes.size() - 1
		if ultimo and banheiro != null:
			# No vagão de serviço o corredor termina na frente da fila do banheiro.
			_adiciona(banheiro.cabeca_global())
			_s_dir.append(comprimento())
			break
		_adiciona(Vector2(dir, yc))
		_s_dir.append(comprimento())
		if not ultimo:
			# Sai pela porta de cima, desce na plataforma até a ponte.
			var plataforma : float = o.x + v.largura_tiles * T + T / 2.0
			_adiciona(Vector2(dir, o.y + v.y_porta()))
			_adiciona(Vector2(plataforma, o.y + v.y_porta()))
			_adiciona(Vector2(plataforma, o.y + v.y_ponte()))

	_gera_caminhos()


func _adiciona(ponto: Vector2) -> void:
	if not _pontos.is_empty() and _pontos[-1].is_equal_approx(ponto):
		return
	_dist.append(0.0 if _pontos.is_empty() else _dist[-1] + _pontos[-1].distance_to(ponto))
	_pontos.append(ponto)


func _meio(i: int) -> float:
	return (_s_esq[i] + _s_dir[i]) / 2.0


func _gera_caminhos() -> void:
	if not tem_linha():
		return
	for i in _vagoes.size():
		var nome : String = _vagoes[i].name
		var eh_banheiro : bool = banheiro != null and i == _vagoes.size() - 1
		if not eh_banheiro:
			_cria_caminho("Corredor" + nome, trecho(_s_esq[i], _s_dir[i]), peso_corredor)
			if banheiro != null:
				_cria_caminho("BanheiroDo" + nome, trecho(_meio(i), comprimento()), 0.0)
		if i + 1 < _vagoes.size():
			_cria_caminho(nome + "_" + _vagoes[i + 1].name, trecho(_meio(i), _meio(i + 1)), peso_entre_vagoes)


func _cria_caminho(nome: String, pontos: PackedVector2Array, peso: float) -> void:
	var caminho := Caminho.new()
	caminho.name = nome
	caminho.peso = peso
	caminho.curve = Curve2D.new()
	for p in pontos:
		caminho.curve.add_point(to_local(p))
	add_child(caminho)
	_gerados.append(caminho)
