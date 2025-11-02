extends Control

# References... why?
@onready var main_container = $UI/MainContainer
@onready var left_panel = $UI/MainContainer/LeftPanel
@onready var center_panel = $UI/MainContainer/RightPanel/CenterPanel
@onready var right_panel = $UI/MainContainer/RightPanel

@onready var block_palette = $UI/MainContainer/LeftPanel/BlockPalette
@onready var piece_info = $UI/MainContainer/LeftPanel/PieceInfo
@onready var workspace = $UI/MainContainer/CenterPanel/Workspace
@onready var ram_counter = $UI/MainContainer/RightPanel/RAMCounter
@onready var control_buttons = $UI/MainContainer/LeftPanel/ControlButtons

# workspace 
var workspace_original_size: Vector2 = Vector2(350, 100)
var workspace_expansion_rate: int = 60
var max_workspace_height: int = 500
var min_workspace_height: int = 100

var is_dragging_interface: bool = false
var drag_interface_offset: Vector2 = Vector2.ZERO

# State
var current_piece: Node = null
var current_blocks: Array = []
var currently_dragging_block: DraggableBlock = null
var drop_zones: Array[Control] = []

var DraggableBlockScene = preload("res://Scenes/draggable_block.tscn")

func _ready():
	print("ProgrammingInterface loaded")
	
	custom_minimum_size = Vector2(600, 400)
	size = Vector2(600, 400)
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	call_deferred("_initialize_interface")
	visible = false

func _add_piece_title():
	var title_label = Label.new()
	title_label.name = "PieceTitle"
	title_label.text = "PROGRAMMING INTERFACE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	
	add_child(title_label)
	title_label.position = Vector2(10, 10)
	title_label.size = Vector2(size.x - 20, 30)

func setup_for_piece(piece: Node):
	current_piece = piece
	current_blocks = piece.behavior_script.duplicate()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	update_piece_info()
	update_ram_display()
	load_block_palette()
	load_workspace_blocks()
	
	# ELIMINAR el centrado desde aquí - ya se hace desde game_manager
	custom_minimum_size = Vector2(600, 400)
	size = Vector2(600, 400)
	
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	
	print("Programming interface ready for: ", piece.piece_type)

func _center_on_screen():
	var screen_size = get_viewport().get_visible_rect().size
	var interface_size = size
	
	global_position = Vector2(
		(screen_size.x - interface_size.x) / 2,
		(screen_size.y - interface_size.y) / 2
	)
	
	print("Interface centered at: ", global_position)

func _initialize_interface():
	_verify_ui_structure()
	_setup_panel_sizes()
	_connect_buttons()
	_setup_drop_zones()
	
	if workspace:
		workspace_original_size = workspace.size
		print("Workspace original size: ", workspace_original_size)

func _setup_drop_zones():
	drop_zones.clear()
	var workspace_drop = workspace.get_node_or_null("DropZone")
	if workspace_drop:
		drop_zones.append(workspace_drop)
		print("Drop zones configured")
	else:
		print("No drop zone found, creating one...")
		_create_drop_zone()

func _verify_ui_structure():
	var nodes = {
		"UI": $UI,
		"MainContainer": main_container, 
		"LeftPanel": left_panel,
		"CenterPanel": center_panel, 
		"RightPanel": right_panel,
		"BlockPalette": block_palette, 
		"PieceInfo": piece_info,
		"Workspace": workspace, 
		"RAMCounter": ram_counter,
		"ControlButtons": control_buttons
	}
	
	for node_name in nodes:
		var node = nodes[node_name]
		if node:
			print( node_name, " found")
		else:
			print(node_name, " NOT found")

func _setup_panel_sizes():
	if main_container is HBoxContainer:
		main_container.set("theme_override_constants/separation", 10)
	
	if block_palette:
		block_palette.custom_minimum_size = Vector2(200, 300)
	
	if workspace:
		workspace.custom_minimum_size = Vector2(100, min_workspace_height)
		workspace.size = Vector2(100, min_workspace_height)
		print("Workspace configured: ", workspace.size)

func _connect_buttons():
	var test_button = control_buttons.get_node_or_null("TestButton")
	var save_button = control_buttons.get_node_or_null("SaveButton")
	var cancel_button = control_buttons.get_node_or_null("CancelButton")
	
	if test_button:
		test_button.pressed.connect(_on_test_button_pressed)
		print("TestButton connected")
	if save_button:
		save_button.pressed.connect(_on_save_button_pressed)
		print("SaveButton connected")  
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_button_pressed)
		print("CancelButton connected")

func load_block_palette():
	if not DraggableBlockScene or not block_palette:
		print("Missing DraggableBlockScene or block_palette")
		return
	
	var blocks_container = block_palette.get_node("ScrollContainer/GridContainer")
	if not blocks_container:
		print("Blocks container not found")
		return
	
	for child in blocks_container.get_children():
		child.queue_free()
	
	var test_blocks = [
		BlockSystem.get_block_info("move_forward"),
		BlockSystem.get_block_info("move_diagonal"),
		BlockSystem.get_block_info("if_enemy_front"),
		BlockSystem.get_block_info("capture"),
		BlockSystem.get_block_info("move_back"),
		BlockSystem.get_block_info("detect_enemy")
	]
	
	print("Loading ", test_blocks.size(), " blocks into palette")
	
	for block_data in test_blocks:
		var block_instance = DraggableBlockScene.instantiate()
		blocks_container.add_child(block_instance)
		block_instance.setup_block(block_data)
		block_instance.mouse_filter = Control.MOUSE_FILTER_STOP
		block_instance.block_dragged.connect(_on_block_dragged)
		block_instance.block_dropped.connect(_on_block_dropped)
	
	print("Block palette loaded with ", blocks_container.get_child_count(), " blocks")

func load_workspace_blocks():
	var workspace_area = workspace.get_node_or_null("DropZone")
	if not workspace_area:
		print("No workspace area found, creating...")
		workspace_area = _create_drop_zone()
	
	# clean workspace
	for child in workspace_area.get_children():
		if child is DraggableBlock:
			child.queue_free()
	
	# charge saved blocks
	if current_piece and not current_piece.behavior_script.is_empty():
		print("Loading ", current_piece.behavior_script.size(), " saved blocks for piece")
		for block_data in current_piece.behavior_script:
			var block_instance = DraggableBlockScene.instantiate()
			workspace_area.add_child(block_instance)
			block_instance.setup_block(block_data)
			block_instance.mouse_filter = Control.MOUSE_FILTER_STOP
			block_instance.block_dragged.connect(_on_block_dragged)
			block_instance.block_dropped.connect(_on_block_dropped)
		
		_reposition_all_workspace_blocks()  # 🔥 Esto ajustará el tamaño automáticamente
	
	print("Workspace ready - DropZone child count: ", workspace_area.get_child_count())

func _create_drop_zone() -> Control:
	var drop_zone = ColorRect.new()
	drop_zone.name = "DropZone"
	drop_zone.z_index = 10
	drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop_zone.color = Color(0.8, 0.2, 0.2, 0.3)  # 🔥 MENOS INTENSO para debug
	
	if workspace:
		drop_zone.size = workspace.size
		drop_zone.custom_minimum_size = workspace.size
		workspace.add_child(drop_zone)
		print("DropZone created with size: ", drop_zone.size)
	
	return drop_zone

func update_piece_info():
	if not current_piece or not piece_info:
		print("No current piece or piece_info node")
		return
	
	print("Updating piece info for: ", current_piece.piece_type)
	
	# search jerachic structure
	var hbox = piece_info.get_node_or_null("HBoxContainer")
	if not hbox:
		print("HBoxContainer not found in PieceInfo")
		# Intentar buscar directamente los labels
		_update_piece_info_direct()
		return
	
	# Update texture
	var texture_rect = hbox.get_node_or_null("TextureRect")
	if texture_rect and current_piece.texture:
		texture_rect.texture = current_piece.texture
		print("Piece texture updated")
	
	# Vbox container info
	var vbox = hbox.get_node_or_null("VBoxContainer")
	if not vbox:
		print("VBoxContainer not found")
		return
	
	var piece_name_label = vbox.get_node_or_null("PieceName")
	var piece_type_label = vbox.get_node_or_null("PieceType") 
	var piece_status_label = vbox.get_node_or_null("PieceStatus")
	
	var piece_name = "%s %s" % [current_piece.piece_color.capitalize(), current_piece.piece_type.capitalize()]
	var ram_info = "Total RAM: %d" % current_piece.available_ram
	var status_info = current_piece.get_programming_status()
	
	print("   - Name: ", piece_name)
	print("   - RAM: ", ram_info)
	print("   - Status: ", status_info)
	
	# Update labels
	if piece_name_label:
		piece_name_label.text = piece_name
		print("PieceName label updated")
	else:
		print("PieceName label not found")
	
	if piece_type_label:
		piece_type_label.text = ram_info
		print("PieceType label updated")
	else:
		print("PieceType label not found")
	
	if piece_status_label:
		piece_status_label.text = status_info
		print("PieceStatus label updated")
	else:
		print("PieceStatus label not found")

func _find_and_update_labels(parent: Node):
	var labels_found = 0
	var labels = []
	
	# Search Label
	_find_all_labels_recursive(parent, labels)
	
	print("Found %d labels in PieceInfo structure" % labels.size())
	
	# Update labels
	for i in range(labels.size()):
		var label = labels[i]
		match labels_found:
			0: 
				label.text = "%s %s" % [current_piece.piece_color.capitalize(), current_piece.piece_type.capitalize()]
				print("Updated label 1 (Name): ", label.text)
			1:
				label.text = "RAM: %d/%d" % [calculate_current_ram_usage(), current_piece.available_ram]
				print("Updated label 2 (RAM): ", label.text)
			2:
				label.text = current_piece.get_programming_status()
				print("Updated label 3 (Status): ", label.text)
		
		labels_found += 1
		if labels_found >= 3:
			break
	
	if labels_found == 0:
		print("No labels found in PieceInfo structure")

func _find_all_labels_recursive(node: Node, labels: Array):
	if node is Label:
		labels.append(node)
		print("   - Found Label: ", node.name, " | Text: ", node.text)
	
	for child in node.get_children():
		_find_all_labels_recursive(child, labels)

func _update_piece_info_direct():
	print("Attempting direct label search in PieceInfo...")
	
	# Search labels by name
	var possible_names = ["PieceName", "NameLabel", "Label", "PieceType", "TypeLabel", "RAMLabel", "PieceStatus", "StatusLabel"]
	
	for name in possible_names:
		var node = _find_node_recursive(piece_info, name)
		if node and node is Label:
			print("Found label: ", name)
			node.text = "%s %s" % [current_piece.piece_color.capitalize(), current_piece.piece_type.capitalize()]
			return
	
	print("No labels found with common names")

func _find_node_recursive(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	
	for child in root.get_children():
		var found = _find_node_recursive(child, node_name)
		if found:
			return found
	
	return null

func update_ram_display():
	if not current_piece or not ram_counter:
		return
	
	var used_ram = calculate_current_ram_usage()
	var ram_used_label = ram_counter.get_node_or_null("RAMUsed")
	var ram_total_label = ram_counter.get_node_or_null("RAMTotal")
	
	if ram_used_label:
		ram_used_label.text = str(used_ram)
	if ram_total_label:
		ram_total_label.text = str(current_piece.available_ram)
	
	print("RAM Display Updated: ", used_ram, "/", current_piece.available_ram)

func calculate_current_ram_usage() -> int:
	var total = 0
	for block_data in current_blocks:
		if block_data is Dictionary and block_data.has("ram_cost"):
			total += block_data["ram_cost"]
		elif block_data is Dictionary and block_data.has("type"):
			var block_info = BlockSystem.get_block_info(block_data["type"])
			total += block_info.get("ram_cost", 0)
	print("Calculated RAM usage: ", total)
	return total

# Sings drag & drop
func _on_block_dragged(block: DraggableBlock, global_pos: Vector2):
	print("START DRAG: ", block.block_data["name"])
	currently_dragging_block = block
	_highlight_drop_zones(true)

func _on_block_dropped(block: DraggableBlock, global_pos: Vector2):
	print("END DRAG: ", block.block_data["name"])
	currently_dragging_block = null
	var target_drop_zone = _get_drop_zone_at_position(global_pos)
	
	if target_drop_zone:
		print("Dropped on valid drop zone")
		_move_block_to_workspace(block, target_drop_zone, global_pos)  # <-- pasar global_pos
	else:
		print("No valid drop zone, returning to palette")
		_return_block_to_palette(block)
	
	_highlight_drop_zones(false)


func _return_block_to_palette(block: DraggableBlock):
	var blocks_container = block_palette.get_node("ScrollContainer/GridContainer")
	if blocks_container:
		var original_parent = block.get_parent()
		if original_parent:
			original_parent.remove_child(block)
		
		blocks_container.add_child(block)
		if current_blocks.has(block.block_data):
			current_blocks.erase(block.block_data)
			update_ram_display()

		_reposition_all_workspace_blocks()
		print("Block returned to palette and workspace adjusted")
	else:
		print("Could not return block to palette - container not found")

func _get_drop_zone_at_position(global_pos: Vector2) -> Control:
	for drop_zone in drop_zones:
		if drop_zone and is_instance_valid(drop_zone):
			var zone_rect = drop_zone.get_global_rect()
			if zone_rect.has_point(global_pos):
				return drop_zone
	return null

func _move_block_to_workspace(block: DraggableBlock, drop_zone: Control, global_pos: Vector2):
	print("Moving block to workspace: ", block.block_data["name"])
	
	var original_parent = block.get_parent()
	if original_parent:
		original_parent.remove_child(block)
	
	drop_zone.add_child(block)
	
	# 🔹 Calculate local position
	var local_pos = global_pos - drop_zone.get_global_position()
	block.position = Vector2(20, local_pos.y)  # Mantener margen X

	block.visible = true
	block.modulate = Color.WHITE
	block.z_index = 1000
	
	# Ensure correct current block
	if not current_blocks.has(block.block_data):
		current_blocks.append(block.block_data)
		print("Block added to current_blocks: ", block.block_data["name"])
		update_ram_display()
	else:
		print("Block already in current_blocks")
	
	print("Block moved to workspace")
	
	# Reposition everything after move
	_reposition_all_workspace_blocks()

func _reposition_all_workspace_blocks():
	var drop_zone = workspace.get_node_or_null("DropZone")
	if not drop_zone:
		print("No drop zone for repositioning")
		return
	
	var blocks = []
	var start_y = 10
	var block_spacing = workspace_expansion_rate - 20  # Espacio entre bloques
	
	for child in drop_zone.get_children():
		if child is DraggableBlock:
			blocks.append(child)
	
	print("Repositioning ", blocks.size(), " blocks")
	
	blocks.sort_custom(func(a, b): return a.position.y < b.position.y)
	
	# Reposition all blocks
	for i in range(blocks.size()):
		blocks[i].position = Vector2(20, start_y + i * block_spacing)
	
	print("Blocks repositioned with spacing: ", block_spacing)
	
	_expand_workspace_if_needed()

func _expand_workspace_if_needed():
	if not workspace:
		return
	
	var new_height = _calculate_workspace_height()
	
	if new_height != workspace.size.y:
		workspace.custom_minimum_size.y = new_height
		workspace.size.y = new_height
		
		var drop_zone = workspace.get_node_or_null("DropZone")
		if drop_zone:
			drop_zone.custom_minimum_size.y = new_height
			drop_zone.size.y = new_height
		print("📐 Workspace auto-resized to: ", new_height, " (blocks: ", _get_workspace_block_count(), ")")
		
		_adjust_parent_containers()

func _get_workspace_block_count() -> int:
	var drop_zone = workspace.get_node_or_null("DropZone")
	if not drop_zone:
		return 0
	
	var count = 0
	for child in drop_zone.get_children():
		if child is DraggableBlock:
			count += 1
	return count

func _highlight_drop_zones(highlight: bool):
	for drop_zone in drop_zones:
		if drop_zone is ColorRect:
			if highlight:
				drop_zone.color = Color(0.3, 0.5, 0.8, 0.5)
			else:
				drop_zone.color = Color(0.2, 0.2, 0.2, 0.3)

# === Button Functionality ===# 
func _on_test_button_pressed():
	print("Testing piece programming...")
	
	if not current_piece:
		print("No piece selected for testing")
		return
	
	var used_ram = calculate_current_ram_usage()
	var available_ram = current_piece.available_ram
	
	print("Test - RAM Usage: ", used_ram, "/", available_ram)
	print("Test - Blocks count: ", current_blocks.size())
	
	if used_ram > available_ram:
		print("RAM limit exceeded: ", used_ram, "/", available_ram)
	elif current_blocks.is_empty():
		print("No blocks programmed")
	else:
		print("Test passed! RAM usage: ", used_ram, "/", available_ram)

func _on_save_button_pressed():
	print("Saving programming...")
	
	if not current_piece:
		print("No piece selected for saving")
		return
	
	# Verify Ram Limit
	var used_ram = calculate_current_ram_usage()
	var available_ram = current_piece.available_ram
	
	if used_ram > available_ram:
		print("Cannot save - RAM limit exceeded: ", used_ram, "/", available_ram)
		return
	
	if current_piece.has_method("update_programming"):
		current_piece.update_programming(current_blocks)
		print("Programming saved for: ", current_piece.piece_type)
		print("   - Blocks: ", current_blocks.size())
		print("   - RAM used: ", used_ram, "/", available_ram)
		
		# update info
		update_piece_info()
		update_ram_display()
	else:
		print("Piece doesn't have update_programming method")
	
	_close_interface()

func _on_cancel_button_pressed():
	print("Cancelling programming...")
	
	_close_interface()

func _close_interface():
	print("Closing programming interface...")
	
	# Notificar al GameManager PRIMERO
	var game_manager = get_node_or_null("/root/Main/GameManager")
	if game_manager and game_manager.has_method("_on_programming_interface_closed"):
		game_manager._on_programming_interface_closed()
	
	# Clean state
	current_piece = null
	current_blocks.clear()
	currently_dragging_block = null
	
	print("Programming interface closed")
	
	queue_free()

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging_interface = true
			drag_interface_offset = get_local_mouse_position()
			get_viewport().set_input_as_handled()
		else:
			is_dragging_interface = false
	
	elif event is InputEventMouseMotion and is_dragging_interface:
		global_position = get_global_mouse_position() - drag_interface_offset
		get_viewport().set_input_as_handled()

func _input(event):
	# Esc to close
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_interface()
		get_viewport().set_input_as_handled()
	
	if event is InputEventMouseMotion and visible:
		print("Interface visible at: ", global_position, ", size: ", size)

func _set(property, value):
	if property == "global_position":
		print("SET global_position to: ", value)
	elif property == "position":
		print("SET position to: ", value)

func _calculate_workspace_height() -> int:
	var drop_zone = workspace.get_node_or_null("DropZone")
	if not drop_zone:
		return min_workspace_height
	
	var max_y = 0
	for child in drop_zone.get_children():
		if child is DraggableBlock:
			var bottom = child.position.y + child.size.y
			if bottom > max_y:
				max_y = bottom
	
	var required_height = max_y + 10
	return clamp(required_height, min_workspace_height, max_workspace_height)


func _adjust_parent_containers():
	if center_panel:
		center_panel.custom_minimum_size.y = workspace.size.y
		center_panel.size.y = workspace.size.y
	
	if main_container:
		## Force layout update
		main_container.queue_redraw()
