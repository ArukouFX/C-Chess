extends Node

#Loop system
static var custom_loops := {}
static var loop_counter := 0

#Escape system
static var custom_escapes := {}
static var escape_counter := 0

static var block_definitions = {
	# --- MOVIMIENTOS ORTOGONALES (Coste: 2 RAM) ---
	"move_f": { "name": "Adelante ↑", "vector": Vector2i(0, 1), "ram_cost": 2, "category": "movement", "color": Color.ROYAL_BLUE, "execute": move_generic },
	"move_b": { "name": "Atrás ↓", "vector": Vector2i(0, -1), "ram_cost": 2, "category": "movement", "color": Color.ROYAL_BLUE, "execute": move_generic },
	"move_l": { "name": "Izquierda ←", "vector": Vector2i(-1, 0), "ram_cost": 2, "category": "movement", "color": Color.ROYAL_BLUE, "execute": move_generic },
	"move_r": { "name": "Derecha →", "vector": Vector2i(1, 0), "ram_cost": 2, "category": "movement", "color": Color.ROYAL_BLUE, "execute": move_generic },

	# --- MOVIMIENTOS DIAGONALES (Coste: 3 RAM) ---
	"move_fl": { "name": "Diag. Adel. Izq. ↖", "vector": Vector2i(-1, 1), "ram_cost": 3, "category": "movement", "color": Color.ROYAL_BLUE, "execute": move_generic },
	"move_fr": { "name": "Diag. Adel. Der. ↗", "vector": Vector2i(1, 1), "ram_cost": 3, "category": "movement", "color": Color.ROYAL_BLUE, "execute": move_generic },
	"move_bl": { "name": "Diag. Atrás Izq. ↙", "vector": Vector2i(-1, -1), "ram_cost": 3, "category": "movement", "color": Color.ROYAL_BLUE, "execute": move_generic },
	"move_br": { "name": "Diag. Atrás Der. ↘", "vector": Vector2i(1, -1), "ram_cost": 3, "category": "movement", "color": Color.ROYAL_BLUE, "execute": move_generic }
}

# --- SISTEMA DE LOOPS AISLADO POR BANDO ---
static var white_loop_counter := 0
static var black_loop_counter := 0

# Creación de loop parametrizada por color de pieza
static func create_loop_block(blocks: Array, ram_cost: int, loop_name: String, piece_color: String) -> String:
	var loop_id := ""
	if piece_color == "white":
		white_loop_counter += 1
		loop_id = "white_loop_%d" % white_loop_counter
	else:
		black_loop_counter += 1
		loop_id = "black_loop_%d" % black_loop_counter
		
	block_definitions[loop_id] = {
		"name": loop_name,
		"type": loop_id,
		"category": "logic",
		"ram_cost": ram_cost,
		"color": Color.MEDIUM_PURPLE,
		"contained_blocks": blocks.duplicate(true),
		"execute": execute_loop_block
	}
	print("Loop creado en bando [", piece_color, "]: ", loop_id)
	print("Contenido:", blocks)
	return loop_id

static func execute_loop_block(piece, block_data):
	var contained_blocks = block_data.get("contained_blocks", [])

	print("Ejecutando loop con ", contained_blocks.size(), " bloques")

	for i in range(contained_blocks.size()):
		var sub_block = contained_blocks[i]
		var block_type = sub_block.get("type", "")

		if block_type == "":
			continue

		var result = await execute_block(
			piece,
			{"type": block_type},
			i
		)

		if result == null:
			return null

		if result.get("stop_execution", false):
			print("Loop detenido por ", result.get("action", "unknown"))
			return result

	return {
		"action":"loop_complete",
		"stop_execution":false
	}

static func execute_block(piece, block_data, instruction_index: int = 0):
	var block_id = block_data.get("type", "")
	var info = block_definitions.get(block_id, {})
	if info.is_empty():
		print("Block no encontrado: ", block_id)
		return null
		
	# LOG CORREGIDO: Imprime el coste real con su penalización visual
	var base_cost = info.get("ram_cost", 0)
	print("BlockSystem: Bloque '", block_id, "' - RAM Base: ", base_cost)
	if instruction_index > 0:
		print("  Instrucción ", instruction_index, ": ", block_id, " +", instruction_index)
	else:
		print("  Instrucción ", instruction_index, ": ", block_id)

	var execute_func = info.get("execute")
	if execute_func:
		var runtime_data = info.duplicate(true)
		runtime_data["type"] = block_id
		for k in block_data.keys():
			runtime_data[k] = block_data[k]
		return await execute_func.call(piece, runtime_data)
	return null

# --- SISTEMA DE ESCAPES AISLADO POR BANDO ---
static var white_escape_counter := 0
static var black_escape_counter := 0

static func create_escape_protocol(blocks: Array, ram_cost: int, protocol_name: String, piece_color: String) -> String:
	var protocol_id := ""
	if piece_color == "white":
		white_escape_counter += 1
		protocol_id = "white_escape_%d" % white_escape_counter
	else:
		black_escape_counter += 1
		protocol_id = "black_escape_%d" % black_escape_counter
		
	block_definitions[protocol_id] = {
		"name": protocol_name,
		"type": protocol_id,
		"category": "action",
		"ram_cost": ram_cost,
		"color": Color.ORANGE,
		"contained_blocks": blocks.duplicate(true),
		"execute": execute_escape_protocol
	}
	print("Protocolo de escape creado en bando [", piece_color, "]: ", protocol_id)
	return protocol_id

static func execute_escape_protocol(piece, block_data):
	var blocks = block_data.get("contained_blocks", [])
	print("=== EJECUTANDO PROTOCOLO DE ESCAPE ===")
	
	for i in range(blocks.size()):
		var block = blocks[i]
		var result = await execute_block(piece, block, i)
		if result == null:
			return null
			
	return {"action":"escape_complete"}

# --- FUNCIONES ADAPTADAS PARA EL FILTRADO Y ENTORNO ---

static func get_block_info(block_type: String) -> Dictionary:
	# Simplemente retorna la info estática sin prints confusos de RAM fija
	return block_definitions.get(block_type, {})


static func get_blocks_for_palette(category: String, piece_color: String) -> Array:
	var result = []
	for block_type in block_definitions:
		var block_info = block_definitions[block_type]
		
		if block_info.get("category") == category:
			# Duplicamos para no alterar el diccionario estático original
			var block_copy = block_info.duplicate(true)
			# INYECCIÓN CRÍTICA: Forzamos que la copia tenga su ID asignado en 'type'
			block_copy["type"] = block_type
			
			# Si es un bloque dinámico (loop o escape), verificamos que pertenezca a su respectivo color
			if "loop" in block_type or "escape" in block_type:
				if block_type.begins_with(piece_color):
					result.append(block_copy)
			else:
				# Si es un movimiento base (move_f, move_b, etc), se comparte globalmente
				result.append(block_copy)
	return result

# Mantener compatibilidad hacia atrás por si tu código de UI viejo aún llama a esta función plana
static func get_blocks_by_category(category: String) -> Array:
	return get_blocks_for_palette(category, "white")

static func get_piece_ram_capacity(piece_type: String) -> int:
	var capacities = { "pawn": 8, "bishop": 20, "horse": 16, "tower": 24, "queen": 32, "king": 12 }
	var ram = capacities.get(piece_type, 8)
	print("BlockSystem: Capacidad RAM para ", piece_type, " = ", ram)
	return ram

static func calculate_ram_usage(script: Array) -> int:
	var total = 0
	
	# Usamos un bucle indexado para saber la posición del bloque en la secuencia
	for i in range(script.size()):
		var block_data = script[i]
		var block_info = get_block_info(block_data.get("type", ""))
		var base_cost = block_info.get("ram_cost", 0)
		
		# Regla incremental: el primer bloque (i=0) cuesta base. 
		# El segundo (i=1) cuesta base + 1, el tercero (i=2) base + 2, etc.
		var incremental_penalty = i
		var final_block_cost = base_cost + incremental_penalty
		
		total += final_block_cost
		
	print("BlockSystem: Uso de RAM total dinámico calculado = ", total)
	return total

static func is_script_valid(script: Array, max_ram: int) -> bool:
	var used = calculate_ram_usage(script)
	var valid = used <= max_ram
	print("BlockSystem: Script válido? ", valid, " (", used, "/", max_ram, ")")
	return valid

# --- FUNCIONES DE MOVIMIENTO CORREGIDAS ---

static func execute_movement(piece, block_id):
	var info = block_definitions.get(block_id, {})
	if info.is_empty(): return null
	var vec = info["vector"]
	var side_multiplier = 1 if piece.piece_color == "white" else -1
	var target = piece.board_position + Vector2(vec.x, vec.y * side_multiplier)
	return {"action": "move", "target": target}

static func execute_loop(piece, block_data):
	var internal_blocks = block_data.get("blocks", [])
	print("=== EJECUTANDO LOOP ===")
	for internal_block in internal_blocks:
		var result = await execute_block(piece, internal_block)
		if result and result.get("stop_execution", false):
			return result
	return {"action": "loop_complete", "stop_execution": false}

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

static func move_generic(piece, params = {}):
	var block_id = params.get("type", "")
	var info = block_definitions.get(block_id, {})
	if info.is_empty():
		print("Error: BlockSystem no reconoce el tipo: ", block_id)
		return {"action":"error","stop_execution":true}
	var vec = info.get("vector", Vector2i.ZERO)
	var side_multiplier = -1 if piece.piece_color == "white" else 1
	var target_board_pos = piece.virtual_board_position + Vector2(vec.x, vec.y * side_multiplier)
	
	if target_board_pos.x < 0 or target_board_pos.x > 7 or target_board_pos.y < 0 or target_board_pos.y > 7:
		print("Fuera de límites: ", target_board_pos)
		return {"action":"out_of_bounds","stop_execution":true}
		
	var gm = piece.get_node_or_null("/root/Main/GameManager")
	if not gm:
		return {"action":"error","stop_execution":true}
		
	var collider = gm.get_piece_at(Vector2i(target_board_pos))
	if collider:
		if collider.piece_color != piece.piece_color:
			print("Captura en ", target_board_pos)
			gm.capture_piece(collider)
			var world_pos = gm._board_to_world_position(target_board_pos)
			var tween = piece.create_tween()
			tween.tween_property(piece, "position", world_pos, 0.20)
			await tween.finished
			piece.virtual_board_position = target_board_pos
			return {"action":"capture","stop_execution":true}
		else:
			if piece.piece_type == "horse":
				var can_phase = piece.has_more_commands()
				if not can_phase:
					print("HORSE FINAL POSITION BLOCKED")
					var rollback_world = gm._board_to_world_position(piece.board_position)
					piece.position = rollback_world
					piece.virtual_board_position = piece.board_position
					return {"action":"blocked","stop_execution":true}
					
				print("HORSE PHASE PASS -> ", target_board_pos)
				var ally_original_world = collider.position
				var offset_dir = Vector2(20,0)
				if randi() % 2 == 0:
					offset_dir = Vector2(-20,0)
				var tween = piece.create_tween()
				tween.set_parallel(true)
				tween.tween_property(collider, "position", ally_original_world + offset_dir, 0.10)
				var horse_world = gm._board_to_world_position(target_board_pos)
				tween.tween_property(piece, "position", horse_world, 0.20)
				await tween.finished
				piece.virtual_board_position = target_board_pos
				var return_tween = piece.create_tween()
				return_tween.tween_property(collider, "position", ally_original_world, 0.10)
				await return_tween.finished
				return {"action":"horse_pass","stop_execution":false}
				
			print("Bloqueado por aliado")
			return {"action":"blocked","stop_execution":true}
			
	var world_pos = gm._board_to_world_position(target_board_pos)
	var tween = piece.create_tween()
	tween.tween_property(piece, "position", world_pos, 0.20)
	await tween.finished
	piece.virtual_board_position = target_board_pos
	return {"action":"move","stop_execution":false}
