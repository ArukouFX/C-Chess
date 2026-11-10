extends GutTest

func after_each():
	GlobalConfig.reset_to_defaults()

func test_reset_to_defaults_reinicia_todos_los_modos():
	GlobalConfig.bot_disabled = true
	GlobalConfig.is_multiplayer = true
	GlobalConfig.load_save = true
	GlobalConfig.tutorial_mode = true
	GlobalConfig.challenge_mode = true
	GlobalConfig.selected_challenge_id = "escape_2"

	GlobalConfig.reset_to_defaults()

	assert_false(GlobalConfig.bot_disabled)
	assert_false(GlobalConfig.is_multiplayer)
	assert_false(GlobalConfig.load_save)
	assert_false(GlobalConfig.tutorial_mode, "Un tutorial anterior no debe afectar a la partida siguiente")
	assert_false(GlobalConfig.challenge_mode, "Un desafio anterior no debe afectar a la partida siguiente")
	assert_eq(GlobalConfig.selected_challenge_id, "")

func test_reset_deja_los_mismos_valores_que_al_iniciar():
	var limpio = load("res://src/core/GlobalConfig.gd").new()
	GlobalConfig.tutorial_mode = true
	GlobalConfig.selected_challenge_id = "horse_1"
	GlobalConfig.reset_to_defaults()

	for campo in ["bot_disabled", "is_multiplayer", "load_save", "tutorial_mode", "challenge_mode", "selected_challenge_id"]:
		assert_eq(GlobalConfig.get(campo), limpio.get(campo), "Campo distinto tras el reinicio: " + campo)
	limpio.free()
