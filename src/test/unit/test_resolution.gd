extends GutTest

# Disposicion adaptable: el diseno de 1360x768 se centra en el area visible

var TestMainScene = preload("res://src/test/fixture/test_main.tscn")

func test_aspecto_expand():
	assert_eq(get_tree().root.content_scale_aspect, Window.CONTENT_SCALE_ASPECT_EXPAND)
	assert_eq(get_tree().root.content_scale_size, ResolutionManager.BASE_SIZE)

func test_rectangulo_de_diseno_centrado():
	var rect: Rect2 = ResolutionManager.design_rect()
	var vis: Vector2 = ResolutionManager.visible_size()
	assert_eq(rect.size, Vector2(ResolutionManager.BASE_SIZE))
	assert_almost_eq(rect.position.x * 2.0 + rect.size.x, vis.x, 0.01)
	assert_almost_eq(rect.position.y * 2.0 + rect.size.y, vis.y, 0.01)

func test_tablero_no_depende_del_area_visible():
	var board = autofree(preload("res://src/entities/board/board.tscn").instantiate())
	assert_eq(board.calculate_cell_size(Vector2(1360, 1024)), board.base_cell_size)
	assert_eq(board.calculate_cell_size(Vector2(1820, 768)), board.base_cell_size)

func test_camara_y_botones_de_la_partida():
	SaveManager.SAVE_PATH = "user://test_savegame.json"
	GlobalConfig.bot_disabled = true
	GlobalConfig.load_save = false
	var main = TestMainScene.instantiate()
	autofree(main)
	get_tree().root.add_child(main)
	for i in range(5):
		await get_tree().process_frame
	var cam = main.get_node("Camera/Camera2D")
	assert_eq(cam.position, Vector2(ResolutionManager.BASE_SIZE) / 2.0, "La camara apunta al centro del diseno")
	# Los botones quedan dentro del area visible, pegados a su borde derecho
	var box: Control = main.get_node("Buttons/VBoxContainer")
	var derecha_mundo: float = main.get_node("Buttons").position.x + box.size.x
	var borde_visible: float = ResolutionManager.BASE_SIZE.x + ResolutionManager.design_rect().position.x
	assert_almost_eq(derecha_mundo, borde_visible - main.CORNER_MARGIN.x, 1.0)
