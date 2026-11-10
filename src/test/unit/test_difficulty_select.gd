extends GutTest

const TEST_PATH := "user://test_settings.cfg"
var Scene = preload("res://src/ui/menus/DifficultySelect.tscn")
var popup: DifficultySelect
var _previa: String

func before_each():
	_previa = GlobalConfig.bot_difficulty
	popup = Scene.instantiate()
	popup.settings_path = TEST_PATH
	add_child_autofree(popup)
	await popup.open()

func after_each():
	GlobalConfig.set_bot_difficulty(_previa)
	DirAccess.remove_absolute(TEST_PATH)

func test_elegir_un_nivel_lo_aplica_guarda_y_avisa():
	watch_signals(popup)
	popup.level_buttons["hard"].pressed.emit()
	assert_eq(GlobalConfig.bot_difficulty, "hard")
	assert_signal_emitted_with_parameters(popup, "difficulty_chosen", ["hard"])
	assert_false(popup.visible)
	var config = ConfigFile.new()
	assert_eq(config.load(TEST_PATH), OK)
	assert_eq(config.get_value("game", "bot_difficulty"), "hard")

func test_guardar_conserva_las_demas_opciones():
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", 0.4)
	config.save(TEST_PATH)
	popup.level_buttons["easy"].pressed.emit()
	config = ConfigFile.new()
	config.load(TEST_PATH)
	assert_almost_eq(float(config.get_value("audio", "master_volume")), 0.4, 0.001)
	assert_eq(config.get_value("game", "bot_difficulty"), "easy")

func test_cancelar_no_cambia_la_dificultad():
	GlobalConfig.set_bot_difficulty("normal")
	watch_signals(popup)
	popup.cancel_button.pressed.emit()
	assert_eq(GlobalConfig.bot_difficulty, "normal")
	assert_signal_emitted(popup, "cancelled")
	assert_signal_not_emitted(popup, "difficulty_chosen")
	assert_false(popup.visible)

func test_cada_nivel_muestra_su_descripcion():
	for level in popup.level_hints:
		assert_eq(popup.level_hints[level].text, SettingsMenu.DIFFICULTY_HINTS[level])

func test_el_menu_principal_pide_la_dificultad_antes_de_empezar():
	var menu = autofree(load("res://src/ui/menus/MainMenu.tscn").instantiate())
	add_child(menu)
	await get_tree().process_frame
	menu._on_new_game_button_pressed()
	assert_true(menu.difficulty_select.visible, "Debe abrirse el selector")
	assert_false(menu._transitioning, "La partida no empieza hasta elegir")
	menu.difficulty_select.close()
	assert_false(menu._transitioning)
