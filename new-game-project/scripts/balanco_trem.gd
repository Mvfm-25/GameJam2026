extends Camera2D
class_name BalancoTrem

# Faz o trem balançar nos trilhos: um leve sobe e desce contínuo, mais solavancos
# curtos quando as rodas passam pelas juntas dos trilhos.
# Como a câmera segue o jogador, tudo dentro do trem (vagões, passageiros, itens) balança junto.

@export var ativo := true
# Intensidade geral do balanço (1 = padrão).
@export_range(0.0, 3.0) var intensidade := 1.0
# Intervalo, em segundos, entre um solavanco e outro.
@export var intervalo_solavanco := Vector2(0.6, 1.6)

# Deslocamento máximo, em pixels do jogo, do sobe e desce contínuo e do solavanco.
const BALANCO_Y := 0.8
const BALANCO_X := 0.5
const SOLAVANCO := 1.6
# Velocidade com que o solavanco se dissipa.
const AMORTECIMENTO := 14.0

# O Diretor liga e desliga o balanço pelo grupo: o trem parado na estação não balança.
const GRUPO := "balanco_trem"

var _tempo := 0.0
var _solavanco := 0.0
var _espera := 1.0

func _ready() -> void:
	add_to_group(GRUPO)

func _process(delta: float) -> void:
	if not ativo:
		offset = Vector2.ZERO
		return
	_tempo += delta
	_espera -= delta
	if _espera <= 0.0:
		_espera = randf_range(intervalo_solavanco.x, intervalo_solavanco.y)
		_solavanco = SOLAVANCO * randf_range(0.6, 1.0)
	_solavanco = lerpf(_solavanco, 0.0, 1.0 - exp(-AMORTECIMENTO * delta))

	var y := sin(_tempo * 9.0) * BALANCO_Y * 0.5 + sin(_tempo * 2.3) * BALANCO_Y * 0.5 + _solavanco
	var x := sin(_tempo * 1.7) * BALANCO_X
	# Arredonda para pixels inteiros, assim o pixel art não borra.
	offset = (Vector2(x, y) * intensidade).round()
