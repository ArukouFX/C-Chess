extends Node

# Singleton to improme usage

# 1. Dictionary of Blocks
var block_library = {
	# Moviments blocks
	"move_forward": {
		"name": "Mover Adelante",
		"ram_cost": 2,
		"category": "movement",
		"description": "Avanza una casilla hacia adelante",
		"texture": "res://Assets/Blocks/move_forward.png",
		"color": Color("4a9cff")
	},
	"move_back": {
		"name": "Mover Atrás", 
		"ram_cost": 2,
		"category": "movement",
		"description": "Retrocede una casilla",
		"texture": "res://Assets/Blocks/move_back.png",
		"color": Color("4a9cff")
	},
	"move_diagonal": {
		"name": "Mover Diagonal",
		"ram_cost": 3,
		"category": "movement", 
		"description": "Movimiento diagonal (izquierda/derecha)",
		"texture": "res://Assets/Blocks/move_diagonal.png",
		"color": Color("4a9cff")
	},
	"move_L": {
		"name": "Movimiento L",
		"ram_cost": 4,
		"category": "movement",
		"description": "Movimiento en L (caballo)",
		"texture": "res://Assets/Blocks/move_L.png",
		"color": Color("4a9cff")
	},
	
	# Logic blocks
	"if_enemy_front": {
		"name": "Si Enemigo Frente",
		"ram_cost": 3,
		"category": "logic",
		"description": "Si hay enemigo en la casilla frontal",
		"texture": "res://Assets/Blocks/if_enemy_front.png",
		"color": Color("ff6b4a")
	},
	"if_ally_front": {
		"name": "Si Aliado Frente",
		"ram_cost": 3,
		"category": "logic",
		"description": "Si hay aliado en la casilla frontal", 
		"texture": "res://Assets/Blocks/if_ally_front.png",
		"color": Color("ff6b4a")
	},
	"loop_3": {
		"name": "Repetir 3 Veces",
		"ram_cost": 5,
		"category": "logic",
		"description": "Ejecuta bloques internos 3 veces",
		"texture": "res://Assets/Blocks/loop_3.png",
		"color": Color("ff6b4a")
	},
	
	# Sensor blocks
	"detect_enemy": {
		"name": "Detectar Enemigo",
		"ram_cost": 4,
		"category": "sensor", 
		"description": "Detecta enemigos en rango de 2 casillas",
		"texture": "res://Assets/Blocks/detect_enemy.png",
		"color": Color("4aff6b")
	},
	"detect_wall": {
		"name": "Detectar Pared",
		"ram_cost": 2,
		"category": "sensor",
		"description": "Detecta si hay borde del tablero adelante",
		"texture": "res://Assets/Blocks/detect_wall.png",
		"color": Color("4aff6b")
	},
	
	# Action blocks
	"capture": {
		"name": "Capturar",
		"ram_cost": 3,
		"category": "action",
		"description": "Captura pieza enemiga en posición actual",
		"texture": "res://Assets/Blocks/capture.png",
		"color": Color("ff4ae6")
	}
}

# 2. Capacity of ram
var piece_ram_capacity = {
	"pawn": 8,      # Peón
	"horse": 16,    # Caballo  
	"bishop": 20,   # Alfil
	"tower": 24,    # Torre
	"queen": 32,    # Reina
	"king": 12      # Rey
}

# 3. Public funcs

func get_block_info(block_type: String) -> Dictionary:
	if block_library.has(block_type):
		return block_library[block_type].duplicate()
	else:
		push_error("Block type not found: " + block_type)
		return {}

## Get all the blocks
func get_blocks_by_category(category: String) -> Array:
	var result = []
	for block_type in block_library:
		if block_library[block_type]["category"] == category:
			result.append(block_type)
	return result

## Ram capacity
func get_piece_ram_capacity(piece_type: String) -> int:
	if piece_ram_capacity.has(piece_type):
		return piece_ram_capacity[piece_type]
	else:
		push_error("Piece type not found: " + piece_type)
		return 0

## Calculate ram usage
func calculate_ram_usage(blocks: Array) -> int:
	var total_ram = 0
	for block_data in blocks:
		if block_data is Dictionary and block_data.has("type"):
			var block_info = get_block_info(block_data["type"])
			total_ram += block_info.get("ram_cost", 0)
	return total_ram

## Verify if there's ram
func is_script_valid(blocks: Array, available_ram: int) -> bool:
	return calculate_ram_usage(blocks) <= available_ram

## Get categiries
func get_available_categories() -> Array:
	var categories = []
	for block_type in block_library:
		var category = block_library[block_type]["category"]
		if not category in categories:
			categories.append(category)
	return categories

# 4. Debug
func print_block_library():
	print("=== BLOCK LIBRARY ===")
	for block_type in block_library:
		var block = block_library[block_type]
		print("• %s: %s (RAM: %d)" % [block_type, block.name, block.ram_cost])
	print("=====================")

func print_piece_ram_capacities():
	print("=== PIECE RAM CAPACITIES ===")
	for piece_type in piece_ram_capacity:
		print("• %s: %d RAM" % [piece_type, piece_ram_capacity[piece_type]])
	print("============================")

# 5. Inilization
func _ready():
	print("🔧 BlockSystem loaded successfully!")
	print_block_library()
	print_piece_ram_capacities()
