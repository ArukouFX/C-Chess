extends Sprite2D

signal released(piece, world_position)
signal right_clicked(piece)

var is_dragging = false
var piece_offset = Vector2.ZERO
var last_valid_pos = Vector2.ZERO
var piece_color: String = ""
var piece_type: String = ""
var original_modulate: Color = Color.WHITE

var available_ram: int = 0
var used_ram: int = 0
var behavior_script: Array = []
var is_programmed: bool = false

func setup_piece(tex: Texture2D, color: String, type: String) -> void:
	texture = tex
	centered = true
	piece_color = color
	piece_type = type
	original_modulate = Color.WHITE
	
	# --- Ram Init ---
	available_ram = BlockSystem.get_piece_ram_capacity(type)
	used_ram = 0
	behavior_script = []
	
	$Area2D.position = Vector2.ZERO
	var shape = RectangleShape2D.new()
	shape.extents = tex.get_size() / 2
	$Area2D/CollisionShape2D.shape = shape
	$Area2D/CollisionShape2D.position = Vector2.ZERO

func _ready():
	$Area2D.input_event.connect(_on_area_2d_input_event)
	$Area2D.monitoring = true
	$Area2D.input_pickable = true
	call_deferred("_set_initial_position")

func _set_initial_position():
	last_valid_pos = global_position

func _handle_right_click():
	print("Right click on piece for programming: ", piece_type)
	var game_manager = get_node_or_null("/root/Main/GameManager")
	if game_manager and game_manager.has_method("_on_piece_right_clicked"):
		game_manager._on_piece_right_clicked(self)
	else:
		print("GameManager not available for programming")

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and is_dragging:
			is_dragging = false
			z_index = 0
			# Restaurar color original al soltar
			modulate = original_modulate
			print("Piece released, glow removed")
			emit_signal("released", self, global_position)
	
	if is_dragging and event is InputEventMouseMotion:
		global_position = get_global_mouse_position() + piece_offset

func get_programming_status() -> String:
	if behavior_script.is_empty():
		return "No program"
	else:
		var block_count = behavior_script.size()
		return "%d block%s programmed" % [block_count, "s" if block_count != 1 else ""]

func update_programming(new_script: Array):
	behavior_script = new_script
	used_ram = BlockSystem.calculate_ram_usage(new_script)
	is_programmed = not new_script.is_empty()
	print("Piece programmed: ", piece_type, " - RAM: ", used_ram, "/", available_ram)

func cancel_drag():
	is_dragging = false
	modulate = original_modulate
	global_position = last_valid_pos
	
func _on_area_2d_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		# SOLO CLICK DERECHO para programación
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			print("Right click - Opening programming for: ", piece_type)
			emit_signal("right_clicked", self)
			get_viewport().set_input_as_handled()
		
		# CLICK IZQUIERDO - Solo movimiento (tu código existente)
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var game_manager = get_node("/root/Main/GameManager")
			if game_manager and game_manager.is_valid_turn(piece_color):
				is_dragging = true
				piece_offset = global_position - get_global_mouse_position()
				z_index = 1
				modulate = Color.YELLOW
func _handle_left_click():
	print("Handling left click for piece: ", piece_type)
	var game_manager = get_node_or_null("/root/Main/GameManager")
	if game_manager and game_manager.has_method("is_valid_turn"):
		if game_manager.is_valid_turn(piece_color):
			is_dragging = true
			piece_offset = global_position - get_global_mouse_position()
			z_index = 1
			modulate = Color.YELLOW
			print("Piece selected and glowing: ", piece_type)
		else:
			var tween = create_tween()
			tween.tween_property(self, "modulate", Color.RED, 0.1)
			tween.tween_property(self, "modulate", original_modulate, 0.1)
			print("Not your turn! Current turn: ", game_manager.current_turn)
	else:
		print("GameManager not available for left click")
