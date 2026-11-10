extends Node2D  # Este es el nodo Board en Main/Table/Board

@export var base_cell_size: float = 80.0
@export var board_size: Vector2 = Vector2(8, 8)

# Sistema de posicionamiento
# Convencion de coordenadas: la celda (0,0) es la esquina superior izquierda
# en pantalla (negras arriba, blancas abajo). Y crece hacia abajo y no se
# invierte en ninguna conversion.
var cell_size: float = 80.0
# board_origin y board_center estan en el espacio del nodo padre (Table), NO
# en coordenadas globales. Para convertir entre celdas y pantalla usar
# cell_to_global() y global_to_cell().
var board_origin: Vector2 = Vector2.ZERO
var board_center: Vector2 = Vector2.ZERO

func _ready():
	print("=== TABLERO REAL INICIALIZADO ===")
	
	# El tablero se ubica siempre sobre el diseno de 1360x768. Si el area
	# visible es mayor, la camara centra ese diseno (ver camera_2d.gd)
	update_board_for_resolution(Vector2(ResolutionManager.BASE_SIZE))
	
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

# El tamano de celda es fijo: el escalado a la ventana lo hace Godot
func calculate_cell_size(_screen_size: Vector2) -> float:
	return base_cell_size

# Centro de una celda en coordenadas globales. Respeta la transformacion de
# Table y del propio tablero, asi que no depende de sus desplazamientos.
func cell_to_global(cell: Vector2) -> Vector2:
	return to_global(Vector2(
		cell.x * cell_size + cell_size / 2.0,
		cell.y * cell_size + cell_size / 2.0
	))

# Inversa exacta de cell_to_global. Puede devolver celdas fuera del tablero
# (por ejemplo (-1, 3)); usar is_inside_board() para validarlas.
func global_to_cell(global_pos: Vector2) -> Vector2i:
	var local := to_local(global_pos)
	return Vector2i(int(floor(local.x / cell_size)), int(floor(local.y / cell_size)))

func is_inside_board(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < int(board_size.x) and cell.y < int(board_size.y)
