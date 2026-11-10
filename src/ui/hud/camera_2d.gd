extends Camera2D

# La camara apunta siempre al centro del diseno de 1360x768. Con una ventana
# de otra proporcion el area visible es mayor y ese diseno queda centrado,
# con el mismo margen a cada lado.

func _ready():
	position = Vector2(ResolutionManager.BASE_SIZE) / 2.0
	zoom = Vector2.ONE
	make_current()
