extends Node2D

# Contenedor de piezas (nodo Pieces de las escenas de juego).
#
# Anima un pulso suave en cada pieza. Antes se escalaba este contenedor, que
# crece desde su origen (desplazado respecto del tablero): las piezas se
# alejaban de sus casillas hasta unos 13 px en las columnas de la derecha.
# Ahora cada pieza pulsa sobre su propio centro y el contenedor queda siempre
# con escala 1, que es lo que asume GameManager._board_to_world_position.

const PULSE_AMOUNT := 0.02    # 2 % de crecimiento en el punto maximo
const PULSE_DURATION := 0.6   # segundos de cada medio ciclo

var pulse_factor: float = 1.0
var _pulse_tween: Tween

func _ready():
	start_pulse()

func start_pulse() -> void:
	stop_pulse()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_method(_apply_pulse, 1.0, 1.0 + PULSE_AMOUNT, PULSE_DURATION)
	_pulse_tween.tween_method(_apply_pulse, 1.0 + PULSE_AMOUNT, 1.0, PULSE_DURATION)

func stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	_apply_pulse(1.0)

func is_pulsing() -> bool:
	return _pulse_tween != null and _pulse_tween.is_valid()

func _apply_pulse(factor: float) -> void:
	pulse_factor = factor
	for child in get_children():
		if child.has_method("apply_pulse"):
			child.apply_pulse(factor)
