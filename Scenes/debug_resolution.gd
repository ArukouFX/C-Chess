extends Control

func _ready():
	print("=== RESOLUTION DEBUG ===")
	
	var viewport = get_viewport()
	var screen_size = DisplayServer.screen_get_size()
	var window_size = get_tree().root.size
	var viewport_size = viewport.get_visible_rect().size
	
	print("Pantalla: ", screen_size)
	print("Ventana: ", window_size)
	print("Viewport: ", viewport_size)
	print("DPI: ", DisplayServer.screen_get_dpi())
	print("Escala: ", get_tree().root.content_scale_factor)
	
	# Verificar configuración de stretch
	print("Stretch Mode: ", get_tree().root.content_scale_mode)
	print("Stretch Aspect: ", get_tree().root.content_scale_aspect)
	print("Base Size: ", get_tree().root.content_scale_size)
	
	# Calcular escala efectiva
	var base_size = Vector2(1360, 768)
	var scale_x = viewport_size.x / base_size.x
	var scale_y = viewport_size.y / base_size.y
	print("Escala X: ", scale_x)
	print("Escala Y: ", scale_y)
	print("Escala mínima: ", min(scale_x, scale_y))
	print("========================")

# Agrega este script a un nodo Control en Main
