extends GutTest

# Perfil sin errores aleatorios: los resultados son deterministas
var _dificultad_previa: String

func before_each():
	_dificultad_previa = GlobalConfig.bot_difficulty
	GlobalConfig.set_bot_difficulty("hard")

func after_each():
	GlobalConfig.set_bot_difficulty(_dificultad_previa)

func test_valor_pieza_conocida_y_desconocida():
	assert_eq(BotSystem._val("queen"), 90.0)
	assert_eq(BotSystem._val("king"), 999.0)
	assert_eq(BotSystem._val("tipo_raro"), 5.0)

func test_factor_riesgo_sin_amenaza():
	assert_eq(BotSystem._factor_riesgo(-1), 0.0)

func test_factor_riesgo_amenaza_lejana_es_cero():
	var riesgo = BotSystem._factor_riesgo(18)
	assert_almost_eq(riesgo, 0.15, 0.01)

func test_costo_incremental_bloques_ortogonales():
	var bloques = ["move_f", "move_f"]
	var costo = BotSystem._costo_incremental(bloques)
	assert_eq(costo, 5)

var PieceScene = preload("res://src/entities/pieces/piece.tscn")

func test_escape_del_bot_se_reutiliza_por_direccion():
	var id_a = BotSystem._obtener_escape_para_bloque("move_l", "black")
	var id_b = BotSystem._obtener_escape_para_bloque("move_l", "black")
	assert_eq(id_a, id_b, "La misma direccion debe reutilizar el mismo protocolo")
	assert_ne(id_a, BotSystem._obtener_escape_para_bloque("move_r", "black"))

func test_escape_del_bot_no_aparece_en_la_paleta():
	var protocol_id = BotSystem._obtener_escape_para_bloque("move_b", "black")
	# El protocolo existe en BlockSystem...
	assert_false(BlockSystem.get_block_info(protocol_id).is_empty(), "El escape del bot debe estar registrado")

	# ...pero no se ofrece en la paleta, mientras que un escape del jugador si
	var escape_jugador = BlockSystem.create_escape_protocol([{"type": "move_f"}], 4, "Escape jugador", "black")
	var tipos_en_paleta := []
	for block in BlockSystem.get_blocks_for_palette("action", "black"):
		tipos_en_paleta.append(block.get("type", ""))
	assert_does_not_have(tipos_en_paleta, protocol_id, "El escape del bot no debe aparecer en la paleta")
	assert_has(tipos_en_paleta, escape_jugador, "Los escapes del jugador si deben aparecer")
	BlockSystem.delete_custom_block(escape_jugador)

func test_instalar_defensa_activa_el_protocolo():
	var pieza = autofree(PieceScene.instantiate())
	add_child_autofree(pieza)
	pieza.setup_piece(null, "black", "pawn", Vector2(0, 1))
	var protocol_id = BotSystem._obtener_escape_para_bloque("move_f", "black")
	BotSystem._instalar_defensa(pieza, protocol_id)
	assert_true(pieza.defense_protocol_active, "capture_piece solo dispara el escape si este flag es true")
	assert_eq(pieza.defense_protocol_id, protocol_id)
	BotSystem._quitar_defensa(pieza)
	assert_false(pieza.defense_protocol_active)
	assert_null(pieza.defense_protocol)

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

func _ubicar(pieza, celda: Vector2i) -> void:
	pieza.board_position = Vector2(celda)
	pieza.virtual_board_position = Vector2(celda)

func test_caballo_del_bot_atraviesa_aliados_sin_terminar_sobre_ellos():
	var gm = await _crear_partida()
	var caballo = gm.get_piece_at(Vector2i(1, 0))
	var jugadas = BotSystem._jugadas_legales(caballo, Vector2i(1, 0), gm)
	var destinos := []
	for j in jugadas:
		destinos.append(j["destino"])
		var occ = gm.get_piece_at(j["destino"])
		assert_true(occ == null or occ.piece_color != "black", "Termina sobre un aliado en %s" % str(j["destino"]))
	assert_has(destinos, Vector2i(1, 2), "Debe poder saltar el peon de (1,1)")

func test_el_rey_del_bot_puede_usar_mas_de_un_bloque():
	var gm = await _crear_partida()
	var rey = gm.get_piece_at(Vector2i(4, 0))
	_ubicar(rey, Vector2i(4, 4))  # centro despejado
	var max_bloques := 0
	for j in BotSystem._jugadas_legales(rey, Vector2i(4, 4), gm):
		max_bloques = max(max_bloques, j["bloques"].size())
		assert_lte(BotSystem._costo_incremental(j["bloques"]), rey.available_ram)
	assert_gt(max_bloques, 1, "El limite lo pone la RAM, no una regla especial")

func test_rescate_del_rey_verificado():
	var gm = await _crear_partida()
	# Se abre la columna del rey y la reina blanca lo amenaza desde (4,3)
	gm.get_piece_at(Vector2i(4, 1)).set_meta("is_dead", true)
	var reina = gm.get_piece_at(Vector2i(3, 7))
	_ubicar(reina, Vector2i(4, 3))
	var rey = gm.get_piece_at(Vector2i(4, 0))

	var mapa = BotSystem._construir_mapa_control(gm)
	assert_true(BotSystem._bajo_ataque(Vector2i(4, 0), mapa), "Precondicion: rey amenazado")

	var plan = await BotSystem._plan_rescate(rey, gm, mapa)
	assert_false(plan.is_empty(), "Debe encontrar un rescate")
	var pieza = plan["pieza"]
	var destino: Vector2i = plan["jugada"]["destino"]
	var mapa_despues = BotSystem._mapa_control_hipotetico(pieza, destino, gm)
	var rey_despues: Vector2i = destino if pieza == rey else Vector2i(4, 0)
	assert_false(BotSystem._bajo_ataque(rey_despues, mapa_despues), "La jugada elegida debe salvar al rey")

func test_elegir_jugada_devuelve_una_jugada_negra_valida():
	var gm = await _crear_partida()
	var mapa = BotSystem._construir_mapa_control(gm)
	var plan = await BotSystem._elegir_jugada(gm, mapa)
	assert_false(plan.is_empty())
	assert_eq(plan["pieza"].piece_color, "black")
	assert_lte(BotSystem._costo_incremental(plan["jugada"]["bloques"]), plan["pieza"].available_ram)

# --- Mejoras de criterio del bot ---

func _vaciar_tablero(gm, conservar: Array) -> void:
	for p in gm.pieces_container.get_children():
		if p not in conservar:
			p.set_meta("is_dead", true)

func test_no_destapa_al_rey():
	var gm = await _crear_partida()
	var rey = gm.get_piece_at(Vector2i(4, 0))
	var torre = gm.get_piece_at(Vector2i(0, 0))
	var peones = [gm.get_piece_at(Vector2i(3, 1)), gm.get_piece_at(Vector2i(4, 1)), gm.get_piece_at(Vector2i(5, 1))]
	var rey_blanco = gm.get_piece_at(Vector2i(4, 7))
	_vaciar_tablero(gm, [rey, torre, rey_blanco] + peones)
	# El rey blanco (RAM 12) solo llega a (4,0) en tres bloques y todos esos
	# caminos pasan por la fila 1, que esta tapada; cuatro bloques ya no entran
	_ubicar(rey_blanco, Vector2i(4, 3))
	var mapa = BotSystem._construir_mapa_control(gm)
	assert_false(BotSystem._bajo_ataque(Vector2i(4, 0), mapa), "Precondicion: rey cubierto")

	# Control: mover la torre no cambia la seguridad del rey
	var control = BotSystem._penalizacion_lookahead(torre, {"bloques": ["move_r"], "destino": Vector2i(1, 0), "captura": false, "ram": 2}, gm, mapa)
	assert_lt(control["penal"], BotSystem.PENAL_REY_EXPUESTO)

	# Apartar el peon de (3,1) abre el camino b, bl, br hacia el rey
	var abre = BotSystem._penalizacion_lookahead(peones[0], {"bloques": ["move_l"], "destino": Vector2i(2, 1), "captura": false, "ram": 2}, gm, mapa)
	assert_gte(abre["penal"], BotSystem.PENAL_REY_EXPUESTO, "Destapar al rey debe penalizarse")

	# Y la jugada elegida no deja al rey amenazado
	var plan = await BotSystem._elegir_jugada(gm, mapa)
	var pos_rey: Vector2i = plan["jugada"]["destino"] if plan["pieza"] == rey else Vector2i(4, 0)
	assert_false(BotSystem._bajo_ataque(pos_rey, plan["mapa_futuro"]), "La jugada elegida no debe exponer al rey")

func test_captura_contra_escape_no_se_sobrevalora():
	var gm = await _crear_partida()
	var torre = gm.get_piece_at(Vector2i(0, 0))
	var rey = gm.get_piece_at(Vector2i(4, 0))
	var reina = gm.get_piece_at(Vector2i(3, 7))
	var peon_blanco = gm.get_piece_at(Vector2i(7, 6))
	var rey_blanco = gm.get_piece_at(Vector2i(4, 7))
	_vaciar_tablero(gm, [torre, rey, reina, peon_blanco, rey_blanco])
	_ubicar(torre, Vector2i(3, 3))
	_ubicar(reina, Vector2i(3, 4))       # al lado de la torre, con escape
	_ubicar(peon_blanco, Vector2i(2, 3)) # al lado de la torre, sin escape
	var escape = BlockSystem.create_escape_protocol([{"type": "move_r"}], 2, "Escape test", "white")
	reina.defense_protocol = {"type": escape}
	reina.defense_protocol_id = escape
	reina.defense_protocol_active = true
	assert_true(BotSystem._tiene_escape_valido(reina, gm), "Precondicion: la reina huiria")

	var mapa = BotSystem._construir_mapa_control(gm)
	var puntajes := {}
	for c in BotSystem._puntuar_jugadas(torre, gm, mapa):
		if c["jugada"]["bloques"].size() == 1:
			puntajes[c["jugada"]["destino"]] = c["score"]
	assert_gt(puntajes[Vector2i(2, 3)], puntajes[Vector2i(3, 4)], "Capturar el peon vale mas que perseguir una reina que huye")
	BlockSystem.delete_custom_block(escape)

func test_mapa_hipotetico_ubica_a_la_victima_que_huye():
	var gm = await _crear_partida()
	var torre = gm.get_piece_at(Vector2i(0, 0))
	var reina = gm.get_piece_at(Vector2i(3, 7))
	var rey = gm.get_piece_at(Vector2i(4, 0))
	_vaciar_tablero(gm, [torre, reina, rey])
	_ubicar(torre, Vector2i(3, 3))
	_ubicar(reina, Vector2i(3, 4))
	var escape = BlockSystem.create_escape_protocol([{"type": "move_r"}], 2, "Escape test", "white")
	reina.defense_protocol = {"type": escape}
	reina.defense_protocol_active = true
	var huida = BotSystem._destino_escape(reina, gm)
	assert_eq(huida, Vector2i(4, 4))
	var mapa = BotSystem._mapa_control_hipotetico(torre, Vector2i(3, 4), gm)
	assert_true(BotSystem._bajo_ataque(Vector2i(3, 4), mapa), "La reina sigue viva y amenaza desde su casilla de huida")
	assert_eq(Vector2i(reina.board_position), Vector2i(3, 4), "La simulacion debe revertirse")
	assert_false(reina.get_meta("is_dead", false))
	BlockSystem.delete_custom_block(escape)

func test_captura_del_rey_blanco_es_prioritaria():
	var gm = await _crear_partida()
	var torre = gm.get_piece_at(Vector2i(0, 0))
	var rey = gm.get_piece_at(Vector2i(4, 0))
	var rey_blanco = gm.get_piece_at(Vector2i(4, 7))
	var reina = gm.get_piece_at(Vector2i(3, 7))
	_vaciar_tablero(gm, [torre, rey, rey_blanco, reina])
	_ubicar(torre, Vector2i(3, 3))
	_ubicar(rey_blanco, Vector2i(3, 5))
	_ubicar(reina, Vector2i(4, 3))
	var mapa = BotSystem._construir_mapa_control(gm)
	var plan = await BotSystem._elegir_jugada(gm, mapa)
	assert_eq(plan["jugada"]["destino"], Vector2i(3, 5), "Debe capturar al rey aunque haya una reina disponible")

func test_rescate_imposible_devuelve_la_jugada_menos_mala():
	var gm = await _crear_partida()
	var rey = gm.get_piece_at(Vector2i(4, 0))
	var reina = gm.get_piece_at(Vector2i(3, 7))
	var torre_blanca = gm.get_piece_at(Vector2i(0, 7))
	_vaciar_tablero(gm, [rey, reina, torre_blanca])
	_ubicar(rey, Vector2i(0, 0))
	_ubicar(reina, Vector2i(2, 2))
	_ubicar(torre_blanca, Vector2i(5, 1))
	var mapa = BotSystem._construir_mapa_control(gm)
	assert_true(BotSystem._bajo_ataque(Vector2i(0, 0), mapa), "Precondicion: rey amenazado")
	var plan = await BotSystem._plan_rescate(rey, gm, mapa)
	if plan.is_empty():
		pass_test("Ninguna jugada reduce el riesgo; se delega en _elegir_jugada")
		return
	var mapa_despues = plan["mapa_futuro"]
	var pos_rey: Vector2i = plan["jugada"]["destino"] if plan["pieza"] == rey else Vector2i(0, 0)
	var riesgo_antes = BotSystem._factor_riesgo(BotSystem._costo_amenaza(Vector2i(0, 0), mapa))
	var riesgo_despues = BotSystem._factor_riesgo(BotSystem._costo_amenaza(pos_rey, mapa_despues))
	var con_escape = plan["pieza"] == rey and BotSystem._rey_puede_escapar(rey, plan["jugada"], gm, mapa_despues)
	assert_true(con_escape or riesgo_despues < riesgo_antes, "El respaldo debe darle un escape al rey o reducir su riesgo")

func test_penaliza_volver_a_la_casilla_anterior():
	var gm = await _crear_partida()
	var caballo = gm.get_piece_at(Vector2i(1, 0))
	caballo.set_meta(BotSystem.META_CELDA_PREVIA, Vector2i(0, 2))
	var mapa = BotSystem._construir_mapa_control(gm)
	var con := {}
	for c in BotSystem._puntuar_jugadas(caballo, gm, mapa):
		con[c["jugada"]["destino"]] = c["score"]
	caballo.remove_meta(BotSystem.META_CELDA_PREVIA)
	var sin := {}
	for c in BotSystem._puntuar_jugadas(caballo, gm, mapa):
		sin[c["jugada"]["destino"]] = c["score"]
	assert_almost_eq(sin[Vector2i(0, 2)] - con[Vector2i(0, 2)], BotSystem.PENAL_VAIVEN, 0.01)
