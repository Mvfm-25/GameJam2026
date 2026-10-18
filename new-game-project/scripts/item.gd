extends StaticBody2D
class_name Item

# Classes de comida: a tábua vazia vai para a cozinha e volta como comida preparada.
const CLASSE_TABUA_VAZIA := "Comida"
const CLASSE_COMIDA_PREPARADA := "ComidaP"
# Caveira que fica na poça de sangue de um passageiro morto; vira combustível na fornalha.
const CLASSE_CAVEIRA := "Caveira"
# Grupo das caveiras no trem; os passageiros que veem uma entram no modo sacrificial.
const GRUPO_CAVEIRAS := "caveiras"
# Arremesso pela porta traseira: duração do voo e do sumiço no fim.
const DURACAO_ARREMESSO := 0.5
const DURACAO_SUMICO := 0.25

@export var nome = ""

# Diferenciar entre comidas, ferramentas por enquanto.
@export var classe = ""

# Se a tábua volta vazia para a posição inicial depois de consumida.
# Tábuas criadas pelo respawn não voltam, simplesmente somem.
@export var volta_para_origem := true

# Se o item bloqueia a passagem quando está no chão. A caveira não bloqueia,
# senão atrapalharia quem anda pelo corredor ao lado das cadeiras.
@export var solido := true

# Passageiros que viram esta caveira e pediram o sacrifício; reagem quando ela
# for queimada ou jogada fora, mesmo que estejam longe na hora.
var testemunhas : Array[Passageiro] = []
# Passageiros sorteados (1 ou 2) que mostram a seta azul em vez do ícone chifrado
# enquanto o maquinista carrega esta caveira.
var seta_azul : Array[Passageiro] = []

# Se o item está nas mãos do maquinista (some do chão).
var carregado := false
# Se o item está sendo preparado na cozinha (não pode ser pego).
var em_preparo := false

# Onde o item começou; a tábua volta para cá depois que a comida é consumida.
var _posicao_origem := Vector2.ZERO

@onready var _colisao: CollisionShape2D = $CollisionShape2D
@onready var _area: Area2D = $Area2D
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	_area.body_entered.connect(_ao_entrar_area)
	_area.body_exited.connect(_ao_sair_area)
	_posicao_origem = global_position
	_atualiza_sprite()

# Pode ser pego pelo maquinista agora?
func disponivel() -> bool:
	return not carregado and not em_preparo

func eh_tabua_vazia() -> bool:
	return classe == CLASSE_TABUA_VAZIA

func eh_comida_preparada() -> bool:
	return classe == CLASSE_COMIDA_PREPARADA

func eh_caveira() -> bool:
	return classe == CLASSE_CAVEIRA

# Tábuas (vazias ou com comida) usam o sprite do maquinista segurando a tábua.
func eh_tabua() -> bool:
	return eh_tabua_vazia() or eh_comida_preparada()

# Quadro atual do sprite, para o maquinista mostrar o item na mão.
func textura_atual() -> Texture2D:
	return _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)

# Maquinista chegou perto, pode pegar este item
func _ao_entrar_area(body: Node2D) -> void:
	if body is Maquinista and not body.itens_proximos.has(self):
		body.itens_proximos.append(self)

func _ao_sair_area(body: Node2D) -> void:
	if body is Maquinista:
		body.itens_proximos.erase(self)
		# Só volta a ser sólido depois que o jogador se afastou de onde o soltou.
		if not carregado and solido:
			_colisao.set_deferred("disabled", false)

# Some do chão enquanto está sendo carregado
func ser_pego() -> void:
	carregado = true
	visible = false
	_colisao.set_deferred("disabled", true)

# Volta para o chão na posição indicada
func ser_solto(posicao: Vector2) -> void:
	# A caveira solta junto de uma cadeira não pode ficar sob o desenho dela.
	if eh_caveira():
		var diretor := get_tree().current_scene as Diretor
		if diretor != null:
			posicao = diretor.fora_das_cadeiras(posicao)
	global_position = posicao
	carregado = false
	visible = true
	# Colisão continua desligada até o jogador sair da área, senão ele fica preso.

# Jogado para fora do trem: voa de 'de' até 'para' girando e some.
func ser_arremessado(de: Vector2, para: Vector2) -> void:
	remove_from_group(GRUPO_CAVEIRAS)
	# Não pode mais ser pego nem cair na fornalha.
	em_preparo = true
	carregado = false
	_colisao.set_deferred("disabled", true)
	_area.set_deferred("monitoring", false)
	_area.set_deferred("monitorable", false)
	global_position = de
	visible = true
	# Por cima das paredes do vagão enquanto passa pela porta.
	z_index = 50
	var voo := create_tween().set_parallel()
	voo.tween_property(self, "global_position", para, DURACAO_ARREMESSO).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	voo.tween_property(self, "rotation", TAU * 1.5, DURACAO_ARREMESSO)
	voo.chain().tween_property(self, "modulate:a", 0.0, DURACAO_SUMICO)
	voo.tween_property(self, "scale", Vector2.ONE * 0.5, DURACAO_SUMICO)
	voo.chain().tween_callback(queue_free)

# A tábua vazia entra no forno: some enquanto a comida é preparada.
func iniciar_preparo() -> void:
	em_preparo = true
	carregado = false
	visible = false
	_colisao.set_deferred("disabled", true)

# A comida ficou pronta: sai do forno na posição indicada e pode ser pega.
func terminar_preparo(posicao: Vector2) -> void:
	global_position = posicao
	em_preparo = false
	visible = true
	rotation = 0.0
	classe = CLASSE_COMIDA_PREPARADA
	_atualiza_sprite()
	# Colisão continua desligada até o jogador sair da área, senão ele fica preso.

# Passageiro comeu: a tábua vazia volta para onde começou (geladeira).
# Itens que não são tábua simplesmente somem.
func consumir() -> void:
	if not eh_comida_preparada() or not volta_para_origem:
		queue_free()
		return
	classe = CLASSE_TABUA_VAZIA
	em_preparo = false
	carregado = false
	rotation = 0.0
	global_position = _posicao_origem
	visible = true
	_colisao.set_deferred("disabled", not solido)
	_atualiza_sprite()

# Mostra a tábua vazia ou a comida preparada conforme a classe.
func _atualiza_sprite() -> void:
	if eh_comida_preparada():
		_sprite.play("comida_preparada")
	elif eh_tabua_vazia():
		_sprite.play("tabua_vazia")
	else:
		_sprite.play("default")
