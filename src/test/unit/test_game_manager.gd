# test/unit/test_game_manager.gd
extends GutTest

var TestMainScene = preload("res://src/test/fixture/test_main.tscn")
var gm

func before_each():
	# Nunca tocar la partida guardada real del jugador
	SaveManager.SAVE_PATH = "user://test_savegame.json"
	# Forzamos modo "multijugador" (bot desactivado) para tests deterministas.
	# El bot en sí se testea por separado en test_bot_system.gd.
	if GlobalConfig:
		GlobalConfig.bot_disabled = true
		GlobalConfig.load_save = false

	var test_main = autofree(TestMainScene.instantiate())
	add_child_autofree(test_main)

	# _ready() -> _initialize_game() hace varios awaits internos
	# (spawn de piezas, process_frame). Esperamos unos frames
	# para que la inicialización asíncrona termine.
	for i in range(5):
		await get_tree().process_frame

	gm = test_main.get_node("GameManager")

func test_game_manager_existe_y_esta_listo():
	assert_not_null(gm)
	assert_eq(gm.current_turn, "white")

func test_piezas_spawneadas_correctamente():
	# 16 blancas + 16 negras = 32 piezas en la posición inicial
	assert_eq(gm.pieces_container.get_child_count(), 32)

func test_is_valid_move_dentro_de_limites():
	assert_true(gm.is_valid_move(null, Vector2i(4, 4)))

func test_is_valid_move_fuera_de_limites():
	assert_false(gm.is_valid_move(null, Vector2i(8, 0)))
	assert_false(gm.is_valid_move(null, Vector2i(-1, 3)))

func test_switch_turn_alterna_correctamente():
	gm.current_turn = "white"
	gm.switch_turn()
	assert_eq(gm.current_turn, "black")
	gm.switch_turn()
	assert_eq(gm.current_turn, "white")

func test_get_piece_at_encuentra_pieza_inicial():
	# Torre blanca en (0,7) según spawn_main_pieces
	var pieza = gm.get_piece_at(Vector2i(0, 7))
	assert_not_null(pieza)
	assert_eq(pieza.piece_type, "tower")
	assert_eq(pieza.piece_color, "white")

func test_get_piece_at_casilla_vacia():
	var pieza = gm.get_piece_at(Vector2i(3, 3))
	assert_null(pieza)

func test_capture_piece_marca_pieza_como_muerta():
	var objetivo = gm.get_piece_at(Vector2i(0, 1))  # peón negro inicial
	assert_not_null(objetivo)
	await gm.capture_piece(objetivo)
	assert_true(objetivo.get_meta("is_dead", false))

func test_check_victory_conditions_sin_ganador_al_inicio():
	gm.check_victory_conditions()
	assert_false(gm.game_over)

func test_end_game_declara_ganador_correctamente():
	gm.end_game("white")
	assert_true(gm.game_over)
	assert_eq(gm.winner, "white")
