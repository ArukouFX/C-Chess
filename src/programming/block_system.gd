extends Node

# Definiciones de bloques. Los movimientos base son fijos; los loops y escapes
# que crean los jugadores se agregan en tiempo de ejecucion.
#
# Es static: vive mientras el juego este abierto, no por escena. Cada modo
# (partida nueva, tutorial, desafio) llama a clear_custom_blocks() al empezar
# para no heredar bloques de otro modo, y una partida cargada los restaura con
# import_custom_blocks().
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
	# Una entrada guardada solo como {"type": id} toma el contenido de la definicion
	if contained_blocks.is_empty():
		contained_blocks = get_block_info(block_data.get("type", "")).get("contained_blocks", [])

	# Si el loop esta anidado, hereda si quedan instrucciones despues de el
	var parent_has_more: bool = block_data.get("has_more_in_container", false)

	print("Ejecutando loop con ", contained_blocks.size(), " bloques")

	for i in range(contained_blocks.size()):
		var sub_block = contained_blocks[i]
		var block_type = sub_block.get("type", "")

		if block_type == "":
			continue

		# Le indica al paso si todavia vienen mas movimientos dentro de este
		# loop (o despues, en el loop padre). El caballo lo usa para saber si
		# puede atravesar a un aliado.
		var has_more_after: bool = i < contained_blocks.size() - 1 or parent_has_more
		var result = await execute_block(
			piece,
			{"type": block_type, "has_more_in_container": has_more_after},
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
		var block = blocks[i].duplicate(true)
		block["is_escape"] = true
		var result = await execute_block(piece, block, i)
		if result == null:
			return null
		if result.get("stop_execution", false):
			return result
	return {"action":"escape_complete"}

# --- FUNCIONES ADAPTADAS PARA EL FILTRADO Y ENTORNO ---

static func get_block_info(block_type: String) -> Dictionary:
	# Simplemente retorna la info estática sin prints confusos de RAM fija
	return block_definitions.get(block_type, {})


# Las flechas de los nombres indican hacia donde se mueve la pieza en la
# pantalla. Las blancas juegan desde abajo, asi que su "adelante" es hacia
# arriba; las negras juegan desde arriba y su "adelante" es hacia abajo. Por
# eso, para las negras, se invierte el componente vertical de la flecha. La
# izquierda y la derecha coinciden en pantalla para ambos colores.
const BLACK_ARROWS := {"↑": "↓", "↓": "↑", "↖": "↙", "↙": "↖", "↗": "↘", "↘": "↗"}

static func get_display_name(block_type: String, piece_color: String) -> String:
	var block_name: String = get_block_info(block_type).get("name", block_type)
	if piece_color != "black":
		return block_name
	var result := ""
	for ch in block_name:
		result += BLACK_ARROWS.get(ch, ch)
	return result

static func get_blocks_for_palette(category: String, piece_color: String) -> Array:
	var result = []
	for block_type in block_definitions:
		var block_info = block_definitions[block_type]
		
		# Los escapes generados por el bot no se ofrecen al jugador
		if block_info.get("bot_only", false):
			continue
		if block_info.get("category") == category:
			# Duplicamos para no alterar el diccionario estático original
			var block_copy = block_info.duplicate(true)
			# INYECCIÓN CRÍTICA: Forzamos que la copia tenga su ID asignado en 'type'
			block_copy["type"] = block_type
			block_copy["name"] = get_display_name(block_type, piece_color)
			
			# Si es un bloque dinámico (loop o escape), verificamos que pertenezca a su respectivo color
			if "loop" in block_type or "escape" in block_type:
				if block_type.begins_with(piece_color):
					result.append(block_copy)
			else:
				# Si es un movimiento base (move_f, move_b, etc), se comparte globalmente
				result.append(block_copy)
	return result

static func get_piece_ram_capacity(piece_type: String) -> int:
	var capacities = { "pawn": 8, "bishop": 20, "horse": 16, "tower": 24, "queen": 32, "king": 12 }
	var ram = capacities.get(piece_type, 8)
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
	var is_escape = params.get("is_escape", false)
	print("[DEBUG] collider encontrado: ", collider.piece_id if collider else "null")

	if collider:
		if is_escape:
			# Una huida nunca captura: cualquier ocupante bloquea el escape
			print("Escape bloqueado: casilla ocupada por ", collider.piece_id)
			return {"action":"blocked", "stop_execution":true}
			
		if collider.piece_color != piece.piece_color:
			print("Captura en ", target_board_pos)
			# Orden intencional: primero se resuelve la captura (o el escape de
			# la victima) y despues entra el atacante. Mientras se resuelve, el
			# atacante sigue en su casilla de origen, asi que la victima no
			# puede escapar hacia ella. Los desafios se disenaron con esta regla.
			await gm.capture_piece(collider, piece)
			var world_pos = gm._board_to_world_position(target_board_pos)
			var tween = piece.create_tween()
			tween.tween_property(piece, "position", world_pos, 0.20)
			await tween.finished
			piece.board_position = target_board_pos
			piece.virtual_board_position = target_board_pos
			piece.remove_meta(PHASE_RETURN_META)
			return {"action":"capture","stop_execution":true}
		else:
			if piece.piece_type == "horse":
				# Quedan instrucciones en el programa principal o dentro del loop actual
				var can_phase = piece.has_more_commands() or params.get("has_more_in_container", false)
				if not can_phase:
					print("HORSE FINAL POSITION BLOCKED")
					var rollback_world = gm._board_to_world_position(piece.board_position)
					piece.position = rollback_world
					piece.virtual_board_position = piece.board_position
					return {"action":"blocked","stop_execution":true}

				print("HORSE PHASE PASS -> ", target_board_pos)
				# Casilla libre desde la que empezo a atravesar aliados: si el
				# programa termina sobre uno, vuelve ahi (resolve_phase_end)
				if not piece.has_meta(PHASE_RETURN_META):
					piece.set_meta(PHASE_RETURN_META, piece.board_position)
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
				piece.board_position = target_board_pos
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
	piece.board_position = target_board_pos
	piece.virtual_board_position = target_board_pos
	piece.remove_meta(PHASE_RETURN_META)
	return {"action":"move","stop_execution":false}

const PHASE_RETURN_META := "phase_return_cell"

# El caballo puede atravesar aliados pero no terminar sobre uno. Si su programa
# se corta mientras esta encima de un aliado (por ejemplo, el paso siguiente se
# sale del tablero), vuelve a la ultima casilla libre en la que estuvo.
static func resolve_phase_end(piece) -> void:
	if not is_instance_valid(piece) or not piece.has_meta(PHASE_RETURN_META):
		return
	var return_cell: Vector2 = piece.get_meta(PHASE_RETURN_META)
	piece.remove_meta(PHASE_RETURN_META)
	if piece.get_meta("is_dead", false):
		return
	var gm = piece.get_node_or_null("/root/Main/GameManager")
	if not gm:
		return
	var other = gm.get_piece_at(Vector2i(piece.board_position), true, piece)
	if other == null or other.piece_color != piece.piece_color:
		return  # termino en una casilla libre: no hay nada que corregir
	var tween = piece.create_tween()
	tween.tween_property(piece, "position", gm._board_to_world_position(return_cell), 0.20)
	await tween.finished
	piece.board_position = return_cell
	piece.virtual_board_position = return_cell

# Eliminacion de bloques personalizados

const CUSTOM_BLOCK_PREFIXES := ["white_loop_", "black_loop_", "white_escape_", "black_escape_"]

# saber si un bloque se puede borrar.
static func is_deletable_block(block_id: String) -> bool:
	if not block_definitions.has(block_id):
		return false
	var info: Dictionary = block_definitions[block_id]

	# Un bloque con vector o de categoria movement es un movimiento base: protegido
	if info.has("vector") or info.get("category", "") == "movement":
		return false

	# Solo los bloques creados por el jugador tienen contenido interno
	if not info.has("contained_blocks"):
		return false

	for prefix in CUSTOM_BLOCK_PREFIXES:
		if block_id.begins_with(prefix):
			return true
	return false

# Devuelve los loops/escapes
static func get_blocks_containing(block_id: String) -> Array:
	var result := []
	for other_id in block_definitions:
		if other_id == block_id:
			continue
		var contained = block_definitions[other_id].get("contained_blocks", [])
		for sub in contained:
			if sub is Dictionary and sub.get("type", "") == block_id:
				result.append(other_id)
				break
	return result

static func delete_custom_block(block_id: String) -> bool:
	if not is_deletable_block(block_id):
		push_warning("BlockSystem: intento de eliminar un bloque protegido o inexistente: " + block_id)
		return false

	# Si otro loop/escape lo contiene, borrarlo romperia ese bloque y su coste de RAM
	var parents = get_blocks_containing(block_id)
	if not parents.is_empty():
		print("BlockSystem: no se elimina ", block_id, ", esta contenido en ", parents)
		return false

	# Los contadores no se decrementan para que los IDs nunca se reutilicen
	block_definitions.erase(block_id)
	print("BlockSystem: bloque eliminado ", block_id)
	return true

# Guardado de bloques personalizados
# Solo se guardan datos serializables (id, nombre, coste y contenido). Al
# cargar se reconstruyen el color y la funcion "execute" segun el tipo.
# Los escapes generados por el bot (bot_only) no se guardan: se recrean
# cuando hacen falta.

static func export_custom_blocks() -> Dictionary:
	var blocks := {}
	for block_id in block_definitions:
		if not is_deletable_block(block_id):
			continue
		var info: Dictionary = block_definitions[block_id]
		if info.get("bot_only", false):
			continue
		var contained := []
		for sub in info.get("contained_blocks", []):
			if sub is Dictionary and sub.get("type", "") != "":
				contained.append({"type": sub["type"]})
		blocks[block_id] = {
			"name": info.get("name", block_id),
			"ram_cost": info.get("ram_cost", 0),
			"contained_blocks": contained,
		}
	return {
		"blocks": blocks,
		"counters": {
			"white_loop": white_loop_counter,
			"black_loop": black_loop_counter,
			"white_escape": white_escape_counter,
			"black_escape": black_escape_counter,
		},
	}

# Borra todos los loops y escapes creados (de jugadores y del bot). Los
# movimientos base no se tocan. Los contadores NO se reinician: asi un id
# nunca se reutiliza aunque algo haya quedado guardando una referencia vieja.
static func clear_custom_blocks() -> void:
	var removed := 0
	for block_id in block_definitions.keys():
		if is_deletable_block(block_id):
			block_definitions.erase(block_id)
			removed += 1
	if removed > 0:
		print("BlockSystem: ", removed, " bloques personalizados eliminados.")

# Reemplaza los bloques personalizados actuales por los guardados
static func import_custom_blocks(data: Dictionary) -> void:
	clear_custom_blocks()

	var counters: Dictionary = data.get("counters", {})
	# Los contadores solo avanzan: se queda el mayor entre la sesion y el archivo
	white_loop_counter = max(white_loop_counter, int(counters.get("white_loop", 0)))
	black_loop_counter = max(black_loop_counter, int(counters.get("black_loop", 0)))
	white_escape_counter = max(white_escape_counter, int(counters.get("white_escape", 0)))
	black_escape_counter = max(black_escape_counter, int(counters.get("black_escape", 0)))

	var blocks: Dictionary = data.get("blocks", {})
	for block_id in blocks:
		var prefix := _custom_prefix_of(block_id)
		if prefix == "":
			push_warning("BlockSystem: bloque guardado con id invalido, se omite: " + str(block_id))
			continue
		var saved: Dictionary = blocks[block_id]
		var contained := []
		for sub in saved.get("contained_blocks", []):
			if sub is Dictionary and sub.get("type", "") != "":
				contained.append({"type": str(sub["type"])})

		var is_loop := prefix.ends_with("_loop_")
		block_definitions[block_id] = {
			"name": str(saved.get("name", block_id)),
			"type": block_id,
			"category": "logic" if is_loop else "action",
			"ram_cost": int(saved.get("ram_cost", 0)),
			"color": Color.MEDIUM_PURPLE if is_loop else Color.ORANGE,
			"contained_blocks": contained,
			"execute": execute_loop_block if is_loop else execute_escape_protocol,
		}
		_sync_counter(block_id, prefix)

	print("BlockSystem: ", blocks.size(), " bloques personalizados restaurados.")

static func _custom_prefix_of(block_id: String) -> String:
	for prefix in CUSTOM_BLOCK_PREFIXES:
		if block_id.begins_with(prefix) and block_id.trim_prefix(prefix).is_valid_int():
			return prefix
	return ""

# Evita que un bloque nuevo reutilice el id de uno restaurado aunque el
# archivo traiga contadores desactualizados
static func _sync_counter(block_id: String, prefix: String) -> void:
	var n := int(block_id.trim_prefix(prefix))
	match prefix:
		"white_loop_":
			white_loop_counter = max(white_loop_counter, n)
		"black_loop_":
			black_loop_counter = max(black_loop_counter, n)
		"white_escape_":
			white_escape_counter = max(white_escape_counter, n)
		"black_escape_":
			black_escape_counter = max(black_escape_counter, n)
