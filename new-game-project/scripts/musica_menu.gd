extends Node

# Autoload: toca a música em loop nas telas de menu (menu e créditos) sem cortar
# na troca entre elas, e some com um fade ao entrar em qualquer outra cena.

const MUSICA := preload("res://audios/musicafoda.wav")
const CENAS_COM_MUSICA := [
	"res://cenas/menu.tscn",
	"res://cenas/creditos.tscn",
]
const DURACAO_FADE := 0.6
const VOLUME_SILENCIO := -60.0

var _player : AudioStreamPlayer
var _tween : Tween
var _tocando := false


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.stream = MUSICA
	add_child(_player)


func _process(_delta: float) -> void:
	var cena := get_tree().current_scene
	var deve_tocar := cena != null and cena.scene_file_path in CENAS_COM_MUSICA
	if deve_tocar == _tocando:
		return
	_tocando = deve_tocar
	if _tween:
		_tween.kill()
	if deve_tocar:
		_player.volume_db = 0.0
		if not _player.playing:
			_player.play()
	else:
		_tween = create_tween()
		_tween.tween_property(_player, "volume_db", VOLUME_SILENCIO, DURACAO_FADE)
		_tween.tween_callback(_player.stop)
