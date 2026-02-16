extends Control

# Rutas de las escenas (Asegúrate de que coincidan con tu nueva estructura)
const GAME_SCENE = "res://src/core/main.tscn"
const SETTINGS_SCENE = "res://src/ui/menus/SettingsMenu.tscn"

@onready var transition_rect = $TransitionLayer/TransitionRect
var settings_menu: SettingsMenu = null

func _ready():
	# Forzamos que el rectángulo de transición esté oculto al arrancar
	transition_rect.visible = false
	# Ponemos el shader en modo "transparente"
	transition_rect.material.set_shader_parameter("progress", 1.0)
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	$MainContainer/ButtonsContainer/NewGameButton.grab_focus()
	
	_prepare_settings_menu()

func _prepare_settings_menu():
	var settings_scene = load(SETTINGS_SCENE)
	settings_menu = settings_scene.instantiate()
	add_child(settings_menu)
	settings_menu.visible = false # Asegurarnos de que empiece oculto

func _on_new_game_button_pressed():
	transition_rect.visible = true
	var tween = create_tween()
	
	# Cerramos a verde (1.0 -> 0.0)
	tween.tween_property(transition_rect.material, "shader_parameter/progress", 0.0, 0.6)
	
	tween.finished.connect(func():
		# Cambiamos a Main, que ahora tiene su propia lógica de apertura
		get_tree().change_scene_to_file("res://main.tscn")
	)

func _on_load_game_button_pressed():
	print("Cargar partida - Próximamente")
	# Aquí iría la lógica de abrir un archivo .save

func _on_multiplayer_button_pressed():
	print("Multijugador Local")
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_settings_button_pressed():
	if settings_menu and settings_menu.visible:
		settings_menu.close()
	else:
		_open_settings_menu()

func _open_settings_menu():
	if settings_menu:
		settings_menu.open()
		# Opcional: Podrías querer conectar una señal para recuperar el focus 
		# de los botones del menú principal cuando se cierre los ajustes.
		if not settings_menu.menu_closed.is_connected(_on_settings_closed):
			settings_menu.menu_closed.connect(_on_settings_closed)

func _on_settings_closed():
	# Al cerrar ajustes, devolvemos el foco al botón de settings para mando/teclado
	$MainContainer/ButtonsContainer/SettingsButton.grab_focus()

func _on_exit_button_pressed():
	get_tree().quit()
