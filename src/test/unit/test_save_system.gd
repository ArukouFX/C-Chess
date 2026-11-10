extends GutTest

# Estos tests no escriben user://savegame.json para no pisar la partida real.
# El guardado se simula pasando los datos por JSON en memoria.

var TestMainScene = preload("res://src/test/fixture/test_main.tscn")

func _json_roundtrip(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))

# --- Bloques personalizados ---

func test_bloques_personalizados_sobreviven_al_guardado():
	var loop_id = BlockSystem.create_loop_block(
		[{"type": "move_f"}, {"type": "move_r"}], 5, "Mi loop", "white"
	)
	var escape_id = BlockSystem.create_escape_protocol(
		[{"type": "move_b"}], 4, "Mi escape", "black"
	)
	var exportado = _json_roundtrip(BlockSystem.export_custom_blocks())

	# Simula una sesion nueva: se borran y se restauran desde el archivo
	BlockSystem.delete_custom_block(loop_id)
	BlockSystem.delete_custom_block(escape_id)
	BlockSystem.import_custom_blocks(exportado)
	BotSystem.reset_escape_cache()

	var loop = BlockSystem.get_block_info(loop_id)
	assert_eq(loop.get("name"), "Mi loop")
	assert_eq(loop.get("category"), "logic")
	assert_eq(loop.get("ram_cost"), 5)
	assert_true(loop.get("execute") is Callable, "La funcion de ejecucion se reconstruye al cargar")
	assert_eq(loop["contained_blocks"].map(func(b): return b["type"]), ["move_f", "move_r"])

	var escape = BlockSystem.get_block_info(escape_id)
	assert_eq(escape.get("category"), "action")
	assert_eq(escape["contained_blocks"][0]["type"], "move_b")

	BlockSystem.delete_custom_block(loop_id)
	BlockSystem.delete_custom_block(escape_id)

func test_ids_nuevos_no_reutilizan_ids_restaurados():
	var loop_id = BlockSystem.create_loop_block([{"type": "move_f"}], 2, "L", "black")
	var exportado = _json_roundtrip(BlockSystem.export_custom_blocks())
	# Contadores desactualizados en el archivo
	exportado["counters"]["black_loop"] = 0
	BlockSystem.import_custom_blocks(exportado)

	var nuevo_id = BlockSystem.create_loop_block([{"type": "move_f"}], 2, "L2", "black")
	assert_ne(nuevo_id, loop_id, "Un loop nuevo no debe pisar uno restaurado")
	assert_false(BlockSystem.get_block_info(loop_id).is_empty())

	BlockSystem.delete_custom_block(loop_id)
	BlockSystem.delete_custom_block(nuevo_id)

func test_escapes_del_bot_no_se_guardan():
	BotSystem.reset_escape_cache()
	var bot_id = BotSystem._obtener_escape_para_bloque("move_l", "black")
	var exportado = BlockSystem.export_custom_blocks()
	assert_false(exportado["blocks"].has(bot_id))
	BotSystem.reset_escape_cache()

func test_movimientos_base_no_se_tocan_al_importar():
	BlockSystem.import_custom_blocks({"blocks": {}, "counters": {}})
	assert_false(BlockSystem.get_block_info("move_f").is_empty())
	assert_false(BlockSystem.get_block_info("move_br").is_empty())
	BotSystem.reset_escape_cache()

func test_id_invalido_en_el_archivo_se_ignora():
	BlockSystem.import_custom_blocks({"blocks": {
		"move_f": {"name": "Pisado", "ram_cost": 99, "contained_blocks": []},
		"white_loop_abc": {"name": "Raro", "ram_cost": 1, "contained_blocks": []},
	}, "counters": {}})
	assert_eq(BlockSystem.get_block_info("move_f").get("ram_cost"), 2, "Un movimiento base no se puede sobrescribir")
	assert_true(BlockSystem.get_block_info("white_loop_abc").is_empty())
	BotSystem.reset_escape_cache()

# --- Validacion del archivo ---

func before_each():
	# Nunca tocar la partida guardada real del jugador
	SaveManager.SAVE_PATH = "user://test_savegame.json"

func _con_game_manager() -> Node:
	if GlobalConfig:
		GlobalConfig.bot_disabled = true
		GlobalConfig.load_save = false
	var test_main = TestMainScene.instantiate()
	autofree(test_main)
	get_tree().root.add_child(test_main)
	for i in range(5):
		await get_tree().process_frame
	return test_main.get_node("GameManager")

func _guardado_minimo() -> Dictionary:
	return _json_roundtrip({
		"version": 2,
		"current_turn": "white",
		"pieces": [
			{"piece_id": "white_king_4_7", "piece_type": "king", "piece_color": "white", "board_x": 4, "board_y": 7},
			{"piece_id": "black_king_4_0", "piece_type": "king", "piece_color": "black", "board_x": 4, "board_y": 0},
		],
	})

func test_guardado_valido_se_acepta():
	var gm = await _con_game_manager()
	assert_eq(gm._validate_save(_guardado_minimo()), "")

func test_guardado_con_turno_none_se_rechaza():
	var gm = await _con_game_manager()
	var data = _guardado_minimo()
	data["current_turn"] = "none"
	assert_ne(gm._validate_save(data), "", "Un guardado posterior al game over no se debe cargar")

func test_guardado_de_partida_terminada_se_rechaza():
	var gm = await _con_game_manager()
	var data = _guardado_minimo()
	data["game_over"] = true
	assert_ne(gm._validate_save(data), "")

func test_guardado_sin_rey_se_rechaza():
	var gm = await _con_game_manager()
	var data = _guardado_minimo()
	data["pieces"].remove_at(1)
	assert_ne(gm._validate_save(data), "")

# --- Turno del bot ---

func test_piezas_del_bot_no_son_seleccionables():
	var gm = await _con_game_manager()
	GlobalConfig.bot_disabled = false
	gm.current_turn = "black"
	gm._update_pieces_input_state()
	var peon_negro = gm.get_piece_at(Vector2i(0, 1))
	assert_false(peon_negro.get_node("Area2D").input_pickable)

	# En multijugador las negras si se programan
	GlobalConfig.bot_disabled = true
	gm._update_pieces_input_state()
	assert_true(peon_negro.get_node("Area2D").input_pickable)

# "Reiniciar" en la pantalla de Game Over recarga la escena: no debe quedar
# una partida guardada para retomar, porque end_game ya la borro
func test_terminar_la_partida_borra_el_guardado():
	var gm = await _con_game_manager()
	SaveManager.save_game({"current_turn": "white", "pieces": []})
	assert_true(SaveManager.has_save(), "Precondicion: hay un guardado de prueba")
	gm.end_game("white")
	assert_false(SaveManager.has_save(), "Al terminar la partida se borra el guardado")
