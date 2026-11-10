extends GutTest

var TestMainScene = preload("res://src/test/fixture/test_main.tscn")
var InterfaceScene = preload("res://src/ui/interface/programming_interface.tscn")
var BlockScene = preload("res://src/programming/draggable_block.tscn")
var gm
var peon  # peon blanco de (0,6)

func before_each():
	# Nunca tocar la partida guardada real del jugador
	SaveManager.SAVE_PATH = "user://test_savegame.json"
	GlobalConfig.bot_disabled = true
	GlobalConfig.load_save = false

	var test_main = TestMainScene.instantiate()
	autofree(test_main)
	get_tree().root.add_child(test_main)
	for i in range(5):
		await get_tree().process_frame
	gm = test_main.get_node("GameManager")
	peon = gm.get_piece_at(Vector2i(0, 6))

# Abre una interfaz para la pieza, como lo hace el GameManager
func _abrir(pieza) -> ProgrammingInterface:
	var ui: ProgrammingInterface = InterfaceScene.instantiate()
	add_child_autofree(ui)
	await ui.setup_for_piece(pieza, gm)
	return ui

func _tipos(blocks: Array) -> Array:
	return blocks.map(func(b): return b["type"])

# --- Punto 1: reabrir no borra el programa ---

func test_reabrir_la_interfaz_muestra_el_programa_guardado():
	gm.save_piece_program(peon, [{"type": "move_f"}, {"type": "move_l"}])
	var ui = await _abrir(peon)
	assert_eq(_tipos(ui.current_blocks), ["move_f", "move_l"])
	assert_eq(_tipos(peon.behavior_script), ["move_f", "move_l"], "Abrir la interfaz no debe tocar la pieza")
	assert_eq(_tipos(gm.get_piece_program(peon.piece_id)), ["move_f", "move_l"])

func test_reabrir_incluye_el_escape_instalado():
	var escape_id = BlockSystem.create_escape_protocol([{"type": "move_b"}], 4, "E", "white")
	gm.save_piece_program(peon, [{"type": "move_f"}, {"type": escape_id}])
	var ui = await _abrir(peon)
	assert_eq(_tipos(ui.current_blocks), ["move_f", escape_id])

# --- Cancelar no guarda ---

func test_cancelar_no_cambia_el_programa_guardado():
	gm.save_piece_program(peon, [{"type": "move_f"}])
	var ui = await _abrir(peon)
	var extra: DraggableBlock = BlockScene.instantiate()
	extra.block_id = "move_r"
	add_child_autofree(extra)
	extra.setup_block(BlockSystem.get_block_info("move_r").duplicate(true))
	extra.move_to_workspace(ui.workspace, 99)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_tipos(ui.current_blocks), ["move_f", "move_r"], "La interfaz ve el cambio")

	ui._on_cancel_button_pressed()
	assert_eq(_tipos(gm.get_piece_program(peon.piece_id)), ["move_f"], "Cancelar no guarda")
	assert_eq(_tipos(peon.behavior_script), ["move_f"])

# --- El escape se instala antes de avisar al tutorial ---

func test_el_escape_esta_activo_cuando_se_emite_piece_programmed():
	var escape_id = BlockSystem.create_escape_protocol([{"type": "move_b"}], 4, "E", "white")
	var activo_en_la_senal := []
	gm.piece_programmed.connect(func(pieza, _script): activo_en_la_senal.append(pieza.defense_protocol_active), CONNECT_ONE_SHOT)
	gm.save_piece_program(peon, [{"type": "move_f"}, {"type": escape_id}])
	assert_eq(activo_en_la_senal, [true])
	assert_eq(peon.defense_protocol_id, escape_id)
	assert_eq(_tipos(peon.behavior_script), ["move_f"], "El escape no forma parte de los movimientos")

func test_quitar_el_escape_del_programa_lo_desinstala():
	var escape_id = BlockSystem.create_escape_protocol([{"type": "move_b"}], 4, "E", "white")
	gm.save_piece_program(peon, [{"type": escape_id}])
	assert_true(peon.defense_protocol_active)
	gm.save_piece_program(peon, [{"type": "move_f"}])
	assert_false(peon.defense_protocol_active)

# --- Contenido valido de loops y escapes ---

func test_validacion_de_contenido_de_loops_y_escapes():
	var ui = await _abrir(peon)
	var loop_id = BlockSystem.create_loop_block([{"type": "move_f"}], 2, "L", "white")
	var escape_id = BlockSystem.create_escape_protocol([{"type": "move_f"}], 4, "E", "white")

	assert_eq(ui.validate_new_block_content([{"type": "move_f"}, {"type": loop_id}], "loop"), "", "Un loop puede contener loops")
	assert_ne(ui.validate_new_block_content([{"type": escape_id}], "loop"), "", "Un loop no puede contener escapes")
	assert_eq(ui.validate_new_block_content([{"type": "move_f"}, {"type": "move_l"}], "escape"), "")
	assert_ne(ui.validate_new_block_content([{"type": loop_id}], "escape"), "", "Un escape solo admite movimientos simples")
	assert_ne(ui.validate_new_block_content([], "loop"), "", "Vacio no es valido")

func test_loops_y_escapes_guardan_el_mismo_formato():
	var ui = await _abrir(peon)
	ui.current_blocks = [{"type": "move_f"}, {"type": "move_r"}]
	var loop_id = BlockSystem.create_loop_block(ui.current_blocks.duplicate(true), 5, "L", "white")
	var escape_id = BlockSystem.create_escape_protocol(ui.current_blocks.duplicate(true), 10, "E", "white")
	for id in [loop_id, escape_id]:
		for sub in BlockSystem.get_block_info(id)["contained_blocks"]:
			assert_eq(sub.keys(), ["type"], "Cada paso guarda solo su tipo")

# --- Posicionamiento ---

func test_la_interfaz_queda_a_la_derecha_del_tablero_y_dentro_de_pantalla():
	await gm.open_programming_interface_for_piece(peon, Vector2.ZERO)
	var ui: Control = gm.current_programming_interface
	assert_not_null(ui)
	var rect: Rect2 = gm.get_interface_visible_rect(ui)
	var screen: Vector2 = ui.get_viewport().get_visible_rect().size
	var borde_tablero: float = (ui.get_viewport().get_canvas_transform() * (gm.board.cell_to_global(Vector2(7, 0)) + Vector2(gm.board.cell_size / 2.0, 0))).x

	assert_true(rect.position.x >= 0 and rect.end.x <= screen.x, "No se sale de la pantalla en X")
	assert_true(rect.position.y >= 0 and rect.end.y <= screen.y, "No se sale de la pantalla en Y")
	if rect.size.x <= screen.x - borde_tablero - 20:
		assert_gte(rect.position.x, borde_tablero, "Si entra, no tapa el tablero")

# --- Pieza seleccionada ---

func test_abrir_la_interfaz_resalta_la_pieza():
	await gm.open_programming_interface_for_piece(peon, Vector2.ZERO)
	assert_true(peon.is_selected)
	assert_eq(gm.selected_piece, peon)

func test_abrir_otra_pieza_cambia_el_resaltado():
	var otro = gm.get_piece_at(Vector2i(1, 6))
	await gm.open_programming_interface_for_piece(peon, Vector2.ZERO)
	await gm.open_programming_interface_for_piece(otro, Vector2.ZERO)
	assert_false(peon.is_selected, "La pieza anterior deja de estar resaltada")
	assert_true(otro.is_selected)

func test_cerrar_la_interfaz_quita_el_resaltado():
	await gm.open_programming_interface_for_piece(peon, Vector2.ZERO)
	gm.current_programming_interface._on_cancel_button_pressed()
	assert_false(peon.is_selected)
	assert_null(gm.selected_piece)

# --- Aparicion de la interfaz ---

func test_la_interfaz_no_se_ve_hasta_estar_ubicada():
	gm.open_programming_interface_for_piece(peon, Vector2.ZERO)  # sin await
	await get_tree().process_frame
	await get_tree().process_frame
	var ui: Control = _interfaz_en_construccion()
	assert_not_null(ui, "La interfaz ya existe")
	assert_eq(ui.modulate.a, 0.0, "Mientras se arma no se ve (antes aparecia en el centro)")

	# Esperar a que termine de ubicarse y del fundido
	for i in range(30):
		await get_tree().process_frame
	assert_eq(gm.current_programming_interface, ui)
	assert_almost_eq(ui.modulate.a, 1.0, 0.01)

func test_dos_clics_seguidos_dejan_una_sola_interfaz():
	var otro = gm.get_piece_at(Vector2i(1, 6))
	gm.open_programming_interface_for_piece(peon, Vector2.ZERO)  # sin await
	await gm.open_programming_interface_for_piece(otro, Vector2.ZERO)
	for i in range(20):
		await get_tree().process_frame
	var abiertas := 0
	for n in _contenedor_de_interfaces().get_children():
		if n is ProgrammingInterface and not n.is_queued_for_deletion():
			abiertas += 1
	assert_eq(abiertas, 1)
	assert_eq(gm.current_programming_interface.current_piece, otro)

func _contenedor_de_interfaces() -> Node:
	var capa = gm.get_node_or_null("../SetProgramming")
	return capa if capa else gm

func _interfaz_en_construccion() -> Control:
	for n in _contenedor_de_interfaces().get_children():
		if n is ProgrammingInterface and not n.is_queued_for_deletion():
			return n
	return null
