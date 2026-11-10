extends GutTest

# Flujos completos: un turno de multijugador y una partida guardada y cargada.
# La escena se agrega en la raiz (/root/Main) porque BlockSystem.move_generic
# busca el GameManager en esa ruta.

var TestMainScene = preload("res://src/test/fixture/test_main.tscn")
var escena: Node = null

func before_each():
	# Nunca tocar la partida guardada real del jugador
	SaveManager.SAVE_PATH = "user://test_savegame.json"
	SaveManager.delete_save()
	GlobalConfig.reset_to_defaults()
	GlobalConfig.bot_disabled = true  # multijugador

func after_each():
	await _cerrar_partida()
	SaveManager.delete_save()
	GlobalConfig.reset_to_defaults()

func _abrir_partida() -> Node:
	escena = TestMainScene.instantiate()
	get_tree().root.add_child(escena)
	for i in range(6):
		await get_tree().process_frame
	return escena.get_node("GameManager")

func _cerrar_partida() -> void:
	if escena and is_instance_valid(escena):
		escena.queue_free()
		escena = null
		# Liberar /root/Main antes de abrir otra partida
		await get_tree().process_frame
		await get_tree().process_frame

func _ubicar(pieza, celda: Vector2i, gm) -> void:
	pieza.board_position = Vector2(celda)
	pieza.virtual_board_position = Vector2(celda)
	pieza.position = gm._board_to_world_position(Vector2(celda))

# --- Multijugador ---

func test_negras_humanas_ejecutan_un_loop_en_multijugador():
	var gm = await _abrir_partida()
	gm.switch_turn()
	assert_eq(gm.current_turn, "black")
	var ronda_antes: int = gm.current_turn_count

	var peon = gm.get_piece_at(Vector2i(0, 1))
	var loop_id = BlockSystem.create_loop_block([{"type": "move_f"}, {"type": "move_f"}], 5, "Doble avance", "black")
	gm.save_piece_program(peon, [{"type": loop_id}])
	await gm.execute_turn_and_switch()

	assert_eq(Vector2i(peon.board_position), Vector2i(0, 3), "El loop negro debe ejecutar sus dos pasos")
	assert_eq(gm.current_turn, "white", "El turno pasa al jugador blanco")
	assert_eq(gm.current_turn_count, ronda_antes + 1, "Al jugar las negras termina la ronda")

# --- Guardar y cargar ---

func test_guardar_y_cargar_restaura_piezas_turno_modo_y_bloques():
	var gm = await _abrir_partida()
	var peon = gm.get_piece_at(Vector2i(0, 6))
	_ubicar(peon, Vector2i(0, 4), gm)
	gm.get_piece_at(Vector2i(7, 1)).set_meta("is_dead", true)
	var loop_id = BlockSystem.create_loop_block([{"type": "move_f"}, {"type": "move_r"}], 5, "Mi loop", "white")
	gm.switch_turn()  # se guarda en el turno de las negras
	gm.save_game()
	assert_true(SaveManager.has_save())
	await _cerrar_partida()

	# Sesion nueva: sin bloques en memoria y con el modo por defecto
	BlockSystem.clear_custom_blocks()
	GlobalConfig.reset_to_defaults()
	GlobalConfig.load_save = true
	gm = await _abrir_partida()

	assert_false(GlobalConfig.load_save, "La bandera de carga se consume")
	assert_true(GlobalConfig.bot_disabled, "Se retoma en multijugador, no contra el bot")
	assert_eq(gm.current_turn, "black")

	var cargado = gm.get_piece_at(Vector2i(0, 4))
	assert_not_null(cargado, "La pieza vuelve a su casilla guardada")
	assert_eq(cargado.piece_id, "white_pawn_0_6", "Conserva su id original")
	assert_null(gm.get_piece_at(Vector2i(7, 1)), "Las piezas muertas no vuelven")

	var info = BlockSystem.get_block_info(loop_id)
	assert_eq(info.get("name"), "Mi loop", "El loop se restaura con su nombre")
	assert_eq(info["contained_blocks"].map(func(b): return b["type"]), ["move_f", "move_r"])

func test_cargar_un_guardado_invalido_inicia_partida_nueva():
	SaveManager.save_game({"current_turn": "none", "pieces": []})
	GlobalConfig.load_save = true
	var gm = await _abrir_partida()
	assert_false(SaveManager.has_save(), "El guardado invalido se descarta")
	assert_eq(gm.current_turn, "white")
	assert_eq(gm.pieces_container.get_child_count(), 32, "Se arma el tablero inicial")
