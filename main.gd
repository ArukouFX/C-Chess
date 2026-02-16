extends Node

# Precargar escena del menú de opciones
var SettingsMenuScene = preload("res://src/ui/menus/SettingsMenu.tscn")

# Referencias
@onready var settings_button = get_node_or_null("CanvasLayer/SettingsButton")
@onready var settings_menu = null  # Se creará dinámicamente

func _ready():
	print("=== INICIALIZANDO JUEGO ===")
	
	_ensure_canvas_layer()
	
	# Configurar botón de opciones (crear si no existe)
	_setup_settings_button()
	
	# Cargar configuración inicial
	_load_initial_settings()
	
	print("Juego inicializado")
	
	# Buscamos el rectángulo de transición en la escena Main
	var transition_rect = $TransitionLayer/TransitionRect
	transition_rect.visible = true
	transition_rect.material.set_shader_parameter("progress", 0.0) # Empezar en verde

	var tween = create_tween()
	# Animamos de 0.0 a 1.0 para que se revele el tablero
	tween.tween_property(transition_rect.material, "shader_parameter/progress", 1.0, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Al terminar, ocultamos para que no interfiera con los clics
	tween.finished.connect(func(): transition_rect.visible = false)

func _ensure_canvas_layer():
	# Verificar si CanvasLayer existe
	var canvas_layer = get_node_or_null("CanvasLayer")
	if not canvas_layer:
		print("Creando CanvasLayer dinámicamente...")
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "CanvasLayer"
		add_child(canvas_layer)
		print("CanvasLayer creado")
	else:
		print("CanvasLayer ya existe")

func _setup_settings_button():
	# Verificar si el botón ya existe
	settings_button = get_node_or_null("CanvasLayer/SettingsButton")
	
	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)
		print("Botón de opciones encontrado y configurado")
	else:
		# Crear botón dinámicamente
		_create_settings_button()

func _create_settings_button():
	print("Creando botón de opciones dinámicamente")
	
	var button = Button.new()
	button.name = "SettingsButton"
	button.text = "⚙ Opciones"
	button.custom_minimum_size = Vector2(120, 40)
	button.position = Vector2(20, 20)
	
	# Agregar al CanvasLayer
	var canvas_layer = get_node_or_null("CanvasLayer")
	if canvas_layer:
		canvas_layer.add_child(button)
		settings_button = button
		settings_button.pressed.connect(_on_settings_button_pressed)
		print("Botón de opciones creado dinámicamente")
	else:
		print("ERROR: CanvasLayer no encontrado")

func _on_settings_button_pressed():
	print("Botón de opciones presionado")
	
	if settings_menu and settings_menu.visible:
		settings_menu.close()
	else:
		_open_settings_menu()

func _open_settings_menu():
	# Crear menú si no existe
	if not settings_menu or not is_instance_valid(settings_menu):
		var menu_instance = SettingsMenuScene.instantiate()
		
		# Agregar al CanvasLayer
		var canvas_layer = get_node_or_null("CanvasLayer")
		if canvas_layer:
			canvas_layer.add_child(menu_instance)
			settings_menu = menu_instance
			
			# Conectar señales
			settings_menu.menu_closed.connect(_on_settings_menu_closed)
			settings_menu.resolution_changed.connect(_on_resolution_changed)
			
			print("Menú de opciones creado")
		else:
			print("ERROR: CanvasLayer no encontrado")
			return
	
	# Abrir menú
	settings_menu.open()

func _on_settings_menu_closed():
	print("Menú de opciones cerrado")

func _on_resolution_changed(new_resolution: Vector2i):
	print("Resolución cambiada a: ", new_resolution)
	
	# Notificar a otros componentes del juego
	_notify_resolution_change(new_resolution)

func _notify_resolution_change(resolution: Vector2i):
	print("Resolución cambiada, notificando componentes...")
	
	# Notificar al GameManager
	var game_manager = get_node_or_null("GameManager")
	if game_manager and game_manager.has_method("on_resolution_changed"):
		game_manager.on_resolution_changed(resolution)
	
	# Notificar al Board
	var board = get_node_or_null("Table/Board")
	if board and board.has_method("on_resolution_changed"):
		board.on_resolution_changed(resolution)
	
	# Notificar a la Cámara
	var camera = get_node_or_null("Camera/Camera2D")
	if camera and camera.has_method("on_resolution_changed"):
		camera.on_resolution_changed(resolution)
	
	# Notificar a la Programming Interface si está abierta
	var canvas_layer = get_node_or_null("CanvasLayer")
	if canvas_layer:
		for child in canvas_layer.get_children():
			if child is ProgrammingInterface and child.visible:
				if child.has_method("_on_resolution_changed"):
					child._on_resolution_changed(resolution)
					print("Programming Interface notificada del cambio")

func _load_initial_settings():
	# Cargar configuración guardada o usar valores por defecto
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		# Resolución
		var res_x = config.get_value("display", "resolution_x", 1360)
		var res_y = config.get_value("display", "resolution_y", 768)
		var resolution = Vector2i(res_x, res_y)
		
		# Fullscreen
		var fullscreen = config.get_value("display", "fullscreen", false)
		
		# Aplicar
		_apply_resolution(resolution, fullscreen)
	else:
		# Valores por defecto
		_apply_resolution(Vector2i(1360, 768), false)

func _apply_resolution(resolution: Vector2i, fullscreen: bool):
	var window = get_tree().root
	
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
		window.set_content_scale_size(resolution)
		window.set_content_scale_mode(Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
		window.set_content_scale_aspect(Window.CONTENT_SCALE_ASPECT_KEEP)
	else:
		window.mode = Window.MODE_WINDOWED
		window.size = resolution
		
		# Centrar
		var screen_size = DisplayServer.screen_get_size()
		var window_pos = (screen_size - resolution) / 2
		window.position = Vector2i(
			max(window_pos.x, 0),
			max(window_pos.y, 0)
		)
	
	print("Resolución inicial aplicada: %dx%d, Fullscreen: %s" % [
		resolution.x, resolution.y,
		"Sí" if fullscreen else "No"
	])
