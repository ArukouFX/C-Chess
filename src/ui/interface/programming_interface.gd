extends Control

class_name ProgrammingInterface

var LoopPopupScene = preload("res://src/ui/interface/loop_name_popup.tscn")

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
@onready var loop_button = $UI/MainContainer/CenterPanel/Loop

# Tamaños y Constantes
const BASE_SIZE = Vector2(600, 450)
const BASE_BLOCK_SIZE = Vector2(160, 50)
const BASE_FONT_SIZE = 14
var min_workspace_height: int = 100

# Variables para el redimensionamiento del Workspace
var workspace_original_size: Vector2 = Vector2.ZERO
var max_workspace_height: int = 500

# Variables para arrastrar la ventana completa
var is_dragging_interface: bool = false
var drag_interface_offset: Vector2 = Vector2.ZERO

# State
var current_piece: Node = null
var current_blocks: Array = []
var currently_dragging_block: DraggableBlock = null
var drop_zones: Array[Control] = []
var DraggableBlockScene = preload("res://src/programming/draggable_block.tscn")

# Para escalado
var scale_factor: float = 1.0
var current_resolution: Vector2i = Vector2i(1360, 768)

func _ready():
	# Buscamos el contador de RAM relativo a este nodo exacto
	ram_counter = find_child("RAMCounter", true, false)
	
	visible = false
	print("=== PROGRAMMING INTERFACE _ready() ===")

func setup_for_piece(piece: Node):
	print("=== setup_for_piece INICIANDO ===")
	current_piece = piece
	
	# 1. Recuperar del GameManager ANTES de mostrar nada
	var gm = get_node_or_null("/root/Main/GameManager")
	if gm and current_piece:
		# CORRECCIÓN: Pasamos el piece_id (String), no el nodo entero
		# Y nos aseguramos de que el GameManager guarde los datos en su diccionario
		gm.saved_programs[current_piece.piece_id] = current_blocks.duplicate(true)
		
		# Si además tu pieza tiene la variable local (para la fase de ejecución)
		current_piece.behavior_script = current_blocks.duplicate(true)
		current_piece.is_programmed = not current_blocks.is_empty()

	# 2. Esperar a que la interfaz esté lista en el árbol
	visible = true # Activamos visibilidad para que Godot la procese
	var attempts = 0
	while attempts < 10 and not is_inside_tree():
		await get_tree().process_frame
		attempts += 1
	
	# 3. Disparar construcción de la interfaz
	_initialize_interface_logic()

func force_save_to_gamemanager():
	# 1. Limpiamos la lista local y la reconstruimos desde los nodos reales
	update_blocks_from_workspace()
	
	# 2. Informamos al GameManager con la ruta de escena correcta
	var gm = get_node_or_null("/root/Main/GameManager") # <--- CORREGIDO
	if gm and current_piece:
		gm.saved_programs[current_piece.piece_id] = current_blocks.duplicate(true)
		print("Sincronización forzada para: ", current_piece.piece_id, " Bloques: ", current_blocks.size())

func _initialize_interface_logic():
	# 1. Configuración física
	current_resolution = Vector2i(get_viewport().get_visible_rect().size)
	scale_factor = _calculate_scale_factor()
	_apply_scaled_size()
	_position_at_screen_right()
	
	# 2. Vincular el DropZone y configurar señales reactivas
	var dz = find_child("DropZone", true, false)
	if dz:
		workspace = dz
		# Usamos child_order_changed porque detecta entradas, salidas y reordenamientos
		if not dz.child_order_changed.is_connected(update_ram_display):
			dz.child_order_changed.connect(update_ram_display)
		
		# Opcional: child_entered_tree por si acaso el reordenamiento no basta
		if not dz.child_entered_tree.is_connected(_on_workspace_changed):
			dz.child_entered_tree.connect(_on_workspace_changed)
			
		print("Sistema reactivo de RAM conectado al DropZone")
	
	# 3. Asegurar referencia al contador de RAM
	if not ram_counter:
		ram_counter = find_child("RAMCounter", true, false)
	
	# 4. Conexiones y carga de datos
	_connect_buttons()
	update_piece_info()
	load_block_palette()
	
	# 5. CARGA CRÍTICA
	load_workspace_blocks() 
	
	
	# Actualización inicial forzada
	update_ram_display()
	visible = true

func load_workspace_blocks():
	# Si no tenemos el DropZone vinculado, lo buscamos ahora
	if not workspace:
		workspace = find_child("DropZone", true, false)
	if not workspace: 
		print("ERROR CRÍTICO: No hay zona de soltado para contar RAM")
		return
	# Limpiar hijos actuales
	for child in workspace.get_children():
		if child is DraggableBlock:
			child.queue_free()
	print("Instanciando bloques en UI: ", current_blocks.size())
	for data in current_blocks:
		var block_instance = DraggableBlockScene.instantiate()
		workspace.add_child(block_instance)
		block_instance.is_in_workspace = true
		# Setup visual
		block_instance.custom_minimum_size = BASE_BLOCK_SIZE * scale_factor
		block_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Recuperar info completa del sistema de bloques
		var full_info = BlockSystem.get_block_info(data["type"])
		var setup_data = full_info.duplicate(true)
		# IMPORTANTE
		setup_data["type"] = data["type"]
		# Si el bloque tiene contained_blocks
		# preservarlos
		if data.has("contained_blocks"):
			setup_data["contained_blocks"] = data["contained_blocks"]
		block_instance.setup_block(setup_data)
		block_instance.block_id = data["type"]
		block_instance.block_data = setup_data
		# Conectar para poder moverlos de nuevo
		block_instance.block_dragged.connect(_on_block_dragged)
		block_instance.block_dropped.connect(_on_block_dropped)
	# Forzar actualización de RAM tras cargar
	update_ram_display()
# En programming_interface.gd

func update_ram_display():
	if not current_piece: return
	
	var used_ram = 0
	var found_blocks_count = 0
	var movement_blocks_count = 0 # <-- NUEVO: Contador de hilos de movimiento cargados
	var new_blocks_list = []
	
	# 1. Acceder al DropZone para evaluar los nodos actuales
	var dz = find_child("DropZone", true, false)
	if dz:
		for child in dz.get_children():
			# FILTRO CRÍTICO
			if child is DraggableBlock and child.visible and not child.is_queued_for_deletion():
				if not child.get("is_dying"):
					found_blocks_count += 1
					
					# Obtener información base del sistema estático
					var info = BlockSystem.get_block_info(child.block_id)
					var base_cost = info.get("ram_cost", 0)
					var current_block_cost = base_cost
					
					# --- LÓGICA DEL IMPUESTO INCREMENTAL (+1 por movimiento previo) ---
					if info.get("category") == "movement":
						var tax = movement_blocks_count * 1
						current_block_cost = base_cost + tax
						movement_blocks_count += 1 # Registramos este bloque para el recargo del próximo
					
					# Acumulamos el coste calculado con impuesto
					used_ram += current_block_cost
					
					# Actualizamos el texto en el nodo visual del bloque de forma reactiva
					if child.has_method("update_visual_cost"):
						child.update_visual_cost(current_block_cost)
					
					# Añadimos a la lista limpia que persistirá
					if child.block_data:
						new_blocks_list.append(
							child.block_data.duplicate(true)
						)
					else:
						new_blocks_list.append({
							"type": child.block_id
						})

	# 2. Sincronizar la verdad con los datos locales
	current_blocks = new_blocks_list

	# 3. ACTUALIZAR GAMEMANAGER AUTOMÁTICAMENTE (Usando la corrección estricta de ID)
	var gm = get_node_or_null("/root/Main/GameManager")
	if gm and current_piece:
		gm.saved_programs[current_piece.piece_id] = current_blocks.duplicate(true)

	# 4. ACTUALIZACIÓN VISUAL DEL CONTADOR DE LA INTERFAZ
	if ram_counter:
		var used_label = ram_counter.find_child("RAMUsed", true, false)
		var total_label = ram_counter.find_child("RAMTotal", true, false)
		
		if used_label:
			used_label.text = str(used_ram)
			
			# Feedback de desbordamiento de memoria
			if used_ram > current_piece.available_ram:
				used_label.add_theme_color_override("font_color", Color.RED)
			else:
				used_label.add_theme_color_override("font_color", Color.WHITE)
		if total_label:
			total_label.text = str(current_piece.available_ram)

	print("SINCRO GLOBAL -> Bloques: ", found_blocks_count, " RAM: ", used_ram, "/", current_piece.available_ram)
	update_piece_info()

func calculate_current_ram_usage() -> int:
	var total_ram = 0
	var movement_block_count = 0 # Contador de bloques de movimiento en este script

	for block_data in current_blocks:
		if block_data.has("type"):
			var info = BlockSystem.get_block_info(block_data["type"])
			var base_cost = info.get("ram_cost", 0)
			
			# Si el bloque pertenece a la categoría de movimiento
			if info.get("category") == "movement":
				# El coste es el base + la cantidad de movimientos previos en la cola
				var incremental_tax = movement_block_count * 1
				total_ram += (base_cost + incremental_tax)
				
				# Registramos este bloque para que el siguiente pague el impuesto
				movement_block_count += 1
			else:
				# Bloques de lógica, sensores o acciones pagan tarifa plana normal
				total_ram += base_cost
				
	return total_ram

func update_blocks_from_workspace():
	current_blocks.clear()
	if workspace:
		for child in workspace.get_children():
			if child is DraggableBlock:
				# Intentamos obtener el ID de varias formas para estar seguros
				var id = ""
				if child.block_id != "": id = child.block_id
				elif child.block_data and child.block_data.has("type"): id = child.block_data["type"]
				
				if id != "":
					current_blocks.append({"type": id})
					# Sincronizamos de vuelta al nodo por si acaso
					child.block_id = id 
	
	# Esto actualiza el RAMCounter visualmente
	update_ram_display()

# --- FUNCIONES DE SOPORTE REUTILIZADAS ---

func _calculate_scale_factor() -> float:
	return clamp(float(current_resolution.y) / 768.0, 0.8, 3.0)

func _apply_scaled_size():
	self.scale = Vector2.ONE
	var scaled_size = BASE_SIZE * scale_factor
	custom_minimum_size = scaled_size
	size = scaled_size

func _position_at_screen_right():
	var viewport_size = get_viewport().get_visible_rect().size
	position = Vector2(viewport_size.x - size.x - 20, (viewport_size.y - size.y) / 2)

func _connect_buttons():
	# Usamos un patrón seguro para evitar múltiples conexiones
	
	var buttons = {
		"TestButton": _on_test_button_pressed,
		"SaveButton": _on_save_button_pressed,
		"CancelButton": _on_cancel_button_pressed
	}
	for b_name in buttons:
		var btn = control_buttons.find_child(b_name, true, false)
		if btn and not btn.pressed.is_connected(buttons[b_name]):
			btn.pressed.connect(buttons[b_name])

# --- EVENTOS DE ARRASTRE ---

func _on_block_dropped(block: DraggableBlock, global_pos: Vector2):
	var target_drop_zone = _get_drop_zone_at_position(global_pos)
	
	if target_drop_zone:
		_move_block_to_target(block, target_drop_zone, global_pos)
		print("Bloque soltado en Workspace físicamente")
	else:
		_return_block_to_palette(block)
	
	# Esto es lo más importante: 
	# Forzamos la actualización de la RAM un frame después 
	# para que el VBoxContainer ya tenga al niño en su lista.
	get_tree().process_frame.connect(update_ram_display, CONNECT_ONE_SHOT)

func _move_block_to_target(block: DraggableBlock, target: Control, _pos: Vector2):
	if block.get_parent(): 
		block.get_parent().remove_child(block)
	
	# 'target' debe ser el DropZone
	target.add_child(block)
	
	# Forzamos que se vea bien en el VBoxContainer
	block.custom_minimum_size = BASE_BLOCK_SIZE * scale_factor
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL

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
	# Buscamos el VBoxContainer donde realmente caen los bloques
	var dz = find_child("DropZone", true, false)
	if dz:
		workspace = dz  # <-- Ahora 'workspace' es el VBoxContainer
		drop_zones = [dz]
		print("Sincronización: Workspace vinculado a ", dz.get_path())
	else:
		# Si no existe DropZone, usamos el panel central pero avisamos
		workspace = $UI/MainContainer/CenterPanel/Workspace
		drop_zones = [workspace]
		print("ALERTA: Usando Workspace por defecto, no se halló DropZone")

func load_block_palette():
	print("=== CARGANDO PALETA DESDE BLOCKSYSTEM ===")
	
	if not block_palette:
		print("ERROR: block_palette no encontrado")
		return
	
	# 1. Obtener o crear contenedores
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
	
	# 2. Limpiar bloques previos
	for child in container.get_children():
		child.queue_free()
	
	container.columns = 1
	container.add_theme_constant_override("h_separation", int(5 * scale_factor))
	container.add_theme_constant_override("v_separation", int(10 * scale_factor))
	
	# 4. CARGA DINÁMICA DESDE EL SISTEMA
	# Iteramos sobre las llaves definidas en block_system.gd
	var all_block_types = BlockSystem.block_definitions.keys()
	print("Cargando ", all_block_types.size(), " bloques desde BlockSystem")
	
	for type_id in all_block_types:
		# Obtenemos la información base del diccionario estático
		var block_data = BlockSystem.get_block_info(type_id)
		
		# Instanciar el bloque visual
		var block_instance = DraggableBlockScene.instantiate()
		container.add_child(block_instance)
		
		# Preparar datos: inyectamos el type_id para que el bloque sepa qué comando representa
		var setup_data = block_data.duplicate()
		setup_data["type"] = type_id 
		
		# Configuración de lógica y datos del bloque
		block_instance.block_id = type_id
		if block_instance.has_method("setup_block"):
			block_instance.setup_block(setup_data)
		
		# 5. Configuración visual individual y escalado
		var scaled_block_size = BASE_BLOCK_SIZE * scale_factor
		block_instance.custom_minimum_size = scaled_block_size
		block_instance.size = scaled_block_size
		block_instance.mouse_filter = Control.MOUSE_FILTER_STOP
		
		# 6. Conexión de señales de arrastre
		if not block_instance.block_dragged.is_connected(_on_block_dragged):
			block_instance.block_dragged.connect(_on_block_dragged)
		
		if not block_instance.block_dropped.is_connected(_on_block_dropped):
			block_instance.block_dropped.connect(_on_block_dropped)
	
	print("Paleta cargada exitosamente: ", container.get_child_count(), " bloques")
	print("=== FIN CARGA PALETA ===")

func _setup_drop_zones():
	# Limpiamos la lista para no acumular zonas fantasma
	drop_zones.clear()
	
	# Usamos el workspace que encontramos en _initialize_interface
	if workspace:
		workspace.mouse_filter = Control.MOUSE_FILTER_PASS
		# Agregamos el workspace real a la lista de colisiones
		drop_zones.append(workspace)
		print("DropZone manual añadido a la lista de detección.")

# Borra el contenido de esta función o coméntala, ya no la necesitamos
func _create_drop_zone() -> Control:
	return workspace

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

func _update_scroll_container(scroll_container: ScrollContainer):
	# Solo forzar redibujado, no configurar propiedades problemáticas
	scroll_container.queue_redraw()
	if scroll_container.has_node("GridContainer"):
		var container = scroll_container.get_node("GridContainer")
		container.queue_redraw()

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
	
	# Vbox container info
	var vbox = hbox.get_node_or_null("VBoxContainer")
	if not vbox:
		print("VBoxContainer not found")
		return
	
	var piece_name_label = vbox.get_node_or_null("PieceName")
	var piece_type_label = vbox.get_node_or_null("PieceType") 
	var piece_status_label = vbox.get_node_or_null("PieceStatus")
	
	# --- NUEVA LÓGICA DE ESTADO ---
	var status_info = ""
	if current_blocks.is_empty():
		status_info = "No programs"
	else:
		status_info = "Installed (%d)" % current_blocks.size()
	# ------------------------------
	
	var piece_name = "%s %s" % [current_piece.piece_color.capitalize(), current_piece.piece_type.capitalize()]
	var ram_info = "Total RAM: %d" % current_piece.available_ram
	
	# Actualizar labels
	if piece_name_label:
		piece_name_label.text = piece_name
	
	if piece_type_label:
		piece_type_label.text = ram_info
	
	if piece_status_label:
		piece_status_label.text = status_info
		# Opcional: Cambiar color si hay programas
		if not current_blocks.is_empty():
			piece_status_label.add_theme_color_override("font_color", Color.GREEN_YELLOW)
		else:
			piece_status_label.add_theme_color_override("font_color", Color.WHITE)

func _on_block_dragged(block: DraggableBlock, global_pos: Vector2):
	print("BLOCK DRAGGED: ", block.block_data["name"])
	currently_dragging_block = block
	_highlight_drop_zones(true)

func _get_drop_zone_at_position(global_pos: Vector2) -> Control:
	for drop_zone in drop_zones:
		if drop_zone and is_instance_valid(drop_zone):
			var zone_rect = drop_zone.get_global_rect()
			print("Comprobando zona: ", drop_zone.name, " Rect: ", zone_rect, " Mouse: ", global_pos)
			if zone_rect.has_point(global_pos):
				return drop_zone
	return null

func _return_block_to_palette(block: DraggableBlock):
	var palette_container = block_palette.get_node_or_null("ScrollContainer/GridContainer")
	if not palette_container: return
	
	if block.get_parent():
		block.get_parent().remove_child(block)
	
	palette_container.add_child(block)
	
	# Forzamos actualización de RAM al sacar el bloque del workspace
	await get_tree().process_frame
	update_blocks_from_workspace()

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

# === Funcionalidad de Botones ===
func _on_test_button_pressed():
	# 1. Asegurarnos de que los datos están sincronizados con lo que se ve en pantalla
	update_blocks_from_workspace()
	
	if current_blocks.is_empty():
		print("AVISO: No hay bloques para ejecutar.")
		return

	# 2. VALIDACIÓN DE RAM: Si se pasa del límite, abortamos ejecución
	var used_ram = calculate_current_ram_usage()
	if used_ram > current_piece.available_ram:
		print("ERROR: RAM insuficiente (%d/%d). Reduce los bloques." % [used_ram, current_piece.available_ram])
		# Aquí podrías añadir un efecto visual al RAMCounter para que parpadee en rojo
		return

	var gm = get_node_or_null("/root/Main/GameManager")
	if gm and current_piece:
		# Guardamos formalmente antes de ejecutar
		gm.save_piece_program(current_piece, current_blocks)
		print("Ejecutando programa para: ", current_piece.piece_type)
		
		# Cerramos primero para limpiar la UI y luego disparamos el turno
		_close_interface()
		await gm.execute_turn_and_switch()

func _on_save_button_pressed():
	update_blocks_from_workspace()
	
	if current_piece and is_instance_valid(current_piece):
		current_piece.behavior_script = current_blocks.duplicate(true)
		current_piece.is_programmed = not current_blocks.is_empty()
		
		var gm = get_node_or_null("/root/Main/GameManager")
		if gm:
			gm.saved_programs[current_piece.piece_id] = current_blocks.duplicate(true)
			print("Guardado exitoso en GM para ", current_piece.piece_id, ". Bloques: ", current_blocks.size())
			
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

func _on_workspace_changed(_node):
	# Esperamos un frame para que el nodo esté totalmente integrado
	await get_tree().process_frame
	update_ram_display()


func _on_drop_zone_child_order_changed() -> void:
	# Verificamos si el nodo aún es parte del árbol de escenas
	if not is_inside_tree(): 
		return
		
	# Intentamos obtener el tree de forma segura
	var tree = get_tree()
	if tree:
		await tree.process_frame
		# Doble verificación después del await (por si se cerró durante la espera)
		if is_inside_tree():
			update_ram_display()
			print("Detectado cambio en la jerarquía del Workspace. RAM recalculada.")

#Loop button
func _on_loop_pressed() -> void:
	update_blocks_from_workspace()
	if current_blocks.is_empty():
		print("No hay bloques para guardar en loop")
		return
	var popup = LoopPopupScene.instantiate()
	add_child(popup)
	popup.popup_centered()
	popup.loop_confirmed.connect(
		_on_loop_name_confirmed
	)

func _on_loop_name_confirmed(loop_name: String):
	update_blocks_from_workspace()
	if current_blocks.is_empty():
		print("No hay bloques para guardar en loop")
		return
	var loop_blocks := []
	for block in current_blocks:
		if block.has("type"):
			loop_blocks.append({
				"type": block["type"]
			})
	var loop_ram = calculate_current_ram_usage()
	var loop_id = BlockSystem.create_loop_block(
		loop_blocks,
		loop_ram,
		loop_name
	)
	print("Loop guardado: ", loop_id)
	load_block_palette()
