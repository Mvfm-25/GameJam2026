extends Interativo
class_name Apito

# Cordinha do apito na sala de máquinas: puxar toca o "choo choo".
# O som não é posicional: o apito do trem se ouve em qualquer vagão.

# Quanto a cordinha desce ao ser puxada, em pixels.
const PUXAO := 6.0

@onready var _som: AudioStreamPlayer = $Som


func interage() -> void:
	# Não repete enquanto o apito ainda está tocando.
	if _som.playing:
		return
	_som.play()
	var origem := _sprite.position
	var tween := create_tween()
	tween.tween_property(_sprite, "position", origem + Vector2(0, PUXAO), 0.08)
	tween.tween_property(_sprite, "position", origem, 0.25).set_delay(0.3)
