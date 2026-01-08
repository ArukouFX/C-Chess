extends Camera2D

var board_center: Vector2 = Vector2.ZERO

func _ready():
	print("=== CÁMARA CENTRADA EN TABLERO ===")
	
	# Escuchar cambios de resolución
	var main = get_node_or_null("/root/Main")
	if main and main.has_signal("resolution_changed"):
		main.resolution_changed.connect(_on_resolution_changed)
	
	# Esperar a que el tablero se posicione
	await get_tree().process_frame
	
	# Centrar en el tablero
	center_on_board()
	
	self.make_current()

func _on_resolution_changed(new_resolution: Vector2i):
	print("Camera: Resolución cambiada")
	# Esperar un frame para que el board se actualice
	await get_tree().process_frame
	center_on_board()

func center_on_board():
	var board = get_node_or_null("/root/Main/Table/Board")
	
	if board and board.has_method("get_center"):
		# Si el board tiene método para obtener su centro
		board_center = board.get_center()
	elif board:
		# Calcular centro manualmente
		var board_pos = board.position
		var cell_size = board.cell_size if board.has_method("get_cell_size") else 80.0
		var board_size = board.board_size if board.has_method("get_board_size") else Vector2(8, 8)
		
		var board_total_size = board_size * cell_size
		board_center = board_pos + (board_total_size / 2)
	else:
		# Fallback: centrar en pantalla
		board_center = get_viewport().get_visible_rect().size / 2
	
	# Posicionar cámara en el centro del tablero
	self.position = board_center
	
	# Zoom fijo (no cambiar con resolución)
	self.zoom = Vector2(1.0, 1.0)
	
	print("Cámara centrada:")
	print("  Posición: ", position)
	print("  Centro tablero: ", board_center)
	print("  Zoom: ", zoom)

# Opcional: Añadir función para seguir pieza específica
func follow_piece(piece_position: Vector2, zoom_level: float = 1.0):
	var tween = create_tween()
	tween.tween_property(self, "position", piece_position, 0.5)
	tween.parallel().tween_property(self, "zoom", Vector2(zoom_level, zoom_level), 0.5)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
