extends Node
class_name TutorialManager

signal objective_completed(level_index: int)
signal tutorial_finished

var current_level: int = 0
var levels: Array = []
var game_manager: Node = null
var tutorial_ui: Node = null
var _level5_attack_pending: bool = false
# Piezas objetivo del nivel cargado (no se escribe en el diccionario del nivel)
var _target_piece_ids: Array = []
var _loading: bool = false
var _previous_bot_disabled: bool = false

func _ready():
	game_manager = get_node("../GameManager")
	tutorial_ui = get_node("../TutorialUI/InstructionPanel")

	if GlobalConfig:
		_previous_bot_disabled = GlobalConfig.bot_disabled
		GlobalConfig.bot_disabled = true
		# La escena activa su propio modo, igual que ChallengeManager, para
		# no depender de que el menu lo haya hecho antes
		GlobalConfig.tutorial_mode = true

	# El modo empieza sin bloques creados en otra partida o modo
	BlockSystem.clear_custom_blocks()
	_define_levels()
	_connect_signals()

	await get_tree().process_frame
	await get_tree().process_frame
	_setup_tutorial_board()
	_load_level(0)

func _define_levels():
	levels = [
		{
			"title": "Movimiento básico",
			"instruction": "Programá el peón resaltado con el bloque 'Adelante' \ny ejecutá el turno para moverlo.",
			"pieces": [
				{"type": "white_pawn", "coord": Vector2(0, 6), "role": "target"}
			],
			"objective": "execute_specific_block",
			"params": {"block_type": "move_f"}
		},
		{
			"title": "Gestión de RAM",
			"instruction": "El alfil resaltado tiene 20 de RAM. \nCada bloque diagonal cuesta más que el anterior. \nArmá un camino de 4 bloques sin fundir su memoria.",
			"pieces": [
				{"type": "white_bishop", "coord": Vector2(2, 7), "role": "target"}
			],
			"objective": "script_within_ram",
			"params": {"min_blocks": 4, "max_ram": 20}
		},
		{
			"title": "Captura diagonal",
			"instruction": "Mové el alfil en diagonal ('Diag. Adel. Der.') \npara capturar al peón enemigo.",
			"pieces": [
				{"type": "white_bishop", "coord": Vector2(3, 4), "role": "target"},
				{"type": "black_pawn",   "coord": Vector2(4, 3), "role": "victim"}
			],
			"objective": "capture_enemy",
			"params": {}
		},
		{
			"title": "Crear un Loop",
			"instruction": "Poné 2 bloques 'Adelante' en el área de trabajo, \npresioná 'Loop' y nombralo. \nLuego arrastrá el bloque de loop resultante \nal área de trabajo y presioná 'Ejecutar'.",
			"pieces": [
				{"type": "white_tower", "coord": Vector2(4, 7), "role": "target"}
			],
			"objective": "create_loop",
			"params": {"min_contained_blocks": 2}
		},
		{
			"title": "Protocolo de escape",
			"instruction": "Arrastrá un bloque de movimiento al área de trabajo, \npresioná 'Escape' y nombralo. \nSacá el bloque de movimiento del área de trabajo \ny arrastrá el nuevo bloque de escape (categoría Acciones). \nPresioná 'Ejecutar' para probar si sobrevivís a una captura.",
			"pieces": [
				{"type": "white_pawn", "coord": Vector2(4, 4), "role": "target"}
			],
			"objective": "assign_escape_and_survive",
			"params": {}
		},
		{
			"title": "Salto del Caballo",
			"instruction": "El caballo puede saltar sobre piezas propias. \nProgramá 2 bloques 'Adelante' para atravesar \nal peón aliado y aterrizar en la casilla libre detrás.",
			"pieces": [
				{"type": "white_horse", "coord": Vector2(4, 7), "role": "target"},
				{"type": "white_pawn",  "coord": Vector2(4, 6), "role": "ally_blocker"}
			],
			"objective": "horse_phase_pass",
			"params": {"expected_landing": Vector2(4, 5)}
		},
		{
			"title": "Bloqueo por aliado",
			"instruction": "Si programás 'Adelante' vas a chocar con tu propio peón: \nla ejecución se detiene ahí. Rodealo: probá \n'Izquierda', 'Adelante' dos veces, 'Derecha' para esquivarlo.",
			"pieces": [
				{"type": "white_tower", "coord": Vector2(4, 7), "role": "target"},
				{"type": "white_pawn",  "coord": Vector2(4, 6), "role": "ally_blocker"}
			],
			"objective": "avoid_ally_blocked",
			"params": {"expected_landing": Vector2(4, 5)}
		},
		{
			"title": "Límites del tablero",
			"instruction": "El tablero tiene bordes. \nProgramá 'Izquierda' dos veces y ejecutá: \nvas a ver que el segundo paso no te saca del tablero, \nsimplemente no se ejecuta y el programa se detiene.",
			"pieces": [
				{"type": "white_pawn", "coord": Vector2(1, 6), "role": "target"}
			],
			"objective": "respect_board_limits",
			# Se aprueba solo si el programa intenta salir del tablero (al menos
			# dos 'Izquierda') y la pieza queda frenada en el borde
			"params": {"block_type": "move_l", "min_count": 2, "expected_landing": Vector2(0, 6)}
		},
		{
			"title": "Capacidad de RAM por pieza",
			"instruction": "Cada tipo de pieza tiene distinta memoria. \nAl peón (8 RAM) programale 2 bloques 'Adelante' y ejecutá. \nDespués abrí la reina (32 RAM), programale 6 bloques \n(podés repetir direcciones) y ejecutá. \nFijate cuánta memoria le queda de sobra a cada una.",
			"pieces": [
				{"type": "white_pawn",  "coord": Vector2(1, 5), "role": "target", "min_blocks": 2},
				{"type": "white_queen", "coord": Vector2(3, 7), "role": "target", "min_blocks": 6}
			],
			"objective": "compare_ram_capacities",
			"params": {}
		}
	]

func _connect_signals():
	if game_manager.has_signal("piece_programmed"):
		game_manager.piece_programmed.connect(_on_piece_programmed)
	if game_manager.has_signal("piece_captured"):
		game_manager.piece_captured.connect(_on_piece_captured)
	if game_manager.has_signal("piece_execution_finished"):
		game_manager.piece_execution_finished.connect(_on_piece_execution_finished)
	tutorial_ui.get_node("VBox/ButtonsRow/NextButton").pressed.connect(_on_next_pressed)
	tutorial_ui.get_node("VBox/ButtonsRow/RetryButton").pressed.connect(_on_retry_pressed)
	tutorial_ui.get_node("VBox/ButtonsRow/SkipButton").pressed.connect(_on_skip_pressed)

func _setup_tutorial_board():
	for piece in game_manager.pieces_container.get_children():
		piece.queue_free()

func _load_level(index: int):
	if index >= levels.size():
		emit_signal("tutorial_finished")
		_show_completion_screen()
		return
	if _loading:
		return
	_loading = true

	var level = levels[index]
	current_level = index
	_level5_attack_pending = false
	# Cada nivel (y cada reintento) empieza sin loops ni escapes de antes
	BlockSystem.clear_custom_blocks()

	tutorial_ui.get_node("VBox/TitleLabel").text = level["title"]
	tutorial_ui.get_node("VBox/InstructionLabel").text = level["instruction"]
	tutorial_ui.get_node("VBox/ButtonsRow/NextButton").visible = false

	for piece in game_manager.pieces_container.get_children():
		piece.queue_free()
	await get_tree().process_frame

	_target_piece_ids.clear()
	for piece_data in level["pieces"]:
		var t = piece_data["type"]
		var c = piece_data["coord"]
		var pid = "%s_%d_%d" % [t, int(c.x), int(c.y)]

		# FIX: borrar cualquier programa viejo (de un nivel anterior con el
		# mismo piece_id, o de un intento previo de este mismo nivel) para
		# que la pieza siempre nazca "en blanco".
		if game_manager.saved_programs.has(pid):
			game_manager.saved_programs.erase(pid)

		var spawned = game_manager.spawn_piece(t, c)
		# Doble seguro: aunque spawn_piece reinyecte algo por una carrera
		# de timing, lo limpiamos a mano en la instancia recién creada.
		spawned.behavior_script = []
		spawned.is_programmed = false
		spawned.clear_defense_protocol()

		if piece_data.get("role", "") == "target":
			_target_piece_ids.append(pid)

	_loading = false

func _find_piece_by_id(pid: String) -> Node:
	for piece in game_manager.pieces_container.get_children():
		if piece.piece_id == pid:
			return piece
	return null

func _check_compare_ram(level: Dictionary) -> bool:
	for piece_data in level["pieces"]:
		if piece_data.get("role", "") != "target":
			continue
		var pid = "%s_%d_%d" % [piece_data["type"], int(piece_data["coord"].x), int(piece_data["coord"].y)]
		var min_blocks = piece_data.get("min_blocks", 1)
		var script = game_manager.saved_programs.get(pid, [])
		if script.size() < min_blocks:
			return false
		var piece_node = _find_piece_by_id(pid)
		if piece_node == null:
			return false
		var ram_used = BlockSystem.calculate_ram_usage(script)
		if ram_used > piece_node.available_ram:
			return false
	return true

func _on_piece_programmed(piece: Node, script_final: Array):
	if current_level >= levels.size():
		return
	var level = levels[current_level]
	if not _target_piece_ids.has(piece.piece_id):
		return

	match level["objective"]:
		"execute_specific_block":
			for block in script_final:
				if block.get("type") == level["params"]["block_type"]:
					_on_objective_completed()
					return

		"script_within_ram":
			var params = level["params"]
			var ram_usado = BlockSystem.calculate_ram_usage(script_final)
			if script_final.size() >= params["min_blocks"] and ram_usado <= params["max_ram"]:
				_on_objective_completed()

		"create_loop":
			var min_blocks = level["params"].get("min_contained_blocks", 2)
			for block in script_final:
				var btype = block.get("type", "")
				if btype.begins_with(piece.piece_color + "_loop_"):
					var info = BlockSystem.get_block_info(btype)
					var contained = info.get("contained_blocks", [])
					if contained.size() >= min_blocks:
						_on_objective_completed()
						return

		"assign_escape_and_survive":
			if not _level5_attack_pending and piece.defense_protocol != null and piece.defense_protocol.get("type", "") != "":
				_level5_attack_pending = true
				_simulate_attack_on(piece)

		"compare_ram_capacities":
			if _check_compare_ram(level):
				_on_objective_completed()
		# "capture_enemy" -> _on_piece_captured
		# horse_phase_pass / avoid_ally_blocked / respect_board_limits -> _on_piece_execution_finished

func _on_piece_captured(attacker: Node, victim: Node):
	if current_level >= levels.size():
		return
	var level = levels[current_level]
	if level["objective"] != "capture_enemy":
		return
	if attacker and is_instance_valid(attacker) and not _target_piece_ids.is_empty() and attacker.piece_id == _target_piece_ids[0]:
		_on_objective_completed()

func _on_piece_execution_finished(piece: Node):
	if current_level >= levels.size():
		return
	var level = levels[current_level]
	if not _target_piece_ids.has(piece.piece_id):
		return

	match level["objective"]:
		"horse_phase_pass":
			var expected = level["params"]["expected_landing"]
			if Vector2i(piece.board_position) == Vector2i(expected):
				_on_objective_completed()
			else:
				tutorial_ui.get_node("VBox/InstructionLabel").text = "No llegaste a la casilla correcta. Presioná 'Reintentar'."

		"avoid_ally_blocked":
			var expected = level["params"]["expected_landing"]
			if Vector2i(piece.board_position) == Vector2i(expected):
				_on_objective_completed()
			else:
				tutorial_ui.get_node("VBox/InstructionLabel").text = "Te bloqueaste contra el aliado. Presioná 'Reintentar'."

		"respect_board_limits":
			var params = level["params"]
			var program: Array = game_manager.get_piece_program(piece.piece_id)
			var count := 0
			for block in program:
				if block.get("type", "") == params["block_type"]:
					count += 1
			if count < params["min_count"]:
				tutorial_ui.get_node("VBox/InstructionLabel").text = "Usá al menos dos bloques 'Izquierda' para intentar salir del tablero. Presioná 'Reintentar'."
			elif Vector2i(piece.board_position) != Vector2i(params["expected_landing"]):
				tutorial_ui.get_node("VBox/InstructionLabel").text = "La pieza no quedó en el borde. Presioná 'Reintentar'."
			else:
				_on_objective_completed()

func _simulate_attack_on(target_piece: Node):
	tutorial_ui.get_node("VBox/InstructionLabel").text = "Simulando un intento de captura..."
	await get_tree().create_timer(0.5).timeout
	await game_manager.capture_piece(target_piece, null)
	# La simulacion termino: se liberan los botones en los dos casos
	_level5_attack_pending = false
	if is_instance_valid(target_piece) and not target_piece.get_meta("is_dead", false):
		_on_objective_completed()
	else:
		tutorial_ui.get_node("VBox/InstructionLabel").text = "El escape falló. Presioná 'Reintentar'."

func _on_objective_completed():
	emit_signal("objective_completed", current_level)
	tutorial_ui.get_node("VBox/InstructionLabel").text = "¡Objetivo cumplido! Presioná 'Siguiente' para continuar."
	tutorial_ui.get_node("VBox/ButtonsRow/NextButton").visible = true

# No se cambia de nivel mientras se ejecuta un programa o la captura
# simulada del nivel de escape: las piezas se liberarian a mitad de la animacion
func _is_busy() -> bool:
	return _loading or _level5_attack_pending or game_manager.execution_phase

func _on_next_pressed():
	if _is_busy():
		return
	_load_level(current_level + 1)

func _on_retry_pressed():
	if _is_busy():
		return
	_load_level(current_level)

func _restore_bot_config():
	if GlobalConfig:
		GlobalConfig.bot_disabled = _previous_bot_disabled

func _on_skip_pressed():
	GlobalConfig.tutorial_mode = false
	_restore_bot_config()
	get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")

func _show_completion_screen():
	GlobalConfig.tutorial_mode = false
	_restore_bot_config()
	tutorial_ui.get_node("VBox/TitleLabel").text = "¡Tutorial completado!"
	tutorial_ui.get_node("VBox/InstructionLabel").text = "Ya conocés lo básico de C-Chess. ¡A jugar!"
	tutorial_ui.get_node("VBox/ButtonsRow/NextButton").text = "Ir al menú"
	tutorial_ui.get_node("VBox/ButtonsRow/NextButton").visible = true
	tutorial_ui.get_node("VBox/ButtonsRow/NextButton").pressed.disconnect(_on_next_pressed)
	tutorial_ui.get_node("VBox/ButtonsRow/NextButton").pressed.connect(_on_skip_pressed)

func _exit_tree():
	GlobalConfig.tutorial_mode = false
	_restore_bot_config()
