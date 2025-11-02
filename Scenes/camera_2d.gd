extends Camera2D

@export var factor_base: float = 0.7
@export var sensibilidad_tamano: float = 0.5  # Sensibility to size

func _ready():
	await get_tree().process_frame
	ajustar_zoom_automatico()

func ajustar_zoom_automatico():
	var viewport_size = get_viewport().get_visible_rect().size
	var target_resolution = Vector2(1360, 768) ## TODO make it interactive
	
	var scale_x = viewport_size.x / target_resolution.x
	var scale_y = viewport_size.y / target_resolution.y
	var zoom_factor = min(scale_x, scale_y)
	
	# Calculate factor of longiness
	var factor_alejamiento = calcular_factor_alejamiento(viewport_size)
	
	self.zoom = Vector2(1.0 / zoom_factor * factor_alejamiento, 1.0 / zoom_factor * factor_alejamiento)

func calcular_factor_alejamiento(viewport_size: Vector2) -> float:
	var area_viewport = viewport_size.x * viewport_size.y
	var area_base = 1920.0 * 1080.0
	
	# aspect ratio
	var relacion_tamano = area_viewport / area_base
	
	return factor_base * pow(relacion_tamano, sensibilidad_tamano)
