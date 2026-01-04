extends Node

static var block_definitions = {
	"move_forward": {
		"name": "Mover Adelante",
		"description": "Mueve la pieza una casilla hacia adelante",
		"ram_cost": 2,  # Cambiado de 1 a 2
		"category": "movement",
		"color": Color.ROYAL_BLUE,
		"execute": move_forward
	},
	"move_diagonal": {
		"name": "Mover Diagonal",
		"description": "Mueve la pieza en diagonal",
		"ram_cost": 3,  # Cambiado de 1 a 3
		"category": "movement",
		"color": Color.ROYAL_BLUE,
		"execute": move_diagonal
	},
	"capture": {
		"name": "Capturar",
		"description": "Captura una pieza enemiga adyacente",
		"ram_cost": 3,  # Ya está en 3 (correcto)
		"category": "action",
		"color": Color.FIREBRICK,
		"execute": capture_piece
	},
	"if_enemy_front": {
		"name": "Si Enemigo Adelante",
		"description": "Condición: verifica si hay enemigo adelante",
		"ram_cost": 2,  # Cambiado de 1 a 2
		"category": "logic",
		"color": Color.FOREST_GREEN,
		"execute": check_enemy_front
	}
}

static func get_block_info(block_type: String) -> Dictionary:
	var block = block_definitions.get(block_type, {})
	if not block.is_empty():
		print("BlockSystem: Bloque '", block_type, "' - RAM: ", block.get("ram_cost", 0))
	return block

static func get_blocks_by_category(category: String) -> Array:
	var result = []
	for block_type in block_definitions:
		if block_definitions[block_type].get("category") == category:
			result.append(block_definitions[block_type])
	return result

static func get_piece_ram_capacity(piece_type: String) -> int:
	var capacities = {
		"pawn": 8,      # Cambiado de 4 a 8
		"bishop": 20,   # Cambiado de 6 a 20
		"horse": 16,    # Cambiado de 5 a 16
		"tower": 24,    # Cambiado de 6 a 24
		"queen": 32,    # Cambiado de 8 a 32
		"king": 12      # Cambiado de 10 a 12
	}
	var ram = capacities.get(piece_type, 8)
	print("BlockSystem: Capacidad RAM para ", piece_type, " = ", ram)
	return ram

static func calculate_ram_usage(script: Array) -> int:
	var total = 0
	for block_data in script:
		var block_info = get_block_info(block_data.get("type", ""))
		total += block_info.get("ram_cost", 0)
	print("BlockSystem: Uso de RAM calculado = ", total)
	return total

static func is_script_valid(script: Array, max_ram: int) -> bool:
	var used = calculate_ram_usage(script)
	var valid = used <= max_ram
	print("BlockSystem: Script válido? ", valid, " (", used, "/", max_ram, ")")
	return valid

# === FUNCIONES DE EJECUCIÓN ===
static func move_forward(piece, params = {}):
	var direction = 1 if piece.piece_color == "white" else -1
	var new_position = piece.board_position + Vector2(0, -direction)
	return {"action": "move", "target": new_position}

static func move_diagonal(piece, params = {}):
	var direction = 1 if piece.piece_color == "white" else -1
	var diagonal_left = piece.board_position + Vector2(-1, -direction)
	var diagonal_right = piece.board_position + Vector2(1, -direction)
	return {"action": "move_options", "targets": [diagonal_left, diagonal_right]}

static func capture_piece(piece, params = {}):
	return {"action": "capture", "direction": params.get("direction", "front")}

static func check_enemy_front(piece, params = {}):
	return {"action": "condition", "check": "enemy_front", "result": true}
