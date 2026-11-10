extends Control

class_name SettingsMenu

# Menu de opciones: modo de pantalla, resolucion de la ventana y volumen.
#
# - La pantalla se cambia en dos pasos: el jugador elige y luego confirma con
#   "Aplicar". El boton solo se habilita si hay cambios pendientes; al cerrar
#   sin aplicar, la seleccion vuelve a lo que esta en uso.
# - El volumen y la dificultad del bot se aplican al instante y se guardan al
#   cerrar el menu.
# - ResolutionManager es el unico que cambia la ventana; MusicManager aplica
#   el volumen guardado al iniciar el juego.

signal resolution_changed(new_resolution: Vector2i)
signal menu_closed

# Tamanos de ventana ofrecidos. El juego se adapta a cualquier proporcion
# (ver ResolutionManager), asi que se incluyen 16:9, 16:10 y 21:9. 1366x768
# no se ofrece: es practicamente igual a la base de 1360x768.
const AVAILABLE_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1360, 768),   # Base del juego
	Vector2i(1440, 900),
	Vector2i(1600, 900),
	Vector2i(1680, 1050),
	Vector2i(1920, 1080),
	Vector2i(1920, 1200),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
	Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]
const DEFAULT_RESOLUTION := Vector2i(1360, 768)
const DEFAULT_VOLUME := 0.8
const TEXT_PENDING := "Hay cambios de pantalla sin aplicar"
const TEXT_APPLIED := "Cambios aplicados"
const DIFFICULTY_HINTS := {
	"easy": "No usa loops ni escapes, y comete errores",
	"normal": "Prevé tus loops, pero no los usa",
	"hard": "Usa loops y escapes, y revisa más jugadas",
}

@onready var panel: PanelContainer = $Center/Panel
@onready var windowed_button: Button = $Center/Panel/VBox/DisplayGrid/ModeRow/WindowedButton
@onready var fullscreen_button: Button = $Center/Panel/VBox/DisplayGrid/ModeRow/FullscreenButton
@onready var resolution_option: OptionButton = $Center/Panel/VBox/DisplayGrid/ResolutionOption
@onready var volume_slider: HSlider = $Center/Panel/VBox/AudioGrid/VolumeRow/VolumeSlider
@onready var volume_value: Label = $Center/Panel/VBox/AudioGrid/VolumeRow/VolumeValue
@onready var difficulty_buttons := {
	"easy": $Center/Panel/VBox/GameGrid/DifficultyRow/EasyButton,
	"normal": $Center/Panel/VBox/GameGrid/DifficultyRow/NormalButton,
	"hard": $Center/Panel/VBox/GameGrid/DifficultyRow/HardButton,
}
@onready var difficulty_hint: Label = $Center/Panel/VBox/DifficultyHint
@onready var status_label: Label = $Center/Panel/VBox/StatusLabel
@onready var reset_button: Button = $Center/Panel/VBox/Buttons/ResetButton
@onready var apply_button: Button = $Center/Panel/VBox/Buttons/ApplyButton
@onready var close_button: Button = $Center/Panel/VBox/Buttons/CloseButton

# Resoluciones que entran en el monitor actual (las demas no se ofrecen)
var resolutions: Array[Vector2i] = []
# Seleccion en el menu, todavia no aplicada
var selected_resolution: Vector2i = DEFAULT_RESOLUTION
var selected_fullscreen: bool = false
# Archivo de configuracion; los tests usan otro para no tocar el real
var settings_path: String = ResolutionManager.SETTINGS_PATH

func _ready():
	visible = false
	_load_resolutions()
	windowed_button.toggled.connect(_on_mode_toggled.bind(false))
	fullscreen_button.toggled.connect(_on_mode_toggled.bind(true))
	resolution_option.item_selected.connect(_on_resolution_selected)
	volume_slider.value_changed.connect(_on_volume_changed)
	for level in difficulty_buttons:
		difficulty_buttons[level].toggled.connect(_on_difficulty_toggled.bind(level))
	reset_button.pressed.connect(_on_reset_pressed)
	apply_button.pressed.connect(_on_apply_pressed)
	close_button.pressed.connect(close)

func _load_resolutions() -> void:
	resolutions.clear()
	resolution_option.clear()
	# Area util del monitor: sin barra de tareas ni paneles del sistema
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	for res in AVAILABLE_RESOLUTIONS:
		# Sin informacion del monitor (por ejemplo, en modo headless) se ofrecen todas
		var fits := usable.x <= 0 or (res.x <= usable.x and res.y <= usable.y)
		if fits or res == DEFAULT_RESOLUTION:
			resolutions.append(res)
			resolution_option.add_item(resolution_label(res))

# "1920 x 1080  (16:9)"
static func resolution_label(res: Vector2i) -> String:
	return "%d x %d  (%s)" % [res.x, res.y, aspect_name(res)]

static func aspect_name(res: Vector2i) -> String:
	var ratio := float(res.x) / float(res.y)
	for known in [[16.0 / 9.0, "16:9"], [16.0 / 10.0, "16:10"], [21.0 / 9.0, "21:9"], [4.0 / 3.0, "4:3"]]:
		# 1360x768 y 2560x1080 no son exactos, pero se los conoce asi
		if absf(ratio - known[0]) < 0.06:
			return known[1]
	return "%.2f:1" % ratio

# --- Abrir y cerrar ---

func open() -> void:
	if not is_node_ready():
		await ready
	_sync_from_current()
	visible = true
	# Aparicion breve: fundido del fondo y del panel
	modulate.a = 0.0
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.96, 0.96)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	(fullscreen_button if selected_fullscreen else windowed_button).grab_focus()

func close() -> void:
	if not visible:
		return
	visible = false
	_save_settings()
	menu_closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

# Carga en el menu lo que esta en uso: lo pendiente sin aplicar se descarta
func _sync_from_current() -> void:
	selected_resolution = ResolutionManager.current_resolution
	selected_fullscreen = ResolutionManager.is_fullscreen
	volume_slider.set_value_no_signal(_current_volume())
	_update_volume_label(volume_slider.value)
	_refresh_difficulty()
	status_label.text = ""
	_refresh_display_controls()

# --- Pantalla ---

func _on_mode_toggled(pressed: bool, fullscreen: bool) -> void:
	if not pressed:
		return
	selected_fullscreen = fullscreen
	_refresh_display_controls()

func _on_resolution_selected(index: int) -> void:
	if index >= 0 and index < resolutions.size():
		selected_resolution = resolutions[index]
	_refresh_display_controls()

func has_pending_changes() -> bool:
	if selected_fullscreen != ResolutionManager.is_fullscreen:
		return true
	# En pantalla completa la resolucion de la ventana no se usa
	return not selected_fullscreen and selected_resolution != ResolutionManager.current_resolution

func _refresh_display_controls() -> void:
	windowed_button.set_pressed_no_signal(not selected_fullscreen)
	fullscreen_button.set_pressed_no_signal(selected_fullscreen)
	resolution_option.disabled = selected_fullscreen
	resolution_option.select(_resolution_index(selected_resolution))
	var pending := has_pending_changes()
	apply_button.disabled = not pending
	if pending:
		status_label.text = TEXT_PENDING
	elif status_label.text == TEXT_PENDING:
		status_label.text = ""

# Indice de la resolucion en la lista; si no esta, la mayor que no la supera
func _resolution_index(res: Vector2i) -> int:
	var best := 0
	for i in range(resolutions.size()):
		if resolutions[i] == res:
			return i
		if resolutions[i].x <= res.x and resolutions[i].y <= res.y:
			best = i
	return best

func _on_apply_pressed() -> void:
	if not has_pending_changes():
		return
	if not selected_fullscreen:
		selected_resolution = resolutions[resolution_option.selected]
	ResolutionManager.set_resolution(selected_resolution, selected_fullscreen)
	_save_settings()
	resolution_changed.emit(selected_resolution)
	_refresh_display_controls()
	status_label.text = TEXT_APPLIED
	close_button.grab_focus()

func _on_reset_pressed() -> void:
	selected_resolution = DEFAULT_RESOLUTION
	selected_fullscreen = false
	volume_slider.value = DEFAULT_VOLUME
	GlobalConfig.set_bot_difficulty("normal")
	_refresh_difficulty()
	_refresh_display_controls()

# --- Dificultad ---

# Rige desde el proximo turno del bot, tambien a mitad de partida
func _on_difficulty_toggled(pressed: bool, level: String) -> void:
	if not pressed:
		return
	GlobalConfig.set_bot_difficulty(level)
	_refresh_difficulty()

func _refresh_difficulty() -> void:
	for level in difficulty_buttons:
		difficulty_buttons[level].set_pressed_no_signal(level == GlobalConfig.bot_difficulty)
	difficulty_hint.text = DIFFICULTY_HINTS.get(GlobalConfig.bot_difficulty, "")

# --- Volumen ---

func _on_volume_changed(value: float) -> void:
	set_master_volume(value)
	_update_volume_label(value)

func _update_volume_label(value: float) -> void:
	volume_value.text = "%d%%" % roundi(value * 100.0)

func _current_volume() -> float:
	var bus := AudioServer.get_bus_index("Master")
	if AudioServer.is_bus_mute(bus):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(bus)), 0.0, 1.0)

# Volumen lineal de 0 a 1 sobre el bus Master. En 0 se silencia el bus,
# porque linear_to_db(0) es -inf.
static func set_master_volume(value: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, value < 0.01)
	if value >= 0.01:
		AudioServer.set_bus_volume_db(bus, linear_to_db(value))

# --- Guardado ---

# Guarda lo que esta en uso (no la seleccion pendiente)
func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(settings_path)  # conserva otras claves si las hay
	config.set_value("display", "resolution_x", ResolutionManager.current_resolution.x)
	config.set_value("display", "resolution_y", ResolutionManager.current_resolution.y)
	config.set_value("display", "fullscreen", ResolutionManager.is_fullscreen)
	config.set_value("audio", "master_volume", volume_slider.value)
	config.set_value("game", "bot_difficulty", GlobalConfig.bot_difficulty)
	var err := config.save(settings_path)
	if err != OK:
		push_error("No se pudo guardar la configuracion: %s" % error_string(err))
