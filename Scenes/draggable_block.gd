extends TextureRect

class_name DraggableBlock

signal block_dragged(block, global_position)
signal block_dropped(block, global_position)

var block_id: String = "move_forward" # Esto se debería asignar al instanciar el bloque
func get_block_type() -> String:
	return block_id

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
	
	# Usamos data.get("llave", "valor_por_defecto") para evitar el error
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
		color_rect.color = category_colors.get(category, Color.GRAY)
	
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

func _start_drag(event: InputEventMouseButton):
	# Si el bloque está en la paleta (no en el workspace)
	if not is_in_workspace:
		_spawn_clone_for_dragging()
		return # Detenemos el drag del bloque original

	# Lógica normal para bloques que YA están en el workspace
	is_dragging = true
	drag_offset = get_global_mouse_position() - global_position
	# ... resto de tu código original ...

func _spawn_clone_for_dragging():
	var clone = duplicate()
	clone.setup_block(block_data)
	clone.block_id = block_id
	
	var interface = _find_programming_interface()
	if interface:
		# Lo añadimos a la interfaz para que herede su CanvasLayer (si tiene)
		interface.add_child(clone)
		# ¡IMPORTANTE! Forzamos que sea el último hijo para estar al frente
		interface.move_child(clone, -1)
	else:
		get_tree().root.add_child(clone)
	
	# Usamos global_position para ignorar offsets de padres
	clone.global_position = get_global_mouse_position() - (clone.size / 2)
	clone.z_index = 100 
	clone._force_start_drag()

func _force_start_drag():
	is_dragging = true
	drag_offset = size / 2
	modulate = Color(1.2, 1.2, 1.2, 0.8) # Un poco de transparencia ayuda
	emit_signal("block_dragged", self, get_global_mouse_position())

func _end_drag(event):
	is_dragging = false
	
	var workspace_node = _find_workspace()
	if workspace_node and _is_over_workspace(workspace_node):
		_move_to_workspace(workspace_node)
	else:
		# Si el bloque es un clon recién sacado de la paleta y no cayó en el sitio
		# lo eliminamos para no llenar la pantalla de basura
		queue_free()

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
	# 1. Intentar por Grupo (La forma más robusta en Godot)
	var nodes_in_group = get_tree().get_nodes_in_group("workspace_dropzone")
	if nodes_in_group.size() > 0:
		return nodes_in_group[0]
	
	# 2. Si falla el grupo, buscar a través de la interfaz padre
	var interface = _find_programming_interface()
	if interface:
		# find_child con el parámetro 'true' busca recursivamente en todos los hijos
		var dz = interface.find_child("DropZone", true, false)
		if dz:
			return dz
			
	# 3. Último recurso: Búsqueda global por nombre (lenta pero segura)
	return get_tree().root.find_child("DropZone", true, false)

func _find_programming_interface() -> Node:
	# Subimos por el árbol de nodos hasta encontrar la interfaz
	var current = get_parent()
	while current != null:
		# Verificamos si es la interfaz por grupo o por método conocido
		if current.is_in_group("programming_interface") or current.has_method("setup_for_piece"):
			return current
		current = current.get_parent()
	return null

func _is_over_workspace(workspace_node: Control) -> bool:
	if not workspace_node: return false
	# get_global_rect() tiene en cuenta la posición real en la pantalla
	# sumada al scroll actual.
	var rect = workspace_node.get_global_rect()
	return rect.has_point(get_global_mouse_position())

func _move_to_workspace(workspace: Control):
	if get_parent():
		get_parent().remove_child(self)
	
	workspace.add_child(self)
	is_in_workspace = true
	
	# RESETEAR PARA CONTENEDOR
	# Al ser hijo de un VBoxContainer, estas propiedades deben estar limpias
	position = Vector2.ZERO
	custom_minimum_size = base_size # El tamaño que definimos al inicio
	
	# Importante: Para que el VBoxContainer lo maneje, el layout_mode debe ser 0
	# y los size_flags deben permitir el llenado horizontal
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Visuales
	visible = true
	modulate = Color.WHITE
	z_index = 0
	
	print("Bloque auto-posicionado por VBoxContainer")
