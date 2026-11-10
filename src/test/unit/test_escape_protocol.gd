extends GutTest

var TestMainScene = preload("res://src/test/fixture/test_main.tscn")
var gm

func before_each():
	# Nunca tocar la partida guardada real del jugador
	SaveManager.SAVE_PATH = "user://test_savegame.json"
	if GlobalConfig:
		GlobalConfig.bot_disabled = true
		GlobalConfig.load_save = false

	var test_main = TestMainScene.instantiate()
	autofree(test_main)
	get_tree().root.add_child(test_main)

	for i in range(5):
		await get_tree().process_frame

	gm = test_main.get_node("GameManager")

func test_sin_protocolo_asignado_pieza_muere():
	var pieza = gm.get_piece_at(Vector2i(0, 1)) 
	assert_not_null(pieza)
	pieza.defense_protocol = null

	await gm.execute_defense_protocol(pieza)

	assert_true(pieza.get_meta("is_dead", false))
	assert_eq(Vector2i(pieza.board_position), Vector2i(-999, -999))
	assert_false(pieza.visible)

func test_protocolo_sin_tipo_pieza_muere():
	var pieza = gm.get_piece_at(Vector2i(1, 1))
	assert_not_null(pieza)
	pieza.defense_protocol = {"type": ""}

	await gm.execute_defense_protocol(pieza)

	assert_true(pieza.get_meta("is_dead", false))

func test_protocolo_sin_bloques_contenidos_pieza_muere():
	var pieza = gm.get_piece_at(Vector2i(2, 1))
	assert_not_null(pieza)

	var protocol_id = BlockSystem.create_escape_protocol([], 0, "Escape vacío", "black")
	pieza.defense_protocol = {"type": protocol_id}

	await gm.execute_defense_protocol(pieza)

	assert_true(pieza.get_meta("is_dead", false))

func test_escape_exitoso_pieza_no_muere_y_se_reubica():
	var pieza = gm.get_piece_at(Vector2i(0, 1))  # peón negro
	assert_not_null(pieza)

	var protocol_id = BlockSystem.create_escape_protocol(
		[{"type": "move_f"}], 4, "Escape test libre", "black"
	)
	pieza.defense_protocol = {"type": protocol_id}

	await gm.execute_defense_protocol(pieza)

	assert_false(pieza.get_meta("is_dead", false), "El escape a casilla libre no debe matar a la pieza")
	assert_eq(Vector2i(pieza.virtual_board_position), Vector2i(0, 2))

func test_escape_fuera_de_limites_pieza_muere():
	var pieza = gm.get_piece_at(Vector2i(0, 1))
	assert_not_null(pieza)
	pieza.virtual_board_position = Vector2i(0, 0)

	var protocol_id = BlockSystem.create_escape_protocol(
		[{"type": "move_l"}], 2, "Escape fuera de límites", "black"
	)
	pieza.defense_protocol = {"type": protocol_id}

	await gm.execute_defense_protocol(pieza)

	assert_true(pieza.get_meta("is_dead", false), "Un escape fuera del tablero debe matar a la pieza")

func test_escape_casilla_ocupada_pieza_muere():
	var pieza = gm.get_piece_at(Vector2i(0, 1))
	assert_not_null(pieza)

	var bloqueante = gm.get_piece_at(Vector2i(1, 1))
	assert_not_null(bloqueante)

	var protocol_id = BlockSystem.create_escape_protocol(
		[{"type": "move_r"}], 2, "Escape bloqueado", "black"
	)
	pieza.defense_protocol = {"type": protocol_id}

	await gm.execute_defense_protocol(pieza)

	assert_true(pieza.get_meta("is_dead", false), "Un escape a casilla ocupada debe matar a la pieza que escapa")
	assert_false(bloqueante.get_meta("is_dead", false), "La pieza que bloquea el escape no debe ser capturada")
	assert_eq(Vector2i(bloqueante.virtual_board_position), Vector2i(1, 1), "La pieza bloqueante debe permanecer en su casilla original")

func test_escape_hacia_pieza_enemiga_no_captura():
	var pieza = gm.get_piece_at(Vector2i(0, 6))
	assert_not_null(pieza)
	pieza.virtual_board_position = Vector2i(0, 2)

	var enemigo = gm.get_piece_at(Vector2i(0, 1))
	assert_not_null(enemigo)

	var protocol_id = BlockSystem.create_escape_protocol(
		[{"type": "move_f"}], 2, "Escape hacia enemigo", "white"
	)
	pieza.defense_protocol = {"type": protocol_id}

	await gm.execute_defense_protocol(pieza)

	assert_true(pieza.get_meta("is_dead", false), "La pieza que escapa hacia un enemigo debe morir, no capturarlo")
	assert_false(enemigo.get_meta("is_dead", false), "El escape jamás debe resultar en la captura del enemigo")
	assert_eq(Vector2i(enemigo.virtual_board_position), Vector2i(0, 1), "El enemigo debe permanecer en su casilla original")

func test_protocolos_de_escape_aislados_por_bando():
	var id_blanco = BlockSystem.create_escape_protocol([{"type": "move_f"}], 4, "Escape blanco", "white")
	var id_negro  = BlockSystem.create_escape_protocol([{"type": "move_f"}], 4, "Escape negro", "black")

	assert_string_starts_with(id_blanco, "white_escape_")
	assert_string_starts_with(id_negro, "black_escape_")
	assert_ne(id_blanco, id_negro)

func test_create_escape_protocol_almacena_ram_cost_tal_cual_se_pasa():
	var protocol_id = BlockSystem.create_escape_protocol(
		[{"type": "move_f"}, {"type": "move_f"}], 8, "Escape con costo explícito", "white"
	)
	var info = BlockSystem.get_block_info(protocol_id)
	assert_eq(info.get("ram_cost"), 8, "BlockSystem no duplica el RAM por sí mismo; eso ocurre en la UI")

# Regresion: el chequeo previo comparaba posiciones locales contra
# global_position y detectaba la pieza ubicada 4 columnas a la derecha.
func test_escape_libre_no_falla_por_pieza_cuatro_columnas_a_la_derecha():
	var pieza = gm.get_piece_at(Vector2i(0, 1))  # peon negro
	assert_not_null(pieza)

	# Se ubica otra pieza en (4,2), a 4 columnas de la casilla de escape (0,2)
	var vecina = gm.get_piece_at(Vector2i(4, 1))
	assert_not_null(vecina)
	vecina.board_position = Vector2(4, 2)
	vecina.virtual_board_position = Vector2(4, 2)
	vecina.position = gm._board_to_world_position(Vector2(4, 2))

	var protocol_id = BlockSystem.create_escape_protocol(
		[{"type": "move_f"}], 2, "Escape regresion offset", "black"
	)
	pieza.defense_protocol = {"type": protocol_id}

	await gm.execute_defense_protocol(pieza)

	assert_false(pieza.get_meta("is_dead", false), "La casilla (0,2) esta libre: el escape debe funcionar")
	assert_eq(Vector2i(pieza.board_position), Vector2i(0, 2))
	assert_eq(Vector2i(vecina.board_position), Vector2i(4, 2), "La pieza vecina no debe moverse")

func test_get_piece_at_position_usa_la_casilla_correcta():
	var pos_mundo = gm._board_to_world_position(Vector2(1, 1))
	var encontrada = gm.get_piece_at_position(pos_mundo)
	assert_not_null(encontrada)
	assert_eq(Vector2i(encontrada.board_position), Vector2i(1, 1))
	assert_null(gm.get_piece_at_position(gm._board_to_world_position(Vector2(3, 3))), "(3,3) esta vacia al inicio")

# Si el rey muere por un escape fallido, la partida debe terminar
func test_rey_con_escape_fallido_termina_la_partida():
	GlobalConfig.tutorial_mode = false
	GlobalConfig.challenge_mode = false

	var rey = gm.get_piece_at(Vector2i(4, 7))  # rey blanco
	assert_not_null(rey)
	assert_eq(rey.piece_type, "king")
	var atacante = gm.get_piece_at(Vector2i(4, 1))  # peon negro, solo como atacante

	# Escape hacia adelante: (4,6) esta ocupada por un peon blanco
	var protocol_id = BlockSystem.create_escape_protocol(
		[{"type": "move_f"}], 2, "Escape rey bloqueado", "white"
	)
	rey.defense_protocol = {"type": protocol_id}
	rey.defense_protocol_active = true

	watch_signals(gm)
	await gm.capture_piece(rey, atacante)

	assert_true(rey.get_meta("is_dead", false), "El escape esta bloqueado: el rey debe morir")
	assert_signal_emitted_with_parameters(gm, "piece_captured", [atacante, rey])
	assert_true(gm.game_over, "Sin rey blanco la partida debe terminar")
	assert_eq(gm.winner, "black")

func test_escape_fallido_no_procesa_dos_veces_la_muerte():
	var pieza = gm.get_piece_at(Vector2i(0, 1))
	watch_signals(gm)
	gm._kill_defending_piece(pieza)
	gm._kill_defending_piece(pieza)
	assert_signal_emit_count(gm, "piece_captured", 1)

func _instalar_escape(pieza, bloque: String, permanente := false) -> void:
	var protocol_id = BlockSystem.create_escape_protocol([{"type": bloque}], 2, "Escape test", pieza.piece_color)
	pieza.defense_protocol = {"type": protocol_id}
	pieza.defense_protocol_id = protocol_id
	pieza.defense_protocol_active = true
	pieza.defense_protocol_permanent = permanente

func test_escape_es_de_un_solo_uso():
	var pieza = gm.get_piece_at(Vector2i(0, 1))  # peon negro
	_instalar_escape(pieza, "move_f")

	await gm.capture_piece(pieza)
	assert_false(pieza.get_meta("is_dead", false), "El primer ataque se esquiva")
	assert_eq(Vector2i(pieza.board_position), Vector2i(0, 2))
	assert_false(pieza.defense_protocol_active, "El escape se consume al usarse")

	await gm.capture_piece(pieza)
	assert_true(pieza.get_meta("is_dead", false), "Sin escape, el segundo ataque la captura")

func test_escape_permanente_de_desafio_no_se_consume():
	var pieza = gm.get_piece_at(Vector2i(0, 1))
	_instalar_escape(pieza, "move_f", true)

	await gm.capture_piece(pieza)
	await gm.capture_piece(pieza)
	assert_false(pieza.get_meta("is_dead", false))
	assert_eq(Vector2i(pieza.board_position), Vector2i(0, 3), "Escapa en cada ataque")
	assert_true(pieza.defense_protocol_active)

# Comprueba QUE pieza bloquea, no solo el resultado. Con el error del punto 4
# el chequeo miraba 4 columnas a la derecha: aca esa pieza (5,1) no existe,
# asi que si la pieza muere es porque se detecto la de (1,1).
func test_escape_bloqueado_detecta_la_pieza_de_la_casilla_destino():
	var pieza = gm.get_piece_at(Vector2i(0, 1))
	gm.get_piece_at(Vector2i(5, 1)).set_meta("is_dead", true)
	assert_not_null(gm.get_piece_at(Vector2i(1, 1)), "Precondicion: (1,1) ocupada")
	assert_null(gm.get_piece_at(Vector2i(5, 1)), "Precondicion: (5,1) libre")

	var protocol_id = BlockSystem.create_escape_protocol([{"type": "move_r"}], 2, "Hacia (1,1)", "black")
	pieza.defense_protocol = {"type": protocol_id}
	await gm.execute_defense_protocol(pieza)

	assert_true(pieza.get_meta("is_dead", false), "El obstaculo detectado es la pieza de (1,1)")
