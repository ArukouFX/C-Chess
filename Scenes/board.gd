extends Node2D

@export var cell_size: float = 160.0
@export var board_size: Vector2 = Vector2(8, 8)

func get_board_origin() -> Vector2:
	return global_position - (board_size * cell_size / 2)

func is_inside_board(world_pos: Vector2) -> bool:
	var origin = get_board_origin()
	var size = board_size * cell_size
	
	#Use margin to tolarance problems
	var margin = 0.1
	
	var inside = (world_pos.x >= origin.x - margin and 
				 world_pos.x <= origin.x + size.x + margin and
				 world_pos.y >= origin.y - margin and 
				 world_pos.y <= origin.y + size.y + margin)
	
	print("Inside board with margin: ", inside)
	return inside

func get_nearest_cell_pos(world_pos: Vector2) -> Vector2:
	var origin = get_board_origin()
	var local_pos = world_pos - origin
	
	print("Get nearest cell - World: ", world_pos, " Local: ", local_pos)
	
	# Calcular coordenadas de celda
	var cell_coord = Vector2(
		floor(local_pos.x / cell_size),
		floor(local_pos.y / cell_size)
	)
	
	print("Raw cell coord: ", cell_coord)
	
	# get in the table
	cell_coord = cell_coord.clamp(Vector2.ZERO, board_size - Vector2.ONE)
	
	print("Clamped cell coord: ", cell_coord)
	
	var result = origin + (cell_coord * cell_size) + Vector2(cell_size / 2, cell_size / 2)
	print("Final cell position: ", result)
	
	return result

# Visual Debug, to delete nextly
func _draw():
	var origin = get_board_origin()
	var size = board_size * cell_size
	
	# Draw rectangle
	draw_rect(Rect2(origin, size), Color(0, 1, 0, 0.2), true)
	
	# Draw board
	draw_rect(Rect2(origin, size), Color(0, 1, 0, 0.8), false, 2.0)
	
	# Cell Center
	for x in range(board_size.x):
		for y in range(board_size.y):
			var cell_center = origin + Vector2(x * cell_size + cell_size / 2, y * cell_size + cell_size / 2)
			draw_circle(cell_center, 3, Color.RED)

func _ready():
	queue_redraw()
