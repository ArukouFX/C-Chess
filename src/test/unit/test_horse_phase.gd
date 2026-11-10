extends GutTest

# Pasada del caballo sobre aliados. Se usa el caballo negro de (1,0), que
# tiene a su peon aliado en (1,1) y la casilla (1,2) libre.

var TestMainScene = preload("res://src/test/fixture/test_main.tscn")
var gm
var caballo

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
	caballo = gm.get_piece_at(Vector2i(1, 0))

func _ejecutar(programa: Array) -> void:
	caballo.behavior_script = programa
	await gm.execute_piece_program(caballo)

func test_caballo_negro_atraviesa_aliado_y_sincroniza_posiciones():
	assert_eq(caballo.piece_type, "horse")
	await _ejecutar([{"type": "move_f"}, {"type": "move_f"}])

	assert_eq(Vector2i(caballo.board_position), Vector2i(1, 2))
	assert_eq(Vector2i(caballo.virtual_board_position), Vector2i(1, 2),
		"board_position y virtual_board_position deben coincidir")
	assert_eq(Vector2i(gm.get_piece_at(Vector2i(1, 1)).board_position), Vector2i(1, 1),
		"El peon aliado no debe moverse")

func test_caballo_negro_no_termina_sobre_aliado():
	await _ejecutar([{"type": "move_f"}])

	assert_eq(Vector2i(caballo.board_position), Vector2i(1, 0),
		"Sin mas instrucciones, el caballo no puede quedar sobre el peon")
	assert_eq(Vector2i(caballo.virtual_board_position), Vector2i(1, 0))

func test_caballo_atraviesa_aliado_dentro_de_un_loop():
	var loop_id = BlockSystem.create_loop_block(
		[{"type": "move_f"}, {"type": "move_f"}], 5, "Loop caballo", "black"
	)
	# El loop es la unica instruccion: el permiso de pasar sale del propio loop
	await _ejecutar([{"type": loop_id}])

	assert_eq(Vector2i(caballo.board_position), Vector2i(1, 2))
	BlockSystem.delete_custom_block(loop_id)

func test_caballo_no_termina_sobre_aliado_al_final_de_un_loop():
	var loop_id = BlockSystem.create_loop_block(
		[{"type": "move_f"}], 2, "Loop caballo corto", "black"
	)
	await _ejecutar([{"type": loop_id}])

	assert_eq(Vector2i(caballo.board_position), Vector2i(1, 0))
	BlockSystem.delete_custom_block(loop_id)

# Encontrado en las partidas simuladas: si el paso siguiente al salto falla
# (aca se sale del tablero), el programa se corta con el caballo encima del
# aliado. Debe volver a la ultima casilla libre.
func test_caballo_vuelve_si_el_programa_se_corta_sobre_un_aliado():
	await _ejecutar([{"type": "move_r"}, {"type": "move_b"}])  # (2,0) es su alfil; despues sale del tablero
	assert_eq(Vector2i(caballo.board_position), Vector2i(1, 0), "Vuelve a su casilla")
	assert_eq(Vector2i(caballo.virtual_board_position), Vector2i(1, 0))
	var alfil = gm.get_piece_at(Vector2i(2, 0))
	assert_not_null(alfil)
	assert_eq(alfil.piece_type, "bishop", "El alfil sigue solo en su casilla")
	assert_false(caballo.has_meta("phase_return_cell"), "No queda estado del salto")

func test_caballo_que_salta_y_termina_libre_no_se_corrige():
	await _ejecutar([{"type": "move_f"}, {"type": "move_f"}])
	assert_eq(Vector2i(caballo.board_position), Vector2i(1, 2))
	assert_false(caballo.has_meta("phase_return_cell"))
