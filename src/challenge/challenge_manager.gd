extends Node
class_name ChallengeManager

signal challenge_resolved(index: int, won: bool)
signal all_challenges_finished

var current_challenge_index: int = -1
var challenges: Array = []

# Estado del desafio cargado (no se escribe en ChallengeDatabase)
var _player_ids: Dictionary = {}   # rol -> piece_id
var _enemy_ids: Dictionary = {}    # rol -> piece_id
# Escapes definidos por la base, reutilizados entre reintentos.
# Clave "id_desafio:rol" -> id del protocolo en BlockSystem.
var _escape_protocol_ids: Dictionary = {}
var game_manager: Node = null
var challenge_ui: Node = null

var turns_used: int = 0
var _resolved: bool = false
var _loading: bool = false
var _previous_bot_disabled: bool = false

# piece_id de la victima -> rol de la pieza que la capturo
var _capture_attackers: Dictionary = {}
var _black_king_captured: bool = false

func _ready():
	game_manager = get_node("../GameManager")
	challenge_ui = get_node("../ChallengeUI/InstructionPanel")

	if GlobalConfig:
		_previous_bot_disabled = GlobalConfig.bot_disabled
		GlobalConfig.bot_disabled = true
		GlobalConfig.challenge_mode = true

	# El modo empieza sin bloques creados en otra partida o modo
	BlockSystem.clear_custom_blocks()
	challenges = ChallengeDatabase.get_all()
	_connect_signals()

	await get_tree().process_frame
	await get_tree().process_frame

	var start_index := 0
	if GlobalConfig and GlobalConfig.get("selected_challenge_id"):
		var idx := ChallengeDatabase.index_of(GlobalConfig.selected_challenge_id)
		if idx >= 0:
			start_index = idx
	_load_challenge(start_index)

func _connect_signals():
	if game_manager.has_signal("piece_captured"):
		game_manager.piece_captured.connect(_on_piece_captured)
	# El GameManager llama a on_turn_end() una vez por turno y espera a que
	# termine (incluido el movimiento enemigo) antes de devolver el control.
	game_manager.turn_end_handler = self
	challenge_ui.get_node("VBox/ButtonsRow/NextButton").pressed.connect(_on_next_pressed)
	challenge_ui.get_node("VBox/ButtonsRow/RetryButton").pressed.connect(_on_retry_pressed)
	challenge_ui.get_node("VBox/ButtonsRow/SkipButton").pressed.connect(_on_menu_pressed)

# ---------------------------------------------------------------------------
# Carga
# ---------------------------------------------------------------------------

func _load_challenge(index: int) -> void:
	if index < 0 or index >= challenges.size() or _loading:
		return
	_loading = true

	current_challenge_index = index
	var ch: Dictionary = challenges[index]
	_resolved = false
	turns_used = 0
	_capture_attackers.clear()
	_black_king_captured = false

	for piece in game_manager.pieces_container.get_children():
		piece.queue_free()
	await get_tree().process_frame

	for pdata in ch["player_pieces"] + ch["enemy_pieces"]:
		game_manager.saved_programs.erase(_piece_id_for(pdata))

	game_manager.game_over = false
	game_manager.winner = ""
	game_manager.current_turn = "white"

	_player_ids.clear()
	for pdata in ch["player_pieces"]:
		_player_ids[pdata["role"]] = _spawn_challenge_piece(ch, pdata)

	_enemy_ids.clear()
	for pdata in ch["enemy_pieces"]:
		_enemy_ids[pdata["role"]] = _spawn_challenge_piece(ch, pdata)

	_validate_enemy_script(ch)

	challenge_ui.get_node("VBox/TitleLabel").text = ch["title"]
	challenge_ui.get_node("VBox/InstructionLabel").text = ch["instruction"]
	challenge_ui.get_node("VBox/ButtonsRow/NextButton").visible = false

	game_manager.update_turn_display()
	game_manager._update_pieces_input_state()
	_loading = false

func _piece_id_for(pdata: Dictionary) -> String:
	return "%s_%d_%d" % [pdata["type"], int(pdata["coord"].x), int(pdata["coord"].y)]

func _spawn_challenge_piece(ch: Dictionary, pdata: Dictionary) -> String:
	var piece = game_manager.spawn_piece(pdata["type"], pdata["coord"])

	# Toda pieza nace sin programa ni defensa, aunque saved_programs tenga
	# algo de un intento anterior.
	piece.behavior_script = []
	piece.is_programmed = false
	piece.clear_defense_protocol()

	piece.set_meta("locked", pdata.get("locked", false))

	if pdata.has("escape"):
		_assign_escape(ch, pdata, piece)

	return piece.piece_id

# Asigna un protocolo de escape definido en la base de datos. El protocolo se
# registra una sola vez por desafio y rol, y se reutiliza en cada reintento.
func _assign_escape(ch: Dictionary, pdata: Dictionary, piece: Node) -> void:
	var role: String = pdata["role"]
	var key: String = ch["id"] + ":" + role
	var protocol_id: String = _escape_protocol_ids.get(key, "")

	if protocol_id == "" or BlockSystem.get_block_info(protocol_id).is_empty():
		# Copia: los datos de la base son de solo lectura
		var blocks: Array = pdata["escape"].duplicate(true)
		var cost: int = BlockSystem.calculate_ram_usage(blocks) * 2
		protocol_id = BlockSystem.create_escape_protocol(
			blocks, cost, "Escape de desafío (%s)" % role, piece.piece_color
		)
		_escape_protocol_ids[key] = protocol_id

	piece.defense_protocol = {"type": protocol_id}
	piece.defense_protocol_id = protocol_id
	piece.defense_protocol_active = true
	# Los escapes del desafio no se consumen: algunos estan pensados para
	# fallar (hay que bloquearlos) y no deben poder agotarse atacando una vez
	piece.defense_protocol_permanent = true

# Avisa si un guion enemigo supera la RAM real de su pieza.
func _validate_enemy_script(ch: Dictionary) -> void:
	var script: Array = ch.get("enemy_script", [])
	for i in range(script.size()):
		var turn_data: Dictionary = script[i]
		var role: String = turn_data.get("piece_role", "")
		var piece = _find_piece_by_id(_enemy_ids.get(role, ""))
		if piece == null:
			push_warning("Desafío %s: el guion del turno %d usa un rol inexistente (%s)." % [ch["id"], i + 1, role])
			continue
		var cost: int = BlockSystem.calculate_ram_usage(turn_data["blocks"])
		if cost > piece.available_ram:
			push_warning("Desafío %s: el guion del turno %d usa %d/%d de RAM." % [ch["id"], i + 1, cost, piece.available_ram])

# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

func _find_piece_by_id(pid: String) -> Node:
	if pid == "":
		return null
	for piece in game_manager.pieces_container.get_children():
		if piece.is_queued_for_deletion():
			continue
		if piece.piece_id == pid:
			return piece
	return null

func _id_for_role(role: String) -> String:
	if _player_ids.has(role):
		return _player_ids[role]
	return _enemy_ids.get(role, "")

func _role_of(piece: Node) -> String:
	if piece == null or not is_instance_valid(piece):
		return ""
	for role in _player_ids:
		if _player_ids[role] == piece.piece_id:
			return role
	for role in _enemy_ids:
		if _enemy_ids[role] == piece.piece_id:
			return role
	return ""

func _on_piece_captured(attacker: Node, victim: Node):
	if current_challenge_index < 0 or current_challenge_index >= challenges.size():
		return
	if victim == null or not is_instance_valid(victim):
		return
	var ch: Dictionary = challenges[current_challenge_index]
	_capture_attackers[victim.piece_id] = _role_of(attacker)
	if victim.piece_type == "king" and victim.piece_color == "black":
		_black_king_captured = true

# ---------------------------------------------------------------------------
# Condiciones
# ---------------------------------------------------------------------------

func _check_condition(ch: Dictionary, cond: Dictionary) -> bool:
	match cond.get("type", ""):
		"piece_at_position":
			var mover = _find_piece_by_id(_id_for_role(cond["role"]))
			if mover == null or mover.get_meta("is_dead", false):
				return false
			return Vector2i(mover.board_position) == Vector2i(cond["coord"])

		"piece_captured":
			var pid := _id_for_role(cond["role"])
			var captured = _find_piece_by_id(pid)
			var is_dead: bool = captured == null or captured.get_meta("is_dead", false)
			if not is_dead:
				return false
			if cond.has("by_role"):
				return _capture_attackers.get(pid, "") == cond["by_role"]
			return true

		"king_captured":
			return _black_king_captured

		"any":
			for sub in cond.get("conditions", []):
				if _check_condition(ch, sub):
					return true
			return false

		"all":
			var subs: Array = cond.get("conditions", [])
			if subs.is_empty():
				return false
			for sub in subs:
				if not _check_condition(ch, sub):
					return false
			return true

		_:
			# "survive_turns" y "turns_exceeded" se resuelven por conteo de turnos
			return false

# Devuelve true si el desafio quedo resuelto.
func _evaluate(ch: Dictionary) -> bool:
	if _check_condition(ch, ch["win_condition"]):
		_resolve(true)
		return true
	if _check_condition(ch, ch["lose_condition"]):
		_resolve(false)
		return true
	return false

# ---------------------------------------------------------------------------
# Turnos
# ---------------------------------------------------------------------------

# Llamado por el GameManager al terminar la ejecucion de un bando.
func on_turn_end(color: String) -> void:
	if _resolved or _loading or color != "white":
		return
	if current_challenge_index < 0 or current_challenge_index >= challenges.size():
		return
	await _on_player_turn_finished(challenges[current_challenge_index])

func _on_player_turn_finished(ch: Dictionary) -> void:
	turns_used += 1

	if _evaluate(ch):
		return

	var enemy_script: Array = ch.get("enemy_script", [])
	var idx := turns_used - 1
	if idx < enemy_script.size():
		await _run_scripted_enemy_move(ch, enemy_script[idx])
		if _resolved or _evaluate(ch):
			return

	if turns_used >= ch["max_turns"]:
		_resolve(ch["win_condition"].get("type", "") == "survive_turns")

func _run_scripted_enemy_move(ch: Dictionary, turn_data: Dictionary) -> void:
	var role: String = turn_data.get("piece_role", "threat")
	var enemy_piece = _find_piece_by_id(_enemy_ids.get(role, ""))
	if enemy_piece == null or enemy_piece.get_meta("is_dead", false):
		return

	# Pausa breve para que el jugador distinga su movimiento del enemigo
	await get_tree().create_timer(0.4).timeout

	# Se asigna el programa directamente: save_piece_program borraria el
	# protocolo de escape de la pieza enemiga.
	enemy_piece.behavior_script = turn_data["blocks"].duplicate(true)
	await game_manager.execute_piece_program(enemy_piece)
	if is_instance_valid(enemy_piece):
		enemy_piece.behavior_script = []

# ---------------------------------------------------------------------------
# Resolucion y UI
# ---------------------------------------------------------------------------

func _resolve(won: bool) -> void:
	if _resolved:
		return
	_resolved = true
	var resolved_index := current_challenge_index

	# game_over corta el avance de turno del GameManager y evita que vuelva
	# a habilitar las piezas.
	game_manager.game_over = true
	_set_board_input(false)
	emit_signal("challenge_resolved", resolved_index, won)

	if won:
		challenge_ui.get_node("VBox/InstructionLabel").text = "¡Desafío superado!"
		challenge_ui.get_node("VBox/ButtonsRow/NextButton").visible = true
	else:
		challenge_ui.get_node("VBox/InstructionLabel").text = "No lo lograste. Reiniciando el desafío..."
		challenge_ui.get_node("VBox/ButtonsRow/NextButton").visible = false
		await get_tree().create_timer(1.5).timeout
		# Si el jugador ya reintento o cambio de desafio, no recargar de nuevo
		if _resolved and current_challenge_index == resolved_index:
			_load_challenge(resolved_index)

func _set_board_input(enabled: bool) -> void:
	for piece in game_manager.pieces_container.get_children():
		if piece.has_node("Area2D"):
			piece.get_node("Area2D").input_pickable = enabled

func _on_next_pressed():
	var next_index := current_challenge_index + 1
	if next_index < challenges.size():
		_load_challenge(next_index)
	else:
		_show_completion_screen()

func _on_retry_pressed():
	# No reiniciar en medio de una ejecucion (propia o enemiga)
	if game_manager.execution_phase:
		return
	_load_challenge(current_challenge_index)

func _restore_config():
	if GlobalConfig:
		GlobalConfig.bot_disabled = _previous_bot_disabled
		GlobalConfig.challenge_mode = false

func _on_menu_pressed():
	_restore_config()
	get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")

func _show_completion_screen():
	_restore_config()
	emit_signal("all_challenges_finished")
	var next_button = challenge_ui.get_node("VBox/ButtonsRow/NextButton")
	challenge_ui.get_node("VBox/TitleLabel").text = "¡Todos los desafíos superados!"
	challenge_ui.get_node("VBox/InstructionLabel").text = "Volvé cuando quieras a probar otra vez."
	next_button.text = "Ir al menú"
	next_button.visible = true
	if next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.disconnect(_on_next_pressed)
	if not next_button.pressed.is_connected(_on_menu_pressed):
		next_button.pressed.connect(_on_menu_pressed)

func _exit_tree():
	if game_manager and is_instance_valid(game_manager) and game_manager.turn_end_handler == self:
		game_manager.turn_end_handler = null
	_restore_config()

# Punto de entrada para una futura pantalla de seleccion
func start_challenge_by_id(id: String):
	var idx := ChallengeDatabase.index_of(id)
	if idx >= 0:
		_load_challenge(idx)
	else:
		push_warning("Challenge id no encontrado: " + id)
