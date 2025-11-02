extends Node

func _ready():
	print("=== TESTING BLOCK SYSTEM ===")
	
	# get b inf
	var move_block = BlockSystem.get_block_info("move_forward")
	print("Move Forward Block: ", move_block)
	
	# Get blok category
	var movement_blocks = BlockSystem.get_blocks_by_category("movement")
	print("Movement Blocks: ", movement_blocks)
	
	# Get Ram Piece
	var pawn_ram = BlockSystem.get_piece_ram_capacity("pawn")
	print("Pawn RAM: ", pawn_ram)
	
	# Calculate ramS
	var test_script = [
		{"type": "move_forward"},
		{"type": "if_enemy_front"}, 
		{"type": "capture"}
	]
	var ram_used = BlockSystem.calculate_ram_usage(test_script)
	print("Test Script RAM: ", ram_used, "/", pawn_ram)
	
	# Verify Validity
	var is_valid = BlockSystem.is_script_valid(test_script, pawn_ram)
	print("Script Valid: ", is_valid)
