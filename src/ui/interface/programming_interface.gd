extends Control

class_name ProgrammingInterface

# Interfaz para programar una pieza con bloques.
#
# Flujo:
#   1. GameManager la crea y llama a setup_for_piece(pieza, game_manager).
#   2. El workspace muestra el programa guardado de la pieza (si tiene).
#   3. Los cambios quedan solo en la interfaz hasta presionar "Ejecutar":
#      ahi se guardan con GameManager.save_piece_program y se juega el turno.
#      "Cancelar" (o ESC) cierra sin guardar nada.
#
# Formato de programa: lista de {"type": id}, igual en workspace, guardado,
# loops y escapes. El contenido de loops y escapes vive en BlockSystem.

const NamePopupScene = preload("res://src/ui/interface/name_popup.tscn")
const DraggableBlockScene = preload("res://src/programming/draggable_block.tscn")

const BASE_SIZE = Vector2(600, 450)

# Referencias
@onready var block_palette = $UI/MainContainer/LeftPanel/BlockPalette
@onready var workspace: VBoxContainer = $UI/MainContainer/CenterPanel/Workspace/ScrollContainer/DropZone
@onready var piece_info = $UI/MainContainer/LeftPanel/PieceInfo
@onready var ram_counter = $UI/MainContainer/LeftPanel/PieceInfo/HBoxContainer/VBoxContainer/RAMCounter
@onready var control_buttons = $UI/MainContainer/CenterPanel/ControlButtons

# Arrastre de la ventana completa
var is_dragging_interface: bool = false
var drag_interface_offset: Vector2 = Vector2.ZERO

# Estado
var current_piece: Node = null
var current_blocks: Array = []
var currently_dragging_block: DraggableBlock = null
var game_manager: Node = null

var _ram_update_pending: bool = false

func _ready():
	visible = false

func setup_for_piece(piece: Node, gm: Node = null):
	current_piece = piece
	game_manager = gm

	# Programa guardado de la pieza: se muestra para editarlo o repetirlo
	var manager = _gm()
	current_blocks = manager.get_program_for_interface(piece) if manager else []

	visible = true
	var attempts = 0
	while attempts < 10 and not is_inside_tree():
		await get_tree().process_frame
		attempts += 1

	_initialize_interface_logic()

	# Esperar a que Godot calcule el tamano real antes de posicionar
	await get_tree().process_frame
	await get_tree().process_frame

func _initialize_interface_logic():
	custom_minimum_size = BASE_SIZE
	size = BASE_SIZE
	_connect_buttons()
	update_piece_info()
	load_block_palette()
	load_workspace_blocks()
	visible = true

# GameManager recibido al abrir; la ruta fija queda solo como respaldo
func _gm() -> Node:
	if game_manager and is_instance_valid(game_manager):
		return game_manager
	return get_node_or_null("/root/Main/GameManager")

func load_workspace_blocks():
	for child in workspace.get_children():
		if child is DraggableBlock:
			child.queue_free()
	for data in current_blocks:
		var block_type: String = data.get("type", "")
		var info = BlockSystem.get_block_info(block_type)
		if info.is_empty():
			continue  # bloque borrado desde que se guardo el programa
		var block_instance: DraggableBlock = DraggableBlockScene.instantiate()
		workspace.add_child(block_instance)
		block_instance.is_in_workspace = true
		block_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block_instance.block_id = block_type
		var setup_data = info.duplicate(true)
		setup_data["type"] = block_type
		setup_data["name"] = BlockSystem.get_display_name(block_type, current_piece.piece_color if current_piece else "white")
		block_instance.setup_block(setup_data)
		register_block(block_instance)
	update_ram_display()

# --- RAM ---

# Junta todos los cambios de un mismo frame en un solo recalculo
func _request_ram_update() -> void:
	if _ram_update_pending:
		return
	_ram_update_pending = true
	_flush_ram_update.call_deferred()

func _flush_ram_update() -> void:
	_ram_update_pending = false
	if is_inside_tree():
		update_ram_display()

# Conectada desde la escena (child_order_changed del DropZone)
func _on_drop_zone_child_order_changed() -> void:
	_request_ram_update()

# Lee el workspace, actualiza current_blocks y el contador. No guarda nada
# fuera de la interfaz: eso solo pasa al ejecutar.
func update_ram_display():
	if not current_piece:
		return

	var used_ram := 0
	var position_in_queue := 0
	var new_blocks := []
	for child in workspace.get_children():
		if not child is DraggableBlock or child.is_dying or child.is_queued_for_deletion():
			continue
		# Cada bloque paga su base + 1 por cada bloque que tenga antes
		var cost: int = BlockSystem.get_block_info(child.block_id).get("ram_cost", 0) + position_in_queue
		position_in_queue += 1
		used_ram += cost
		child.update_visual_cost(cost)
		new_blocks.append({"type": child.block_id})
	current_blocks = new_blocks

	if ram_counter:
		var used_label = ram_counter.find_child("RAMUsed", true, false)
		var total_label = ram_counter.find_child("RAMTotal", true, false)
		if used_label:
			used_label.text = str(used_ram)
			var over: bool = used_ram > current_piece.available_ram
			used_label.add_theme_color_override("font_color", Color.RED if over else Color.WHITE)
		if total_label:
			total_label.text = str(current_piece.available_ram)

	update_piece_info()
	# El tablero muestra el recorrido del programa tal como esta ahora
	var gm = _gm()
	if gm and gm.has_method("show_program_preview"):
		gm.show_program_preview(current_piece, current_blocks)

func calculate_current_ram_usage() -> int:
	return BlockSystem.calculate_ram_usage(current_blocks)

# Sincroniza current_blocks con lo que se ve en pantalla
func update_blocks_from_workspace():
	update_ram_display()

# --- Botones ---

func _connect_buttons():
	var buttons = {
		"TestButton": _on_test_button_pressed,
		"CancelButton": _on_cancel_button_pressed
	}
	for b_name in buttons:
		var btn = control_buttons.find_child(b_name, true, false)
		if btn and not btn.pressed.is_connected(buttons[b_name]):
			btn.pressed.connect(buttons[b_name])

func _on_test_button_pressed():
	update_blocks_from_workspace()

	if current_blocks.is_empty():
		_show_message("No hay bloques para ejecutar.")
		return

	var used_ram = calculate_current_ram_usage()
	if used_ram > current_piece.available_ram:
		_show_message("RAM insuficiente (%d/%d). Quita bloques o agrupalos en un loop." % [used_ram, current_piece.available_ram])
		return

	var gm = _gm()
	if not gm:
		return
	# Guarda el programa e instala el escape (si hay) antes de jugar el turno
	gm.save_piece_program(current_piece, current_blocks)
	_close_interface()
	# Sin await: la interfaz se libera y el turno sigue en el GameManager
	gm.execute_turn_and_switch()

func _on_cancel_button_pressed():
	_close_interface()

func _close_interface():
	var gm = _gm()
	if gm and gm.has_method("_on_programming_interface_closed"):
		gm._on_programming_interface_closed()
	current_piece = null
	current_blocks.clear()
	currently_dragging_block = null
	queue_free()

# --- Arrastre de bloques ---

# Unico punto donde se conectan las senales de un bloque (paleta, workspace o
# clon recien creado al arrastrar)
func register_block(block: DraggableBlock) -> void:
	if not block.block_dragged.is_connected(_on_block_dragged):
		block.block_dragged.connect(_on_block_dragged)
	if not block.block_dropped.is_connected(_on_block_dropped):
		block.block_dropped.connect(_on_block_dropped)
	if not block.delete_requested.is_connected(_on_block_delete_requested):
		block.delete_requested.connect(_on_block_delete_requested)

func _on_block_dragged(block: DraggableBlock, _global_pos: Vector2):
	currently_dragging_block = block

# El bloque ya decidio donde quedo (DraggableBlock._end_drag); el cambio en el
# workspace dispara el recalculo de RAM por child_order_changed
func _on_block_dropped(_block: DraggableBlock, _global_pos: Vector2):
	currently_dragging_block = null

# --- Paleta e informacion de la pieza ---

func load_block_palette():
	if not current_piece:
		return
	var scroll_container = block_palette.get_node_or_null("ScrollContainer")
	if not scroll_container:
		push_warning("ProgrammingInterface: falta el ScrollContainer de la paleta")
		return
	var container = scroll_container.get_node_or_null("GridContainer")
	if not container:
		container = GridContainer.new()
		container.name = "GridContainer"
		scroll_container.add_child(container)
	for child in container.get_children():
		child.queue_free()
	container.columns = 1
	container.add_theme_constant_override("h_separation", 5)
	container.add_theme_constant_override("v_separation", 10)

	# Movimientos, loops y escapes del bando de la pieza
	var color_bando = current_piece.piece_color
	var allowed_blocks = []
	for category in ["movement", "logic", "action"]:
		allowed_blocks.append_array(BlockSystem.get_blocks_for_palette(category, color_bando))

	for block_data in allowed_blocks:
		var type_id = block_data.get("type", "")
		if type_id == "":
			continue
		var block_instance: DraggableBlock = DraggableBlockScene.instantiate()
		container.add_child(block_instance)
		block_instance.block_id = type_id
		block_instance.setup_block(block_data.duplicate(true))
		block_instance.mouse_filter = Control.MOUSE_FILTER_STOP
		register_block(block_instance)

func update_piece_info():
	if not current_piece or not piece_info:
		return
	var hbox = piece_info.get_node_or_null("HBoxContainer")
	if not hbox:
		return
	var texture_rect = hbox.get_node_or_null("TextureRect")
	if texture_rect and current_piece.texture:
		texture_rect.texture = current_piece.texture
	var vbox = hbox.get_node_or_null("VBoxContainer")
	if not vbox:
		return

	var piece_name_label = vbox.get_node_or_null("PieceName")
	var piece_type_label = vbox.get_node_or_null("PieceType")
	var piece_status_label = vbox.get_node_or_null("PieceStatus")

	if piece_name_label:
		piece_name_label.text = "%s %s" % [current_piece.piece_color.capitalize(), current_piece.piece_type.capitalize()]
	if piece_type_label:
		piece_type_label.text = "Total RAM: %d" % current_piece.available_ram
	if piece_status_label:
		if current_blocks.is_empty():
			piece_status_label.text = "No programs"
			piece_status_label.add_theme_color_override("font_color", Color.WHITE)
		else:
			piece_status_label.text = "Installed (%d)" % current_blocks.size()
			piece_status_label.add_theme_color_override("font_color", Color.GREEN_YELLOW)

# --- Entrada ---

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
	# ESC cierra sin guardar, igual que "Cancelar"
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_interface()
		get_viewport().set_input_as_handled()

# --- Crear loops y escapes ---

# Revisa que el contenido del workspace sirva para el tipo de bloque a crear.
# Devuelve "" si es valido o el motivo para mostrarle al jugador.
func validate_new_block_content(blocks: Array, kind: String) -> String:
	if blocks.is_empty():
		return "Arma primero la secuencia en el area de trabajo."
	for block in blocks:
		var info = BlockSystem.get_block_info(block.get("type", ""))
		var category = info.get("category", "")
		if category == "action":
			return "Un %s no puede contener un escape." % kind
		# El escape se valida con la casilla del primer movimiento y no
		# se puede anidar: solo admite movimientos simples
		if kind == "escape" and not info.has("vector"):
			return "Un escape solo puede contener movimientos simples."
	return ""

func _open_name_popup(prompt: String, default_name: String, on_confirmed: Callable) -> void:
	var popup = NamePopupScene.instantiate()
	popup.setup(prompt, default_name)
	add_child(popup)
	popup.name_confirmed.connect(on_confirmed)
	popup.popup_centered()

# Conectada desde la escena
func _on_loop_pressed() -> void:
	update_blocks_from_workspace()
	var error = validate_new_block_content(current_blocks, "loop")
	if error != "":
		_show_message(error)
		return
	_open_name_popup("Nombre del Loop:", "Loop", _on_loop_name_confirmed)

func _on_loop_name_confirmed(loop_name: String):
	update_blocks_from_workspace()
	if not current_piece or validate_new_block_content(current_blocks, "loop") != "":
		return
	var loop_id = BlockSystem.create_loop_block(
		current_blocks.duplicate(true), calculate_current_ram_usage(), loop_name, current_piece.piece_color
	)
	print("Loop creado: ", loop_id)
	load_block_palette()

# Conectada desde la escena
func _on_escape_pressed() -> void:
	update_blocks_from_workspace()
	var error = validate_new_block_content(current_blocks, "escape")
	if error != "":
		_show_message(error)
		return
	_open_name_popup("Nombre del Escape:", "Escape", _on_escape_name_confirmed)

func _on_escape_name_confirmed(escape_name: String):
	update_blocks_from_workspace()
	if not current_piece or validate_new_block_content(current_blocks, "escape") != "":
		return
	# Un escape cuesta el doble de su secuencia
	var protocol_id = BlockSystem.create_escape_protocol(
		current_blocks.duplicate(true), calculate_current_ram_usage() * 2, escape_name, current_piece.piece_color
	)
	print("Escape creado: ", protocol_id)
	load_block_palette()

# --- Eliminar loops y escapes ---

func _on_block_delete_requested(block: DraggableBlock) -> void:
	var block_id = block.block_id
	# Aunque la senal llegue, un bloque protegido no se toca
	if not BlockSystem.is_deletable_block(block_id):
		return

	var block_name = BlockSystem.get_block_info(block_id).get("name", block_id)

	var parents = BlockSystem.get_blocks_containing(block_id)
	if not parents.is_empty():
		var parent_names := []
		for p in parents:
			parent_names.append("\"%s\"" % BlockSystem.get_block_info(p).get("name", p))
		_show_message("No se puede eliminar \"%s\" porque se usa dentro de %s.\nElimina primero esos bloques." % [block_name, ", ".join(parent_names)])
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = "Eliminar bloque"
	dialog.dialog_text = "¿Eliminar \"%s\"?\nSe quitara de todas las piezas que lo tengan programado." % block_name
	dialog.ok_button_text = "Eliminar"
	dialog.cancel_button_text = "Cancelar"
	add_child(dialog)
	dialog.confirmed.connect(_delete_custom_block.bind(block_id))
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			dialog.queue_free()
	)
	dialog.popup_centered()

func _delete_custom_block(block_id: String) -> void:
	if not BlockSystem.delete_custom_block(block_id):
		return
	for child in workspace.get_children():
		if child is DraggableBlock and child.block_id == block_id:
			child.queue_free()
	var gm = _gm()
	if gm and gm.has_method("purge_block_references"):
		gm.purge_block_references(block_id)
	load_block_palette()
	_request_ram_update()

func _show_message(text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Aviso"
	dialog.dialog_text = text
	add_child(dialog)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			dialog.queue_free()
	)
	dialog.popup_centered()
