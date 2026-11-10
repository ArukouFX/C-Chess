extends Node

# References
@onready var pieces_container = $"../Pieces"
@onready var board = $"../Table/Board"
@onready var turn_display = $"../Turn/TurnDisplay"

var game_over := false
var winner := ""

# Contador de turnos
var current_turn_count: int = 1

# Diccionario global para guardar programas
var saved_programs = {}

var current_programming_interface: Node = null
var current_turn: String = "white"
var execution_phase: bool = false

# Nodo opcional (por ejemplo ChallengeManager) con un metodo on_turn_end(color).
# Se llama una vez al terminar la ejecucion de un bando, y el turno no avanza
# hasta que termina.
var turn_end_handler: Node = null

# Precarga de escenas y texturas
var GameOverScreenScene = preload("res://src/ui/menus/game_over_screen.tscn")
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

signal piece_programmed(piece, script)
signal piece_captured(attacker, victim)
signal piece_execution_finished(piece)

func _ready():
	#Verificar configuración global
	if GlobalConfig:
		if GlobalConfig.bot_disabled:
			print("GameManager: Modo multijugador - Bot desactivado")
		else:
			print("GameManager: Modo normal - Bot activado")
	_initialize_game()
	call_deferred("_connect_piece_signals")
	$"../Buttons/VBoxContainer/Back".pressed.connect(_on_back_pressed)
	$"../Buttons/VBoxContainer/Exit".pressed.connect(_on_exit_pressed)

func _initialize_game():
	print("=== INICIALIZANDO JUEGO ===")
	
	if GlobalConfig:
		if GlobalConfig.bot_disabled:
			print("GameManager: Modo multijugador - Bot desactivado")
	
	if GlobalConfig and GlobalConfig.load_save:
		if SaveManager.has_save():
			print("GameManager: Cargando partida guardada...")
			var loaded: bool = await load_saved_game()
			GlobalConfig.load_save = false  # Resetear bandera
			if loaded:
				return
			print("GameManager: El guardado no era valido, se inicia un juego nuevo")
		else:
			print("GameManager: No hay save para cargar")
	
	print("GameManager: Iniciando juego nuevo")
	# Una partida nueva no hereda loops ni escapes de otra partida, del
	# tutorial o de un desafio (block_definitions vive toda la sesion)
	BlockSystem.clear_custom_blocks()
	spawn_pawns()
	spawn_main_pieces()
	update_turn_display()
	
	await get_tree().process_frame
	_connect_piece_signals()
	start_programming_phase()

#Control de fase-----

func end_turn():
	print("=== FIN DEL TURNO ===")
 
	for piece in pieces_container.get_children():
		if piece.get_meta("is_dead", false) == true:
			print("Liberando memoria de: ", piece.piece_id)
			piece.queue_free()
 
	execution_phase = false
 
	if game_over:
		return
 
	switch_turn()
 
	await get_tree().create_timer(1.0).timeout
 
	if game_over:
		return
 
	if current_turn == "black" and GlobalConfig and GlobalConfig.bot_disabled:
		print("[GameManager]: Modo multijugador - Turno del jugador negro")
		start_programming_phase()
		return
 
	if current_turn == "black":
		await _run_bot_turn()
		return

	start_programming_phase()

func _is_bot_turn() -> bool:
	return current_turn == "black" and not (GlobalConfig and GlobalConfig.bot_disabled)

# Turno completo de la IA. Se usa al terminar el turno blanco y al cargar una
# partida que se guardo mientras jugaba el bot.
func _run_bot_turn() -> void:
	print("[GameManager]: Es el turno de la IA (Negro). Solicitando jugada...")
	# Las piezas negras no se pueden programar mientras decide el bot
	_update_pieces_input_state()
	var bot_jugo = await BotSystem.procesar_turno_ia(self)
	if game_over:
		return
	if bot_jugo:
		await get_tree().process_frame
		await execute_turn_and_switch()
	else:
		print("[GameManager]: La IA no pudo jugar. Forzando devolución de turno al humano.")
		switch_turn()
		start_programming_phase()


func _cambiar_bando_y_avanzar():
	if game_over:
		return

	var bando_que_jugo = current_turn
	await end_turn()   # <-- await agregado: CLAVE del fix

	if game_over:
		return

	# Bookkeeping únicamente. end_turn() ya se encargó de TODO:
	# cambiar turno, invocar al bot si correspondía, y arrancar
	# la fase de programación correcta. NO se vuelve a invocar
	# al bot acá — por eso ya no existe el bloque `else`.
	# Una ronda termina cuando juegan las negras, sea el bot o un jugador humano
	if bando_que_jugo == "black":
		current_turn_count += 1
		print("\n=======================================================")
		print("=== RONDA COMPLETA. Iniciando Turno Global N°: ", current_turn_count, " ===")
		print("=======================================================\n")


func execute_turn_and_switch():
	if execution_phase: return
 
	var pieces_to_run  = []
	var processed_ids  = {}
 
	for piece in pieces_container.get_children():
		var pid = piece.get_instance_id()
		if piece.piece_color == current_turn and piece.is_programmed and not processed_ids.has(pid):
			pieces_to_run.append(piece)
			processed_ids[pid] = true
 
	if pieces_to_run.is_empty():
		await _cambiar_bando_y_avanzar()   # <-- await agregado
		return
 
	execution_phase = true
	print("--- INICIANDO EJECUCIÓN DE TURNO: ", current_turn.to_upper(), " ---")
 
	for piece in pieces_to_run:
		if game_over:
			break
 
		piece.is_programmed = false
		await execute_piece_program(piece)
		emit_signal("piece_execution_finished", piece)
		await get_tree().create_timer(0.2).timeout

	print("--- EJECUCIÓN DE MOVIMIENTOS FINALIZADA ---")

	# El hook corre con execution_phase todavia en true, para que nada pueda
	# reiniciar o ejecutar otro turno mientras se mueve el enemigo guionado.
	if turn_end_handler and is_instance_valid(turn_end_handler) and turn_end_handler.has_method("on_turn_end"):
		await turn_end_handler.on_turn_end(current_turn)

	execution_phase = false
 
	for piece in pieces_container.get_children():
		if piece.piece_color == current_turn:
			piece.is_programmed = false
 
	await _cambiar_bando_y_avanzar()   # <-- await agregado

#--------------------

#modificado con sistema actual
func spawn_piece(type: String, board_coord: Vector2):
	var piece = PieceScene.instantiate()
	var color = type.split("_")[0]
	var piece_type = type.split("_")[1]
	
	# Un solo ID consistente basado en su posición inicial
	var unique_id = "%s_%d_%d" % [type, int(board_coord.x), int(board_coord.y)]
	piece.piece_id = unique_id
	
	piece.setup_piece(piece_textures[type], color, piece_type, board_coord)
	piece.fit_to_cell(board.cell_size)
	
	# === FIX CRÍTICO: asegurar sincronización inicial ===
	piece.board_position = board_coord
	piece.virtual_board_position = board_coord
	# =====================================================
	
	# Cargar programa desde el diccionario global si ya existe
	if saved_programs.has(unique_id):
		piece.behavior_script = saved_programs[unique_id].duplicate(true)
		piece.is_programmed = true
		print("Programa inyectado en ", unique_id, " desde el spawn (saved_programs).")
	
	# Conexión de señales
	piece.selected.connect(_on_piece_selected)
	
	# Posicionamiento y árbol
	var world_position = _board_to_world_position(board_coord)
	piece.position = world_position
	pieces_container.add_child(piece)
	
	
	return piece

# Celda del tablero -> valor para piece.position (local al contenedor Pieces).
# Pasa por coordenadas globales, asi que funciona aunque Table y Pieces tengan
# desplazamientos distintos. Supone que Pieces no tiene escala: el pulso se
# aplica a cada pieza sobre su propio centro (ver pieces.gd).
func _board_to_world_position(board_coord: Vector2) -> Vector2:
	return board.cell_to_global(board_coord) - pieces_container.global_position

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

# === Movement Manager ===

# Inversa de _board_to_world_position: recibe una posicion local al
# contenedor Pieces y busca la pieza viva de esa casilla. Para codigo nuevo es
# preferible llamar directo a get_piece_at con la coordenada de tablero.
func get_piece_at_position(position: Vector2, exclude_piece: Node = null) -> Node:
	var cell: Vector2i = board.global_to_cell(position + pieces_container.global_position)
	return get_piece_at(cell, true, exclude_piece)

func capture_piece(piece_to_capture, attacker: Node = null):
	if piece_to_capture.defense_protocol_active:
		print("DEFENSE PROTOCOL ACTIVATED:", piece_to_capture.piece_id)
		await execute_defense_protocol(piece_to_capture, attacker)
		return
 
	var captured_type  = piece_to_capture.piece_type
	var captured_color = piece_to_capture.piece_color
 
	piece_to_capture.board_position         = Vector2(-999, -999)
	piece_to_capture.virtual_board_position = Vector2(-999, -999)
	piece_to_capture.visible = false
 
	if piece_to_capture.has_node("Area2D"):
		piece_to_capture.get_node("Area2D").input_pickable = false
		piece_to_capture.get_node("Area2D").monitoring     = false
 
	piece_to_capture.set_meta("is_dead", true)
 
	print("Pieza marcada para eliminación: ", captured_color, " ", captured_type,
		  ", id:", piece_to_capture.piece_id)
 
	emit_signal("piece_captured", attacker, piece_to_capture) 
	# Esperamos el frame para que el árbol de escena esté estable
	await get_tree().process_frame
 
	# Verificar victoria INMEDIATAMENTE después de marcar la pieza
	check_victory_conditions()

# Pieza resaltada mientras se programa
var selected_piece: Node = null
# Cada apertura tiene un numero; si llega otra antes de terminar, la vieja se descarta
var _interface_request: int = 0

func _set_selected_piece(piece: Node) -> void:
	if selected_piece and is_instance_valid(selected_piece):
		selected_piece.set_selected(false)
	selected_piece = piece
	if piece and is_instance_valid(piece):
		piece.set_selected(true)

func open_programming_interface_for_piece(piece: Node, _mouse_pos: Vector2):
	_interface_request += 1
	var request := _interface_request

	if current_programming_interface and is_instance_valid(current_programming_interface):
		current_programming_interface.queue_free()
	current_programming_interface = null
	_set_selected_piece(piece)

	var new_interface = ProgrammingInterfaceScene.instantiate()
	# Transparente hasta estar ubicada: setup_for_piece la hace visible y
	# durante unos frames estaria en su posicion por defecto (el centro)
	new_interface.modulate.a = 0.0
	var ui_layer = get_node_or_null("../SetProgramming")
	if ui_layer:
		ui_layer.add_child(new_interface)
	else:
		add_child(new_interface)
	await get_tree().process_frame
	await new_interface.setup_for_piece(piece, self)
	new_interface.update_ram_display()

	# Esperar a que el layout termine de calcular el tamano
	var last_size = Vector2.ZERO
	for i in range(10):
		await get_tree().process_frame
		if new_interface.size == last_size:
			break
		last_size = new_interface.size

	# Mientras se armaba, el jugador abrio otra pieza (o cerro esta)
	if request != _interface_request or not is_instance_valid(new_interface):
		if is_instance_valid(new_interface):
			new_interface.queue_free()
		return

	current_programming_interface = new_interface
	_position_interface_smartly(new_interface)
	new_interface.create_tween().tween_property(new_interface, "modulate:a", 1.0, 0.12)

# Rectangulo que realmente se ve de la interfaz, en coordenadas de pantalla.
# No se usa el rect del nodo UI: esta anclado a lo ancho con offsets y mide
# mucho mas que su contenido. Se toma la union de los paneles de MainContainer
# y se suma la transformacion del CanvasLayer (su offset, si tiene).
func get_interface_visible_rect(interface: Control) -> Rect2:
	var container: Node = interface.get_node_or_null("UI/MainContainer")
	var rect := Rect2()
	var first := true
	if container:
		for child in container.get_children():
			if child is Control and child.visible:
				var r: Rect2 = child.get_global_rect()
				rect = r if first else rect.merge(r)
				first = false
	if first:
		rect = interface.get_global_rect()
	var layer: CanvasLayer = interface.get_canvas_layer_node()
	if layer:
		rect.position = layer.get_final_transform() * rect.position
	return rect

# Centra la interfaz en el espacio libre a la derecha del tablero. Funciona con
# cualquier offset en el CanvasLayer SetProgramming (incluido 0).
const INTERFACE_OFFSET := Vector2(0, 30)
func _position_interface_smartly(interface: Control):
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var margin := 10.0

	# Borde derecho del tablero en coordenadas de pantalla (incluye la camara)
	var board_right_world: Vector2 = board.cell_to_global(Vector2(7, 0)) + Vector2(board.cell_size / 2.0, 0)
	var board_right: float = (get_viewport().get_canvas_transform() * board_right_world).x
	var panel := Rect2(board_right + margin, margin, screen.x - board_right - 2.0 * margin, screen.y - 2.0 * margin)

	var rect: Rect2 = get_interface_visible_rect(interface)
	var target: Vector2 = panel.position + (panel.size - rect.size) / 2.0 + INTERFACE_OFFSET
	# Si no entra en el panel se corre a la izquierda lo justo, sin salir de pantalla
	target.x = max(margin, min(max(target.x, panel.position.x), screen.x - rect.size.x - margin))
	target.y = max(margin, min(target.y, screen.y - rect.size.y - margin))

	# El desplazamiento es el mismo en pantalla y dentro del CanvasLayer
	interface.position += target - rect.position

func _on_piece_selected(piece):
	# Segunda barrera por si el Area2D quedo habilitado: las piezas bloqueadas
	# no se programan y no se abre la interfaz durante una ejecucion.
	if piece.get_meta("locked", false) or execution_phase:
		return
	open_programming_interface_for_piece(piece, piece.global_position)

# === SISTEMA DE TURNOS ===
func switch_turn():
	if GlobalConfig and (GlobalConfig.tutorial_mode or GlobalConfig.challenge_mode):
		current_turn = "white"
	else:
		current_turn = "black" if current_turn == "white" else "white"
	print("Turn changed to: ", current_turn)
	update_turn_display()
	_update_pieces_input_state()

func _update_pieces_input_state():
	for piece in pieces_container.get_children():
		_apply_input_state(piece)

# Habilita la seleccion solo para piezas del turno actual que no esten
# bloqueadas. Las piezas bloqueadas (meta "locked", usada en desafios) se ven
# normales pero no se pueden programar.
func _apply_input_state(piece: Node) -> void:
	if not piece.has_node("Area2D"):
		return
	var area2d = piece.get_node("Area2D")
	var is_own_turn: bool = piece.piece_color == current_turn
	var is_locked: bool = piece.get_meta("locked", false)
	# Las piezas del bot nunca las programa el jugador
	var can_program: bool = is_own_turn and not is_locked and not _is_bot_turn()

	area2d.input_pickable = can_program
	area2d.monitoring = can_program
	if is_own_turn:
		piece.modulate = Color.WHITE
	else:
		piece.modulate = Color(0.5, 0.5, 0.5, 0.7)

func update_turn_display():
	if turn_display and turn_display.has_method("update_turn"):
		turn_display.update_turn(current_turn)

# --- Vista previa del recorrido ---
# Mientras se arma un programa, el tablero muestra las casillas que va a
# recorrer la pieza (ver ProgramPreview y PathPreview).
var path_preview: PathPreview = null

func show_program_preview(piece: Node, blocks: Array) -> void:
	if not piece or not is_instance_valid(piece) or blocks.is_empty():
		clear_program_preview()
		return
	if path_preview == null or not is_instance_valid(path_preview):
		path_preview = PathPreview.new()
		path_preview.name = "PathPreview"
		board.add_child(path_preview)
	path_preview.show_result(ProgramPreview.simulate(piece, blocks, self), board.cell_size)

func clear_program_preview() -> void:
	if path_preview and is_instance_valid(path_preview):
		path_preview.clear()

# Close manager
func _on_programming_interface_closed():
	current_programming_interface = null
	clear_program_preview()
	# Una apertura en curso ya no corresponde
	_interface_request += 1
	_set_selected_piece(null)
	_update_pieces_input_state()

func _connect_piece_signals():
	print("Connecting piece signals...")
	var connected_count = 0
	for piece in pieces_container.get_children():
		if piece.has_signal("selected"):
			if not piece.selected.is_connected(_on_piece_selected):
				piece.selected.connect(_on_piece_selected)
				connected_count += 1
				print("Connected selected to: ", piece.piece_type)
		# Configurar estado inicial del Área2D
		_apply_input_state(piece)

	print("Connected to ", connected_count, " pieces")
	print("Input configured for current turn: ", current_turn)

# NUEVO SISTEMA DE PROGRAMACIÓN POR BLOQUES


func start_programming_phase():
	print("=== FASE DE PROGRAMACIÓN ===")
	print("Turno: ", current_turn)
	execution_phase = false

	# Habilitar/deshabilitar la detección de input por Área2D
	_update_pieces_input_state()

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

# Guarda lo que el jugador armo en la interfaz. Formato unico de programa: una
# lista de {"type": id}; loops y escapes se resuelven desde BlockSystem.
#
# Es el unico lugar donde se instala el escape de una pieza programada por el
# jugador, y lo deja activo ANTES de emitir piece_programmed: quien escuche la
# senal (por ejemplo el tutorial) ve la pieza ya protegida.
func save_piece_program(piece: Node, blocks_array: Array) -> void:
	if not piece or not is_instance_valid(piece):
		return
	var behavior_blocks := []
	var escape_id := ""
	for block in blocks_array:
		var block_type: String = block.get("type", "") if block is Dictionary else ""
		if block_type == "":
			continue
		if BlockSystem.get_block_info(block_type).get("category", "") == "action":
			escape_id = block_type  # si hubiera varios, vale el ultimo
		else:
			behavior_blocks.append({"type": block_type})

	piece.behavior_script = behavior_blocks
	saved_programs[piece.piece_id] = behavior_blocks.duplicate(true)

	if escape_id != "":
		piece.defense_protocol = {"type": escape_id}
		piece.defense_protocol_id = escape_id
		piece.defense_protocol_active = true
		piece.defense_protocol_owner_turn = piece.piece_color
		# Los escapes que instala el jugador son de un solo uso
		piece.defense_protocol_permanent = false
	elif not piece.defense_protocol_permanent:
		# El jugador quito el escape del programa
		piece.clear_defense_protocol()

	piece.is_programmed = not behavior_blocks.is_empty() or piece.defense_protocol_active
	emit_signal("piece_programmed", piece, behavior_blocks)
	print("Programa guardado: ", piece.piece_id, " Movimientos:", behavior_blocks.size(), " Escape:", escape_id)

# Programa que se muestra al volver a abrir la interfaz de una pieza: sus
# movimientos guardados y, al final, el escape si sigue instalado
func get_program_for_interface(piece: Node) -> Array:
	var program := get_piece_program(piece.piece_id)
	if piece.defense_protocol_active and not piece.defense_protocol_permanent:
		var escape_id: String = piece.defense_protocol_id
		if escape_id != "" and not BlockSystem.get_block_info(escape_id).is_empty():
			program.append({"type": escape_id})
	return program

# Recupera el programa guardado para una pieza específica
func get_piece_program(piece_id: String) -> Array:
	if saved_programs.has(piece_id):
		var program = saved_programs[piece_id]
		# Asegurarse de que sea un Array
		if program is Array:
			return program.duplicate(true)
		elif program is Dictionary and program.has("behavior"):
			return program["behavior"].duplicate(true)
	return []

# Elimina toda referencia a un bloque borrado
func purge_block_references(block_id: String) -> void:
	for pid in saved_programs.keys():
		var program = saved_programs[pid]
		if program is Array:
			saved_programs[pid] = _filter_block_list(program, block_id)

	for piece in pieces_container.get_children():
		if not piece.has_method("is_valid_piece"):
			continue
		var was_programmed: bool = piece.is_programmed
		piece.behavior_script = _filter_block_list(piece.behavior_script, block_id)

		var proto_type = piece.defense_protocol.get("type", "") if piece.defense_protocol is Dictionary else ""
		if proto_type == block_id or piece.defense_protocol_id == block_id:
			piece.clear_defense_protocol()

		# nunca se activa una pieza que ya habia ejecutado su turno
		if was_programmed and piece.behavior_script.is_empty() and piece.defense_protocol == null:
			piece.is_programmed = false

	print("[GameManager] Referencias a ", block_id, " eliminadas.")

func _filter_block_list(blocks: Array, block_id: String) -> Array:
	var result := []
	for b in blocks:
		if b is Dictionary and b.get("type", "") == block_id:
			continue
		result.append(b)
	return result

func execute_piece_program(piece: Node):
	print("--- Ejecutando programa de: ", piece.piece_id)
	piece.reset_execution()

	# Congelamos una copia
	var script_snapshot = piece.behavior_script.duplicate(true)
	for i in range(script_snapshot.size()):
		if not is_instance_valid(piece) or piece.get_meta("is_dead", false):
			print("Pieza inválida o muerta durante ejecución, abortando programa.")
			break
		var current_block = script_snapshot[i]
		if current_block == null or not current_block is Dictionary:
			push_warning("Bloque inválido en índice " + str(i) + " de " + piece.piece_id)
			continue
		var block_type = current_block.get("type", "")
		var info = BlockSystem.get_block_info(block_type)
		if info.get("category") == "action":
			continue
		print("  Instrucción ", i, ": ", block_type)
		# Ambos colores usan el mismo motor (BlockSystem.move_generic), que
		# orienta el vector segun el color, resuelve loops y mantiene
		# sincronizadas board_position y virtual_board_position.
		var result = await piece.execute_next_command()
		await get_tree().create_timer(0.4).timeout
		if not result is Dictionary or result.get("stop_execution", false):
			print("Programa interrumpido por solicitud de la pieza.")
			break
	# Un caballo no puede terminar sobre un aliado
	await BlockSystem.resolve_phase_end(piece)

func get_piece_at(board_coord: Vector2i, use_virtual := true, exclude_piece: Node = null) -> Node:
	for piece in pieces_container.get_children():
		# Ignorar piezas muertas
		if piece.get_meta("is_dead", false):
			continue
		
		# Ignorar la pieza que se está moviendo
		if piece == exclude_piece:
			continue
		
		# FIX: validar que sea una pieza válida
		if not piece.has_method("is_valid_piece") or not piece.is_valid_piece():
			continue
		
		# Primero intentar con virtual_board_position
		var pos := Vector2i(piece.virtual_board_position)
		if pos == board_coord:
			return piece
		
		# Fallback: si no coincide, probar con board_position (fuente de verdad)
		if piece.get("board_position") is Vector2:
			pos = Vector2i(piece.board_position)
			if pos == board_coord:
				# Silenciosamente sincronizamos para arreglar el desfase
				piece.sync_positions()
				return piece
	
	return null

#Victoria
func check_victory_conditions():
	if game_over:
		return
	if GlobalConfig and (GlobalConfig.tutorial_mode or GlobalConfig.challenge_mode):
		return
	
	var white_king_alive := false
	var black_king_alive  := false
 
	for piece in pieces_container.get_children():
		if piece.get_meta("is_dead", false):
			continue
		if piece.piece_type == "king":
			if piece.piece_color == "white":
				white_king_alive = true
			elif piece.piece_color == "black":
				black_king_alive = true
 
	if not white_king_alive:
		# Setear ANTES de end_game para que cualquier código que corra
		# después del await lo vea inmediatamente
		game_over = true
		end_game("black")
	elif not black_king_alive:
		game_over = true
		end_game("white")

func end_game(winning_color: String):
	if game_over and winner != "":
		return  # Ya procesado
	game_over = true
	winner = winning_color
	
	print("======================")
	print("GAME OVER")
	print("Winner: ", winning_color)
	print("======================")
	
	current_turn = "none"

	# Una partida terminada no se puede continuar
	if not _is_practice_mode():
		SaveManager.delete_save()

	
	for piece in pieces_container.get_children():
		if piece.has_node("Area2D"):
			piece.get_node("Area2D").input_pickable = false
			piece.get_node("Area2D").monitoring = false
	
	# Buscar CanvasLayer de forma robusta
	var canvas_layer = get_node_or_null("/root/Main/CanvasLayer2")
	if not canvas_layer:
		# Buscar en toda la escena
		canvas_layer = get_tree().root.find_child("CanvasLayer", true, false)
	if not canvas_layer:
		# Crear uno nuevo como fallback
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "CanvasLayer_GameOver"
		get_tree().root.add_child(canvas_layer)
	
	print("CanvasLayer encontrado: ", canvas_layer.get_path())
	
	var game_over_ui = GameOverScreenScene.instantiate()
	canvas_layer.add_child(game_over_ui)
	game_over_ui.setup(winning_color)
	
	print("Pantalla de Game Over instanciada.")

#Defensa
func execute_defense_protocol(piece, attacker: Node = null):
	if piece.defense_protocol == null:
		_kill_defending_piece(piece, attacker) # Si no hay protocolo, muere directo
		return
	var protocol_type = piece.defense_protocol.get("type", "")
	if protocol_type.is_empty():
		_kill_defending_piece(piece, attacker)
		return
	var protocol_data = BlockSystem.get_block_info(protocol_type)
	if protocol_data.is_empty():
		_kill_defending_piece(piece, attacker)
		return
		
	# VALIDADOR DE CASILLA DE ESCAPE
	var defense_blocks = protocol_data.get("contained_blocks", []) 
	if defense_blocks.is_empty():
		print("[DEFENSA] El protocolo de escape no contiene bloques de movimiento.")
		_kill_defending_piece(piece, attacker)
		return
		
	var move_block_type = defense_blocks[0].get("type", "")
	var move_block_info = BlockSystem.get_block_info(move_block_type)
	if move_block_info.is_empty() or not move_block_info.has("vector"):
		_kill_defending_piece(piece, attacker)
		return
		
	# 2. Calcular coordenada teórica usando la posición VIRTUAL
	var vec = Vector2i(move_block_info["vector"])
	var side_multiplier = -1 if piece.piece_color == "white" else 1
	
	var escape_target = Vector2i(
		piece.virtual_board_position.x + vec.x,
		piece.virtual_board_position.y + (vec.y * side_multiplier)
	)
	
	# 3. Comprobar límites del tablero preventivamente
	if escape_target.x < 0 or escape_target.x > 7 or escape_target.y < 0 or escape_target.y > 7:
		print("[DEFENSA] Escape fallido preventivo: Fuera del tablero (", escape_target, ").")
		_kill_defending_piece(piece, attacker)
		return
		
	# 4. Comprobar colisión preventiva en coordenadas de tablero.
	# No se usan posiciones de mundo: Table y Pieces estan desplazados y la
	# comparacion contra global_position apuntaba a otra casilla.
	var obstacle = get_piece_at(escape_target, true, piece)
	
	if obstacle != null:
		print("[DEFENSA] Escape fallido preventivo: Casilla ", escape_target, " ocupada por ", obstacle.piece_id)
		_kill_defending_piece(piece, attacker) # <-- CAMBIADO: Muere sin gatillar re-evaluación
		return
		
	# 5. Si la casilla está libre, procedemos al BlockSystem
	print("[DEFENSA] Casilla ", escape_target, " libre preventivamente. Ejecutando escape...")
	var result = await BlockSystem.execute_escape_protocol(piece, protocol_data)
	
	# 6. Validación post-ejecución. Un resultado que no es diccionario (bloque
	# inexistente dentro del escape) tambien cuenta como fallo.
	if not result is Dictionary or result.get("action") == "blocked" or result.get("stop_execution", false):
		print("[DEFENSA] El BlockSystem denegó el movimiento. Ejecutando muerte.")
		_kill_defending_piece(piece, attacker)
		return

	# 7. Escape exitoso: el protocolo es de un solo uso (salvo los permanentes
	# de los desafios)
	piece.consume_defense_protocol()
	print("[DEFENSA] Escape exitoso de ", piece.piece_id, ". Protocolo activo: ", piece.defense_protocol_active)

# Un escape fallido cuenta como captura: se emite la misma senal y se
# revisa la victoria, igual que en capture_piece. Asi la partida termina
# si el que cae es un rey.
func _kill_defending_piece(piece: Node, attacker: Node = null):
	if piece.get_meta("is_dead", false):
		return
	print("[SISTEMA] Eliminando pieza defensora ", piece.piece_id, " por escape fallido.")
	piece.board_position = Vector2(-999, -999)
	piece.virtual_board_position = Vector2(-999, -999)
	piece.visible = false
	if piece.has_node("Area2D"):
		piece.get_node("Area2D").input_pickable = false
		piece.get_node("Area2D").monitoring = false
	piece.set_meta("is_dead", true)

	emit_signal("piece_captured", attacker, piece)
	check_victory_conditions()

# -------------------------------------------------------
# 2. Handler del botón Back
# -------------------------------------------------------
func _is_practice_mode() -> bool:
	return GlobalConfig and (GlobalConfig.tutorial_mode or GlobalConfig.challenge_mode)

func _on_back_pressed():
	print("[GameManager] Back presionado — volviendo al menú.")
	_save_on_leave()
	
	# Buscar el TransitionRect en la escena
	var transition_rect = get_node_or_null("/root/Main/TransitionLayer/TransitionRect")
	if transition_rect:
		transition_rect.visible = true
		transition_rect.material.set_shader_parameter("progress", 1.0)
		var tween = create_tween()
		tween.tween_property(transition_rect.material, "shader_parameter/progress", 0.0, 0.6)
		tween.finished.connect(func():
			get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
		)
	else:
		# Si no encuentra el nodo, cambia de escena directamente
		get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")

func _on_exit_pressed():
	print("[GameManager] Exit presionado — saliendo.")

	_save_on_leave()
	get_tree().quit()

# Guardado al salir de la partida (botones Atras y Salir)
func _save_on_leave() -> void:
	# En tutorial y desafios no se guarda: pisaria la partida real del jugador
	if _is_practice_mode():
		return
	# Una partida terminada no se guarda; si quedo un archivo viejo, se borra
	if game_over:
		SaveManager.delete_save()
		return
	save_game()
 
# -------------------------------------------------------
# 3. Serializar y guardar el estado completo del juego
# -------------------------------------------------------
const SAVE_VERSION := 2

func save_game() -> void:
	if game_over or not current_turn in ["white", "black"]:
		print("[GameManager] Partida terminada o sin turno valido: no se guarda.")
		return

	var pieces_data: Array = []
	for piece in pieces_container.get_children():
		# No guardamos piezas muertas
		if piece.get_meta("is_dead", false):
			continue
		pieces_data.append({
			"piece_id":    piece.piece_id,
			"piece_type":  piece.piece_type,
			"piece_color": piece.piece_color,
			"board_x":     piece.virtual_board_position.x,
			"board_y":     piece.virtual_board_position.y,
		})

	var save_data := {
		"version":            SAVE_VERSION,
		"current_turn":       current_turn,
		"current_turn_count": current_turn_count,
		# Modo de juego: al cargar se respeta, asi una partida multijugador
		# no se retoma contra el bot
		"bot_disabled":       GlobalConfig.bot_disabled if GlobalConfig else false,
		"pieces":             pieces_data,
		# Loops y escapes creados por los jugadores (no los programas de las piezas)
		"custom_blocks":      BlockSystem.export_custom_blocks(),
	}
	SaveManager.save_game(save_data)

# Revisa el archivo antes de tocar el tablero. Devuelve "" si es valido o el
# motivo por el que no se puede cargar.
func _validate_save(data: Dictionary) -> String:
	if data.get("game_over", false):
		return "la partida ya habia terminado"
	if not data.get("current_turn", "") in ["white", "black"]:
		return "turno invalido (%s)" % str(data.get("current_turn"))

	var pieces = data.get("pieces", [])
	if not pieces is Array or pieces.is_empty():
		return "no hay piezas"

	var kings := {"white": false, "black": false}
	for p in pieces:
		if not p is Dictionary:
			return "pieza con formato invalido"
		for key in ["piece_id", "piece_type", "piece_color", "board_x", "board_y"]:
			if not p.has(key):
				return "a una pieza le falta el campo " + key
		if not piece_textures.has(str(p["piece_color"]) + "_" + str(p["piece_type"])):
			return "tipo de pieza desconocido: %s %s" % [p["piece_color"], p["piece_type"]]
		var x := int(p["board_x"])
		var y := int(p["board_y"])
		if x < 0 or x > 7 or y < 0 or y > 7:
			return "pieza fuera del tablero: %s" % p["piece_id"]
		if p["piece_type"] == "king" and kings.has(p["piece_color"]):
			kings[p["piece_color"]] = true

	if not kings["white"] or not kings["black"]:
		return "falta un rey: la partida no puede continuar"
	return ""

# Carga el estado guardado. Si el archivo no sirve lo borra y devuelve false,
# para que _initialize_game arranque una partida nueva.
func load_saved_game() -> bool:
	var data := SaveManager.load_game()
	if data.is_empty():
		return false

	var error := _validate_save(data)
	if error != "":
		push_warning("[GameManager] Guardado descartado: " + error)
		SaveManager.delete_save()
		return false

	# Modo de juego guardado (los archivos viejos no lo tienen)
	if GlobalConfig and data.has("bot_disabled"):
		GlobalConfig.bot_disabled = bool(data["bot_disabled"])
		GlobalConfig.is_multiplayer = GlobalConfig.bot_disabled

	# Bloques personalizados antes de crear piezas e interfaces
	if data.has("custom_blocks") and data["custom_blocks"] is Dictionary:
		BlockSystem.import_custom_blocks(data["custom_blocks"])
		BotSystem.reset_escape_cache()

	current_turn       = data["current_turn"]
	current_turn_count = int(data.get("current_turn_count", 1))
	game_over          = false
	winner             = ""

	# Limpiar piezas actuales
	for child in pieces_container.get_children():
		child.queue_free()
	await get_tree().process_frame

	for piece_data in data["pieces"]:
		var type  = str(piece_data["piece_color"]) + "_" + str(piece_data["piece_type"])
		var coord = Vector2(int(piece_data["board_x"]), int(piece_data["board_y"]))
		var piece = spawn_piece(type, coord)
		piece.piece_id = str(piece_data["piece_id"])

	update_turn_display()
	_connect_piece_signals()
	print("[GameManager] Partida restaurada. Turno: ", current_turn)

	# Si se guardo durante el turno del bot, el bot retoma su jugada
	if _is_bot_turn():
		# Diferido: la escena termina de inicializarse antes de que juegue el bot
		_run_bot_turn.call_deferred()
	else:
		start_programming_phase()
	return true
