extends GutTest

var TestMainScene = preload("res://src/test/fixture/test_main.tscn")
var gm
var contenedor

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
	contenedor = gm.pieces_container

# Espera a que el pulso este lejos de 1.0, para que el test mida algo real
func _esperar_pulso_visible() -> void:
	for i in range(120):
		if contenedor.pulse_factor > 1.0 + contenedor.PULSE_AMOUNT * 0.5:
			return
		await get_tree().process_frame

func test_el_contenedor_usa_el_script_externo_y_pulsa():
	assert_true(contenedor.has_method("start_pulse"), "Pieces debe usar pieces.gd")
	assert_true(contenedor.is_pulsing())

func test_el_contenedor_nunca_cambia_de_escala():
	await _esperar_pulso_visible()
	assert_gt(contenedor.pulse_factor, 1.0, "El pulso deberia estar en curso")
	assert_eq(contenedor.scale, Vector2.ONE)

func test_las_piezas_no_se_mueven_de_su_casilla_durante_el_pulso():
	await _esperar_pulso_visible()
	for piece in contenedor.get_children():
		var esperado = gm.board.cell_to_global(piece.board_position)
		assert_almost_eq(piece.global_position, esperado, Vector2(0.5, 0.5),
			"La pieza %s se corrio de su casilla" % piece.piece_id)

func test_el_pulso_escala_cada_pieza_sobre_su_base():
	await _esperar_pulso_visible()
	var piece = contenedor.get_child(0)
	assert_almost_eq(piece.scale, piece.base_scale * contenedor.pulse_factor, Vector2(0.0001, 0.0001))

func test_detener_el_pulso_restaura_la_escala_base():
	await _esperar_pulso_visible()
	contenedor.stop_pulse()
	assert_false(contenedor.is_pulsing())
	for piece in contenedor.get_children():
		assert_eq(piece.scale, piece.base_scale)
