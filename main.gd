extends Node

# Precargar escena del menú de opciones
var SettingsMenuScene = preload("res://src/ui/menus/SettingsMenu.tscn")

# Referencias
@onready var settings_button = get_node_or_null("Buttons/VBoxContainer/SettingsButton")
@onready var settings_menu = null  # Se creará dinámicamente

func _ready():
	print("=== INICIALIZANDO JUEGO ===")
	
	_ensure_canvas_layer()
	
	# Configurar botón de opciones (crear si no existe)
	_setup_settings_button()
	ResolutionManager.layout_changed.connect(_place_corner_buttons)
	# Diferido: el VBoxContainer necesita un cuadro para medir sus botones
	_place_corner_buttons.call_deferred()
	
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

# Atras, Opciones y Salir van a la esquina superior derecha del area visible,
# no del diseno: en pantallas anchas quedan en el borde real de la ventana
const CORNER_MARGIN := Vector2(20, 10)

func _place_corner_buttons() -> void:
	var buttons = get_node_or_null("Buttons")
	var box = get_node_or_null("Buttons/VBoxContainer")
	if not buttons or not box:
		return
	var rect: Rect2 = ResolutionManager.design_rect()
	# Esquina superior derecha visible, en coordenadas del mundo (la camara
	# muestra el diseno desplazado en rect.position)
	var right := Vector2(ResolutionManager.BASE_SIZE.x, 0) + Vector2(rect.position.x, -rect.position.y)
	buttons.position = Vector2(right.x - box.size.x - CORNER_MARGIN.x, right.y + CORNER_MARGIN.y)

func _ensure_canvas_layer():
	# Verificar si CanvasLayer existe
	var canvas_layer = get_node_or_null("CanvasLayer")
	if not canvas_layer:
		print("Creando CanvasLayer dinámicamente...")
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "CanvasLayer"
		# Por encima de la interfaz de programacion, por debajo de la transicion
		canvas_layer.layer = 5
		add_child(canvas_layer)
		print("CanvasLayer creado")
	else:
		print("CanvasLayer ya existe")

func _setup_settings_button():
	# Verificar si el botón ya existe
	settings_button = get_node_or_null("Buttons/VBoxContainer/SettingsButton")
	
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
	button.text = "Opciones"
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
			
			print("Menú de opciones creado")
		else:
			print("ERROR: CanvasLayer no encontrado")
			return
	
	# Abrir menú
	settings_menu.open()

func _on_settings_menu_closed():
	print("Menú de opciones cerrado")
