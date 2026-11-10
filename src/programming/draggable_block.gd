extends TextureRect
class_name DraggableBlock

# Bloque arrastrable de la interfaz de programacion.
#
# El propio bloque es el unico responsable del drag & drop: decide si queda en
# el workspace (y en que posicion de la cola) o si se descarta. La interfaz
# solo escucha block_dropped para recalcular la RAM.
#
# - Desde la paleta: se arrastra un clon nuevo; el original queda en la paleta.
# - Dentro del workspace: el bloque se puede reordenar; si se suelta fuera, se
#   elimina del programa.

signal block_dragged(block: DraggableBlock, global_position: Vector2)
signal block_dropped(block: DraggableBlock, global_position: Vector2)
signal delete_requested(block: DraggableBlock)

const SCENE_PATH := "res://src/programming/draggable_block.tscn"
const PLACEHOLDER_COLOR := Color(0.55, 0.85, 1.0, 0.9)
const PLACEHOLDER_HEIGHT := 6.0

var block_id: String = ""  # Se asigna al instanciar (por ejemplo "move_f")
var base_size: Vector2 = Vector2(180, 70)
var block_data: Dictionary

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var is_in_workspace: bool = false
var is_dying: bool = false

# Linea que marca donde se va a insertar el bloque mientras se arrastra
var _placeholder: ColorRect = null

@onready var block_name_label: Label = _find_node("BlockName") as Label
@onready var ram_cost_label: Label = _find_node("RAMCost") as Label
@onready var color_rect: PanelContainer = $ColorRect as PanelContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

func _exit_tree() -> void:
	_remove_placeholder()

func setup_block(data: Dictionary) -> void:
	block_data = data

	if block_name_label:
		block_name_label.text = data.get("name", "Sin Nombre")

	if ram_cost_label:
		ram_cost_label.text = "RAM: " + str(data.get("ram_cost", 0))

	if color_rect:
		var category_colors = {
			"movement": Color.ROYAL_BLUE,
			"logic": Color.FOREST_GREEN,
			"action": Color.FIREBRICK,
			"sensor": Color.DARK_ORANGE,
			"control": Color.PURPLE
		}
		var target_color = category_colors.get(data.get("category", "movement"), Color.GRAY)

		var stylebox: StyleBoxFlat
		if color_rect.has_theme_stylebox_override("panel"):
			# Se duplica para no cambiar el estilo compartido con otros bloques
			stylebox = color_rect.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		else:
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

func update_visual_cost(current_real_cost: int) -> void:
	if ram_cost_label:
		ram_cost_label.text = "RAM: " + str(current_real_cost)
		var base_cost = block_data.get("ram_cost", 0)
		if current_real_cost > base_cost:
			ram_cost_label.add_theme_color_override("font_color", Color.GOLD)
		else:
			ram_cost_label.add_theme_color_override("font_color", Color.WHITE)

# --- DRAG & DROP ---

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not is_dragging and not is_dying and _is_mouse_over_self():
				_start_drag()
				get_viewport().set_input_as_handled()
		elif is_dragging:
			_end_drag()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_try_request_delete()

	elif event is InputEventMouseMotion and is_dragging:
		global_position = get_global_mouse_position() - drag_offset
		_update_placeholder()
		block_dragged.emit(self, get_global_mouse_position())
		get_viewport().set_input_as_handled()

# El bloque esta bajo el mouse y en una parte visible de su ScrollContainer
func _is_mouse_over_self() -> bool:
	if not is_visible_in_tree():
		return false
	if not Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
		return false
	return _is_mouse_inside_scroll_clip()

func _start_drag() -> void:
	if not is_in_workspace:
		_spawn_clone_for_dragging()
		return

	# Reordenar un bloque que ya esta en el workspace: se saca del contenedor
	# para que siga al mouse por encima de todo
	var interface = _find_programming_interface()
	if interface:
		var pos = global_position
		get_parent().remove_child(self)
		interface.add_child(self)
		global_position = pos
	_begin_drag(get_global_mouse_position() - global_position)

func _begin_drag(offset: Vector2) -> void:
	is_dragging = true
	drag_offset = offset
	z_index = 100
	modulate = Color(1.2, 1.2, 1.2, 0.8)
	block_dragged.emit(self, get_global_mouse_position())

# Crea una instancia nueva (no duplicate(): copiaria las conexiones de senal
# del bloque de la paleta) y la registra en la interfaz
func _spawn_clone_for_dragging() -> void:
	var clone: DraggableBlock = load(SCENE_PATH).instantiate()
	clone.block_id = block_id
	clone.is_in_workspace = false

	var interface = _find_programming_interface()
	if interface:
		interface.add_child(clone)
		if interface.has_method("register_block"):
			interface.register_block(clone)
	else:
		get_tree().root.add_child(clone)

	clone.setup_block(block_data.duplicate(true))
	clone.global_position = get_global_mouse_position() - clone.size / 2
	clone._begin_drag(clone.size / 2)

func _end_drag() -> void:
	is_dragging = false
	modulate = Color.WHITE
	z_index = 0

	var workspace = _find_workspace()
	if workspace and _is_over_workspace(workspace):
		var slot := get_insertion_slot(workspace, get_global_mouse_position().y)
		_remove_placeholder()
		move_to_workspace(workspace, slot)
	else:
		_remove_placeholder()
		_fade_out_and_free()

	block_dropped.emit(self, get_global_mouse_position())

# Posicion en la cola (0 = primer bloque) que corresponde a una altura global.
# Se cuentan solo los bloques reales: ni el que se arrastra ni la linea guia.
func get_insertion_slot(workspace: Control, global_y: float) -> int:
	var blocks := _workspace_blocks(workspace)
	for i in range(blocks.size()):
		var rect: Rect2 = blocks[i].get_global_rect()
		if global_y < rect.position.y + rect.size.y / 2.0:
			return i
	return blocks.size()

func move_to_workspace(workspace: Control, slot: int) -> void:
	var blocks := _workspace_blocks(workspace)
	if get_parent():
		get_parent().remove_child(self)
	workspace.add_child(self)
	if slot < blocks.size():
		workspace.move_child(self, blocks[slot].get_index())

	is_in_workspace = true
	position = Vector2.ZERO
	custom_minimum_size = base_size
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visible = true
	modulate = Color.WHITE
	z_index = 0

func _workspace_blocks(workspace: Control) -> Array:
	var result := []
	for child in workspace.get_children():
		if child is DraggableBlock and child != self and not child.is_dying and not child.is_queued_for_deletion():
			result.append(child)
	return result

# --- Linea guia de insercion ---

func _update_placeholder() -> void:
	var workspace = _find_workspace()
	if not workspace or not _is_over_workspace(workspace):
		_remove_placeholder()
		return

	if not is_instance_valid(_placeholder):
		_placeholder = ColorRect.new()
		_placeholder.name = "InsertMarker"
		_placeholder.color = PLACEHOLDER_COLOR
		_placeholder.custom_minimum_size = Vector2(0, PLACEHOLDER_HEIGHT)
		_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		workspace.add_child(_placeholder)

	var slot := get_insertion_slot(workspace, get_global_mouse_position().y)
	var blocks := _workspace_blocks(workspace)
	var target_index: int = blocks[slot].get_index() if slot < blocks.size() else workspace.get_child_count() - 1
	# move_child cuenta la propia linea; si esta antes del destino, se compensa
	if _placeholder.get_index() < target_index and slot < blocks.size():
		target_index -= 1
	if _placeholder.get_index() != target_index:
		workspace.move_child(_placeholder, target_index)

func _remove_placeholder() -> void:
	if is_instance_valid(_placeholder):
		_placeholder.get_parent().remove_child(_placeholder)
		_placeholder.queue_free()
	_placeholder = null

# --- Descartar ---

func _fade_out_and_free() -> void:
	if is_dying:
		return
	is_dying = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var interface = _find_programming_interface()
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	tween.set_parallel(false)
	tween.finished.connect(func():
		queue_free()
		if interface and is_instance_valid(interface) and interface.has_method("update_ram_display"):
			interface.update_ram_display()
	)

# --- BUSQUEDAS ---

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
	var interface = _find_programming_interface()
	if interface:
		var dz = interface.find_child("DropZone", true, false)
		if dz:
			return dz as Control
	return null

func _find_programming_interface() -> Node:
	var current = get_parent()
	while current != null:
		if current.has_method("setup_for_piece"):
			return current
		current = current.get_parent()
	return null

# Se usa el area visible del ScrollContainer, no la del DropZone: el DropZone
# puede ser mas alto que lo que se ve y su parte oculta no debe aceptar bloques
func _is_over_workspace(workspace: Control) -> bool:
	if not workspace:
		return false
	var area: Control = workspace.get_parent() if workspace.get_parent() is ScrollContainer else workspace
	return area.get_global_rect().has_point(get_global_mouse_position())

# --- Eliminar bloques personalizados (clic derecho en la paleta) ---

func _try_request_delete() -> void:
	if is_in_workspace or is_dragging or is_dying:
		return
	if not _is_mouse_over_self():
		return
	if not BlockSystem.is_deletable_block(block_id):
		return
	get_viewport().set_input_as_handled()
	delete_requested.emit(self)

# Evita que un bloque oculto por el scroll reciba el clic
func _is_mouse_inside_scroll_clip() -> bool:
	var current = get_parent()
	while current != null:
		if current is ScrollContainer:
			return current.get_global_rect().has_point(get_global_mouse_position())
		current = current.get_parent()
	return true
