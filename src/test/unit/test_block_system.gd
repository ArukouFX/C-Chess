extends GutTest

func test_ram_usage_incremental_penalty():
	var script = [{"type": "move_f"}, {"type": "move_b"}]
	var total = BlockSystem.calculate_ram_usage(script)
	assert_eq(total, 5, "El segundo bloque debe sumar +1 de penalización incremental")

func test_ram_usage_tres_bloques_diagonales():
	var script = [{"type": "move_fl"}, {"type": "move_fl"}, {"type": "move_fl"}]
	var total = BlockSystem.calculate_ram_usage(script)
	assert_eq(total, 12)

func test_script_invalido_excede_ram():
	var script = [{"type": "move_fl"}, {"type": "move_fl"}, {"type": "move_fl"}]
	assert_false(BlockSystem.is_script_valid(script, 5))

func test_capacidad_ram_por_pieza():
	assert_eq(BlockSystem.get_piece_ram_capacity("pawn"), 8)
	assert_eq(BlockSystem.get_piece_ram_capacity("queen"), 32)
	assert_eq(BlockSystem.get_piece_ram_capacity("king"), 12)

func test_get_block_info_bloque_inexistente():
	var info = BlockSystem.get_block_info("bloque_falso")
	assert_true(info.is_empty(), "Un bloque no registrado debe devolver diccionario vacío")

func test_create_escape_protocol_aislado_por_bando():
	var id_blanco = BlockSystem.create_escape_protocol([{"type": "move_f"}], 2, "Escape test", "white")
	var id_negro = BlockSystem.create_escape_protocol([{"type": "move_f"}], 2, "Escape test", "black")
	assert_string_starts_with(id_blanco, "white_escape_")
	assert_string_starts_with(id_negro, "black_escape_")

func test_clear_custom_blocks_borra_loops_y_escapes_pero_no_los_movimientos():
	var loop_id = BlockSystem.create_loop_block([{"type": "move_f"}], 2, "L", "white")
	var escape_id = BlockSystem.create_escape_protocol([{"type": "move_b"}], 2, "E", "black")
	BlockSystem.clear_custom_blocks()
	assert_true(BlockSystem.get_block_info(loop_id).is_empty())
	assert_true(BlockSystem.get_block_info(escape_id).is_empty())
	for base in ["move_f", "move_b", "move_l", "move_r", "move_fl", "move_fr", "move_bl", "move_br"]:
		assert_false(BlockSystem.get_block_info(base).is_empty(), "Movimiento base borrado: " + base)

func test_clear_no_reutiliza_ids():
	var antes = BlockSystem.create_loop_block([{"type": "move_f"}], 2, "L", "white")
	BlockSystem.clear_custom_blocks()
	var despues = BlockSystem.create_loop_block([{"type": "move_f"}], 2, "L", "white")
	assert_ne(antes, despues, "Un id borrado no se vuelve a asignar")
	BlockSystem.clear_custom_blocks()

func test_las_funciones_viejas_ya_no_existen():
	# Control: has_method si ve funciones estaticas del autoload
	assert_true(BlockSystem.has_method("get_block_info"))
	for viejo in ["execute_movement", "execute_loop", "move_forward", "move_diagonal", "capture_piece", "check_enemy_front", "get_blocks_by_category"]:
		assert_false(BlockSystem.has_method(viejo), "Sigue existiendo: " + viejo)

# --- Con escena de juego ---

var TestMainScene = preload("res://src/test/fixture/test_main.tscn")

func _crear_partida() -> Node:
	SaveManager.SAVE_PATH = "user://test_savegame.json"
	GlobalConfig.bot_disabled = true
	GlobalConfig.load_save = false
	var test_main = TestMainScene.instantiate()
	autofree(test_main)
	get_tree().root.add_child(test_main)
	for i in range(5):
		await get_tree().process_frame
	return test_main.get_node("GameManager")

func test_partida_nueva_no_hereda_bloques_de_otro_modo():
	var loop_previo = BlockSystem.create_loop_block([{"type": "move_f"}], 2, "De otro modo", "white")
	await _crear_partida()
	assert_true(BlockSystem.get_block_info(loop_previo).is_empty())

# La victima no puede escapar hacia la casilla de la que viene el atacante:
# durante la captura, el atacante todavia la ocupa
func test_victima_no_escapa_hacia_el_origen_del_atacante():
	var gm = await _crear_partida()
	var atacante = gm.get_piece_at(Vector2i(0, 6))  # peon blanco
	atacante.board_position = Vector2(0, 2)
	atacante.virtual_board_position = Vector2(0, 2)
	atacante.position = gm._board_to_world_position(Vector2(0, 2))

	var victima = gm.get_piece_at(Vector2i(0, 1))   # peon negro
	var escape_id = BlockSystem.create_escape_protocol([{"type": "move_f"}], 2, "Hacia el atacante", "black")
	victima.defense_protocol = {"type": escape_id}
	victima.defense_protocol_active = true

	atacante.behavior_script = [{"type": "move_f"}]  # blanco: (0,2) -> (0,1)
	await gm.execute_piece_program(atacante)

	assert_true(victima.get_meta("is_dead", false), "(0,2) sigue ocupada por el atacante: el escape falla")
	assert_eq(Vector2i(atacante.board_position), Vector2i(0, 1))

func test_las_escenas_de_juego_no_cargan_test_blocks():
	for ruta in ["res://src/scenes/game_board.tscn", "res://main.tscn", "res://src/tutorial/tutorial_scene.tscn",
			"res://src/challenge/challenge_scene.tscn", "res://src/test/fixture/test_main.tscn"]:
		var estado: SceneState = load(ruta).get_state()
		for i in range(estado.get_node_count()):
			assert_ne(str(estado.get_node_name(i)), "Debug", "Sigue el nodo Debug en " + ruta)

# --- Flechas segun el bando ---

func test_flechas_de_las_blancas_sin_cambios():
	assert_eq(BlockSystem.get_display_name("move_f", "white"), "Adelante ↑")
	assert_eq(BlockSystem.get_display_name("move_bl", "white"), "Diag. Atrás Izq. ↙")

func test_flechas_de_las_negras_invierten_lo_vertical():
	assert_eq(BlockSystem.get_display_name("move_f", "black"), "Adelante ↓")
	assert_eq(BlockSystem.get_display_name("move_b", "black"), "Atrás ↑")
	assert_eq(BlockSystem.get_display_name("move_fl", "black"), "Diag. Adel. Izq. ↙")
	assert_eq(BlockSystem.get_display_name("move_br", "black"), "Diag. Atrás Der. ↗")
	# Izquierda y derecha coinciden en pantalla para ambos bandos
	assert_eq(BlockSystem.get_display_name("move_l", "black"), "Izquierda ←")
	assert_eq(BlockSystem.get_display_name("move_r", "black"), "Derecha →")

func test_paleta_negra_muestra_flechas_invertidas():
	var nombres := {}
	for b in BlockSystem.get_blocks_for_palette("movement", "black"):
		nombres[b["type"]] = b["name"]
	assert_eq(nombres["move_f"], "Adelante ↓")
	# El nombre original no se modifica
	assert_eq(BlockSystem.get_block_info("move_f")["name"], "Adelante ↑")

# La flecha debe coincidir con el desplazamiento real en pantalla
# (y crece hacia abajo en el tablero)
func test_flecha_coincide_con_el_movimiento_real():
	var esperadas := {
		Vector2i(0, -1): "↑", Vector2i(0, 1): "↓", Vector2i(-1, 0): "←", Vector2i(1, 0): "→",
		Vector2i(-1, -1): "↖", Vector2i(1, -1): "↗", Vector2i(-1, 1): "↙", Vector2i(1, 1): "↘",
	}
	for color in ["white", "black"]:
		var side = -1 if color == "white" else 1
		for t in ["move_f", "move_b", "move_l", "move_r", "move_fl", "move_fr", "move_bl", "move_br"]:
			var v: Vector2i = BlockSystem.get_block_info(t)["vector"]
			var en_pantalla = Vector2i(v.x, v.y * side)
			assert_true(BlockSystem.get_display_name(t, color).ends_with(esperadas[en_pantalla]), "%s %s" % [color, t])
