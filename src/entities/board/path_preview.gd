extends Node2D
class_name PathPreview

# Dibuja sobre el tablero el recorrido que hara un programa (ProgramPreview):
# - una linea que une el origen con cada paso, en orden;
# - cada casilla recorrida con su numero de paso;
# - el caballo que atraviesa un aliado, con un borde sin relleno;
# - la casilla final con un borde grueso;
# - una captura en rojo y un choque o salida del tablero con una cruz.
#
# Es hija del tablero: trabaja en sus coordenadas locales (celda * cell_size).

const LIGHT := Color(0.878, 0.973, 0.816)   # paleta GameBoy
const MID := Color(0.533, 0.753, 0.439)
const DARK := Color(0.031, 0.094, 0.125)
const DANGER := Color(0.86, 0.29, 0.24)

var cell_size: float = 80.0
var result: Dictionary = {}

func _ready() -> void:
	# Por encima de las piezas, que estan en otro nodo
	z_as_relative = false
	z_index = 20

func show_result(new_result: Dictionary, size: float) -> void:
	result = new_result
	cell_size = size
	visible = true
	queue_redraw()

func clear() -> void:
	result = {}
	visible = false
	queue_redraw()

func has_preview() -> bool:
	return not result.is_empty()

func _cell_rect(cell: Vector2i, inset: float = 0.0) -> Rect2:
	return Rect2(Vector2(cell) * cell_size + Vector2.ONE * inset, Vector2.ONE * (cell_size - 2.0 * inset))

func _center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size

func _draw() -> void:
	if result.is_empty():
		return
	var steps: Array = result["steps"]
	if steps.is_empty():
		return
	var font: Font = ThemeDB.fallback_font

	# Linea del recorrido (solo hasta donde la pieza entra)
	var points := PackedVector2Array([_center(result["start"])])
	for s in steps:
		if s["kind"] in [ProgramPreview.MOVE, ProgramPreview.PASS, ProgramPreview.CAPTURE]:
			points.append(_center(s["cell"]))
	if result["returned"]:
		points.append(_center(result["final"]))
	if points.size() > 1:
		# Contorno oscuro para que se lea sobre casillas claras y oscuras
		draw_polyline(points, Color(DARK, 0.75), 9.0, true)
		draw_polyline(points, LIGHT, 4.0, true)

	# Origen
	draw_arc(_center(result["start"]), cell_size * 0.14, 0, TAU, 24, LIGHT, 3.0, true)

	# Casillas, en orden
	for i in range(steps.size()):
		var s: Dictionary = steps[i]
		var cell: Vector2i = s["cell"]
		match s["kind"]:
			ProgramPreview.MOVE:
				draw_rect(_cell_rect(cell, 4), Color(LIGHT, 0.30))
				_outlined_rect(_cell_rect(cell, 4), Color(LIGHT, 0.9), 2.0)
			ProgramPreview.PASS:
				# Sin relleno: la pieza aliada sigue viendose
				_outlined_rect(_cell_rect(cell, 6), MID, 3.0)
			ProgramPreview.CAPTURE:
				draw_rect(_cell_rect(cell, 3), Color(DANGER, 0.40))
				draw_rect(_cell_rect(cell, 3), DANGER, false, 5.0)
			ProgramPreview.BLOCKED, ProgramPreview.OUT:
				var r := _cell_rect(cell, cell_size * 0.25)
				for pass_color in [[DARK, 10.0], [DANGER, 6.0]]:
					draw_line(r.position, r.end, pass_color[0], pass_color[1], true)
					draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), pass_color[0], pass_color[1], true)
		_draw_step_number(font, cell, i + 1)

	# Casilla final
	if result["final"] != result["start"] and result["stop"] != ProgramPreview.CAPTURE:
		_outlined_rect(_cell_rect(result["final"], 2), LIGHT, 5.0)

# Borde con un contorno oscuro por fuera
func _outlined_rect(rect: Rect2, color: Color, width: float) -> void:
	draw_rect(rect, Color(DARK, 0.8), false, width + 3.0)
	draw_rect(rect, color, false, width)

func _draw_step_number(font: Font, cell: Vector2i, number: int) -> void:
	var radius := cell_size * 0.15
	var badge := Vector2(cell) * cell_size + Vector2(radius + 4, radius + 4)
	draw_circle(badge, radius, DARK)
	var text := str(number)
	var font_size := int(cell_size * 0.2)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, badge + Vector2(-text_size.x / 2.0, text_size.y * 0.32), text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, LIGHT)
