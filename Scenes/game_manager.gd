extends Node

# References
@onready var pieces_container = $"../Pieces"
@onready var board = $"../Table/Board"
@onready var turn_display = $"../Turn/TurnDisplay"
@onready var camera = $"../Camera/Camera2D"

var current_programming_interface: Control = null
var current_turn: String = "white"
var is_opening_interface: bool = false

# Pre-cgarge
var PieceScene = preload("res://Scenes/piece.tscn")
var ProgrammingInterfaceScene = preload("res://Scenes/programming_interface.tscn")
var piece_textures = {
	# White pieces
	"white_pawn": preload("res://Assets/white/white-pawn.png"),
	"white_bishop": preload("res://Assets/white/white-bishop.png"),
	"white_horse": preload("res://Assets/white/white-horse.png"),
	"white_tower": preload("res://Assets/white/white-tower.png"),
	"white_queen": preload("res://Assets/white/white-queen.png"),
	"white_king": preload("res://Assets/white/white-king.png"),
	# Black pieces
	"black_pawn": preload("res://Assets/black/black-pawn.png"),
	"black_bishop": preload("res://Assets/black/black-bishop.png"),
	"black_horse": preload("res://Assets/black/black-horse.png"),
	"black_tower": preload("res://Assets/black/black-tower.png"),
	"black_queen": preload("res://Assets/black/black-queen.png"),
	"black_king": preload("res://Assets/black/black-king.png"),
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
func spawn_piece(type: String, board_coord: Vector2):
	var piece = PieceScene.instantiate()
	var color = type.split("_")[0]
	var piece_type = type.split("_")[1]
	
	piece.setup_piece(piece_textures[type], color, piece_type)
	piece.connect("released", _on_piece_released)
	
	# Connect to click
	if piece.has_signal("right_clicked"):
		piece.right_clicked.connect(_on_piece_right_clicked)
		print("Connected right_clicked signal to: ", type)
	else:
		print("No right_clicked signal in new piece: ", type)

	var world_position = _board_to_world_position(board_coord)
	piece.position = world_position
	
	pieces_container.add_child(piece)
	return piece

func _board_to_world_position(board_coord: Vector2) -> Vector2:
	var origin = board.get_board_origin()
	var cell_size = board.cell_size
	return origin + Vector2(
		(board_coord.x + 0.5) * cell_size,
		(board_coord.y + 0.5) * cell_size
	)

func spawn_pawns():
	for i in range(8):
		spawn_piece("white_pawn", Vector2(i, 6))
		spawn_piece("black_pawn", Vector2(i, 1))

func spawn_main_pieces():
	var white_order = ["white_tower", "white_horse", "white_bishop", "white_queen", "white_king", "white_bishop", "white_horse", "white_tower"]
	var black_order = ["black_tower", "black_horse", "black_bishop", "black_queen", "black_king", "black_bishop", "black_horse", "black_tower"]
	
	for i in range(8):
		spawn_piece(white_order[i], Vector2(i, 7))
		spawn_piece(black_order[i], Vector2(i, 0))

# === Movement Manager ===
func _on_piece_released(piece, world_position):
	print("=== PIECE RELEASED ===")
	print("Piece:", piece.piece_type, " (", piece.piece_color, ")")
	print("Current turn:", current_turn)
	
	if not is_valid_turn(piece.piece_color):
		print("Not your turn! Current: ", current_turn)
		_reset_piece_position(piece)
		return
	
	if not board.is_inside_board(world_position):
		print("Outside board")
		_reset_piece_position(piece)
		return
	
	var target_cell = board.get_nearest_cell_pos(world_position)
	
	if not _is_different_cell(piece.last_valid_pos, target_cell):
		print("Same cell - no movement")
		_reset_piece_position(piece)
		return
	
	var target_piece = get_piece_at_position(target_cell, piece)
	
	if target_piece:
		if can_capture(piece.piece_color, target_piece.piece_color):
			print("Capture allowed")
			capture_piece(target_piece)
			_finalize_move(piece, target_cell)
		else:
			print("Cannot capture own pieces")
			_reset_piece_position(piece)
	else:
		print("Valid move to empty cell")
		_finalize_move(piece, target_cell)

func _reset_piece_position(piece):
	piece.global_position = piece.last_valid_pos

func _finalize_move(piece, target_position):
	piece.global_position = target_position
	piece.last_valid_pos = piece.global_position
	switch_turn()

func get_piece_at_position(position: Vector2, exclude_piece: Node = null) -> Node:
	var cell_coord = _world_to_board_coord(position)
	
	for piece in pieces_container.get_children():
		if piece == exclude_piece:
			continue
		
		var piece_cell_coord = _world_to_board_coord(piece.global_position)
		if piece_cell_coord == cell_coord:
			return piece
	
	return null

func _world_to_board_coord(world_position: Vector2) -> Vector2:
	var origin = board.get_board_origin()
	var cell_size = board.cell_size
	var local_pos = world_position - origin
	
	return Vector2(
		floor(local_pos.x / cell_size),
		floor(local_pos.y / cell_size)
	)

func _is_different_cell(pos1: Vector2, pos2: Vector2) -> bool:
	var coord1 = _world_to_board_coord(pos1)
	var coord2 = _world_to_board_coord(pos2)
	return coord1 != coord2

func can_capture(attacker_color: String, defender_color: String) -> bool:
	return attacker_color != defender_color

func capture_piece(piece_to_capture):
	print("Capturing: ", piece_to_capture.piece_type)
	piece_to_capture.queue_free()

func _input(event):
	_handle_touch_events(event)
	_handle_debug_keys(event)

func _handle_touch_events(event):
	if event is InputEventScreenTouch and not event.pressed:
		for piece in pieces_container.get_children():
			if piece.has_method("cancel_drag"):
				piece.cancel_drag()

func _handle_debug_keys(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		print_all_piece_positions()

func _find_piece_under_mouse(mouse_pos: Vector2) -> Node:
	print("IMPROVED piece detection for mouse: ", mouse_pos)
	
	var closest_piece = null
	var closest_distance = 1000000.0
	var detection_radius = 100.0  # AUMENTAR radio de detección
	
	for piece in pieces_container.get_children():
		if piece.has_method("get_programming_status"):
			var piece_pos = piece.global_position
			var distance = mouse_pos.distance_to(piece_pos)
			
			print("   - ", piece.piece_type, " at ", piece_pos, " distance: ", distance)
			
			# Save nearest piece
			if distance < closest_distance:
				closest_distance = distance
				closest_piece = piece
	
	if closest_piece and closest_distance < detection_radius:
		print("CLOSEST piece: ", closest_piece.piece_type, " distance: ", closest_distance)
		return closest_piece
	else:
		print("No piece within ", detection_radius, "px tolerance. Closest: ", 
			  closest_piece.piece_type if closest_piece else "None", 
			  " at ", closest_distance, "px")
		return null

func open_programming_interface_for_piece(piece: Node, mouse_pos: Vector2):
	print("Opening programming interface for: ", piece.piece_type)
	
	# Close interface
	if current_programming_interface and is_instance_valid(current_programming_interface):
		current_programming_interface.queue_free()
		await get_tree().process_frame
	
	# Crear nueva interfaz
	var new_interface = ProgrammingInterfaceScene.instantiate()
	get_tree().root.add_child(new_interface)
	new_interface.z_index = 1000
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	new_interface.custom_minimum_size = Vector2(600, 400)
	new_interface.size = Vector2(600, 400)
	
	_position_interface_at_camera_right(new_interface)
	
	# Setup piece information
	if new_interface.has_method("setup_for_piece"):
		new_interface.setup_for_piece(piece)
	
	current_programming_interface = new_interface
	print("Programming interface opened successfully at camera right wall")

func _center_interface_on_camera(interface: Control):
	if not camera:
		print("No camera reference, falling back to screen center")
		_center_interface_on_screen(interface)
		return
	
	# Get cam info
	var camera_center = camera.global_position
	var camera_zoom = camera.zoom
	var viewport_size = get_viewport().get_visible_rect().size
	var interface_size = interface.size
	
	print("Detailed camera info:")
	print("   - Camera position: ", camera_center)
	print("   - Camera zoom: ", camera_zoom)
	print("   - Viewport size: ", viewport_size)
	
	# Cam area for zoom
	var visible_rect = Rect2(
		camera_center - (viewport_size * camera_zoom) / 2,
		viewport_size * camera_zoom
	)
	
	print("   - Visible area: ", visible_rect)
	
	var target_position = Vector2()
	target_position.x = visible_rect.position.x + visible_rect.size.x - interface_size.x - 20  # 🔥 20px de margen desde el borde derecho
	target_position.y = visible_rect.position.y + (visible_rect.size.y - interface_size.y) / 2  # 🔥 Centrada verticalmente
	
	target_position = _convert_to_global_position(target_position)
	
	interface.global_position = target_position
	
	print(" Interface positioned at camera right wall:")
	print("   - Target position: ", target_position)
	print("   - Final position: ", interface.global_position)

func _convert_to_global_position(local_pos: Vector2) -> Vector2:
	return local_pos

func _center_interface_on_screen(interface: Control):
	var screen_size = get_viewport().get_visible_rect().size
	var interface_size = interface.size
	
	var target_position = Vector2(
		(screen_size.x - interface_size.x) / 2,
		(screen_size.y - interface_size.y) / 2
	)
	
	interface.global_position = target_position
	print(" Fallback: Centered on screen: ", target_position)

func _get_piece_global_rect(piece) -> Rect2:
	var piece_size = piece.texture.get_size() if piece.texture else Vector2(80, 80)
	var piece_top_left = piece.global_position - piece_size / 2
	return Rect2(piece_top_left, piece_size)

func _calculate_smart_interface_position(mouse_pos: Vector2, interface_size: Vector2, screen_size: Vector2) -> Vector2:
	print(" PRECISE positioning for mouse: ", mouse_pos)
	
	var target_position = Vector2()
	
	target_position.x = mouse_pos.x + 20
	
	var available_space_above = mouse_pos.y - interface_size.y - 20
	var available_space_below = screen_size.y - (mouse_pos.y + 20) - interface_size.y
	
	print(" Space analysis - Above: ", available_space_above, " Below: ", available_space_below)
	
	if available_space_below >= available_space_above and available_space_below > 50:
		# More space bellow
		target_position.y = mouse_pos.y + 20
		print(" Strategy: BELOW mouse (more space below)")
	elif available_space_above > 50:
		# More space above
		target_position.y = mouse_pos.y - interface_size.y - 20
		print(" Strategy: ABOVE mouse (more space above)")
	else:
		# Use just in case of few space
		var ideal_center = mouse_pos.y - interface_size.y / 2
		target_position.y = clamp(ideal_center, 10, screen_size.y - interface_size.y - 10)
		print(" Strategy: CENTERED (limited space)")
	
	if target_position.x + interface_size.x > screen_size.x - 10:
		target_position.x = mouse_pos.x - interface_size.x - 20
		print(" Adjusting: moved to left side")
	
	target_position.x = clamp(target_position.x, 10, screen_size.x - interface_size.x - 10)
	target_position.y = clamp(target_position.y, 10, screen_size.y - interface_size.y - 10)
	
	print(" Final position: ", target_position)
	return target_position

func _find_best_adjusted_position(mouse_pos: Vector2, interface_size: Vector2, screen_size: Vector2) -> Vector2:
	
	var ideal_pos = mouse_pos + Vector2(20, 20)
	var adjusted_pos = ideal_pos
	
	if ideal_pos.x + interface_size.x > screen_size.x:
		adjusted_pos.x = mouse_pos.x - interface_size.x - 20
	elif ideal_pos.x < 0:
		adjusted_pos.x = 10
	
	# Vertical
	if ideal_pos.y + interface_size.y > screen_size.y:
		var above_pos = mouse_pos.y - interface_size.y - 20
		var centered_pos = mouse_pos.y - interface_size.y / 2
		
		var distance_above = abs(above_pos + interface_size.y / 2 - mouse_pos.y)
		var distance_centered = abs(centered_pos + interface_size.y / 2 - mouse_pos.y)
		
		if distance_centered < distance_above and centered_pos >= 0 and centered_pos + interface_size.y <= screen_size.y:
			adjusted_pos.y = centered_pos
		else:
			adjusted_pos.y = above_pos
	elif ideal_pos.y < 0:
		adjusted_pos.y = 10
	
	# limits
	adjusted_pos.x = clamp(adjusted_pos.x, 10, screen_size.x - interface_size.x - 10)
	adjusted_pos.y = clamp(adjusted_pos.y, 10, screen_size.y - interface_size.y - 10)
	
	print(" Adjusted position - Mouse: ", mouse_pos, " -> Interface: ", adjusted_pos)
	return adjusted_pos

func _calculate_best_interface_position(piece: Node, mouse_pos: Vector2, interface_size: Vector2, screen_size: Vector2) -> Vector2:
	# Option 1
	var mouse_based_pos = mouse_pos + Vector2(20, 20)
	
	# Option 2
	var piece_based_pos = Vector2(
		piece.global_position.x - interface_size.x / 2,
		piece.global_position.y + 80
	)
	
	# Screen fitness
	var mouse_fits = _position_fits_in_screen(mouse_based_pos, interface_size, screen_size)
	var piece_fits = _position_fits_in_screen(piece_based_pos, interface_size, screen_size)
	
	if mouse_fits:
		return _clamp_position_to_screen(mouse_based_pos, interface_size, screen_size)
	else:
		return _clamp_position_to_screen(piece_based_pos, interface_size, screen_size)

func _position_fits_in_screen(position: Vector2, size: Vector2, screen_size: Vector2) -> bool:
	var margin = 5
	return (position.x >= margin and 
			position.y >= margin and 
			position.x + size.x <= screen_size.x - margin and 
			position.y + size.y <= screen_size.y - margin)

func _clamp_position_to_screen(position: Vector2, size: Vector2, screen_size: Vector2) -> Vector2:
	return Vector2(
		clamp(position.x, 10, screen_size.x - size.x - 10),
		clamp(position.y, 10, screen_size.y - size.y - 10)
	)

func _calculate_interface_position(global_mouse_pos: Vector2, interface_size: Vector2) -> Vector2:
	var screen_size = get_viewport().get_visible_rect().size
	var target = global_mouse_pos + Vector2(20, 20)
	
	target.x = clamp(target.x, 10, screen_size.x - interface_size.x - 10)
	target.y = clamp(target.y, 10, screen_size.y - interface_size.y - 10)
	
	print(" Calculated position - Mouse: ", global_mouse_pos, " Target: ", target)
	return target

func _position_interface_at_mouse(interface: Control, mouse_pos: Vector2):
	print(" === POSITIONING ===")
	print("   - Mouse position: ", mouse_pos)
	
	var screen_size = get_viewport().get_visible_rect().size
	var target_position = mouse_pos + Vector2(20, 20)
	
	target_position.x = clamp(target_position.x, 10, screen_size.x - interface.size.x - 10)
	target_position.y = clamp(target_position.y, 10, screen_size.y - interface.size.y - 10)
	
	interface.global_position = target_position
	
	print("   - Final position: ", interface.global_position)
	print("=== END ===")

func _position_interface_before_adding(interface: Control, mouse_pos: Vector2):
	print("=== PRE-POSITIONING ===")
	print("   - Target mouse position: ", mouse_pos)
	
	var screen_size = get_viewport().get_visible_rect().size
	var target_position = mouse_pos + Vector2(20, 20)
	
	# Don't get out of screen
	target_position.x = clamp(target_position.x, 10, screen_size.x - interface.size.x - 10)
	target_position.y = clamp(target_position.y, 10, screen_size.y - interface.size.y - 10)
	
	interface.position = target_position
	
	print("   - Pre-set position: ", target_position)
	print("=== END ===")

func _on_piece_right_clicked(piece):
	print("Piece right_clicked signal received: ", piece.piece_type)
	print("   - Piece position: ", piece.global_position)
	print("   - Piece color: ", piece.piece_color)
	print("   - Piece type: ", piece.piece_type)
	
	# Surrender to mouse position
	open_programming_interface_for_piece(piece, piece.global_position)

# === SISTEMA DE TURNOS ===
func is_valid_turn(piece_color: String) -> bool:
	return piece_color == current_turn

func switch_turn():
	current_turn = "black" if current_turn == "white" else "white"
	print("Turn changed to: ", current_turn)
	update_turn_display()

func update_turn_display():
	if turn_display and turn_display.has_method("update_turn"):
		turn_display.update_turn(current_turn)

# === Close manager ===
func _on_programming_interface_closed():
	print("Programming interface closed from GameManager")
	current_programming_interface = null
	is_opening_interface = false  # RESETEAR ESTADO

# === DEBUG UTILITIES ===
func print_all_piece_positions():
	print("=== ALL PIECE POSITIONS ===")
	for piece in pieces_container.get_children():
		var coord = _world_to_board_coord(piece.global_position)
		print("Piece:", piece.piece_type, " at cell:", coord)
	print("===========================")

func _test_block_system():
	print("=== BLOCK SYSTEM TEST ===")
	if BlockSystem:
		var pawn_ram = BlockSystem.get_piece_ram_capacity("pawn")
		print("Pawn RAM capacity: ", pawn_ram)
	else:
		print("BlockSystem not found")

func _connect_piece_signals():
	print("Connecting piece signals...")
	var connected_count = 0
	
	for piece in pieces_container.get_children():
		if piece.has_signal("right_clicked"):
			if not piece.right_clicked.is_connected(_on_piece_right_clicked):
				piece.right_clicked.connect(_on_piece_right_clicked)
				connected_count += 1
				print("Connected to: ", piece.piece_type)
		else:
			print("No right_clicked signal in: ", piece.piece_type)
	
	print("Connected to ", connected_count, " pieces")

func _position_interface_at_camera_right(interface: Control):
	if not camera:
		print("No camera reference, falling back to screen right")
		_position_interface_at_screen_right(interface)
		return
	
	var camera_center = camera.global_position
	var camera_zoom = camera.zoom
	var viewport_size = get_viewport().get_visible_rect().size
	var interface_size = interface.size
	
	var visible_rect = Rect2(
		camera_center - (viewport_size * camera_zoom) / 2,
		viewport_size * camera_zoom
	)
	
	var target_position = Vector2()
	target_position.x = visible_rect.position.x + visible_rect.size.x - interface_size.x - 20  # Margen derecho de 20px
	target_position.y = visible_rect.position.y + (visible_rect.size.y - interface_size.y) / 2  # Centrada verticalmente
	
	interface.global_position = target_position
	
	print("Interface positioned at camera right:")
	print("   - Camera view: ", visible_rect)
	print("   - Interface size: ", interface_size)
	print("   - Final position: ", target_position)

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
