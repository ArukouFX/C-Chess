extends TextureRect
class_name DraggableBlock

signal block_dragged(block: DraggableBlock, global_position: Vector2)
signal block_dropped(block: DraggableBlock, global_position: Vector2)

var block_id: String = "move_forward" # Se asigna al instanciar
var base_size: Vector2 = Vector2(180, 70)
var block_data: Dictionary

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2
var original_parent: Node
var is_in_workspace: bool = false
var is_dying: bool = false

@onready var block_name_label: Label = _find_node("BlockName") as Label
@onready var ram_cost_label: Label = _find_node("RAMCost") as Label
@onready var color_rect: PanelContainer = $ColorRect as PanelContainer

func get_block_type() -> String:
	return block_id

func get_block_data() -> Dictionary:
	return block_data

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

func setup_block(data: Dictionary) -> void:
	block_data = data
	
	if block_name_label:
		block_name_label.text = data.get("name", "Sin Nombre")
		
	if ram_cost_label:
		var cost = data.get("ram_cost", 0)
		ram_cost_label.text = "RAM: " + str(cost)
		
	if color_rect:
		var category_colors = {
			"movement": Color.ROYAL_BLUE,
			"logic": Color.FOREST_GREEN,
			"action": Color.FIREBRICK,
			"sensor": Color.DARK_ORANGE,
			"control": Color.PURPLE
		}
		var category = data.get("category", "movement")
		var target_color = category_colors.get(category, Color.GRAY)
		
		# --- CORRECCIÓN DEL PANELCONTAINER AQUÍ ---
		var stylebox: StyleBoxFlat
		
		# Verificamos si ya le pusiste un estilo (bordes/sombras) en el editor
		if color_rect.has_theme_stylebox_override("panel"):
			# Duplicamos para no sobrescribir el estilo de otros bloques accidentalmente
			stylebox = color_rect.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		else:
			# Si por alguna razón no tiene estilo, creamos uno nuevo
			stylebox = StyleBoxFlat.new()
			stylebox.corner_radius_top_left = 8
			stylebox.corner_radius_top_right = 8
			stylebox.corner_radius_bottom_left = 8
			stylebox.corner_radius_bottom_right = 8
			
		if stylebox:
			stylebox.bg_color = target_color
			color_rect.add_theme_stylebox_override("panel", stylebox)
	
	custom_minimum_size = base_size
	size = base_size

func rescale_block(new_scale: float) -> void:
	var scaled_size = base_size * new_scale
	custom_minimum_size = scaled_size
	size = scaled_size
	
	if block_name_label:
		var base_font_size = 14
		block_name_label.add_theme_font_size_override("font_size", int(base_font_size * new_scale))

func update_visual_cost(current_real_cost: int) -> void:
	if ram_cost_label:
		ram_cost_label.text = "RAM: " + str(current_real_cost)
		var base_cost = block_data.get("ram_cost", 0)
		
		if current_real_cost > base_cost:
			ram_cost_label.add_theme_color_override("font_color", Color.GOLD)
		else:
			ram_cost_label.add_theme_color_override("font_color", Color.WHITE)

# --- SISTEMA DE DRAG & DROP ---

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var local_pos = get_local_mouse_position()
			var rect = Rect2(Vector2.ZERO, size)
			if rect.has_point(local_pos) and is_visible_in_tree():
				_start_drag(event)
				get_viewport().set_input_as_handled()
		elif is_dragging:
			_end_drag(event)
			get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion and is_dragging:
		global_position = get_global_mouse_position() - drag_offset
		emit_signal("block_dragged", self, get_global_mouse_position())
		get_viewport().set_input_as_handled()

func _start_drag(_event: InputEventMouseButton) -> void:
	if not is_in_workspace:
		_spawn_clone_for_dragging()
		return 

	is_dragging = true
	drag_offset = get_global_mouse_position() - global_position
	original_parent = get_parent() 
	original_position = global_position
	
	var interface = _find_programming_interface()
	if interface:
		var global_pos_actual = global_position
		get_parent().remove_child(self)
		interface.add_child(self)
		global_position = global_pos_actual
		move_child(self, -1)

func _spawn_clone_for_dragging() -> void:
	var clone = duplicate()
	clone.setup_block(block_data)
	clone.block_id = block_id
	clone.is_in_workspace = false
	
	var interface = _find_programming_interface()
	if interface:
		interface.add_child(clone)
		interface.move_child(clone, -1)
	else:
		get_tree().root.add_child(clone)
	
	clone.global_position = get_global_mouse_position() - (clone.size / 2)
	clone.z_index = 100 
	clone._force_start_drag()

func _force_start_drag() -> void:
	is_dragging = true
	drag_offset = size / 2
	modulate = Color(1.2, 1.2, 1.2, 0.8)
	emit_signal("block_dragged", self, get_global_mouse_position())

func _end_drag(_event: InputEvent) -> void:
	is_dragging = false
	modulate = Color.WHITE
	
	# Emitimos la señal que tenías declarada pero no se estaba usando
	emit_signal("block_dropped", self, get_global_mouse_position())
	
	var workspace_node = _find_workspace()
	
	if workspace_node and _is_over_workspace(workspace_node):
		_move_to_workspace(workspace_node)
		var interface = _find_programming_interface()
		if interface and interface.has_method("update_ram_usage"):
			interface.update_ram_usage()
	else:
		_fade_out_and_free()
		var interface = _find_programming_interface()
		if interface and interface.has_method("update_ram_usage"):
			interface.call_deferred("update_ram_usage")

func _return_to_palette() -> void:
	if original_parent:
		if get_parent():
			get_parent().remove_child(self)
		original_parent.add_child(self)
		global_position = original_position
		is_in_workspace = false
	else:
		queue_free()

func _move_to_workspace(workspace: Control) -> void:
	if get_parent():
		get_parent().remove_child(self)
	
	workspace.add_child(self)
	is_in_workspace = true
	
	position = Vector2.ZERO
	custom_minimum_size = base_size
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	visible = true
	modulate = Color.WHITE
	z_index = 0

func _fade_out_and_free() -> void:
	if is_dying: return
	is_dying = true 
	
	visible = false 
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var interface = _find_programming_interface()
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	
	tween.set_parallel(false)
	tween.finished.connect(func():
		queue_free()
		if interface and interface.has_method("update_ram_display"):
			interface.update_ram_display()
	)

# --- FUNCIONES DE BÚSQUEDA (HELPERS) ---

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

func _find_workspace() -> Control:
	var nodes_in_group = get_tree().get_nodes_in_group("workspace_dropzone")
	if nodes_in_group.size() > 0:
		return nodes_in_group[0] as Control
	
	var interface = _find_programming_interface()
	if interface:
		var dz = interface.find_child("DropZone", true, false)
		if dz: return dz as Control
			
	return get_tree().root.find_child("DropZone", true, false) as Control

func _find_programming_interface() -> Node:
	var current = get_parent()
	while current != null:
		if current.is_in_group("programming_interface") or current.has_method("setup_for_piece"):
			return current
		current = current.get_parent()
	return null

func _is_over_workspace(workspace_node: Control) -> bool:
	if not workspace_node: return false
	var rect = workspace_node.get_global_rect()
	return rect.has_point(get_global_mouse_position())
