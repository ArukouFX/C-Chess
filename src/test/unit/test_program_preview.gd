extends GutTest

# La vista previa debe coincidir exactamente con la ejecucion real

var TestMainScene = preload("res://src/test/fixture/test_main.tscn")
var _creados: Array = []

func after_each():
	Engine.time_scale = 1.0
	_creados.reverse()  # los loops externos primero
	for id in _creados:
		BlockSystem.delete_custom_block(id)
	_creados.clear()

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

func _prog(tipos: Array) -> Array:
	var p := []
	for t in tipos:
		p.append({"type": t})
	return p

func _loop(tipos: Array, color: String) -> String:
	var contenido = _prog(tipos)
	var id = BlockSystem.create_loop_block(contenido, BlockSystem.calculate_ram_usage(contenido), "Loop test", color)
	_creados.append(id)
	return id

func _kinds(r: Dictionary) -> Array:
	var k := []
	for s in r["steps"]:
		k.append(s["kind"])
	return k

# --- Casos puntuales ---

func test_peon_blanco_avanza_hacia_arriba():
	var gm = await _crear_partida()
	var peon = gm.get_piece_at(Vector2i(4, 6))
	var r = ProgramPreview.simulate(peon, _prog(["move_f", "move_f"]), gm)
	assert_eq(r["final"], Vector2i(4, 4))
	assert_eq(_kinds(r), [ProgramPreview.MOVE, ProgramPreview.MOVE])
	assert_eq(r["stop"], "")

func test_peon_negro_avanza_hacia_abajo():
	var gm = await _crear_partida()
	var peon = gm.get_piece_at(Vector2i(4, 1))
	assert_eq(ProgramPreview.simulate(peon, _prog(["move_f"]), gm)["final"], Vector2i(4, 2))

func test_choque_con_aliado_corta_el_programa():
	var gm = await _crear_partida()
	var torre = gm.get_piece_at(Vector2i(0, 7))
	var r = ProgramPreview.simulate(torre, _prog(["move_f", "move_r"]), gm)
	assert_eq(r["final"], Vector2i(0, 7))
	assert_eq(r["stop"], ProgramPreview.BLOCKED)
	assert_eq(r["steps"].size(), 1, "Despues del choque no se simula nada mas")

func test_salir_del_tablero():
	var gm = await _crear_partida()
	var peon = gm.get_piece_at(Vector2i(0, 6))
	var r = ProgramPreview.simulate(peon, _prog(["move_f", "move_l"]), gm)
	assert_eq(r["final"], Vector2i(0, 5))
	assert_eq(r["stop"], ProgramPreview.OUT)
	assert_eq(r["steps"][-1]["cell"], Vector2i(-1, 5))

func test_captura_termina_el_programa():
	var gm = await _crear_partida()
	var peon = gm.get_piece_at(Vector2i(3, 6))
	_ubicar(peon, Vector2i(3, 2))
	var r = ProgramPreview.simulate(peon, _prog(["move_f", "move_f"]), gm)
	assert_eq(r["capture"], Vector2i(3, 1))
	assert_eq(r["final"], Vector2i(3, 1))
	assert_eq(r["steps"].size(), 1)

func test_caballo_atraviesa_aliado_y_sigue():
	var gm = await _crear_partida()
	var caballo = gm.get_piece_at(Vector2i(1, 7))
	var r = ProgramPreview.simulate(caballo, _prog(["move_f", "move_f"]), gm)
	assert_eq(_kinds(r), [ProgramPreview.PASS, ProgramPreview.MOVE])
	assert_eq(r["final"], Vector2i(1, 5))

func test_caballo_que_termina_sobre_aliado_vuelve():
	var gm = await _crear_partida()
	var caballo = gm.get_piece_at(Vector2i(1, 7))
	# Atraviesa (1,6) y luego intenta salir por la izquierda dos veces
	var r = ProgramPreview.simulate(caballo, _prog(["move_f", "move_l", "move_l"]), gm)
	assert_true(r["returned"] or r["final"] != Vector2i(1, 6), "Nunca termina sobre un aliado")

func test_loop_anidado_se_expande():
	var gm = await _crear_partida()
	var peon = gm.get_piece_at(Vector2i(4, 6))
	_ubicar(peon, Vector2i(4, 5))
	var l1 = _loop(["move_f"], "white")
	var l2 = _loop([l1, l1], "white")
	var r = ProgramPreview.simulate(peon, _prog([l2]), gm)
	assert_eq(r["final"], Vector2i(4, 3))
	assert_eq(r["steps"].size(), 2)

func test_el_escape_no_se_mueve_en_el_turno():
	var gm = await _crear_partida()
	var peon = gm.get_piece_at(Vector2i(4, 6))
	var escape = BlockSystem.create_escape_protocol(_prog(["move_l"]), 2, "Escape test", "white")
	_creados.append(escape)
	var r = ProgramPreview.simulate(peon, _prog([escape, "move_f"]), gm)
	assert_eq(r["final"], Vector2i(4, 5))
	assert_eq(r["steps"].size(), 1)

# --- Integracion con el tablero ---

func test_el_tablero_muestra_y_borra_la_vista_previa():
	var gm = await _crear_partida()
	var peon = gm.get_piece_at(Vector2i(4, 6))
	gm.show_program_preview(peon, _prog(["move_f"]))
	assert_not_null(gm.path_preview)
	assert_true(gm.path_preview.has_preview())
	assert_eq(gm.path_preview.get_parent(), gm.board)
	gm.show_program_preview(peon, [])
	assert_false(gm.path_preview.has_preview(), "Un programa vacio no muestra nada")
	gm.show_program_preview(peon, _prog(["move_f"]))
	gm._on_programming_interface_closed()
	assert_false(gm.path_preview.has_preview(), "Al cerrar la interfaz se borra")

# --- La vista previa coincide con la ejecucion real ---

func test_vista_previa_igual_a_la_ejecucion_real():
	seed(20261110)
	Engine.time_scale = 20.0
	var basicos = ["move_f", "move_b", "move_l", "move_r", "move_fl", "move_fr", "move_bl", "move_br"]
	for prueba in range(24):
		var gm = await _crear_partida()
		var piezas = gm.pieces_container.get_children()
		# Tablero con huecos al azar
		for p in piezas:
			if p.piece_type != "king" and randf() < 0.35:
				p.set_meta("is_dead", true)
		var vivas = piezas.filter(func(p): return not p.get_meta("is_dead", false) and p.piece_type != "king")
		# Los caballos aparecen seguido: son el caso mas delicado
		var caballos = vivas.filter(func(p): return p.piece_type == "horse")
		var pieza = caballos.pick_random() if (not caballos.is_empty() and prueba % 3 == 0) else vivas.pick_random()
		var color: String = pieza.piece_color

		var programa := []
		for i in range(randi_range(1, 4)):
			var r = randf()
			if r < 0.6:
				programa.append(basicos.pick_random())
			elif r < 0.85:
				programa.append(_loop([basicos.pick_random(), basicos.pick_random()], color))
			else:
				var interno = _loop([basicos.pick_random()], color)
				programa.append(_loop([interno, basicos.pick_random(), interno], color))
		var script = _prog(programa)

		# move_generic busca el GameManager en /root/Main: debe ser esta partida
		assert_eq(gm.get_parent().name, &"Main", "La partida anterior sigue en el arbol")
		var prevista = ProgramPreview.simulate(pieza, script, gm)
		var victima = gm.get_piece_at(prevista["capture"]) if prevista["capture"] != null else null

		pieza.behavior_script = script.duplicate(true)
		await gm.execute_piece_program(pieza)

		var etiqueta = "prueba %d: %s %s %s" % [prueba, color, pieza.piece_type, str(programa)]
		assert_eq(Vector2i(pieza.board_position), prevista["final"], etiqueta)
		if victima:
			assert_true(victima.get_meta("is_dead", false), "Captura prevista no ocurrio. " + etiqueta)
		else:
			# Ninguna otra pieza fue capturada
			var muertas_nuevas = 0
			for p in piezas:
				if p.get_meta("is_dead", false) and p.board_position == Vector2(-999, -999):
					muertas_nuevas += 1
			assert_eq(muertas_nuevas, 0, "Hubo una captura no prevista. " + etiqueta)
		# Se retira ya del arbol: si no, la proxima partida no se llamaria "Main"
		var main = gm.get_parent()
		get_tree().root.remove_child(main)
		main.queue_free()
