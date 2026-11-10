extends Control

const GAME_SCENE = "res://main.tscn"  # Mantén tu ruta actual que ya funciona
const SETTINGS_SCENE = "res://src/ui/menus/SettingsMenu.tscn"
const DIFFICULTY_SCENE = "res://src/ui/menus/DifficultySelect.tscn"

@onready var transition_rect = $TransitionLayer/TransitionRect
@onready var exit_button = $MainContainer/ButtonsContainer/ExitButton
var settings_menu: SettingsMenu = null
var difficulty_select: DifficultySelect = null
# Evita que un segundo clic durante el fundido inicie otra transicion
var _transitioning: bool = false

func _ready():
	# Restablecer configuración al iniciar el menú
	if GlobalConfig:
		GlobalConfig.reset_to_defaults()
	
	# Forzamos que el rectángulo de transición esté visible al arrancar
	transition_rect.visible = true
	transition_rect.material.set_shader_parameter("progress", 0.0)
	# Tween de entrada: abre la transición
	var tween = create_tween()
	tween.tween_property(transition_rect.material, "shader_parameter/progress", 1.0, 0.6)
	tween.finished.connect(func():
		transition_rect.visible = false
	)
	process_mode = Node.PROCESS_MODE_ALWAYS
	$MainContainer/ButtonsContainer/NewGameButton.grab_focus()
	# Sin partida guardada no hay nada que cargar
	$MainContainer/ButtonsContainer/LoadGameButton.disabled = not SaveManager.has_save()
	_prepare_settings_menu()
	_prepare_difficulty_select()

func _prepare_difficulty_select():
	difficulty_select = load(DIFFICULTY_SCENE).instantiate()
	add_child(difficulty_select)
	difficulty_select.difficulty_chosen.connect(func(_level): _start_new_game())
	difficulty_select.cancelled.connect(func(): $MainContainer/ButtonsContainer/NewGameButton.grab_focus())

func _prepare_settings_menu():
	var settings_scene = load(SETTINGS_SCENE)
	settings_menu = settings_scene.instantiate()
	add_child(settings_menu)
	settings_menu.visible = false

# Nueva partida contra el bot: primero se elige la dificultad
func _on_new_game_button_pressed():
	if _transitioning or difficulty_select.visible:
		return
	difficulty_select.open()

# Borra la partida guardada anterior y arranca con la dificultad elegida
func _start_new_game():
	if _transitioning:
		return
	print("Nueva partida - Eliminando save anterior")
	
	# Configurar como juego normal (con bot)
	if GlobalConfig:
		GlobalConfig.bot_disabled = false
		GlobalConfig.is_multiplayer = false
		GlobalConfig.load_save = false  
	
	if SaveManager:
		SaveManager.delete_save()
		print("Save eliminado")
	
	_transition_to_game()

func _on_load_game_button_pressed():
	if _transitioning:
		return
	if not SaveManager.has_save():
		print("No hay partida guardada.")
		return
	
	print("Cargando partida guardada")
	
	if GlobalConfig:
		GlobalConfig.bot_disabled = false
		GlobalConfig.is_multiplayer = false
		GlobalConfig.load_save = true
	
	_transition_to_game()

func _on_multiplayer_button_pressed():
	if _transitioning:
		return
	print("Multijugador Local - Eliminando save anterior")
	
	# Configurar como multijugador
	if GlobalConfig:
		GlobalConfig.bot_disabled = true
		GlobalConfig.is_multiplayer = true
		GlobalConfig.load_save = false  # No cargar save
	
	if SaveManager:
		SaveManager.delete_save()
		print("Save eliminado")
	
	_transition_to_game()

func _on_settings_button_pressed():
	if settings_menu and settings_menu.visible:
		settings_menu.close()
	else:
		_open_settings_menu()

func _open_settings_menu():
	if settings_menu:
		settings_menu.open()
		if not settings_menu.menu_closed.is_connected(_on_settings_closed):
			settings_menu.menu_closed.connect(_on_settings_closed)

func _on_settings_closed():
	$MainContainer/ButtonsContainer/SettingsButton.grab_focus()

func _on_exit_button_pressed():
	get_tree().quit()

# 
func _transition_to_game():
	_transition_to(GAME_SCENE)

func _on_tutorial_pressed() -> void:
	if _transitioning:
		return
	GlobalConfig.tutorial_mode = true
	_transition_to("res://src/tutorial/tutorial_scene.tscn")

func _on_desafios_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	get_tree().change_scene_to_file("res://src/challenge/challenge_select_screen.tscn")

# Fundido de salida y cambio de escena. Ignora clics mientras esta en curso.
func _transition_to(scene_path: String) -> void:
	if _transitioning:
		return
	if not ResourceLoader.exists(scene_path):
		push_error("No se puede cargar la escena: " + scene_path)
		return
	_transitioning = true
	transition_rect.visible = true
	var tween = create_tween()
	tween.tween_property(transition_rect.material, "shader_parameter/progress", 0.0, 0.6)
	tween.finished.connect(func(): get_tree().change_scene_to_file(scene_path))
