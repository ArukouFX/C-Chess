extends Node

# Actualiza tu diccionario en game_manager.gd
@onready var block_logic_map = {
	"move_forward": func(piece): return await _execute_movement_block(piece, "move_forward"),
	"move_back": func(piece): return await _execute_movement_block(piece, "move_back"),
	"move_side": func(piece): return await _execute_movement_block(piece, "move_side"), # Si usas izquierda/derecha separados, añádelos aquí
	"capture": _logic_capture
}

# References
@onready var pieces_container = $"../Pieces"
@onready var board = $"../Table/Board"
@onready var turn_display = $"../Turn/TurnDisplay"
@onready var camera = $"../Camera/Camera2D"

var game_over := false
var winner := ""

# Diccionario global para guardar programas: { "ID_PIEZA": [lista_de_bloques] }
var saved_programs = {}

var current_programming_interface: Node = null
var current_turn: String = "white"
var is_opening_interface: bool = false

var programmed_moves: Array = []
var execution_phase: bool = false
var current_programming_piece: Node = null
var execution_timer: Timer = null

# Pre-cgarge
var GameOverScreenScene = preload("res://src/ui/game_over_screen.tscn")
var PieceScene = preload("res://src/entities/pieces/piece.tscn")
var ProgrammingInterfaceScene = preload("res://src/ui/interface/programming_interface.tscn")
var piece_textures = {
	# White pieces
	"white_pawn": preload("res://assets/graphics/white/white-pawn.png"),
	"white_bishop": preload("res://assets/graphics/white/white-bishop.png"),
	"white_horse": preload("res://assets/graphics/white/white-horse.png"),
	"white_tower": preload("res://assets/graphics/white/white-tower.png"),
	"white_queen": preload("res://assets/graphics/white/white-queen.png"),
	"white_king": preload("res://assets/graphics/white/white-king.png"),
	# Black pieces
	"black_pawn": preload("res://assets/graphics/black/black-pawn.png"),
	"black_bishop": preload("res://assets/graphics/black/black-bishop.png"),
	"black_horse": preload("res://assets/graphics/black/black-horse.png"),
	"black_tower": preload("res://assets/graphics/black/black-tower.png"),
	"black_queen": preload("res://assets/graphics/black/black-queen.png"),
	"black_king": preload("res://assets/graphics/black/black-king.png"),
}

func _ready():
	_debug_board_info()
	_initialize_game()
	call_deferred("_test_block_system")
	call_deferred("_connect_piece_signals")

func _initialize_game():
	spawn_pawns()
	spawn_main_pieces()
	update_turn_display()
	
	# Esperar un frame para que las piezas estén listas
	await get_tree().process_frame
	
	# Conectar señales y configurar estado inicial
	_connect_piece_signals()
	
	# Iniciar fase de programación
	start_programming_phase()

func on_resolution_changed(new_resolution: Vector2i):
	print("GameManager: Resolución cambiada a ", new_resolution)
	
	# 1. Esperar a que el board se actualice
	await get_tree().process_frame
	
	# 2. Re-posicionar todas las piezas
	_reposition_all_pieces()

func _reposition_all_pieces():
	print("Re-posicionando todas las piezas...")
	
	for piece in pieces_container.get_children():
		if piece.has_method("get_board_position"):
			var board_coord = piece.board_position
			var new_world_pos = _board_to_world_position(board_coord)
			
			# Actualizar posición
			piece.position = new_world_pos
			piece.global_position = new_world_pos
			
			print("  ", piece.piece_type, " movido a: ", new_world_pos)

#modificado con sistema actual
func spawn_piece(type: String, board_coord: Vector2):
	var piece = PieceScene.instantiate()
	var color = type.split("_")[0]
	var piece_type = type.split("_")[1]
	
	# Un solo ID consistente basado en su posición inicial
	var unique_id = "%s_%d_%d" % [type, int(board_coord.x), int(board_coord.y)]
	piece.piece_id = unique_id
	
	piece.setup_piece(piece_textures[type], color, piece_type, board_coord)
	
	# Cargar programa desde el diccionario global si ya existe
	if saved_programs.has(unique_id):
		piece.behavior_script = saved_programs[unique_id].duplicate(true)
		piece.is_programmed = true
		print("Programa inyectado en ", unique_id, " desde el spawn (saved_programs).")
	
	# Conexión de señales
	if piece.has_signal("right_clicked"):
		piece.right_clicked.connect(_on_piece_right_clicked)
	
	# Posicionamiento y árbol
	var world_position = _board_to_world_position(board_coord)
	piece.position = world_position
	pieces_container.add_child(piece)
	
	return piece

# Asegurar que _board_to_world_position use la función del board:
func _board_to_world_position(board_coord: Vector2) -> Vector2:
	if board and board.has_method("get_world_position_from_cell"):
		return board.get_world_position_from_cell(board_coord)
	
	# Fallback con valores por defecto
	print("WARNING: Usando fallback para coordenada ", board_coord)
	return Vector2(320 + board_coord.x * 80, 384 + (7 - board_coord.y) * 80)

func _debug_board_info():
	print("=== BOARD POSITION DEBUG ===")
	print("Board global_position:", board.global_position)
	print("Board origin:", board.get_board_origin())
	print("Board cell_size:", board.cell_size)
	
	var origin = board.get_board_origin()
	var size = board.board_size * board.cell_size
	print("Board top-left:", origin)
	print("Board bottom-right:", origin + size)
	print("=============================")

# === Piece System ===
func spawn_pawns():
	# CORRECCIÓN: Ahora Y=0 es ARRIBA (negras), Y=7 es ABAJO (blancas)
	# Pero board.gd NO invierte Y, así que:
	# - Negras en Y=0,1 (arriba en pantalla)
	# - Blancas en Y=6,7 (abajo en pantalla)
	
	print("Generando peones...")
	
	for i in range(8):
		# NEGRAS ARRIBA (Y bajos)
		spawn_piece("black_pawn", Vector2(i, 1))  # Fila 7 en ajedrez
		# BLANCAS ABAJO (Y altos)  
		spawn_piece("white_pawn", Vector2(i, 6))  # Fila 2 en ajedrez
	
	print("Peones generados")

func spawn_main_pieces():
	var white_order = ["white_tower", "white_horse", "white_bishop", "white_queen", "white_king", "white_bishop", "white_horse", "white_tower"]
	var black_order = ["black_tower", "black_horse", "black_bishop", "black_queen", "black_king", "black_bishop", "black_horse", "black_tower"]
	
	print("Generando piezas principales...")
	
	for i in range(8):
		# NEGRAS ARRIBA - fila 8 en ajedrez (Y=0)
		spawn_piece(black_order[i], Vector2(i, 0))
		# BLANCAS ABAJO - fila 1 en ajedrez (Y=7)
		spawn_piece(white_order[i], Vector2(i, 7))
	
	print("Piezas principales generadas")

func _world_to_board_coord(world_position: Vector2) -> Vector2:
	# Usar SIEMPRE la función del tablero
	if board and board.has_method("get_cell_coord"):
		return board.get_cell_coord(world_position)
	
	# Fallback CORREGIDO (sin invertir Y)
	var cell_size = 80.0
	var board_center = Vector2(680, 384)
	var total_size = Vector2(640, 640)
	var board_origin = board_center - (total_size / 2)
	
	var local_pos = world_position - board_origin
	var cell_x = floor(local_pos.x / cell_size)
	var cell_y = floor(local_pos.y / cell_size)  # NO INVERTIR
	
	return Vector2(cell_x, cell_y)

# === Movement Manager ===

func get_piece_at_position(position: Vector2, exclude_piece: Node = null) -> Node:
	var cell_coord = _world_to_board_coord(position)
	
	for piece in pieces_container.get_children():
		if piece == exclude_piece:
			continue
		
		var piece_cell_coord = _world_to_board_coord(piece.global_position)
		if piece_cell_coord == cell_coord:
			return piece
	
	return null

func _is_different_cell(pos1: Vector2, pos2: Vector2) -> bool:
	var coord1 = _world_to_board_coord(pos1)
	var coord2 = _world_to_board_coord(pos2)
	return coord1 != coord2

func can_capture(attacker_color: String, defender_color: String) -> bool:
	return attacker_color != defender_color

func capture_piece(piece_to_capture):
	# Guardar referencia antes del queue_free
	var captured_type = piece_to_capture.piece_type
	var captured_color = piece_to_capture.piece_color
	piece_to_capture.board_position = Vector2(-999, -999)
	piece_to_capture.virtual_board_position = Vector2(-999, -999)
	piece_to_capture.queue_free()
	print("Pieza capturada: ", captured_color, " ", captured_type)
	# Esperar frame para asegurar queue_free
	await get_tree().process_frame
	check_victory_conditions()

func open_programming_interface_for_piece(piece: Node, mouse_pos: Vector2):
	if current_programming_interface:
		current_programming_interface.queue_free()

	if piece.piece_id == "":
		var pos = piece.board_position
		piece.piece_id = "%s_%d_%d" % [piece.piece_type, int(pos.x), int(pos.y)]

	# --- SOLUCIÓN AQUÍ ---
	current_programming_piece = piece # Guardamos qué pieza se está programando a nivel global
	# ---------------------

	var new_interface = ProgrammingInterfaceScene.instantiate()
	new_interface.visible = false
	
	var ui_layer = get_node_or_null("/root/Main/CanvasLayer")
	if ui_layer:
		ui_layer.add_child(new_interface)
	else:
		add_child(new_interface)
	
	await get_tree().process_frame 
	
	if new_interface.has_method("setup_for_piece"):
		new_interface.setup_for_piece(piece)
		if new_interface.has_method("update_ram_display"):
			new_interface.update_ram_display()
	
	new_interface.visible = true
	current_programming_interface = new_interface
	_position_interface_smartly(new_interface)

func _position_interface_smartly(interface: Control):
	var screen_size = get_viewport().get_visible_rect().size
	var interface_size = interface.size
	
	print("Posicionando interfaz:")
	print("  Pantalla: ", screen_size)
	print("  Interfaz: ", interface_size)
	
	# Calcular posición óptima
	var target_position = Vector2()
	
	# 1. Intentar posición derecha-centro
	target_position.x = screen_size.x - interface_size.x - 20
	target_position.y = (screen_size.y - interface_size.y) / 2
	
	# 2. Si no cabe a la derecha, poner a la izquierda
	if target_position.x < 20:
		target_position.x = 20
	
	# 3. Asegurar que esté dentro de la pantalla
	target_position.x = clamp(target_position.x, 10, screen_size.x - interface_size.x - 10)
	target_position.y = clamp(target_position.y, 10, screen_size.y - interface_size.y - 10)
	
	interface.position = target_position
	print("  Posición final: ", target_position)

# Función auxiliar para debug
func _debug_canvas_layers():
	print("=== DEBUG CANVAS LAYERS ===")
	
	# Buscar en root
	for child in get_tree().root.get_children():
		print(child.name, " (", child.get_class(), ")")
		if child is CanvasLayer:
			print("  -> Es CanvasLayer con ", child.get_child_count(), " hijos")
			for subchild in child.get_children():
				print("    - ", subchild.name, " (", subchild.get_class(), ")")
	
	# Buscar en Main
	var main = get_node_or_null("/root/Main")
	if main:
		print("\nEn Main:")
		for child in main.get_children():
			print("  ", child.name, " (", child.get_class(), ")")
	
	print("=== FIN DEBUG ===\n")

func _get_or_create_canvas_layer() -> CanvasLayer:
	# Buscar CanvasLayer existente
	var main = get_node_or_null("/root/Main")
	if main:
		# Buscar en Main
		var canvas_layer = main.get_node_or_null("CanvasLayer")
		if canvas_layer:
			return canvas_layer
		
		# Crear si no existe
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "CanvasLayer"
		main.add_child(canvas_layer)
		return canvas_layer
	
	# Fallback: buscar en root
	var root = get_tree().root
	for child in root.get_children():
		if child is CanvasLayer:
			return child
	
	# Crear nuevo
	var new_canvas = CanvasLayer.new()
	new_canvas.name = "CanvasLayer"
	root.add_child(new_canvas)
	return new_canvas

func _open_interface_fallback(piece: Node):
	print("=== INTENTANDO FALLBACK ===")
	
	# Método ultra simple
	var control = Control.new()
	control.name = "ProgrammingInterface_Fallback"
	control.custom_minimum_size = Vector2(600, 400)
	control.size = Vector2(600, 400)
	control.visible = true
	
	# Fondo
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.2, 0.95)
	bg.size = control.size
	control.add_child(bg)
	
	# Título
	var label = Label.new()
	label.text = "Programando: " + piece.piece_color + " " + piece.piece_type
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 20)
	control.add_child(label)
	
	# Botón cerrar
	var close_btn = Button.new()
	close_btn.text = "Cerrar"
	close_btn.position = Vector2(250, 350)
	close_btn.size = Vector2(100, 40)
	close_btn.pressed.connect(func():
		print("Cerrando interfaz fallback")
		control.queue_free()
		current_programming_interface = null
	)
	control.add_child(close_btn)
	
	# Agregar al GameManager
	add_child(control)
	
	# Posicionar
	var screen_size = get_viewport().get_visible_rect().size
	control.position = Vector2(
		screen_size.x - control.size.x - 50,
		(screen_size.y - control.size.y) / 2
	)
	
	current_programming_interface = control
	print("Interfaz fallback creada")

# También modificar _on_piece_right_clicked para debug:
func _on_piece_right_clicked(piece):
	print("=== CLICK DERECHO EN PIEZA ===")
	print("Pieza: ", piece.piece_type)
	print("Color: ", piece.piece_color)
	print("Turno actual: ", current_turn)
	print("Posición: ", piece.global_position)
	
	open_programming_interface_for_piece(piece, piece.global_position)

func _simple_open_interface(piece: Node):
	# Método alternativo más simple
	var new_interface = ProgrammingInterfaceScene.instantiate()
	
	# Agregar como hijo directo de Main
	var main_node = get_node("/root/Main")
	if main_node:
		main_node.add_child(new_interface)
		
		# Configurar propiedades básicas
		new_interface.position = Vector2(100, 100)
		new_interface.size = Vector2(600, 400)
		new_interface.visible = true
		
		if new_interface.has_method("setup_for_piece"):
			new_interface.setup_for_piece(piece)
		
		current_programming_interface = new_interface
		print("Interface opened with fallback method")

func _position_interface_at_camera_right(interface: Control):
	if not interface:
		print("ERROR: Interface is null")
		return
	
	# Usar una posición fija y segura
	var screen_size = get_viewport().get_visible_rect().size
	
	# Posición en el lado derecho de la pantalla
	interface.position = Vector2(
		screen_size.x - interface.size.x - 20,
		(screen_size.y - interface.size.y) / 2
	)
	
	print("Interface positioned at: ", interface.position)

# FUNCIÓN DE RESPALDO: Posiciona en el lado derecho de la pantalla
func _position_interface_at_screen_right(interface: Control):
	var screen_size = get_viewport().get_visible_rect().size
	var interface_size = interface.size
	
	var target_position = Vector2(
		screen_size.x - interface_size.x - 20,  # 20px desde el borde derecho
		(screen_size.y - interface_size.y) / 2   # Centrada verticalmente
	)
	
	interface.global_position = target_position
	print("Fallback: Positioned at screen right: ", target_position)
# === SISTEMA DE TURNOS ===
func is_valid_turn(piece_color: String) -> bool:
	return piece_color == current_turn

func switch_turn():
	current_turn = "black" if current_turn == "white" else "white"
	print("Turn changed to: ", current_turn)
	update_turn_display()
	
	# Actualizar estado de todas las piezas después de cambiar turno
	_update_pieces_input_state()

func _update_pieces_input_state():
	for piece in pieces_container.get_children():
		if piece.has_node("Area2D"):
			var area2d = piece.get_node("Area2D")
			
			if piece.piece_color == current_turn:
				area2d.input_pickable = true
				area2d.monitoring = true
				piece.modulate = Color.WHITE
			else:
				area2d.input_pickable = false
				area2d.monitoring = false
				piece.modulate = Color(0.5, 0.5, 0.5, 0.7)

func update_turn_display():
	if turn_display and turn_display.has_method("update_turn"):
		turn_display.update_turn(current_turn)

# === Close manager ===
func _on_programming_interface_closed():
	print("Programming interface closed from GameManager")
	
	if current_programming_interface and is_instance_valid(current_programming_interface):
		current_programming_interface = null
	
	current_programming_piece = null # <--- Limpiamos la pieza activa
	is_opening_interface = false
	_update_pieces_input_state()

# === DEBUG UTILITIES ===
func print_all_piece_positions():
	print("=== ALL PIECE POSITIONS ===")
	for piece in pieces_container.get_children():
		var coord = _world_to_board_coord(piece.global_position)
		print("Piece:", piece.piece_type, " at cell:", coord)
	print("===========================")

func _test_block_system():
	print("=== TEST BLOCK SYSTEM DEBUG ===")
	
	# Verificar si BlockSystem existe
	if not BlockSystem:
		print("ERROR: BlockSystem no está cargado")
		return
	
	print("BlockSystem encontrado")
	
	# Probar obtener un bloque
	var test_block = BlockSystem.get_block_info("move_forward")
	print("Bloque 'move_forward':")
	print("  Tipo: ", typeof(test_block))
	print("  Es diccionario: ", test_block is Dictionary)
	print("  Contenido: ", test_block)
	print("  Tiene 'name': ", "name" in test_block if test_block is Dictionary else "N/A")
	print("  Tiene 'ram_cost': ", "ram_cost" in test_block if test_block is Dictionary else "N/A")
	
	# Si el bloque está vacío, usar valores por defecto
	if test_block.is_empty():
		print("ADVERTENCIA: get_block_info devolvió diccionario vacío")
		# Crear bloque de prueba manualmente
		test_block = {
			"name": "Mover Adelante",
			"ram_cost": 2,
			"category": "movement",
			"description": "Avanza una casilla hacia adelante"
		}
		print("  Usando bloque de prueba: ", test_block)
	
	print("=== FIN TEST ===\n")

func _connect_piece_signals():
	print("Connecting piece signals...")
	var connected_count = 0
	
	for piece in pieces_container.get_children():
		# Conectar señal right_clicked si existe
		if piece.has_signal("right_clicked"):
			if not piece.right_clicked.is_connected(_on_piece_right_clicked):
				piece.right_clicked.connect(_on_piece_right_clicked)
				connected_count += 1
				print("Connected right_clicked to: ", piece.piece_type)
		
		# Configurar estado inicial del Área2D
		if piece.has_node("Area2D"):
			var area2d = piece.get_node("Area2D")
			
			# Inicialmente solo las blancas pueden programarse
			if piece.piece_color == current_turn:
				area2d.input_pickable = true
				area2d.monitoring = true
				piece.modulate = Color.WHITE
			else:
				area2d.input_pickable = false
				area2d.monitoring = false
				piece.modulate = Color(0.5, 0.5, 0.5, 0.7)
	
	print("Connected to ", connected_count, " pieces")
	print("Input configured for current turn: ", current_turn)

# ==============================================
# NUEVO SISTEMA DE PROGRAMACIÓN POR BLOQUES
# ==============================================

func start_programming_phase():
	print("=== FASE DE PROGRAMACIÓN ===")
	print("Turno: ", current_turn)
	execution_phase = false
	
	# Habilitar/deshabilitar la detección de input por Área2D
	for piece in pieces_container.get_children():
		if piece.has_node("Area2D"):
			var area2d = piece.get_node("Area2D")
			
			if piece.piece_color == current_turn:
				# Habilitar detección para piezas del turno actual
				area2d.input_pickable = true
				area2d.monitoring = true
				piece.modulate = Color.WHITE  # Color normal
			else:
				# Deshabilitar detección para piezas del oponente
				area2d.input_pickable = false
				area2d.monitoring = false
				piece.modulate = Color(0.5, 0.5, 0.5, 0.7)  # Grisado

func start_programming_timer(seconds: float):
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = seconds
	timer.timeout.connect(func():
		print("Tiempo de programación terminado")
		timer.queue_free()
		start_execution_phase()
	)
	timer.start()
	print("Temporizador de programación iniciado: ", seconds, " segundos")

func start_execution_phase(target_piece: Node = null):
	print("=== FASE DE EJECUCIÓN SELECCIONADA ===")
	execution_phase = true
	programmed_moves.clear()
	
	if target_piece:
		# CASO A: Solo ejecutamos la pieza que lanzamos desde la interfaz
		if target_piece.is_programmed:
			programmed_moves.append({"piece": target_piece, "script": target_piece.behavior_script})
			print("Ejecutando programa específico para: ", target_piece.piece_id)
	else:
		# CASO B: Comportamiento antiguo (opcional, por si quieres ejecutar todo el tablero)
		for piece in pieces_container.get_children():
			if piece.piece_color == current_turn and piece.is_programmed:
				programmed_moves.append({"piece": piece, "script": piece.behavior_script})
	
	if programmed_moves.is_empty():
		print("No hay programas para ejecutar o la pieza no tiene bloques")
		execution_phase = false # No bloqueamos el juego si no hay nada que hacer
		return 
		
	execute_programs_sequentially()

func execute_programs_sequentially():
	var index = 0
	
	if execution_timer:
		execution_timer.queue_free()
	
	execution_timer = Timer.new()
	add_child(execution_timer)
	execution_timer.wait_time = 1.0  # 1 segundo entre movimientos
	
	execution_timer.timeout.connect(func():
		if index < programmed_moves.size():
			var data = programmed_moves[index]
			print("Ejecutando programa ", index + 1, "/", programmed_moves.size())
			execute_piece_program(data["piece"])
			index += 1
		else:
			execution_timer.queue_free()
			execution_timer = null
			print("Todos los programas ejecutados")
			end_turn()
	)
	
	execution_timer.start()

func _on_execute_turn_button_pressed():
	# Solo iniciamos si no estamos ya ejecutando movimientos
	if not execution_phase:
		print("Iniciando ejecución de turno...")
		start_execution_phase()

func _execute_movement_block(piece: Node, type: String):
	var block_info = BlockSystem.get_block_info(type)
	if block_info.is_empty() or not block_info.has("vector"):
		return {"stop_execution": true}

	var vec = Vector2i(block_info["vector"])
	
	# --- CORRECCIÓN MATEMÁTICA DE ORIENTACIÓN ---
	# Si es blanca, invertimos tanto el eje Y (adelante/atrás) como el eje X (izquierda/derecha)
	# para que los comandos de la UI sean relativos a la perspectiva de la pieza.
	var multiplier = -1 if piece.piece_color == "white" else 1
	var target_modifier = vec * multiplier
	
	var current_pos = Vector2i(piece.board_position)
	var target = current_pos + target_modifier
	
	print("[PROCESADOR] ", piece.piece_id, " ejecuta ", type, ". Objetivo relativo calculado: ", target)

	# 2. Validación y ejecución física
	if is_valid_move(piece, target):
		# El caballo saltará los obstáculos del camino aquí gracias a tu regla en move_piece_to
		var hit_obstacle = await move_piece_to(piece, Vector2(target)) 
		
		if hit_obstacle:
			print("[SISTEMA] Movimiento interrumpido en destino.")
			return {"stop_execution": true}
			
		return {"stop_execution": false}
	else:
		var obstacle = get_piece_at(target)
		if obstacle:
			print("HARDWARE ERROR: Destino final bloqueado por aliado en ", target)
		else:
			print("HARDWARE ERROR: Movimiento fuera de los límites del tablero en ", target)
		return {"stop_execution": true} # Detiene el resto del programa si choca

func _execute_loop(piece: Node, action_type: String, repetitions: int):
	print("Iniciando bucle de ", repetitions, " repeticiones para ", action_type)
	for i in range(repetitions):
		# Ejecutamos el movimiento y esperamos a que termine
		await _execute_movement_block(piece, action_type)
		
		# Pausa entre pasos del bucle
		await get_tree().create_timer(0.1).timeout

# Función para evaluar sensores
func _check_condition(condition_type: String, piece: Node) -> bool:
	var forward_dir = -1 if piece.piece_color == "white" else 1
	var target_cell = piece.board_position + Vector2(0, forward_dir)
	
	var target_world_pos = _board_to_world_position(target_cell)
	var obstacle = get_piece_at_position(target_world_pos)
	
	match condition_type:
		"enemy_front":
			return obstacle != null and obstacle.piece_color != piece.piece_color
		"ally_front":
			return obstacle != null and obstacle.piece_color == piece.piece_color
		"detect_wall":
			return target_cell.y < 0 or target_cell.y > 7
	return false

func process_command_result(piece, command):
	print("Procesando comando: ", command.get("action"))
	
	match command.get("action"):
		"move":
			var target = command["target"]
			if is_valid_move(piece, target):
				move_piece_to(piece, target)
			else:
				print("Movimiento no válido para ", piece.piece_type)
		"move_options":
			var targets = command["targets"]
			# Ejecutar el primer movimiento válido
			for target in targets:
				if is_valid_move(piece, target):
					move_piece_to(piece, target)
					break
		"capture":
			var direction = command.get("direction", "front")
			attempt_capture(piece, direction)
		"condition":
			print("Condición evaluada: ", command.get("check"))
		_:
			print("Comando desconocido: ", command.get("action"))

func is_valid_move(piece: Node, target: Vector2i) -> bool:
	# 1. Límites del tablero
	if target.x < 0 or target.x > 7 or target.y < 0 or target.y > 7:
		return false
	
	var target_piece = get_piece_at(target)
	
	if target_piece:
		# === NUEVA REGLA PARA EL CABALLO ===
		if piece.piece_type == "horse":
			return true
		
		# Reglas normales para otras piezas
		if target_piece.piece_color == piece.piece_color:
			print("Espacio ocupado por aliado en: ", target)
			return false
		
		return true
		
	return true

func _is_basic_move_valid(piece: Node, target_cell: Vector2) -> bool:
	var current_cell = piece.board_position
	var delta = target_cell - current_cell
	
	match piece.piece_type:
		"pawn":
			var direction = -1 if piece.piece_color == "white" else 1
			# Movimiento básico del peón: una casilla adelante
			if delta == Vector2(0, direction):
				return true
			# Primer movimiento: dos casillas
			if (piece.piece_color == "white" and current_cell.y == 6) or \
			   (piece.piece_color == "black" and current_cell.y == 1):
				if delta == Vector2(0, 2 * direction):
					return true
			return false
		
		"bishop":
			# Alfil: movimiento diagonal
			return abs(delta.x) == abs(delta.y)
		
		"horse":
			# Caballo: movimiento en L
			var abs_delta = delta.abs()
			return (abs_delta.x == 1 and abs_delta.y == 2) or \
				   (abs_delta.x == 2 and abs_delta.y == 1)
		
		"tower":
			# Torre: movimiento horizontal o vertical
			return delta.x == 0 or delta.y == 0
		
		"queen":
			# Reina: movimiento horizontal, vertical o diagonal
			return delta.x == 0 or delta.y == 0 or abs(delta.x) == abs(delta.y)
		
		"king":
			# Rey: movimiento una casilla en cualquier dirección
			return abs(delta.x) <= 1 and abs(delta.y) <= 1
	
	return true  # Para pruebas, permitir cualquier movimiento

func move_piece_to(piece: Node, target_cell: Vector2) -> bool:
	var target_cell_i = Vector2i(target_cell)
	var current_cell_i = Vector2i(piece.board_position)
	
	# 1. Fuera de límites del tablero
	if target_cell_i.x < 0 or target_cell_i.x > 7 or target_cell_i.y < 0 or target_cell_i.y > 7:
		print("Movimiento abortado: Fuera de límites")
		return true # Detener ejecución del programa de la pieza

	# =========================================================================
	# 2. VALIDACIÓN DE OBSTÁCULOS EN EL CAMINO (¡EL CABALLO SE LO SALTA!)
	# =========================================================================
	if piece.piece_type != "horse":
		var diff = target_cell_i - current_cell_i
		
		# Calculamos la dirección del paso en cada eje (-1, 0 o 1)
		var step = Vector2i(
			sign(diff.x),
			sign(diff.y)
		)
		
		var check_cell = current_cell_i + step
		
		# Avanzamos celda por celda en línea recta/diagonal ANTES del destino final
		while check_cell != target_cell_i:
			var obstacle = get_piece_at(check_cell)
			if obstacle != null:
				print("HARDWARE ERROR: ", piece.piece_type, " colisionó con ", obstacle.piece_type, " en el camino ", check_cell)
				return true # Chocó en el trayecto, abortamos el hilo del script
				
			check_cell += step
	else:
		# Debug para confirmar que el caballo está usando su propiedad de salto
		print("PROPIEDAD DE SALTO: El caballo ", piece.piece_id, " ignora el camino desde ", current_cell_i, " hasta ", target_cell_i)
	# =========================================================================

	# 3. Verificar el ocupante de la CASILLA FINAL (Destino)
	var piece_at_target = get_piece_at(target_cell_i)
	
	if piece_at_target:
		# Si hay una pieza enemiga -> Captura automática (también aplica al caballo al aterrizar)
		if piece_at_target.piece_color != piece.piece_color:
			print("Capturando pieza enemiga al aterrizar: ", piece_at_target.piece_type)
			capture_piece(piece_at_target)
			
			# Mover visualmente y actualizar lógica
			piece.board_position = target_cell
			var target_world_pos = _board_to_world_position(target_cell)
			var tween = create_tween()
			tween.tween_property(piece, "position", target_world_pos, 0.3)
			
			return true # Hubo captura, detenemos el hilo de este turno
		else:
			# === EXCEPCIÓN DEL CABALLO ===
			if piece.piece_type == "horse":
				print("Caballo aterriza sobre aliado (modo salto avanzado)")
				
				# OPCIÓN A: compartir casilla
				# No hacemos nada, dejamos coexistir
				
				# OPCIÓN B: swap/intercambio
				# var old_pos = piece.board_position
				# piece_at_target.board_position = old_pos
				
			else:
				print("Bloqueado: Casilla de aterrizaje ocupada por aliado.")
				return true
	
	# 4. Movimiento normal (casilla de destino vacía)
	piece.board_position = target_cell
	var target_world_pos = _board_to_world_position(target_cell)
	var tween = create_tween()
	# Añadimos un pequeño efecto de arco/salto visual en el Tween para que se note que salta
	tween.set_parallel(false)
	tween.tween_property(piece, "position", target_world_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	return false # No hubo colisión en destino, puede seguir ejecutando bloques si le quedan RAM

func attempt_capture(piece: Node, direction: String):
	print("Intentando captura con ", piece.piece_type, " en dirección ", direction)
	
	var target_cell = piece.board_position
	
	match direction:
		"front":
			var dir = -1 if piece.piece_color == "white" else 1
			target_cell += Vector2(0, dir)
		"diagonal_left":
			var dir = -1 if piece.piece_color == "white" else 1
			target_cell += Vector2(-1, dir)
		"diagonal_right":
			var dir = -1 if piece.piece_color == "white" else 1
			target_cell += Vector2(1, dir)
	
	if is_valid_move(piece, target_cell):
		move_piece_to(piece, target_cell)

func end_turn():
	print("=== FIN DEL TURNO ===")
	
	# Limpiar programas ejecutados
	programmed_moves.clear()
	execution_phase = false
	
	# Cambiar turno
	switch_turn()
	
	# Iniciar siguiente fase de programación
	await get_tree().create_timer(1.0).timeout
	start_programming_phase()

# Función para iniciar ejecución manual (para testing)
func start_execution_manually():
	if not execution_phase:
		start_execution_phase()

# Función para saltar a la siguiente fase (para testing)
func skip_to_next_phase():
	if execution_phase:
		if execution_timer:
			execution_timer.queue_free()
			execution_timer = null
		end_turn()
	else:
		start_execution_phase()

func highlight_programmable_pieces():
	for piece in pieces_container.get_children():
		if piece.piece_color == current_turn:
			# Resaltar piezas que se pueden programar
			var tween = create_tween()
			tween.tween_property(piece, "modulate", Color(1.2, 1.2, 1.0, 1.0), 0.3)
			tween.tween_property(piece, "modulate", Color.WHITE, 0.3)
			tween.set_loops()

func debug_scene_tree():
	print("=== SCENE TREE DEBUG ===")
	print("Root children: ", get_tree().root.get_child_count())
	for child in get_tree().root.get_children():
		print("  - ", child.name, " (", child.get_class(), ")")
	print("=======================")

#Debug
# En game_manager.gd, después de crear piezas:
func verify_chess_setup():
	print("\n=== VERIFICACIÓN DE AJEDREZ ===")
	
	# Coordenadas esperadas (para 1360x768, celda 80px)
	var board_center = Vector2(680, 384)
	var cell_size = 80.0
	
	print("Centro tablero: ", board_center)
	print("Tamaño celda: ", cell_size)
	
	# Verificar posiciones clave
	var test_cells = [
		Vector2(0, 0),  # Torre negra izquierda (A8)
		Vector2(7, 0),  # Torre negra derecha (H8)
		Vector2(0, 7),  # Torre blanca izquierda (A1)
		Vector2(7, 7),  # Torre blanca derecha (H1)
		Vector2(3, 0),  # Reina negra
		Vector2(4, 0),  # Rey negro
		Vector2(3, 7),  # Reina blanca
		Vector2(4, 7),  # Rey blanco
	]
	
	for cell in test_cells:
		var expected_x = board_center.x - (4 * cell_size) + (cell.x * cell_size) + (cell_size / 2)
		var expected_y = board_center.y - (4 * cell_size) + (cell.y * cell_size) + (cell_size / 2)
		
		print("Celda ", cell, " debería estar en: (", expected_x, ", ", expected_y, ")")
	
	# Verificar piezas reales
	for piece in pieces_container.get_children():
		var cell = _world_to_board_coord(piece.global_position)
		print(piece.piece_color, " ", piece.piece_type, " en celda: ", cell)
	
	print("================================\n")

func debug_canvas_layer():
	print("=== DEBUG CANVASLAYER ===")
	
	var canvas_layer = get_node_or_null("/root/Main/CanvasLayer")
	if canvas_layer:
		print("CanvasLayer encontrado")
		print("  Posición: ", canvas_layer.position)
		print("  Tamaño: ", canvas_layer.size)
		print("  Hijos: ", canvas_layer.get_child_count())
		
		for child in canvas_layer.get_children():
			print("  - ", child.name, " (", child.get_class(), ")")
	else:
		print("ERROR: CanvasLayer no encontrado")
	
	print("========================")
 
func debug_block_system():
	print("=== DEBUG BLOCK SYSTEM ===")
	
	# Verificar BlockSystem
	if not BlockSystem:
		print("ERROR: BlockSystem is null")
		return
	
	print("BlockSystem loaded successfully")
	
	# Verificar métodos
	var methods = ["get_block_info", "get_piece_ram_capacity", "calculate_ram_usage"]
	for method in methods:
		if BlockSystem.has_method(method):
			print("✓ ", method, " exists")
		else:
			print("✗ ", method, " missing")
	
	var test_blocks = [
	# --- MOVIMIENTOS SIMPLES ---
	{"name": "Avanzar", "ram_cost": 2, "category": "movement", "type": "move_forward"},
	{"name": "Retroceder", "ram_cost": 2, "category": "movement", "type": "move_back"},
	{"name": "Paso Lateral", "ram_cost": 3, "category": "movement", "type": "move_side"},
	
	# --- ACCIONES ---
	{"name": "Capturar", "ram_cost": 4, "category": "action", "type": "capture"},
	
	# --- LÓGICA / SENSORES ---
	{"name": "Si Enemigo Al Frente", "ram_cost": 3, "category": "logic", "type": "if_enemy_front"},
	{"name": "Si Casilla Libre", "ram_cost": 2, "category": "logic", "type": "if_cell_empty"}
]
	
	print("=== END DEBUG ===")

func save_piece_program(piece: Node, blocks_array: Array) -> void:
	if not piece or not is_instance_valid(piece): return

	var piece_id = piece.piece_id
	saved_programs[piece_id] = blocks_array.duplicate(true)
	
	# Sincronización idéntica de scripts de comportamiento
	piece.behavior_script = saved_programs[piece_id].duplicate(true)
	
	piece.is_programmed = true 
	print("Programa inyectado en la pieza: ", piece_id, " Bloques: ", piece.behavior_script.size())


# Recupera el programa guardado para una pieza específica
func get_piece_program(piece_id: String) -> Array:
	if saved_programs.has(piece_id):
		# Devolvemos una copia para que la UI trabaje sobre ella sin alterar el original
		return saved_programs[piece_id].duplicate(true)
	
	return [] # Retorna array vacío si no hay nada guardado

func _logic_move_forward(piece: Node):
	var forward = -1 if piece.piece_color == "white" else 1
	var target = Vector2i(piece.board_position) + Vector2i(0, forward)
	
	if is_valid_move(piece, target):
		# Forzamos await aquí para que respete el flujo del turno
		await move_piece_to(piece, Vector2(target)) 
	else:
		print("Movimiento adelante bloqueado para ", piece.piece_id)

func _logic_move_back(piece: Node):
	var direction = 1 if piece.piece_color == "white" else -1
	var target = Vector2i(piece.board_position) + Vector2i(0, direction)
	
	if is_valid_move(piece, target):
		await move_piece_to(piece, Vector2(target))

func _logic_capture(piece: Node):
	attempt_capture(piece, "front")

#Cambio de turno

# Esta función coordina a TODAS las piezas
func execute_turn_and_switch():
	if execution_phase: return
	
	# 1. Buscamos piezas únicas programadas
	var pieces_to_run = []
	var processed_ids = {} # Para evitar duplicados en el array
	
	for piece in pieces_container.get_children():
		var pid = piece.get_instance_id()
		if piece.piece_color == current_turn and piece.is_programmed and not processed_ids.has(pid):
			pieces_to_run.append(piece)
			processed_ids[pid] = true
	
	if pieces_to_run.is_empty():
		return
	
	execution_phase = true 
	print("--- INICIANDO EJECUCIÓN DE TURNO ---")

	for piece in pieces_to_run:
		# IMPORTANTE: Desmarcamos la pieza ANTES de ejecutar para evitar re-entradas
		piece.is_programmed = false 
		
		await execute_piece_program(piece)
		await get_tree().create_timer(0.2).timeout

	execution_phase = false
	print("--- TURNO FINALIZADO ---")
	
	# 2. LIMPIEZA TOTAL: Por seguridad, limpiamos cualquier flag restante
	for piece in pieces_container.get_children():
		if piece.piece_color == current_turn:
			piece.is_programmed = false

	end_turn()

func execute_piece_program(piece: Node):
	print("--- Ejecutando programa de: ", piece.piece_id)
	
	piece.reset_execution() 
	
	for i in range(piece.behavior_script.size()):
		var current_block = piece.behavior_script[i]
		print("  Instrucción ", i, ": ", current_block.get("type", "unknown"))
		
		# --- CORRECCIÓN: Forzamos el await para que termine la ejecución física del bloque ---
		var result = await piece.execute_next_command()
		
		# Mantener el margen de seguridad para que el Tween de 0.3s termine de asentarse
		await get_tree().create_timer(0.4).timeout
		
		if result is Dictionary and result.get("stop_execution", false):
			print("Programa interrumpido por solicitud de la pieza.")
			break

func get_piece_at(board_coord: Vector2i, use_virtual := true) -> Node:
	for piece in pieces_container.get_children():
		var pos := Vector2i(
			piece.virtual_board_position
			if use_virtual
			else piece.board_position
		)
		if pos == board_coord:
			return piece
	return null

func _logic_if_cell_empty(piece: Node) -> Dictionary:
	var forward = -1 if piece.piece_color == "white" else 1
	var target = Vector2i(piece.board_position) + Vector2i(0, forward)
	
	var obstacle = get_piece_at(target)
	if obstacle == null:
		print("Sensor: Casilla ", target, " libre. Continuando ejecución.")
		return {"stop_execution": false}
	else:
		print("Sensor: Casilla ", target, " ocupada por ", obstacle.piece_id, ". Abortando secuencia.")
		return {"stop_execution": true}

#Victoria

func check_victory_conditions():
	if game_over:
		return
	var white_king_exists := false
	var black_king_exists := false
	for piece in pieces_container.get_children():
		if piece.piece_type == "king":
			if piece.piece_color == "white":
				white_king_exists = true
			elif piece.piece_color == "black":
				black_king_exists = true
	# =========================
	# RESULTADOS
	# =========================
	if not white_king_exists:
		end_game("black")
	elif not black_king_exists:
		end_game("white")

func end_game(winning_color: String):
	if game_over:
		return
	game_over = true
	winner = winning_color
	print("======================")
	print("GAME OVER")
	print("Winner: ", winning_color)
	print("======================")
	current_turn = "none"
	if execution_timer:
		execution_timer.stop()
	for piece in pieces_container.get_children():
		if piece.has_node("Area2D"):
			var area = piece.get_node("Area2D")
			area.input_pickable = false
			area.monitoring = false
	# =========================
	# CREAR UI GAME OVER
	# =========================
	var game_over_ui = GameOverScreenScene.instantiate()
	var canvas_layer = get_node("/root/Main/CanvasLayer")
	canvas_layer.add_child(game_over_ui)
	game_over_ui.setup(winning_color)
