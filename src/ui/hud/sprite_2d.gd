extends Sprite2D

# Fondo de la partida. Usa una region del tamano del area visible (la textura
# se repite en lugar de estirarse) y se ubica en su esquina superior
# izquierda, asi cubre la ventana con cualquier proporcion.

func _ready():
	centered = false
	region_enabled = true
	ResolutionManager.layout_changed.connect(apply_background_region)
	apply_background_region()

func apply_background_region():
	var vis := ResolutionManager.visible_size()
	region_rect = Rect2(Vector2.ZERO, vis)
	# En el mundo, el diseno ocupa (0,0)-(1360,768) y la camara lo centra
	global_position = (Vector2(ResolutionManager.BASE_SIZE) - vis) / 2.0
