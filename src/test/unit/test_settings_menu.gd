extends GutTest

const TEST_PATH := "user://test_settings.cfg"
var SettingsScene = preload("res://src/ui/menus/SettingsMenu.tscn")
var menu: SettingsMenu
var _vol_db: float
var _mute: bool
var _res: Vector2i
var _fs: bool

func before_each():
	var bus = AudioServer.get_bus_index("Master")
	_vol_db = AudioServer.get_bus_volume_db(bus)
	_mute = AudioServer.is_bus_mute(bus)
	_res = ResolutionManager.current_resolution
	_fs = ResolutionManager.is_fullscreen
	# Estado conocido: en ventana y con la resolucion base. Sin esto los tests
	# dependerian del settings.cfg real (por ejemplo, si se juega en pantalla
	# completa). Solo se cambian las variables, no la ventana.
	ResolutionManager.current_resolution = SettingsMenu.DEFAULT_RESOLUTION
	ResolutionManager.is_fullscreen = false
	menu = SettingsScene.instantiate()
	menu.settings_path = TEST_PATH
	add_child_autofree(menu)
	await menu.open()

func after_each():
	var bus = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, _vol_db)
	AudioServer.set_bus_mute(bus, _mute)
	ResolutionManager.current_resolution = _res
	ResolutionManager.is_fullscreen = _fs
	DirAccess.remove_absolute(TEST_PATH)

func test_abre_y_cierra():
	assert_true(menu.visible)
	watch_signals(menu)
	menu.close()
	assert_false(menu.visible)
	assert_signal_emitted(menu, "menu_closed")

func test_aplicar_solo_con_cambios_pendientes():
	assert_true(menu.apply_button.disabled, "Sin cambios no hay nada que aplicar")
	menu.fullscreen_button.button_pressed = true
	assert_false(menu.apply_button.disabled)
	assert_true(menu.resolution_option.disabled, "En pantalla completa la resolucion no se usa")
	assert_eq(menu.status_label.text, SettingsMenu.TEXT_PENDING)
	menu.windowed_button.button_pressed = true
	assert_true(menu.apply_button.disabled, "Volver a lo que estaba en uso no deja cambios")
	assert_eq(menu.status_label.text, "")

func test_cerrar_sin_aplicar_descarta_la_seleccion():
	menu.fullscreen_button.button_pressed = true
	menu.close()
	await menu.open()
	assert_eq(menu.selected_fullscreen, ResolutionManager.is_fullscreen)
	assert_true(menu.apply_button.disabled)

func test_aplicar_cambia_la_resolucion_y_guarda():
	var otra = 0 if menu.resolutions[0] != ResolutionManager.current_resolution else 1
	menu.resolution_option.select(otra)
	menu.resolution_option.item_selected.emit(otra)
	assert_false(menu.apply_button.disabled)
	menu._on_apply_pressed()
	assert_eq(ResolutionManager.current_resolution, menu.resolutions[otra])
	assert_eq(menu.status_label.text, SettingsMenu.TEXT_APPLIED)
	assert_true(menu.apply_button.disabled)
	var config = ConfigFile.new()
	assert_eq(config.load(TEST_PATH), OK)
	assert_eq(config.get_value("display", "resolution_x"), menu.resolutions[otra].x)
	# Este test si cambia la ventana: se deja como estaba
	ResolutionManager.set_resolution(_res, _fs)

func test_volumen_se_aplica_al_instante_y_se_guarda_al_cerrar():
	menu.volume_slider.value = 0.5
	assert_eq(menu.volume_value.text, "50%")
	var bus = AudioServer.get_bus_index("Master")
	assert_almost_eq(db_to_linear(AudioServer.get_bus_volume_db(bus)), 0.5, 0.01)
	menu.close()
	var config = ConfigFile.new()
	assert_eq(config.load(TEST_PATH), OK)
	assert_almost_eq(float(config.get_value("audio", "master_volume")), 0.5, 0.01)

func test_volumen_cero_silencia_el_bus():
	menu.volume_slider.value = 0.0
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")))
	assert_eq(menu.volume_value.text, "0%")
	menu.volume_slider.value = 0.3
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")))

func test_restablecer_carga_valores_por_defecto():
	menu.fullscreen_button.button_pressed = true
	menu.volume_slider.value = 0.2
	menu.reset_button.pressed.emit()
	assert_false(menu.selected_fullscreen)
	assert_eq(menu.selected_resolution, SettingsMenu.DEFAULT_RESOLUTION)
	assert_almost_eq(menu.volume_slider.value, SettingsMenu.DEFAULT_VOLUME, 0.01)

func test_la_resolucion_base_siempre_se_ofrece():
	assert_has(menu.resolutions, SettingsMenu.DEFAULT_RESOLUTION)

func test_no_hay_resoluciones_casi_iguales():
	var lista = SettingsMenu.AVAILABLE_RESOLUTIONS
	for i in range(lista.size()):
		for j in range(i + 1, lista.size()):
			var a: Vector2i = lista[i]
			var b: Vector2i = lista[j]
			var casi_iguales = absi(a.x - b.x) <= 16 and absi(a.y - b.y) <= 16
			assert_false(casi_iguales, "%s y %s son practicamente la misma" % [a, b])

func test_etiquetas_de_proporcion():
	assert_eq(SettingsMenu.aspect_name(Vector2i(1920, 1080)), "16:9")
	assert_eq(SettingsMenu.aspect_name(Vector2i(1360, 768)), "16:9")
	assert_eq(SettingsMenu.aspect_name(Vector2i(1920, 1200)), "16:10")
	assert_eq(SettingsMenu.aspect_name(Vector2i(2560, 1080)), "21:9")
	assert_eq(SettingsMenu.resolution_label(Vector2i(1600, 900)), "1600 x 900  (16:9)")

func test_selector_de_dificultad():
	var previa = GlobalConfig.bot_difficulty
	menu.difficulty_buttons["hard"].button_pressed = true
	assert_eq(GlobalConfig.bot_difficulty, "hard")
	assert_eq(menu.difficulty_hint.text, SettingsMenu.DIFFICULTY_HINTS["hard"])
	assert_false(menu.difficulty_buttons["normal"].button_pressed)
	menu.close()
	var config = ConfigFile.new()
	config.load(TEST_PATH)
	assert_eq(config.get_value("game", "bot_difficulty"), "hard")
	menu.reset_button.pressed.emit()
	assert_eq(GlobalConfig.bot_difficulty, "normal")
	GlobalConfig.set_bot_difficulty(previa)

func test_dificultad_invalida_vuelve_a_normal():
	var previa = GlobalConfig.bot_difficulty
	GlobalConfig.set_bot_difficulty("imposible")
	assert_eq(GlobalConfig.bot_difficulty, "normal")
	GlobalConfig.set_bot_difficulty(previa)
