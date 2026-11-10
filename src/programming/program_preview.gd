extends RefCounted
class_name ProgramPreview

# Simula un programa sin mover ninguna pieza, con las mismas reglas que
# GameManager.execute_piece_program y BlockSystem.move_generic:
# - Los escapes (categoria "action") no se ejecutan en el turno.
# - Un loop recorre su contenido; los loops anidados se expanden igual.
# - Salir del tablero o chocar con un aliado corta el programa.
# - Una captura entra en la casilla y termina el programa.
# - El caballo atraviesa un aliado si todavia le quedan pasos; si el programa
#   termina con el caballo sobre un aliado, vuelve a su ultima casilla libre.
#
# No se revela si la victima tiene un escape: eso no lo sabe el jugador.

# Tipos de paso
const MOVE := "move"          # entra en una casilla libre
const PASS := "pass"          # el caballo atraviesa a un aliado
const CAPTURE := "capture"    # entra capturando; termina el programa
const BLOCKED := "blocked"    # aliado en el camino; no entra
const OUT := "out"            # fuera del tablero; no entra

# Resultado:
# {
#   "start": Vector2i,
#   "steps": [{"cell": Vector2i, "kind": String}],  en orden
#   "final": Vector2i,          casilla donde termina la pieza
#   "capture": Vector2i o null, casilla capturada
#   "stop": String,             "", BLOCKED, OUT, CAPTURE o "unknown"
#   "returned": bool,           el caballo volvio a su ultima casilla libre
# }
static func simulate(piece: Node, program: Array, game_manager: Node) -> Dictionary:
	var start := Vector2i(piece.board_position)
	var state := {
		"pos": start,
		"return_cell": null,
		"steps": [],
		"capture": null,
		"stop": "",
		"grid": BotSystem._grilla(game_manager),
		"piece": piece,
		"side": -1 if piece.piece_color == "white" else 1,
	}
	# Igual que save_piece_program: el escape se separa del programa
	var moves: Array = []
	for block in program:
		var t: String = block.get("type", "") if block is Dictionary else ""
		if t != "" and BlockSystem.get_block_info(t).get("category", "") != "action":
			moves.append(t)

	for i in range(moves.size()):
		# has_more_commands() de la pieza: quedan bloques despues de este
		var top_has_more := i < moves.size() - 1
		if not _run(moves[i], false, top_has_more, state):
			break

	var final_cell: Vector2i = state["pos"]
	var returned := false
	# resolve_phase_end: el caballo no puede terminar sobre un aliado
	if state["return_cell"] != null:
		var other = state["grid"].get(final_cell)
		if other != null and other != piece and other.piece_color == piece.piece_color:
			final_cell = state["return_cell"]
			returned = true

	return {
		"start": start,
		"steps": state["steps"],
		"final": final_cell,
		"capture": state["capture"],
		"stop": state["stop"],
		"returned": returned,
	}

# Ejecuta un bloque. Devuelve false si el programa se corta.
static func _run(block_type: String, has_more_in_container: bool, top_has_more: bool, state: Dictionary) -> bool:
	var info := BlockSystem.get_block_info(block_type)
	if info.is_empty():
		state["stop"] = "unknown"
		return false
	if info.get("category", "") == "action":
		return true
	if info.has("contained_blocks") and not info.has("vector"):
		var contents: Array = info.get("contained_blocks", [])
		for i in range(contents.size()):
			var sub: String = contents[i].get("type", "")
			if sub == "":
				continue
			var more_after: bool = i < contents.size() - 1 or has_more_in_container
			if not _run(sub, more_after, top_has_more, state):
				return false
		return true
	if info.has("vector"):
		return _step(info["vector"], has_more_in_container or top_has_more, state)
	state["stop"] = "unknown"
	return false

static func _step(vec: Vector2i, has_more: bool, state: Dictionary) -> bool:
	var piece: Node = state["piece"]
	var pos: Vector2i = state["pos"]
	var target := Vector2i(pos.x + vec.x, pos.y + vec.y * state["side"])

	if target.x < 0 or target.x > 7 or target.y < 0 or target.y > 7:
		state["steps"].append({"cell": target, "kind": OUT})
		state["stop"] = OUT
		return false

	var occupant = state["grid"].get(target)
	if occupant == piece:
		occupant = null
	if occupant != null:
		if occupant.piece_color != piece.piece_color:
			state["steps"].append({"cell": target, "kind": CAPTURE})
			state["pos"] = target
			state["return_cell"] = null
			state["capture"] = target
			state["stop"] = CAPTURE
			return false
		if piece.piece_type == "horse" and has_more:
			if state["return_cell"] == null:
				state["return_cell"] = pos
			state["steps"].append({"cell": target, "kind": PASS})
			state["pos"] = target
			return true
		state["steps"].append({"cell": target, "kind": BLOCKED})
		state["stop"] = BLOCKED
		return false

	state["steps"].append({"cell": target, "kind": MOVE})
	state["pos"] = target
	state["return_cell"] = null
	return true
