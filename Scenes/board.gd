extends Node2D  # Este es el nodo Board en Main/Table/Board

@export var base_cell_size: float = 80.0
@export var board_size: Vector2 = Vector2(8, 8)

# Sistema de posicionamiento
var cell_size: float = 80.0
var board_origin: Vector2 = Vector2.ZERO
var board_center: Vector2 = Vector2.ZERO

func _ready():
	print("=== TABLERO REAL INICIALIZADO ===")
	
	# Escuchar cambios de resolución
	var main = get_node_or_null("/root/Main")
	if main and main.has_signal("resolution_changed"):
		main.resolution_changed.connect(_on_resolution_changed)
	
	# Posicionar inicialmente
	update_board_for_resolution(get_viewport().get_visible_rect().size)
	
	# Configurar Area2D para todo el tablero
	_setup_area2d()

func _setup_area2d():
	if has_node("Area2D"):
		var area = $Area2D
		var shape = RectangleShape2D.new()
		var total_size = board_size * cell_size
		shape.extents = total_size / 2
		
		if area.has_node("CollisionShape2D"):
			var collision = area.get_node("CollisionShape2D")
			collision.shape = shape
			collision.position = total_size / 2  # Centrar la forma de colisión

func _on_resolution_changed(new_resolution: Vector2i):
	print("Board: Resolución cambiada a ", new_resolution)
	update_board_for_resolution(Vector2(new_resolution))

func update_board_for_resolution(screen_size: Vector2):
	print("Actualizando tablero real para: ", screen_size)
	
	# 1. Calcular tamaño de celda
	cell_size = calculate_cell_size(screen_size)
	
	# 2. Calcular tamaño total
	var board_total_size = board_size * cell_size
	
	# 3. Calcular posición CENTRADA
	var board_position = Vector2(
		(screen_size.x - board_total_size.x) / 2,
		(screen_size.y - board_total_size.y) / 2
	)
	
	# 4. Actualizar posición DEL NODO REAL (este nodo)
	position = board_position
	
	# 5. Actualizar sprite si existe
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		sprite.position = board_total_size / 2  # Centrar sprite en el nodo
		
		# Escalar sprite para que cubra el tablero
		var texture_size = sprite.texture.get_size() if sprite.texture else Vector2(640, 640)
		var scale_x = board_total_size.x / texture_size.x
		var scale_y = board_total_size.y / texture_size.y
		sprite.scale = Vector2(scale_x, scale_y)
	
	# 6. Actualizar puntos de referencia
	board_origin = board_position
	board_center = board_position + (board_total_size / 2)
	
	# 7. Actualizar Area2D
	_setup_area2d()
	
	print("Tablero real actualizado:")
	print("  Posición: ", position)
	print("  Tamaño celda: ", cell_size)
	print("  Tamaño total: ", board_total_size)

func calculate_cell_size(screen_size: Vector2) -> float:
	var base_height = 768.0
	var scale_factor = screen_size.y / base_height
	scale_factor = clamp(scale_factor, 0.8, 1.2)
	return base_cell_size * scale_factor

func get_board_origin() -> Vector2:
	return board_origin


func get_world_position_from_cell(cell_coord: Vector2) -> Vector2:
	"""Convierte coordenadas de celda a posición mundial"""
	
	return board_origin + Vector2(
		cell_coord.x * cell_size + (cell_size / 2),
		cell_coord.y * cell_size + (cell_size / 2)  # SIN INVERTIR
	)

func get_cell_coord(world_pos: Vector2) -> Vector2:
	"""Obtiene coordenadas de celda desde posición mundial"""
	var local_pos = world_pos - board_origin
	
	var cell_x = floor(local_pos.x / cell_size)
	var cell_y = floor(local_pos.y / cell_size)
	
	# Invertir Y para obtener coordenadas de ajedrez
	var chess_y = (board_size.y - 1) - cell_y
	
	return Vector2(cell_x, chess_y)
