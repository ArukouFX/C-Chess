extends Sprite2D

func _ready():
	centered = false
	# Es vital que 'Region Enabled' esté activado en el Inspector
	region_enabled = true 
	
	var res_manager = get_node_or_null("/root/ResolutionManager")
	if res_manager:
		res_manager.resolution_changed.connect(_on_resolution_changed)
	
	apply_background_region()

func _on_resolution_changed(_new_res: Vector2i):
	apply_background_region()

func apply_background_region():
	var viewport_size = get_viewport_rect().size
	
	# Ajustamos el rectángulo de la región al tamaño total de la pantalla
	# Esto evita que la imagen se estire (scaling) y permite que se 'extienda'
	region_rect = Rect2(Vector2.ZERO, viewport_size)
	
	# Aseguramos que la posición sea el origen
	global_position = Vector2.ZERO
	
	print("Fondo: Región ajustada a ", viewport_size)
