extends GutTest

var TestMainScene = preload("res://src/test/fixture/test_main.tscn")
var gm
var board

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
	board = gm.board

func test_conversion_ida_y_vuelta_en_las_64_casillas():
	for x in range(8):
		for y in range(8):
			var cell = Vector2i(x, y)
			assert_eq(board.global_to_cell(board.cell_to_global(Vector2(cell))), cell)

func test_y_no_se_invierte():
	# (0,0) arriba a la izquierda, (0,7) abajo: la fila 7 tiene mayor Y en pantalla
	assert_lt(board.cell_to_global(Vector2(0, 0)).y, board.cell_to_global(Vector2(0, 7)).y)
	assert_lt(board.cell_to_global(Vector2(0, 0)).x, board.cell_to_global(Vector2(7, 0)).x)

func test_casillas_fuera_del_tablero():
	assert_true(board.is_inside_board(Vector2i(0, 0)))
	assert_true(board.is_inside_board(Vector2i(7, 7)))
	assert_false(board.is_inside_board(Vector2i(-1, 3)))
	assert_false(board.is_inside_board(Vector2i(8, 0)))

func test_piezas_iniciales_se_ven_en_su_casilla():
	# Posicion de reposo de cada pieza (sin la escala del pulso) -> su casilla logica
	for piece in gm.pieces_container.get_children():
		var global_reposo = gm.pieces_container.global_position + piece.position
		assert_eq(board.global_to_cell(global_reposo), Vector2i(piece.board_position),
			"La pieza %s se dibuja fuera de su casilla" % piece.piece_id)

func test_funciona_si_pieces_y_table_tienen_desplazamientos_distintos():
	# Antes esto rompia: la conversion asumia que ambos nodos estaban en el mismo lugar
	gm.pieces_container.position += Vector2(123, -45)

	var celda = Vector2(5, 4)
	var local = gm._board_to_world_position(celda)
	var global_reposo = gm.pieces_container.global_position + local
	assert_eq(board.global_to_cell(global_reposo), Vector2i(5, 4))
	assert_almost_eq(global_reposo, board.cell_to_global(celda), Vector2(0.01, 0.01), "La pieza debe dibujarse en el centro de la casilla")

	# Y la busqueda inversa sigue encontrando la pieza correcta
	var encontrada = gm.get_piece_at_position(gm._board_to_world_position(Vector2(2, 1)))
	assert_not_null(encontrada)
	assert_eq(Vector2i(encontrada.board_position), Vector2i(2, 1))
