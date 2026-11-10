extends Node

# ResolutionManager (autoload)
# Unico lugar donde se cambia el tamano o el modo de la ventana.
#
# El juego se diseno para 1360x768 (BASE_SIZE) y usa el escalado
# "canvas_items" con aspecto "expand":
# - La escala es la misma que con "keep": el diseno entra completo en la
#   ventana, sin deformarse.
# - Si la ventana tiene otra proporcion (16:10, 4:3, ultrapanoramica), el
#   area visible crece en ancho o en alto en lugar de mostrar bandas negras.
#   La partida mantiene su disposicion de 1360x768 centrada en esa area, el
#   fondo la cubre entera y los menus se acomodan con sus anclas.
#
# design_rect() da el rectangulo de diseno dentro del area visible y
# layout_changed avisa cada vez que la ventana cambia de tamano.

signal resolution_changed(new_resolution: Vector2i)
signal layout_changed

const BASE_SIZE := Vector2i(1360, 768)
const SETTINGS_PATH := "user://settings.cfg"

var current_resolution: Vector2i = BASE_SIZE
var is_fullscreen: bool = false

func _ready():
	_apply_scaling()
	get_tree().root.size_changed.connect(func(): layout_changed.emit())
	# Diferido: la ventana ya tiene aplicada la configuracion del proyecto
	_apply_saved_settings.call_deferred()

func _apply_scaling() -> void:
	var window := get_tree().root
	window.content_scale_size = BASE_SIZE
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

# Aplica lo guardado por el menu de opciones. Sin archivo no se toca nada y
# se respeta la configuracion del proyecto (ventana maximizada).
func _apply_saved_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var res := Vector2i(
		int(config.get_value("display", "resolution_x", BASE_SIZE.x)),
		int(config.get_value("display", "resolution_y", BASE_SIZE.y))
	)
	set_resolution(res, bool(config.get_value("display", "fullscreen", false)))

# Tamano del area visible en unidades logicas (siempre >= BASE_SIZE)
func visible_size() -> Vector2:
	return get_tree().root.get_visible_rect().size

# Rectangulo de 1360x768 centrado en el area visible, en unidades logicas
func design_rect() -> Rect2:
	var vis := visible_size()
	return Rect2((vis - Vector2(BASE_SIZE)) / 2.0, Vector2(BASE_SIZE))

func set_resolution(new_resolution: Vector2i, fullscreen: bool = false) -> void:
	var window := get_tree().root
	_apply_scaling()

	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		# Nunca mas grande que la pantalla en la que esta la ventana
		var screen_size := DisplayServer.screen_get_size(window.current_screen)
		var size := Vector2i(mini(new_resolution.x, screen_size.x), mini(new_resolution.y, screen_size.y))
		window.size = size
		var screen_pos := DisplayServer.screen_get_position(window.current_screen)
		window.position = screen_pos + (screen_size - size) / 2

	current_resolution = new_resolution
	is_fullscreen = fullscreen
	resolution_changed.emit(current_resolution)
	print("[ResolutionManager] Ventana: ", new_resolution, " | Pantalla completa: ", fullscreen)
