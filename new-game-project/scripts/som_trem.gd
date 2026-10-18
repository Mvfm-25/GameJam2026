extends Node
class_name SomTrem

# Barulho do trem (motor e trilhos), ouvido igual em qualquer ponto do trem.
# Dentro de um vagão fica abafado (mais baixo e sem agudos);
# na passarela entre vagões, ao ar livre, fica mais alto e limpo.
# Os AudioStreamPlayer filhos deste nó tocam num bus próprio com filtro passa-baixa.

const BUS := "Trem"

# Dentro do vagão: volume do bus (dB) e corte do filtro (Hz).
const VOLUME_DENTRO := -4.0
const CORTE_DENTRO := 600.0
# Na passarela.
const VOLUME_FORA := 3.0
const CORTE_FORA := 20000.0
# Quão rápido o som muda ao passar pela porta (maior = mais rápido).
const SUAVIZACAO := 5.0

var _bus := -1
var _filtro : AudioEffectLowPassFilter
var _maquinista : Node2D
# 0 = dentro de um vagão, 1 = na passarela.
var _abertura := 0.0


func _ready() -> void:
	_cria_bus()
	_maquinista = get_parent().get_node_or_null("Maquinista")
	_aplica()
	for filho in get_children():
		if filho is AudioStreamPlayer:
			filho.bus = BUS
			filho.play()


func _process(delta: float) -> void:
	var alvo := 0.0 if _dentro_de_vagao() else 1.0
	_abertura = move_toward(_abertura, alvo, SUAVIZACAO * delta)
	_aplica()


func _cria_bus() -> void:
	_bus = AudioServer.get_bus_index(BUS)
	if _bus == -1:
		_bus = AudioServer.bus_count
		AudioServer.add_bus(_bus)
		AudioServer.set_bus_name(_bus, BUS)
		AudioServer.set_bus_send(_bus, "Master")
	for i in AudioServer.get_bus_effect_count(_bus):
		var efeito := AudioServer.get_bus_effect(_bus, i)
		if efeito is AudioEffectLowPassFilter:
			_filtro = efeito
			return
	_filtro = AudioEffectLowPassFilter.new()
	AudioServer.add_bus_effect(_bus, _filtro)


func _aplica() -> void:
	AudioServer.set_bus_volume_db(_bus, lerpf(VOLUME_DENTRO, VOLUME_FORA, _abertura))
	# Interpolação exponencial: o ouvido percebe frequência em escala logarítmica.
	_filtro.cutoff_hz = CORTE_DENTRO * pow(CORTE_FORA / CORTE_DENTRO, _abertura)


# O maquinista está dentro da área de algum vagão? (Fora disso, está na passarela.)
func _dentro_de_vagao() -> bool:
	if _maquinista == null:
		return true
	var pos := _maquinista.global_position
	for v in get_parent().get_children():
		if not (v is Node2D and v.has_method("y_corredor")):
			continue
		var tamanho : Vector2 = Vector2(v.largura_tiles, v.altura_tiles) * v.TAMANHO_TILE
		if Rect2(v.global_position, tamanho).has_point(pos):
			return true
	return false
