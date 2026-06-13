# simple_resolution.gd
extends Node

signal resolution_changed(new_resolution: Vector2i)

var current_resolution: Vector2i = Vector2i(1360, 768)

func _ready():
	print("SimpleResolution inicializado")
	current_resolution = Vector2i(get_viewport().get_visible_rect().size)

func set_resolution(new_resolution: Vector2i, fullscreen: bool = false):
	var window = get_tree().root
	
	# Aseguramos que Godot maneje el escalado automáticamente SIEMPRE
	window.set_content_scale_size(Vector2i(1360, 768)) # Tu resolución base de diseño
	window.set_content_scale_mode(Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	window.set_content_scale_aspect(Window.CONTENT_SCALE_ASPECT_KEEP)
	
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		window.size = new_resolution
		
		# Centrar ventana
		var screen_size = DisplayServer.screen_get_size()
		var window_pos = (screen_size - new_resolution) / 2
		window.position = Vector2i(max(window_pos.x, 0), max(window_pos.y, 0))
	
	current_resolution = new_resolution
	emit_signal("resolution_changed", current_resolution)
	print("Resolución establecida: ", new_resolution)
