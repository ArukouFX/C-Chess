extends TextureRect

class_name DraggableBlock

signal block_dragged(block, global_position)
signal block_dropped(block, global_position)

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
			"sensor": Color.DARK_ORANGE
		}
		color_rect.color = category_colors.get(data.get("category", "movement"), Color.GRAY)
	
	custom_minimum_size = Vector2(180, 60)
	size = custom_minimum_size

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
	
	# MOVIMIENTO - igual que piece.gd
	elif event is InputEventMouseMotion and is_dragging:
		global_position = get_global_mouse_position() - drag_offset
		emit_signal("block_dragged", self, get_global_mouse_position())
		get_viewport().set_input_as_handled()

func _start_drag(event: InputEventMouseButton):
	print("START DRAG: ", block_data["name"])
	is_dragging = true
	drag_offset = get_global_mouse_position() - global_position
	original_position = global_position
	original_parent = get_parent()
	
	z_index = 100
	modulate = Color(1.3, 1.3, 0.7)
	
	# Ignore impues while u drag a piece
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	emit_signal("block_dragged", self, get_global_mouse_position())

func _end_drag(event: InputEventMouseButton):
	print("END DRAG: ", block_data["name"])
	is_dragging = false
	z_index = 0
	modulate = Color.WHITE
	
	# Restaure filter
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Destiny
	var workspace = get_workspace_dropzone()
	if workspace and is_over_workspace(workspace):
		print("   ✅ Moving to workspace")
		move_to_workspace(workspace)
	else:
		print("   ↩️ Returning to palette")
		return_to_palette()
	
	emit_signal("block_dropped", self, get_global_mouse_position())

func get_workspace_dropzone():
	var programming_interface = null
	
	# Search possible paths
	var possible_paths = [
		"ProgrammingInterface",
		"../ProgrammingInterface",
		"../../ProgrammingInterface"
	]
	
	# Try first relative paths
	for path in possible_paths:
		if has_node(path):
			programming_interface = get_node(path)
			break
	
	# Search in the root
	if not programming_interface:
		for child in get_tree().root.get_children():
			if child.name == "ProgrammingInterface":
				programming_interface = child
				break
	
	if programming_interface:
		print("Found ProgrammingInterface")
		# Differents roots in ProgrammingInterface
		var possible_workspace_paths = [
			"UI/MainContainer/CenterPanel/Workspace/DropZone",
			"Workspace/DropZone",
			"DropZone"
		]
		
		for path in possible_workspace_paths:
			var workspace_node = programming_interface.get_node_or_null(path)
			if workspace_node:
				print("Found workspace at: ", path)
				return workspace_node
	
	print("Workspace not found")
	return null

func is_over_workspace(workspace: Control) -> bool:
	if not workspace:
		return false
	
	var workspace_rect = Rect2(workspace.global_position, workspace.size)
	var block_center = global_position + size / 2
	
	print("Checking workspace overlap:")
	print("     - Workspace rect: ", workspace_rect)
	print("     - Block center: ", block_center)
	print("     - Overlap: ", workspace_rect.has_point(block_center))
	
	return workspace_rect.has_point(block_center)

func move_to_workspace(workspace: Control):
	if get_parent():
		get_parent().remove_child(self)
	
	workspace.add_child(self)
	is_in_workspace = true
	
	# Posicionar en el workspace
	position = Vector2(20, 20 + workspace.get_child_count() * 70)
	
	print("Successfully moved to workspace")

func return_to_palette():
	if get_parent():
		get_parent().remove_child(self)
	
	if original_parent:
		original_parent.add_child(self)
		global_position = original_position
		is_in_workspace = false
		print("Successfully returned to palette")
	else:
		print("No original parent, queuing free")
		queue_free()
		
