extends Node

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

#Loop system
static var custom_loops := {}
static var loop_counter := 0

static func create_loop_block(blocks: Array, ram_cost: int, loop_name: String) -> String:
	loop_counter += 1
	var loop_id = "loop%d" % loop_counter
	block_definitions[loop_id] = {
		"name": loop_name,
		"type": loop_id,
		"category": "logic",
		"ram_cost": ram_cost,
		"color": Color.MEDIUM_PURPLE,
		"contained_blocks": blocks.duplicate(true),
		"execute": execute_loop_block
	}
	print("Loop creado:", loop_id)
	print("Contenido:", blocks)
	return loop_id

static func execute_loop_block(piece, block_data):
	var contained_blocks = block_data.get("contained_blocks", [])
	print("Ejecutando loop con ", contained_blocks.size(), " bloques")
	for sub_block in contained_blocks:
		var block_type = sub_block.get("type", "")
		if block_type == "":
			print("ERROR: bloque dentro del loop no tiene type")
			continue
		var result = await execute_block(piece, {
			"type": block_type
		})
		if result == null:
			return null
	return {"action":"loop_complete"}

static func execute_block(piece, block_data):
	var block_id = block_data.get("type", "")
	var info = block_definitions.get(block_id, {})
	if info.is_empty():
		print("Block no encontrado: ", block_id)
		return null
	var execute_func = info.get("execute")
	if execute_func:
		var runtime_data = info.duplicate(true)
		runtime_data["type"] = block_id
		# si vienen datos extra del loop
		for k in block_data.keys():
			runtime_data[k] = block_data[k]
		return await execute_func.call(piece, runtime_data)
	return null

# Función genérica para ejecutar cualquier movimiento basado en su vector
static func execute_movement(piece, block_id):
	var info = block_definitions.get(block_id, {})
	if info.is_empty(): return null
	
	var vec = info["vector"]
	# Si la pieza es negra, invertimos el eje Y para que "Adelante" sea hacia abajo
	var side_multiplier = 1 if piece.piece_color == "white" else -1
	var target = piece.board_position + Vector2(vec.x, vec.y * side_multiplier)
	
	return {"action": "move", "target": target}

static func execute_loop(piece, block_data):
	var internal_blocks = block_data.get("blocks", [])
	print("=== EJECUTANDO LOOP ===")
	for internal_block in internal_blocks:
		var result = await execute_block(
			piece,
			internal_block
		)
		# Si un bloque interno detiene ejecución
		# propagamos el stop
		if result and result.get("stop_execution", false):
			return result
	return {
		"action": "loop_complete",
		"stop_execution": false
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
		"pawn": 8,
		"bishop": 20,
		"horse": 16,
		"tower": 24,
		"queen": 32,
		"king": 12
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

static func move_generic(piece, params = {}):

	var block_id = params.get("type", "")
	var info = block_definitions.get(block_id, {})

	if info.is_empty():
		print("Error: BlockSystem no reconoce el tipo: ", block_id)
		return {"action":"error","stop_execution":true}

	var vec = info.get("vector", Vector2i.ZERO)

	# ==========================================
	# USAR SIEMPRE POSICIÓN VIRTUAL
	# ==========================================

	var side_multiplier = -1 if piece.piece_color == "white" else 1

	var target_board_pos = (
		piece.virtual_board_position +
		Vector2(vec.x, vec.y * side_multiplier)
	)

	# ==========================================
	# LÍMITES
	# ==========================================

	if target_board_pos.x < 0 or target_board_pos.x > 7 \
	or target_board_pos.y < 0 or target_board_pos.y > 7:

		print("Fuera de límites: ", target_board_pos)

		return {
			"action":"out_of_bounds",
			"stop_execution":true
		}

	var gm = piece.get_node_or_null("/root/Main/GameManager")

	if not gm:
		return {"action":"error","stop_execution":true}

	# ==========================================
	# COLISIONES
	# ==========================================

	var collider = gm.get_piece_at(Vector2i(target_board_pos))

	# =========================================================
	# SI HAY PIEZA
	# =========================================================

	if collider:

		# ======================================
		# ENEMIGO
		# ======================================

		if collider.piece_color != piece.piece_color:

			print("Captura en ", target_board_pos)

			gm.capture_piece(collider)

			var world_pos = gm._board_to_world_position(target_board_pos)

			var tween = piece.create_tween()

			tween.tween_property(
				piece,
				"position",
				world_pos,
				0.20
			)

			await tween.finished

			# SOLO virtual
			piece.virtual_board_position = target_board_pos

			return {
				"action":"capture",
				"stop_execution":true
			}

		# ======================================
		# ALIADO
		# ======================================

		else:

			# ==================================
			# CABALLO
			# ==================================

			if piece.piece_type == "horse":

				var can_phase = piece.has_more_commands()

				# ==================================
				# ÚLTIMO MOVIMIENTO
				# ==================================

				if not can_phase:

					print("HORSE FINAL POSITION BLOCKED")

					# IMPORTANTE:
					# rollback visual

					var rollback_world = gm._board_to_world_position(
						piece.board_position
					)

					piece.position = rollback_world
					piece.virtual_board_position = piece.board_position

					return {
						"action":"blocked",
						"stop_execution":true
					}

				# ==================================
				# PHASE PASS
				# ==================================

				print("HORSE PHASE PASS -> ", target_board_pos)

				var ally_original_world = collider.position

				var offset_dir = Vector2(20,0)

				if randi() % 2 == 0:
					offset_dir = Vector2(-20,0)

				var tween = piece.create_tween()

				tween.set_parallel(true)

				tween.tween_property(
					collider,
					"position",
					ally_original_world + offset_dir,
					0.10
				)

				var horse_world = gm._board_to_world_position(
					target_board_pos
				)

				tween.tween_property(
					piece,
					"position",
					horse_world,
					0.20
				)

				await tween.finished

				# ==================================
				# SOLO VIRTUAL
				# ==================================

				piece.virtual_board_position = target_board_pos

				var return_tween = piece.create_tween()

				return_tween.tween_property(
					collider,
					"position",
					ally_original_world,
					0.10
				)

				await return_tween.finished

				return {
					"action":"horse_pass",
					"stop_execution":false
				}

			# ==================================
			# OTRAS PIEZAS BLOQUEADAS
			# ==================================

			print("Bloqueado por aliado")

			return {
				"action":"blocked",
				"stop_execution":true
			}

	# =========================================================
	# CASILLA VACÍA
	# =========================================================

	var world_pos = gm._board_to_world_position(target_board_pos)

	var tween = piece.create_tween()

	tween.tween_property(
		piece,
		"position",
		world_pos,
		0.20
	)

	await tween.finished

	# SOLO virtual
	piece.virtual_board_position = target_board_pos

	return {
		"action":"move",
		"stop_execution":false
	}
