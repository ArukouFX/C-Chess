extends GutTest

# Perfil sin errores aleatorios: los resultados son deterministas
var _dificultad_previa: String

func before_each():
	_dificultad_previa = GlobalConfig.bot_difficulty
	GlobalConfig.set_bot_difficulty("hard")

func after_each():
	GlobalConfig.set_bot_difficulty(_dificultad_previa)

# El bot preve los loops del jugador y los usa en sus jugadas

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

func _ubicar(pieza, celda: Vector2i) -> void:
	pieza.board_position = Vector2(celda)
	pieza.virtual_board_position = Vector2(celda)

func _vaciar(gm, conservar: Array) -> void:
	for p in gm.pieces_container.get_children():
		if p not in conservar:
			p.set_meta("is_dead", true)

func test_costos_de_los_rayos():
	# Bloque ortogonal (2): 2 casillas = 2+3; 4 casillas = loop(2)+loop(2) = 5+6
	assert_eq(BotSystem._costo_rayo(2, 1), 2)
	assert_eq(BotSystem._costo_rayo(2, 2), 5)
	assert_eq(BotSystem._costo_rayo(2, 4), 11)
	# Diagonal (3)
	assert_eq(BotSystem._costo_rayo(3, 2), 7)
	# Nunca mas caro que la secuencia sin loops
	for m in range(1, 8):
		var plano := 0
		for i in range(m):
			plano += 2 + i
		assert_lte(BotSystem._costo_rayo(2, m), plano)

func test_el_loop_materializado_cuesta_lo_previsto():
	for bloque in ["move_f", "move_fr"]:
		for m in range(2, 8):
			var loop_id = BotSystem._obtener_loop(bloque, m, "black")
			var info = BlockSystem.get_block_info(loop_id)
			assert_eq(info["ram_cost"], BotSystem._costo_tramo("%s*%d" % [bloque, m]), "%s x%d" % [bloque, m])
			assert_true(info.get("bot_only", false))

func test_mapa_de_amenazas_ve_el_ataque_con_loops():
	# La jugada de la partida: reina en (3,7) con [Diag, loop, loop] hasta el rey
	var gm = await _crear_partida()
	var rey = gm.get_piece_at(Vector2i(4, 0))
	var reina = gm.get_piece_at(Vector2i(3, 7))
	_vaciar(gm, [rey, reina])
	var mapa = BotSystem._construir_mapa_control(gm)
	assert_true(BotSystem._bajo_ataque(Vector2i(4, 0), mapa), "Sin loops la reina solo llegaba a 6 casillas")
	assert_lte(mapa[Vector2i(4, 0)]["costo_min"], reina.available_ram)

func test_el_bot_ejecuta_una_jugada_larga_con_loops():
	var gm = await _crear_partida()
	var torre = gm.get_piece_at(Vector2i(0, 0))
	var rey = gm.get_piece_at(Vector2i(4, 0))
	var rey_blanco = gm.get_piece_at(Vector2i(4, 7))
	var peon_blanco = gm.get_piece_at(Vector2i(0, 6))
	_vaciar(gm, [torre, rey, rey_blanco, peon_blanco])
	# Columna libre: el peon esta a 6 casillas, fuera del alcance sin loops (5)
	var jugadas = BotSystem._jugadas_legales(torre, Vector2i(0, 0), gm)
	var captura = null
	for j in jugadas:
		if j["destino"] == Vector2i(0, 6):
			captura = j
	assert_not_null(captura, "La torre debe alcanzar (0,6) usando loops")
	var script = BotSystem._materializar(captura["bloques"], "black")
	assert_eq(BlockSystem.calculate_ram_usage(script), captura["ram"])
	assert_lte(captura["ram"], torre.available_ram)

	# Ejecucion real del programa
	gm.saved_programs[torre.piece_id] = script
	torre.behavior_script = script.duplicate(true)
	torre.is_programmed = true
	await gm.execute_piece_program(torre)
	assert_eq(Vector2i(torre.board_position), Vector2i(0, 6))
	assert_true(peon_blanco.get_meta("is_dead", false), "El peon debe quedar capturado")

func test_loops_del_bot_no_aparecen_en_la_paleta():
	var loop_id = BotSystem._obtener_loop("move_b", 3, "black")
	var tipos := []
	for b in BlockSystem.get_blocks_for_palette("logic", "black"):
		tipos.append(b["type"])
	assert_does_not_have(tipos, loop_id)

# --- Perfiles de dificultad ---

func _max_tramo(jugadas: Array) -> int:
	var maximo := 1
	for j in jugadas:
		for tramo in j["bloques"]:
			maximo = max(maximo, BotSystem._largo_de(tramo))
	return maximo

func test_facil_y_normal_no_usan_loops_propios():
	var gm = await _crear_partida()
	var torre = gm.get_piece_at(Vector2i(0, 0))
	_vaciar(gm, [torre, gm.get_piece_at(Vector2i(4, 0)), gm.get_piece_at(Vector2i(4, 7))])
	for nivel in ["easy", "normal"]:
		GlobalConfig.set_bot_difficulty(nivel)
		assert_eq(_max_tramo(BotSystem._jugadas_legales(torre, Vector2i(0, 0), gm)), 1, nivel)
	GlobalConfig.set_bot_difficulty("hard")
	assert_gt(_max_tramo(BotSystem._jugadas_legales(torre, Vector2i(0, 0), gm)), 1)

func test_solo_facil_ignora_los_loops_del_jugador():
	var gm = await _crear_partida()
	var rey = gm.get_piece_at(Vector2i(4, 0))
	var reina = gm.get_piece_at(Vector2i(3, 7))
	_vaciar(gm, [rey, reina])
	GlobalConfig.set_bot_difficulty("easy")
	assert_false(BotSystem._bajo_ataque(Vector2i(4, 0), BotSystem._construir_mapa_control(gm)))
	GlobalConfig.set_bot_difficulty("normal")
	assert_true(BotSystem._bajo_ataque(Vector2i(4, 0), BotSystem._construir_mapa_control(gm)))

func test_facil_no_se_instala_escapes():
	var gm = await _crear_partida()
	var peon = gm.get_piece_at(Vector2i(3, 1))
	var reina = gm.get_piece_at(Vector2i(3, 7))
	_ubicar(reina, Vector2i(3, 4))  # amenaza la casilla de llegada
	var mapa = BotSystem._construir_mapa_control(gm)
	GlobalConfig.set_bot_difficulty("easy")
	BotSystem._decidir_defensa(peon, Vector2i(3, 2), 6, gm, mapa)
	assert_false(peon.defense_protocol_active)

func test_cada_nivel_elige_una_jugada_valida():
	var gm = await _crear_partida()
	for nivel in GlobalConfig.DIFFICULTIES:
		GlobalConfig.set_bot_difficulty(nivel)
		var plan = await BotSystem._elegir_jugada(gm, BotSystem._construir_mapa_control(gm))
		assert_false(plan.is_empty(), nivel)
		assert_eq(plan["pieza"].piece_color, "black")
		assert_lte(BotSystem._costo_incremental(plan["jugada"]["bloques"]), plan["pieza"].available_ram)
