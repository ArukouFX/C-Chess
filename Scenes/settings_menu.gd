extends Control

class_name SettingsMenu

# Señales
signal resolution_changed(new_resolution: Vector2i)
signal menu_closed

# Resoluciones predefinidas
const AVAILABLE_RESOLUTIONS = [
	Vector2i(1280, 720),   # HD
	Vector2i(1360, 768),   # Original del juego
	Vector2i(1366, 768),   # Laptop común
	Vector2i(1600, 900),   # HD+
	Vector2i(1920, 1080),  # Full HD
	Vector2i(2560, 1440),  # 2K
	Vector2i(3840, 2160)   # 4K
]

# Referencias usando rutas directas
@onready var resolution_option: OptionButton = $PanelContainer/VBoxContainer/HBoxContainer/ResolutionOptionButton
@onready var fullscreen_check: CheckBox = $PanelContainer/VBoxContainer/FullscreenCheckBox
@onready var apply_button: Button = $PanelContainer/VBoxContainer/HBoxContainer2/ApplyButton
@onready var close_button: Button = $PanelContainer/VBoxContainer/HBoxContainer2/CloseButton

var current_resolution: Vector2i = Vector2i(1360, 768)
var is_fullscreen: bool = false

func _ready():
	print("SettingsMenu _ready() llamado")
	
	# Configurar tamaño responsive
	_setup_responsive_size()
	
	# Configurar tamaño del menú
	custom_minimum_size = Vector2(400, 300)
	size = custom_minimum_size
	
	# Ocultar inicialmente
	visible = false
	
	# Verificar que los nodos existen
	call_deferred("_verify_and_setup")

func _setup_responsive_size():
	var screen_size = get_viewport().get_visible_rect().size
	
	# Calcular tamaño basado en pantalla
	var scale_factor = min(screen_size.x / 1360.0, screen_size.y / 768.0)
	scale_factor = clamp(scale_factor, 0.8, 1.2)
	
	# Tamaño base del menú
	var base_size = Vector2(400, 300)
	var target_size = base_size * scale_factor
	
	# Limitar tamaño
	target_size.x = clamp(target_size.x, 350, 500)
	target_size.y = clamp(target_size.y, 250, 400)
	
	# Aplicar
	custom_minimum_size = target_size
	size = target_size
	
	print("Menú ajustado a pantalla:")
	print("  Pantalla: ", screen_size)
	print("  Escala: ", scale_factor)
	print("  Tamaño: ", target_size)

func _verify_and_setup():
	print("Verificando nodos de UI...")
	
	if not _verify_nodes():
		print("ERROR: Faltan nodos en la UI")
		_create_fallback_ui()
	else:
		print("Todos los nodos encontrados")
		_setup_ui()

func _verify_nodes() -> bool:
	# Verificar cada nodo individualmente
	var nodes_valid = true
	
	if not resolution_option:
		print("ERROR: resolution_option no encontrado")
		nodes_valid = false
	
	if not fullscreen_check:
		print("ERROR: fullscreen_check no encontrado")
		nodes_valid = false
	
	if not apply_button:
		print("ERROR: apply_button no encontrado")
		nodes_valid = false
	
	if not close_button:
		print("ERROR: close_button no encontrado")
		nodes_valid = false
	
	return nodes_valid

func _create_fallback_ui():
	print("Creando UI de fallback...")
	
	# Limpiar todo
	for child in get_children():
		child.queue_free()
	
	# Crear ColorRect de fondo
	var color_rect = ColorRect.new()
	color_rect.name = "ColorRect"
	color_rect.color = Color(0.1, 0.1, 0.1, 0.95)
	color_rect.size = size
	add_child(color_rect)
	
	# Panel principal
	var panel = PanelContainer.new()
	panel.name = "PanelContainer"
	panel.size = size
	color_rect.add_child(panel)
	
	# VBoxContainer principal
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.size = size - Vector2(40, 40)
	vbox.position = Vector2(20, 20)
	panel.add_child(vbox)
	
	# Título
	var title = Label.new()
	title.text = "OPCIONES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	# Resolución
	var res_hbox = HBoxContainer.new()
	var res_label = Label.new()
	res_label.text = "Resolución:"
	res_hbox.add_child(res_label)
	
	resolution_option = OptionButton.new()
	resolution_option.name = "ResolutionOptionButton"
	resolution_option.custom_minimum_size = Vector2(200, 30)
	res_hbox.add_child(resolution_option)
	vbox.add_child(res_hbox)
	
	# Fullscreen
	fullscreen_check = CheckBox.new()
	fullscreen_check.name = "FullscreenCheckBox"
	fullscreen_check.text = "Pantalla completa"
	vbox.add_child(fullscreen_check)
	
	vbox.add_child(HSeparator.new())
	
	# Botones
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.name = "HBoxContainer"
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	apply_button = Button.new()
	apply_button.name = "ApplyButton"
	apply_button.text = "APLICAR"
	apply_button.custom_minimum_size = Vector2(100, 40)
	buttons_hbox.add_child(apply_button)
	
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "CERRAR"
	close_button.custom_minimum_size = Vector2(100, 40)
	buttons_hbox.add_child(close_button)
	
	vbox.add_child(buttons_hbox)
	
	print("UI de fallback creada")
	
	# Configurar la UI recién creada
	_setup_ui()

func _setup_ui():
	print("Configurando UI...")
	
	# Cargar resoluciones
	_load_resolutions()
	
	# Conectar señales
	apply_button.pressed.connect(_on_apply_pressed)
	close_button.pressed.connect(_on_close_pressed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	
	# Cargar configuración
	_load_settings()

func _load_resolutions():
	if not resolution_option:
		print("ERROR: resolution_option es null")
		return
	
	print("Cargando ", AVAILABLE_RESOLUTIONS.size(), " resoluciones")
	
	resolution_option.clear()
	
	for i in range(AVAILABLE_RESOLUTIONS.size()):
		var res = AVAILABLE_RESOLUTIONS[i]
		var text = "%d x %d" % [res.x, res.y]
		resolution_option.add_item(text, i)
		print("  Agregada: ", text)
	
	# Seleccionar resolución actual
	_select_current_resolution()

func _select_current_resolution():
	if not resolution_option or resolution_option.item_count == 0:
		print("ERROR: No hay resoluciones cargadas")
		return
	
	var window = get_tree().root
	var current_size = window.size
	
	print("Tamaño de ventana actual: ", current_size)
	
	# Buscar coincidencia
	var selected_index = 0
	for i in range(AVAILABLE_RESOLUTIONS.size()):
		if AVAILABLE_RESOLUTIONS[i] == current_size:
			selected_index = i
			print("Coincidencia encontrada en índice: ", i)
			break
	
	resolution_option.selected = selected_index
	current_resolution = AVAILABLE_RESOLUTIONS[selected_index]
	
	print("Resolución seleccionada: ", current_resolution)

func _load_settings():
	print("Cargando configuración guardada...")
	
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		# Resolución
		var res_x = config.get_value("display", "resolution_x", 1360)
		var res_y = config.get_value("display", "resolution_y", 768)
		current_resolution = Vector2i(res_x, res_y)
		
		# Fullscreen
		is_fullscreen = config.get_value("display", "fullscreen", false)
		print("Configuración cargada: ", current_resolution, ", fullscreen: ", is_fullscreen)
	else:
		# Valores por defecto
		current_resolution = Vector2i(1360, 768)
		is_fullscreen = false
		print("Usando valores por defecto")
	
	# Aplicar a UI
	call_deferred("_apply_to_ui")

func _apply_to_ui():
	if not resolution_option or not fullscreen_check:
		print("ERROR: No se puede aplicar a UI - nodos null")
		return
	
	# Buscar la resolución actual
	var found_index = -1
	for i in range(AVAILABLE_RESOLUTIONS.size()):
		if AVAILABLE_RESOLUTIONS[i] == current_resolution:
			found_index = i
			break
	
	if found_index >= 0:
		resolution_option.selected = found_index
	else:
		# Seleccionar primera opción si no se encuentra
		if resolution_option.item_count > 0:
			resolution_option.selected = 0
			current_resolution = AVAILABLE_RESOLUTIONS[0]
	
	fullscreen_check.button_pressed = is_fullscreen
	
	print("UI actualizada - Res: ", current_resolution, ", FS: ", is_fullscreen)

func open():
	print("=== ABRIENDO MENÚ ===")
	
	# Si los nodos no están listos, inicializar
	if not resolution_option:
		_verify_and_setup()
		await get_tree().process_frame
	
	visible = true
	
	# Centrar en pantalla
	var viewport_size = get_viewport().get_visible_rect().size
	position = (viewport_size - size) / 2
	
	# Traer al frente
	z_index = 1000
	
	# Actualizar con valores actuales
	_select_current_resolution()
	
	print("Menú abierto en: ", position)
	print("=== MENÚ ABIERTO ===")

func close():
	print("Cerrando menú")
	visible = false
	menu_closed.emit()

func _on_apply_pressed():
	print("Botón APLICAR presionado")
	
	if not resolution_option:
		print("ERROR: resolution_option es null")
		return
	
	# Obtener resolución seleccionada
	var selected_idx = resolution_option.selected
	if selected_idx >= 0 and selected_idx < AVAILABLE_RESOLUTIONS.size():
		current_resolution = AVAILABLE_RESOLUTIONS[selected_idx]
		print("Resolución seleccionada: ", current_resolution)
	else:
		print("ERROR: Índice inválido: ", selected_idx)
		return
	
	# Aplicar configuración
	_apply_display_settings()
	
	# Guardar
	_save_settings()

func _on_close_pressed():
	print("Botón CERRAR presionado")
	close()

func _on_fullscreen_toggled(toggled: bool):
	is_fullscreen = toggled
	print("Fullscreen: ", is_fullscreen)

func _apply_display_settings():
	var window = get_tree().root
	
	print("Aplicando: ", current_resolution, ", FS: ", is_fullscreen)
	
	if not is_fullscreen:
		window.mode = Window.MODE_WINDOWED
		window.size = current_resolution
		
		# Centrar
		var screen_size = DisplayServer.screen_get_size()
		var window_pos = (screen_size - current_resolution) / 2
		window.position = Vector2i(
			max(window_pos.x, 0),
			max(window_pos.y, 0)
		)
	else:
		window.mode = Window.MODE_FULLSCREEN
		window.set_content_scale_size(current_resolution)
		window.set_content_scale_mode(Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
		window.set_content_scale_aspect(Window.CONTENT_SCALE_ASPECT_KEEP)
	
	# Notificar cambio
	resolution_changed.emit(current_resolution)

func _save_settings():
	var config = ConfigFile.new()
	
	config.set_value("display", "resolution_x", current_resolution.x)
	config.set_value("display", "resolution_y", current_resolution.y)
	config.set_value("display", "fullscreen", is_fullscreen)
	
	var err = config.save("user://settings.cfg")
	if err == OK:
		print("Configuración guardada")
	else:
		print("Error al guardar: ", err)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and visible:
			print("ESC - cerrando menú")
			close()
			get_viewport().set_input_as_handled()
