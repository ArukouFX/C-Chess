extends Sprite2D

signal released(piece, world_position)
signal right_clicked(piece)

var piece_id: String = ""
var piece_type: String = ""
var piece_color: String = ""
var original_modulate: Color = Color.WHITE

# Sistema de programación
var available_ram: int = 0
var used_ram: int = 0
var behavior_script: Array = []
var is_programmed: bool = false
var board_position: Vector2 = Vector2.ZERO
var program_execution_index: int = 0

func _ready():
	$Area2D.input_event.connect(_on_area_2d_input_event)
	$Area2D.monitoring = true
	$Area2D.input_pickable = true
	
	# Configurar escala ORIGINAL (la que tenías antes)
	self.scale = Vector2(0.4375, 0.4375)  # ← ESCALA ORIGINAL
	
	# Configurar la forma de colisión
	var shape = RectangleShape2D.new()
	shape.extents = texture.get_size() * 0.4375 / 2 if texture else Vector2(35, 35)
	$Area2D/CollisionShape2D.shape = shape
	$Area2D/CollisionShape2D.position = Vector2.ZERO

func setup_piece(tex: Texture2D, color: String, type: String, board_pos: Vector2) -> void:
	texture = tex
	centered = true
	piece_color = color
	piece_type = type
	board_position = board_pos
	original_modulate = Color.WHITE
	
	# --- NUEVO: Generar ID Único ---
	# Ejemplo: "white_pawn_0_1"
	piece_id = "%s_%s_%d_%d" % [color, type, int(board_pos.x), int(board_pos.y)]
	
	# --- RAM Init ---
	if BlockSystem and BlockSystem.has_method("get_piece_ram_capacity"):
		available_ram = BlockSystem.get_piece_ram_capacity(type)
	else:
		var default_ram = {"pawn": 8, "horse": 16, "bishop": 20, "tower": 24, "queen": 32, "king": 12}
		available_ram = default_ram.get(type, 8)
	
	used_ram = 0
	behavior_script = []
	is_programmed = false
	
	# Configurar escala FIJA
	self.scale = Vector2(0.4375, 0.4375)  # ← ESCALA FIJA ORIGINAL
	
	# Configurar Area2D con tamaño CORRECTO para la escala
	$Area2D.position = Vector2.ZERO
	var shape = RectangleShape2D.new()
	shape.extents = tex.get_size() * 0.4375 / 2 if tex else Vector2(35, 35)
	$Area2D/CollisionShape2D.shape = shape
	$Area2D/CollisionShape2D.position = Vector2.ZERO


# Esta función se llamará desde la ProgrammingInterface al darle a "Guardar"
func save_program_to_manager(new_script: Array):
	update_programming(new_script) # Actualiza la pieza localmente
	
	var gm = get_node_or_null("/root/Main/GameManager")
	if gm and gm.has_method("save_piece_program"):
		gm.save_piece_program(piece_id, new_script)

func update_world_position(new_world_pos: Vector2):
	position = new_world_pos
	global_position = new_world_pos

func _handle_right_click():
	print("Right click on piece for programming: ", piece_type)
	var game_manager = get_node_or_null("/root/Main/GameManager")
	if game_manager and game_manager.has_method("_on_piece_right_clicked"):
		game_manager._on_piece_right_clicked(self)
	else:
		print("GameManager not available for programming")

func get_programming_status() -> String:
	if behavior_script.is_empty():
		return "No program"
	else:
		var block_count = behavior_script.size()
		if BlockSystem and BlockSystem.has_method("calculate_ram_usage"):
			var ram_used = BlockSystem.calculate_ram_usage(behavior_script)
			return "%d block%s (%d/%d RAM)" % [block_count, "s" if block_count != 1 else "", ram_used, available_ram]
		return "%d blocks" % block_count

func update_programming(new_script: Array):
	behavior_script = new_script
	if BlockSystem and BlockSystem.has_method("calculate_ram_usage"):
		used_ram = BlockSystem.calculate_ram_usage(new_script)
	else:
		# Calcular manualmente
		used_ram = 0
		for block in new_script:
			if block is Dictionary and block.has("ram_cost"):
				used_ram += block["ram_cost"]
	
	is_programmed = not new_script.is_empty()
	print("Piece programmed: ", piece_type, " - RAM: ", used_ram, "/", available_ram, " - Blocks: ", new_script.size())

func reset_execution():
	program_execution_index = 0

func execute_next_command():
	if program_execution_index < behavior_script.size():
		var block_data = behavior_script[program_execution_index]
		
		# Verificar que BlockSystem existe
		if BlockSystem and BlockSystem.has_method("get_block_info"):
			var block_info = BlockSystem.get_block_info(block_data.get("type", ""))
			
			if block_info and block_info.has("execute"):
				var result = block_info["execute"].call(self, block_data.get("params", {}))
				program_execution_index += 1
				return result
			else:
				print("Block info not found for: ", block_data.get("type", ""))
				program_execution_index += 1
		else:
			print("BlockSystem not available")
			program_execution_index += 1
	
	return null

func _on_area_2d_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		# SOLO CLICK DERECHO para programación
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			print("Right click - Opening programming for: ", piece_type)
			emit_signal("right_clicked", self)
			get_viewport().set_input_as_handled()
