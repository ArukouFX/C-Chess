extends TextureRect

class_name DraggableBlock

signal block_dragged(block, global_position)
signal block_dropped(block, global_position)

var base_size = Vector2(180, 60)

var block_data: Dictionary
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO  
var original_position: Vector2
var original_parent: Node
var is_in_workspace: bool = false

# References
@onready var block_name_label = _find_node("BlockName")
@onready var ram_cost_label = _find_node("RAMCost")
@onready var color_rect = $ColorRect

func _find_node(node_name: String) -> Node:
	return _find_node_recursive(self, node_name)

func _find_node_recursive(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found = _find_node_recursive(child, node_name)
		if found:
			return found
	return null

func setup_block(data: Dictionary):
	block_data = data
	
	if block_name_label:
		block_name_label.text = data["name"]
	if ram_cost_label:
		ram_cost_label.text = "RAM: " + str(data["ram_cost"])
	if color_rect:
		var category_colors = {
			"movement": Color.ROYAL_BLUE,
			"logic": Color.FOREST_GREEN, 
			"action": Color.FIREBRICK,
			"sensor": Color.DARK_ORANGE,
			"control": Color.PURPLE
		}
		color_rect.color = category_colors.get(data.get("category", "movement"), Color.GRAY)
	
	# El tamaño ahora se ajusta desde programming_interface.gd
	# Solo establecer mínimo
	custom_minimum_size = base_size
	size = base_size

# Agregar método para reescalar:
func rescale_block(new_scale: float):
	var scaled_size = base_size * new_scale
	custom_minimum_size = scaled_size
	size = scaled_size
	
	# También escalar fuente si es necesario
	if block_name_label:
		var base_font_size = 14
		block_name_label.add_theme_font_size_override("font_size", int(base_font_size * new_scale))

func get_block_data() -> Dictionary:
	return block_data

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Verificar click en el bloque
			var local_pos = get_local_mouse_position()
			var rect = Rect2(Vector2.ZERO, size)
			if rect.has_point(local_pos):
				_start_drag(event)
				get_viewport().set_input_as_handled()
		elif is_dragging:
			_end_drag(event)
			get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion and is_dragging:
		global_position = get_global_mouse_position() - drag_offset
		emit_signal("block_dragged", self, get_global_mouse_position())
		get_viewport().set_input_as_handled()

# En draggable_block.gd, verificar que estas funciones existan:
func _start_drag(event: InputEventMouseButton):
	print("START DRAG: ", block_data["name"])
	
	is_dragging = true
	drag_offset = get_global_mouse_position() - global_position
	original_position = global_position
	original_parent = get_parent()
	
	# Mover al frente
	z_index = 100
	modulate = Color(1.3, 1.3, 0.7)
	
	emit_signal("block_dragged", self, get_global_mouse_position())

func _end_drag(event: InputEventMouseButton):
	print("END DRAG: ", block_data["name"])
	
	is_dragging = false
	z_index = 0
	modulate = Color.WHITE
	
	emit_signal("block_dropped", self, get_global_mouse_position())

func _return_to_palette():
	if original_parent:
		# Remover del parent actual
		if get_parent():
			get_parent().remove_child(self)
		
		# Regresar al parent original
		original_parent.add_child(self)
		global_position = original_position
		is_in_workspace = false
		print("Bloque regresado a paleta")
	else:
		print("No hay parent original, eliminando")
		queue_free()

func _find_workspace():
	# Buscar ProgrammingInterface primero
	var programming_interface = null
	
	# Buscar en toda la escena
	for node in get_tree().get_nodes_in_group("programming_interface"):
		programming_interface = node
		break
	
	# Si no está en grupo, buscar por nombre
	if not programming_interface:
		for node in get_tree().get_nodes_in_group(""):
			if "ProgrammingInterface" in node.name:
				programming_interface = node
				break
	
	# Si aún no, buscar en root
	if not programming_interface:
		for child in get_tree().root.get_children():
			if child.name == "ProgrammingInterface" or child.has_method("setup_for_piece"):
				programming_interface = child
				break
	
	if programming_interface:
		print("Found ProgrammingInterface")
		# Buscar DropZone dentro
		var dropzone = programming_interface.get_node_or_null("UI/MainContainer/CenterPanel/Workspace/DropZone")
		if dropzone:
			return dropzone
		
		# Intentar otras rutas
		dropzone = programming_interface.get_node_or_null("Workspace/DropZone")
		if dropzone:
			return dropzone
		
		dropzone = programming_interface.get_node_or_null("DropZone")
		if dropzone:
			return dropzone
	
	print("Workspace not found")
	return null

func _is_over_workspace(workspace: Control) -> bool:
	if not workspace:
		return false
	
	var workspace_rect = Rect2(workspace.global_position, workspace.size)
	var block_center = global_position + size / 2
	
	print("Checking workspace overlap:")
	print("     - Workspace rect: ", workspace_rect)
	print("     - Block center: ", block_center)
	print("     - Overlap: ", workspace_rect.has_point(block_center))
	
	return workspace_rect.has_point(block_center)

func _move_to_workspace(workspace: Control):
	if get_parent():
		get_parent().remove_child(self)
	
	workspace.add_child(self)
	is_in_workspace = true
	
	# Posicionar en el workspace (ajustar posición local)
	var local_pos = get_global_mouse_position() - workspace.global_position
	position = Vector2(20, max(local_pos.y, 10))
	
	# Asegurar que sea visible
	visible = true
	modulate = Color.WHITE
	z_index = 1000
	
	print("Successfully moved to workspace at position: ", position)
