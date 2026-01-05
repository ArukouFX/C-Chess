extends Control

class_name ProgrammingInterface

# Referencias
@onready var main_container = $UI/MainContainer
@onready var left_panel = $UI/MainContainer/LeftPanel
@onready var center_panel = $UI/MainContainer/CenterPanel
@onready var right_panel = $UI/MainContainer/RightPanel
@onready var block_palette = $UI/MainContainer/LeftPanel/BlockPalette
@onready var workspace = $UI/MainContainer/CenterPanel/Workspace

@onready var piece_info = $UI/MainContainer/LeftPanel/PieceInfo
@onready var ram_counter = $UI/MainContainer/RightPanel/RAMCounter
@onready var control_buttons = $UI/MainContainer/LeftPanel/ControlButtons

# Tamaños AJUSTADOS para mejor visibilidad
const BASE_SIZE = Vector2(600, 450)
const BASE_BLOCK_SIZE = Vector2(160, 50)
const BASE_FONT_SIZE = 14

# Workspace ajustado
var workspace_original_size: Vector2 = Vector2(300, 100)
var workspace_expansion_rate: int = 55
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

# Para escalado
var scale_factor: float = 1.0
var current_resolution: Vector2i = Vector2i(1360, 768)

func _ready():
	print("=== PROGRAMMING INTERFACE _ready() ===")
	
	# **NO hacer nada aquí** - dejar que setup_for_piece haga todo
	# Solo ocultar inicialmente
	visible = false
	
	# Posponer TODO para setup_for_piece
	print("Listo para ser configurado por setup_for_piece")

func setup_for_piece(piece: Node):
	print("=== setup_for_piece INICIANDO ===")
	print("Pieza: ", piece.piece_type)
	
	current_piece = piece
	
	# NUEVO: Intentar cargar desde GameManager primero
	var gm = get_node_or_null("/root/Main/GameManager")
	if gm and gm.has_method("get_piece_program"):
		var saved_script = gm.get_piece_program(piece.piece_id)
		if not saved_script.is_empty():
			current_blocks = saved_script.duplicate(true)
		else:
			current_blocks = piece.behavior_script.duplicate(true)
	else:
		current_blocks = piece.behavior_script.duplicate(true)
	
	# **ESPERAR hasta estar en el árbol y visible**
	var attempts = 0
	while attempts < 10 and (not is_inside_tree() or not visible):
		print("Esperando... ({attempts}/10) - En árbol: {is_inside_tree()}, Visible: {visible}")
		await get_tree().process_frame
		attempts += 1
	
	if attempts >= 10:
		print("ADVERTENCIA: Timeout esperando a que la interfaz esté lista")
	
	print("Interfaz lista, configurando...")
	
	current_piece = piece
	current_blocks = piece.behavior_script.duplicate() if piece.behavior_script else []
	
	# **AHORA SÍ configurar**
	_initialize_interface_components()
	
	print("=== setup_for_piece COMPLETADO ===")

func _initialize_interface_components():
	print("Inicializando componentes de interfaz...")
	
	# Obtener resolución actual
	current_resolution = Vector2i(get_viewport().get_visible_rect().size)
	print("Resolución actual: ", current_resolution)
	
	# Calcular escala
	scale_factor = _calculate_scale_factor()
	print("Factor de escala: ", scale_factor)
	
	# Aplicar tamaño escalado
	_apply_scaled_size()
	
	# Posicionar (ahora que tenemos tamaño)
	_position_at_screen_right()
	
	# Hacer visible FINALMENTE
	visible = true
	
	# Inicializar interfaz interna
	_initialize_interface()
	
	# Cargar datos
	update_piece_info()
	update_ram_display()
	load_block_palette()
	load_workspace_blocks()
	_rescale_internal_elements()
	
	print("Componentes inicializados")

func _delayed_initialize():
	print("Inicialización diferida de ProgrammingInterface")
	
	# Verificar que estamos en el árbol
	if not is_inside_tree():
		print("ERROR: No estamos en el árbol, esperando...")
		await get_tree().process_frame
		return
	
	# Obtener resolución actual
	current_resolution = Vector2i(get_viewport().get_visible_rect().size)
	print("Resolución actual: ", current_resolution)
	
	# Calcular escala
	scale_factor = _calculate_scale_factor()
	print("Factor de escala: ", scale_factor)
	
	# Aplicar tamaño escalado
	_apply_scaled_size()
	
	# Posicionar (ahora que tenemos tamaño)
	_position_at_screen_right()
	
	# Hacer visible
	visible = true
	
	# Inicializar interfaz interna
	call_deferred("_initialize_interface")

func _calculate_scale_factor() -> float:
	# Base de referencia: 768p
	var base_height = 768.0
	var current_height = float(current_resolution.y)
	
	# El factor será 1.0 en 768p, ~1.4 en 1080p y ~2.8 en 4K
	var factor = current_height / base_height
	
	# Permitimos que crezca más para pantallas de alta resolución
	return clamp(factor, 0.8, 3.0)

func _apply_scaled_size():
	# 1. Resetear la escala física del nodo a 1.0 (MUY IMPORTANTE)
	# Si el nodo tiene escala 0, sus hijos no se verán aunque midan 1000px
	self.scale = Vector2.ONE
	
	# 2. Calcular el nuevo tamaño de la caja contenedora
	var scaled_size = BASE_SIZE * scale_factor
	
	# 3. Aplicar tamaños
	custom_minimum_size = scaled_size
	size = scaled_size
	
	# 4. Forzar al MarginContainer (UI) a ocupar todo el espacio
	if has_node("UI"):
		var ui_node = $UI
		ui_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Añadir un pequeño margen interno para que no toque los bordes
		var margin = int(10 * scale_factor)
		ui_node.add_theme_constant_override("margin_left", margin)
		ui_node.add_theme_constant_override("margin_top", margin)
		ui_node.add_theme_constant_override("margin_right", margin)
		ui_node.add_theme_constant_override("margin_bottom", margin)

func _position_at_screen_right():
	var viewport_size = get_viewport().get_visible_rect().size
	var margin = 20 * scale_factor
	
	position = Vector2(
		viewport_size.x - size.x - margin,
		(viewport_size.y - size.y) / 2
	)
	
	print("Interface posicionada en: ", position)

# Conectar a cambios de resolución
func connect_to_resolution_changes():
	var main = get_node_or_null("/root/Main")
	if main and main.has_signal("resolution_changed"):
		main.resolution_changed.connect(_on_resolution_changed)
		print("Conectado a cambios de resolución")

func _on_resolution_changed(new_resolution: Vector2i):
	print("Interface: Resolución cambiada a ", new_resolution)
	
	current_resolution = new_resolution
	scale_factor = _calculate_scale_factor()
	
	# Reaplicar tamaño y posición
	_apply_scaled_size()
	_position_at_screen_right()
	
	# Reajustar elementos internos
	call_deferred("_rescale_internal_elements")

func _rescale_internal_elements():
	print("Reescalando elementos internos...")
	
	# Escalar fuentes
	_scale_fonts()
	
	# Escalar paneles
	_scale_panels()
	
	# Escalar bloques existentes
	_scale_existing_blocks()
	
	print("Elementos internos reescalados")

func _scale_fonts():
	# Buscar y escalar todos los Labels
	var labels = _find_all_labels(self)
	for label in labels:
		var current_size = label.get_theme_font_size("font_size")
		if current_size > 0:
			var new_size = int(BASE_FONT_SIZE * scale_factor)
			label.add_theme_font_size_override("font_size", new_size)

func _find_all_labels(node: Node) -> Array:
	var labels = []
	if node is Label:
		labels.append(node)
	for child in node.get_children():
		labels.append_array(_find_all_labels(child))
	return labels

func _scale_panels():
	# Escalar paneles principales con tamaños reducidos
	if left_panel:
		left_panel.custom_minimum_size.x = 160 * scale_factor  # Reducido de 200
	
	if right_panel:
		right_panel.custom_minimum_size.x = 120 * scale_factor  # Reducido de 150
	
	if workspace:
		var base_workspace_height = min_workspace_height * scale_factor
		workspace.custom_minimum_size.y = base_workspace_height
		workspace.size.y = base_workspace_height
		
		# Ancho también reducido
		workspace.custom_minimum_size.x = 80 * scale_factor  # Reducido
		workspace.size.x = 80 * scale_factor
		
		# Actualizar dropzone si existe
		var drop_zone = workspace.get_node_or_null("DropZone")
		if drop_zone:
			drop_zone.size = workspace.size
	
	# Espaciado en contenedores reducido
	if main_container is HBoxContainer:
		main_container.add_theme_constant_override("separation", int(8 * scale_factor))

func _scale_existing_blocks():
	# Escalar bloques en la paleta
	var palette_container = block_palette.get_node_or_null("ScrollContainer/GridContainer")
	if palette_container:
		for child in palette_container.get_children():
			if child is DraggableBlock:
				child.custom_minimum_size = BASE_BLOCK_SIZE * scale_factor
				child.size = child.custom_minimum_size
	
	# Escalar bloques en el workspace
	var workspace_drop = workspace.get_node_or_null("DropZone")
	if workspace_drop:
		for child in workspace_drop.get_children():
			if child is DraggableBlock:
				child.custom_minimum_size = BASE_BLOCK_SIZE * scale_factor
				child.size = child.custom_minimum_size

func _initialize_interface():
	_verify_ui_structure()
	_setup_panel_sizes()
	_connect_buttons()
	_setup_drop_zones()
	
	if workspace:
		workspace_original_size = workspace.size
		print("Workspace original size: ", workspace_original_size)

# El resto del código se mantiene igual hasta load_block_palette...

func load_block_palette():
	print("=== CARGANDO PALETA DE BLOQUES ===")
	
	if not block_palette:
		print("ERROR: block_palette no encontrado")
		return
	
	# Obtener contenedores
	var scroll_container = block_palette.get_node_or_null("ScrollContainer")
	if not scroll_container:
		print("ERROR: No hay ScrollContainer en block_palette")
		return
	
	var container = scroll_container.get_node_or_null("GridContainer")
	if not container:
		print("Creando GridContainer...")
		container = GridContainer.new()
		container.name = "GridContainer"
		scroll_container.add_child(container)
	
	# Limpiar
	for child in container.get_children():
		child.queue_free()
	
	# Configurar ScrollContainer
	scroll_container.custom_minimum_size = Vector2(200 * scale_factor, 300 * scale_factor)
	scroll_container.size = Vector2(200 * scale_factor, 300 * scale_factor)
	
	# Configurar GridContainer
	container.columns = 1
	container.add_theme_constant_override("h_separation", int(5 * scale_factor))
	container.add_theme_constant_override("v_separation", int(10 * scale_factor))
	
	# Lista de bloques (mantener igual)
	var test_blocks = [
		{"name": "Mover Adelante", "ram_cost": 2, "category": "movement", "type": "move_forward"},
		{"name": "Mover Diagonal", "ram_cost": 3, "category": "movement", "type": "move_diagonal"},
		{"name": "Capturar", "ram_cost": 3, "category": "action", "type": "capture"},
		{"name": "Si Enemigo", "ram_cost": 2, "category": "logic", "type": "if_enemy_front"},
		{"name": "Mover Atrás", "ram_cost": 2, "category": "movement", "type": "move_back"},
		{"name": "Movimiento L", "ram_cost": 4, "category": "movement", "type": "move_L"},
		{"name": "Detectar Enemigo", "ram_cost": 4, "category": "sensor", "type": "detect_enemy"},
		{"name": "Detectar Pared", "ram_cost": 2, "category": "sensor", "type": "detect_wall"},
		{"name": "Si Aliado", "ram_cost": 2, "category": "logic", "type": "if_ally_front"},
		{"name": "Repetir 3", "ram_cost": 5, "category": "control", "type": "loop_3"}
	]
	
	print("Cargando ", test_blocks.size(), " bloques")
	
	# Cargar cada bloque con tamaño escalado
	for block_data in test_blocks:
		var block_scene = preload("res://Scenes/draggable_block.tscn")
		if not block_scene:
			print("ERROR: No se puede cargar draggable_block.tscn")
			continue
		
		var block_instance = block_scene.instantiate()
		container.add_child(block_instance)
		
		if block_instance.has_method("setup_block"):
			block_instance.setup_block(block_data)
			
			# Tamaño escalado
			var scaled_block_size = BASE_BLOCK_SIZE * scale_factor
			block_instance.custom_minimum_size = scaled_block_size
			block_instance.size = scaled_block_size
			
			# Conectar señales
			if block_instance.has_signal("block_dragged"):
				block_instance.block_dragged.connect(_on_block_dragged)
			
			if block_instance.has_signal("block_dropped"):
				block_instance.block_dropped.connect(_on_block_dropped)
			
			# Asegurar que el bloque pueda recibir input
			block_instance.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			print("ERROR: bloque no tiene setup_block")
	
	print("Paleta cargada: ", container.get_child_count(), " bloques")
	print("=== FIN CARGA PALETA ===")

# En _move_block_to_target, actualizar el espaciado:
func _move_block_to_target(block: DraggableBlock, target: Control, global_pos: Vector2):
	print("Moving block to: ", target.name)
	
	# Guardar referencia al padre original
	var original_parent = block.get_parent()
	
	# Si es el workspace, organizar en columna con espaciado reducido
	if target.name == "DropZone" or "DropZone" in target.name:
		# Organizar en columna con espaciado escalado REDUCIDO
		var blocks_in_workspace = target.get_children().filter(func(child): return child is DraggableBlock)
		var block_spacing = 55 * scale_factor  # Reducido de 70
		var y_position = 15 * scale_factor + (blocks_in_workspace.size() - 1) * block_spacing  # Margen reducido
		var x_position = 15 * scale_factor  # Margen reducido
		block.position = Vector2(x_position, y_position)
	
	# Remover del padre actual
	if original_parent:
		original_parent.remove_child(block)
	
	# Agregar al nuevo destino
	target.add_child(block)
	
	# Si es el workspace, organizar en columna con espaciado escalado
	if target.name == "DropZone" or "DropZone" in target.name:
		# Organizar en columna con espaciado escalado
		var blocks_in_workspace = target.get_children().filter(func(child): return child is DraggableBlock)
		var block_spacing = 70 * scale_factor  # Espaciado escalado
		var y_position = 20 * scale_factor + (blocks_in_workspace.size() - 1) * block_spacing
		block.position = Vector2(20 * scale_factor, y_position)
		
		# Agregar a current_blocks si no está
		if not current_blocks.has(block.block_data):
			current_blocks.append(block.block_data)
			update_ram_display()
			print("Block added to current_blocks")
	else:
		# Para otros destinos, usar posición relativa
		var local_pos = global_pos - target.global_position
		block.position = local_pos
	
	# Asegurar que el bloque sea visible
	block.visible = true
	block.modulate = Color.WHITE
	
	print("Block successfully moved")
	
	# Reorganizar workspace si es necesario
	if target.name == "DropZone" or "DropZone" in target.name:
		_reposition_all_workspace_blocks()

func _reposition_all_workspace_blocks():
	var drop_zone = workspace.get_node_or_null("DropZone")
	if not drop_zone:
		print("No drop zone for repositioning")
		return
	
	var blocks = []
	var start_y = 8 * scale_factor  # Reducido
	var block_spacing = 55 * scale_factor  # Reducido de 70
	var x_position = 15 * scale_factor  # Reducido
	
	for child in drop_zone.get_children():
		if child is DraggableBlock:
			blocks.append(child)
	
	print("Repositioning ", blocks.size(), " blocks")
	
	# Ordenar por posición Y actual
	blocks.sort_custom(func(a, b): return a.position.y < b.position.y)
	
	# Reposicionar todos los bloques
	for i in range(blocks.size()):
		blocks[i].position = Vector2(x_position, start_y + i * block_spacing)
	
	print("Blocks repositioned")
	
	_expand_workspace_if_needed()

func _expand_workspace_if_needed():
	if not workspace:
		return
	
	var new_height = _calculate_workspace_height()
	
	# Escalar límites máximos y mínimos
	var scaled_min_height = min_workspace_height * scale_factor
	var scaled_max_height = max_workspace_height * scale_factor
	
	new_height = clamp(new_height, scaled_min_height, scaled_max_height)
	
	if new_height != workspace.size.y:
		workspace.custom_minimum_size.y = new_height
		workspace.size.y = new_height
		
		var drop_zone = workspace.get_node_or_null("DropZone")
		if drop_zone:
			drop_zone.custom_minimum_size.y = new_height
			drop_zone.size.y = new_height
		print("Workspace auto-resized to: ", new_height, " (blocks: ", _get_workspace_block_count(), ")")

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
	# Tamaños fijos - eliminar escalado
	if main_container is HBoxContainer:
		main_container.add_theme_constant_override("separation", 10)
	
	if block_palette:
		block_palette.custom_minimum_size = Vector2(200, 300)
		block_palette.size = Vector2(200, 300)
	
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

func _update_scroll_container(scroll_container: ScrollContainer):
	# Solo forzar redibujado, no configurar propiedades problemáticas
	scroll_container.queue_redraw()
	if scroll_container.has_node("GridContainer"):
		var container = scroll_container.get_node("GridContainer")
		container.queue_redraw()

func load_workspace_blocks():
	var workspace_area = workspace.get_node_or_null("DropZone")
	if not workspace_area:
		print("No workspace area found, creating...")
		workspace_area = _create_drop_zone()
	
	# Limpiar workspace
	for child in workspace_area.get_children():
		if child is DraggableBlock:
			child.queue_free()
	
	# Cargar bloques guardados
	if current_piece and not current_piece.behavior_script.is_empty():
		print("Loading ", current_piece.behavior_script.size(), " saved blocks for piece")
		for block_data in current_piece.behavior_script:
			var block_instance = DraggableBlockScene.instantiate()
			workspace_area.add_child(block_instance)
			block_instance.setup_block(block_data)
			block_instance.mouse_filter = Control.MOUSE_FILTER_STOP
			
			# Conectar señales
			if block_instance.has_signal("block_dragged"):
				block_instance.block_dragged.connect(_on_block_dragged)
			
			if block_instance.has_signal("block_dropped"):
				block_instance.block_dropped.connect(_on_block_dropped)
		
		_reposition_all_workspace_blocks()
	
	print("Workspace ready - DropZone child count: ", workspace_area.get_child_count())

func _create_drop_zone() -> Control:
	var drop_zone = ColorRect.new()
	drop_zone.name = "DropZone"
	drop_zone.z_index = 10
	drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop_zone.color = Color(0.8, 0.2, 0.2, 0.3)
	
	if workspace:
		drop_zone.size = workspace.size
		drop_zone.custom_minimum_size = workspace.size
		workspace.add_child(drop_zone)
		print("DropZone created with size: ", drop_zone.size)
	
	# Agregar a drop_zones
	drop_zones.append(drop_zone)
	
	return drop_zone

func update_piece_info():
	if not current_piece or not piece_info:
		print("No current piece or piece_info node")
		return
	
	print("Updating piece info for: ", current_piece.piece_type)
	
	# Buscar estructura jerárquica
	var hbox = piece_info.get_node_or_null("HBoxContainer")
	if not hbox:
		print("HBoxContainer not found in PieceInfo")
		return
	
	# Actualizar textura
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
	
	# Actualizar labels
	if piece_name_label:
		piece_name_label.text = piece_name
	
	if piece_type_label:
		piece_type_label.text = ram_info
	
	if piece_status_label:
		piece_status_label.text = status_info

func update_ram_display():
	if not current_piece or not piece_info:
		return
	
	var hbox = piece_info.get_node_or_null("HBoxContainer")
	if not hbox: return
	
	var texture_rect = hbox.get_node_or_null("TextureRect")
	
	# --- CORRECCIÓN AQUÍ ---
	if texture_rect:
		if current_piece.get("texture"):
			# Asignamos la textura pero nos aseguramos que no sea nula
			texture_rect.texture = current_piece.texture
		else:
			# Si la pieza no tiene textura, podrías estar intentando 
			# acceder a un nodo que no ha cargado. Usamos el sprite de la pieza:
			var piece_sprite = current_piece.get_node_or_null("Sprite2D")
			if piece_sprite:
				texture_rect.texture = piece_sprite.texture
	# -----------------------
	
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
			if BlockSystem:
				var block_info = BlockSystem.get_block_info(block_data["type"])
				total += block_info.get("ram_cost", 0)
	print("Calculated RAM usage: ", total)
	return total

func _on_block_dragged(block: DraggableBlock, global_pos: Vector2):
	print("BLOCK DRAGGED: ", block.block_data["name"])
	currently_dragging_block = block
	_highlight_drop_zones(true)

func _on_block_dropped(block: DraggableBlock, global_pos: Vector2):
	print("BLOCK DROPPED: ", block.block_data["name"])
	currently_dragging_block = null
	
	# Buscar el dropzone más cercano
	var target_drop_zone = _get_drop_zone_at_position(global_pos)
	
	if target_drop_zone:
		print("Dropped on drop zone: ", target_drop_zone.name)
		_move_block_to_target(block, target_drop_zone, global_pos)
	else:
		print("No valid drop zone found, returning to palette")
		_return_block_to_palette(block)
	
	_highlight_drop_zones(false)

func _get_drop_zone_at_position(global_pos: Vector2) -> Control:
	for drop_zone in drop_zones:
		if drop_zone and is_instance_valid(drop_zone):
			var zone_rect = drop_zone.get_global_rect()
			var block_center = global_pos
			
			if zone_rect.has_point(block_center):
				return drop_zone
	return null

func _return_block_to_palette(block: DraggableBlock):
	print("Returning block to palette")
	
	var palette_container = block_palette.get_node_or_null("ScrollContainer/GridContainer")
	if not palette_container:
		print("ERROR: Palette container not found")
		return
	
	# Remover del padre actual
	if block.get_parent():
		block.get_parent().remove_child(block)
	
	# Agregar a la paleta
	palette_container.add_child(block)
	
	# Posición aproximada en la paleta
	block.position = Vector2(10, 10 + palette_container.get_child_count() * 70)
	
	# Remover de current_blocks si estaba
	if current_blocks.has(block.block_data):
		current_blocks.erase(block.block_data)
		update_ram_display()
	
	print("Block returned to palette")

func _get_workspace_block_count() -> int:
	var drop_zone = workspace.get_node_or_null("DropZone")
	if not drop_zone:
		return 0
	
	var count = 0
	for child in drop_zone.get_children():
		if child is DraggableBlock:
			count += 1
	return count

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
	
	var required_height = max_y + 20  # Margen adicional
	return clamp(required_height, min_workspace_height, max_workspace_height)

func _highlight_drop_zones(highlight: bool):
	for drop_zone in drop_zones:
		if drop_zone is ColorRect:
			if highlight:
				drop_zone.color = Color(0.3, 0.5, 0.8, 0.5)
			else:
				drop_zone.color = Color(0.2, 0.2, 0.2, 0.3)

# === Funcionalidad de Botones ===
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
	if current_piece:
		var final_blocks = []
		
		# Usamos la referencia que ya definiste en tus @onready al principio del script
		# En tu caso es: workspace -> que apunta a $UI/MainContainer/CenterPanel/Workspace
		var drop_zone = workspace.get_node_or_null("DropZone")
		
		if drop_zone:
			# 1. Filtramos solo los nodos que son DraggableBlock
			var children = []
			for child in drop_zone.get_children():
				if child is DraggableBlock:
					children.append(child)
			
			# 2. Ordenamos por posición Y (ejecución de arriba hacia abajo)
			children.sort_custom(func(a, b): return a.position.y < b.position.y)
			
			for block in children:
				if not block.block_data.is_empty():
					final_blocks.append(block.block_data)
		
		# 3. BUSCAR EL GAMEMANAGER (Esta es la solución al error de Identifier not declared)
		var gm = get_node_or_null("/root/Main/GameManager")
		
		if gm:
			# Guardamos el programa en el diccionario central del GM
			gm.save_piece_program(current_piece, final_blocks)
			
			# OPCIONAL: Para el test del peón, si quieres que se mueva JUSTO al guardar
			# puedes descomentar la siguiente línea:
			# gm.execute_piece_program(current_piece)
		else:
			print("ERROR: No se pudo encontrar el GameManager en /root/Main/GameManager")
		
		# 4. Actualizar la pieza localmente
		if current_piece.has_method("update_programming"):
			current_piece.update_programming(final_blocks)
		
		print("--- GUARDADO EXITOSO ---")
		print("Pieza ID: ", current_piece.get_instance_id())
		print("Bloques: ", final_blocks) 
		
		_close_interface()

func _on_cancel_button_pressed():
	print("Cancelling programming...")
	_close_interface()

func _close_interface():
	print("Closing programming interface...")
	
	# Notificar al GameManager
	var game_manager = get_node_or_null("/root/Main/GameManager")
	if game_manager and game_manager.has_method("_on_programming_interface_closed"):
		game_manager._on_programming_interface_closed()
	
	# Limpiar estado
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
	# ESC para cerrar
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_interface()
		get_viewport().set_input_as_handled()
