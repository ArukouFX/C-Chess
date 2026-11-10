extends Sprite2D

# Se emite al hacer clic (boton izquierdo) sobre la pieza para programarla
signal selected(piece)

# Fraccion de la casilla que ocupa la pieza. Con texturas de 160 px y celdas
# de 80 px equivale a la escala de 0.4375 que se usaba antes (70 px).
const CELL_FILL := 0.875
const DEFAULT_CELL_SIZE := 80.0

# Escala de reposo calculada por fit_to_cell. El pulso del contenedor Pieces
# la multiplica sin acumularse.
var base_scale: Vector2 = Vector2.ONE

# Resaltado de la pieza que se esta programando
const SELECTION_COLOR := Color(1.0, 0.82, 0.25)
const SELECTION_WIDTH := 4.0  # grosor del borde en pixeles de pantalla
var is_selected: bool = false
var _cell_size: float = DEFAULT_CELL_SIZE

var piece_id: String = ""
var piece_type: String = ""
var piece_color: String = ""

# Posicion en el tablero. board_position es la fuente de verdad; la virtual
# se mantiene por compatibilidad y siempre deberia coincidir.
var board_position: Vector2 = Vector2.ZERO
var virtual_board_position: Vector2

# Sistema de programacion
var available_ram: int = 0
var behavior_script: Array = []
var is_programmed: bool = false
var program_execution_index: int = 0

# Protocolo de escape. Es de un solo uso: tras un escape exitoso se consume,
# salvo que sea permanente (los que asignan los desafios).
var defense_protocol = null
var defense_protocol_id := ""
var defense_protocol_active := false
var defense_protocol_owner_turn := ""
var defense_protocol_permanent := false

func _ready():
	$Area2D.input_event.connect(_on_area_2d_input_event)
	$Area2D.monitoring = true
	$Area2D.input_pickable = true

func setup_piece(tex: Texture2D, color: String, type: String, board_pos: Vector2) -> void:
	texture = tex
	centered = true
	piece_color = color
	piece_type = type
	board_position = board_pos
	virtual_board_position = board_pos

	# ID unico basado en la posicion inicial, por ejemplo "white_pawn_0_6"
	piece_id = "%s_%s_%d_%d" % [color, type, int(board_pos.x), int(board_pos.y)]

	available_ram = BlockSystem.get_piece_ram_capacity(type)
	behavior_script = []
	is_programmed = false

	fit_to_cell(DEFAULT_CELL_SIZE)

# Ajusta escala y zona de clic al tamano de casilla del tablero
func fit_to_cell(cell_size: float) -> void:
	_cell_size = cell_size
	var shape := RectangleShape2D.new()
	if texture:
		var tex_size := texture.get_size()
		var target := cell_size * CELL_FILL
		base_scale = Vector2.ONE * (target / max(tex_size.x, tex_size.y))
		# La forma es hija del sprite y ya hereda su escala: se usa el tamano
		# de la textura sin escalar para que la zona de clic cubra toda la pieza
		shape.size = tex_size
	else:
		base_scale = Vector2.ONE
		shape.size = Vector2(cell_size, cell_size) * CELL_FILL
	scale = base_scale
	$Area2D.position = Vector2.ZERO
	$Area2D/CollisionShape2D.shape = shape
	$Area2D/CollisionShape2D.position = Vector2.ZERO
	queue_redraw()

func set_selected(value: bool) -> void:
	if is_selected == value:
		return
	is_selected = value
	queue_redraw()

# Borde alrededor de la casilla de la pieza seleccionada. Se dibuja en el
# espacio local del sprite (escalado), asi que tamano y grosor se dividen por
# la escala para que en pantalla midan una casilla y SELECTION_WIDTH pixeles.
func _draw() -> void:
	if not is_selected:
		return
	var s: float = max(scale.x, 0.001)
	var lado: float = _cell_size / s
	var grosor: float = SELECTION_WIDTH / s
	var rect := Rect2(Vector2(-lado, -lado) / 2.0, Vector2(lado, lado)).grow(-grosor / 2.0)
	draw_rect(rect, SELECTION_COLOR, false, grosor)

# Llamado por el contenedor Pieces: escala sobre el centro de la pieza, asi
# que nunca se mueve de su casilla
func apply_pulse(factor: float) -> void:
	scale = base_scale * factor

func get_programming_status() -> String:
	if behavior_script.is_empty():
		return "No program"
	var block_count = behavior_script.size()
	var ram_used = BlockSystem.calculate_ram_usage(behavior_script)
	return "%d block%s (%d/%d RAM)" % [block_count, "s" if block_count != 1 else "", ram_used, available_ram]

func reset_execution():
	program_execution_index = 0

func execute_next_command() -> Dictionary:
	if program_execution_index >= behavior_script.size():
		return {"action": "end_of_program", "stop_execution": true}

	var block_data = behavior_script[program_execution_index]
	var block_type = block_data.get("type", "") if block_data is Dictionary else ""
	var block_info = BlockSystem.get_block_info(block_type)

	if block_info.is_empty() or not block_info.has("execute"):
		push_warning("Bloque desconocido o sin ejecucion en " + piece_id + ": " + block_type)
		program_execution_index = behavior_script.size()
		return {"action": "unknown_block", "stop_execution": true}

	# block_data (que contiene el "type") se pasa como segundo argumento
	var result = await block_info["execute"].call(self, block_data)
	if not result is Dictionary:
		result = {"action": "error", "stop_execution": true}

	if result.get("stop_execution", false):
		program_execution_index = behavior_script.size()
	else:
		program_execution_index += 1
	return result

func has_more_commands() -> bool:
	return program_execution_index < behavior_script.size() - 1

func _on_area_2d_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected.emit(self)
			get_viewport().set_input_as_handled()

# Quita el escape despues de usarlo. Los permanentes se conservan.
func consume_defense_protocol() -> void:
	if defense_protocol_permanent:
		return
	clear_defense_protocol()

func clear_defense_protocol() -> void:
	defense_protocol = null
	defense_protocol_id = ""
	defense_protocol_active = false
	defense_protocol_owner_turn = ""
	defense_protocol_permanent = false

# Fuerza la sincronizacion entre posicion logica y virtual
func sync_positions():
	virtual_board_position = board_position

# Valida que esta pieza tenga datos minimos para ser considerada en colisiones
func is_valid_piece() -> bool:
	return piece_id != "" and piece_type != "" and piece_color != ""
