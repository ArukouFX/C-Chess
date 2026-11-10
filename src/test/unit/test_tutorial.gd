extends GutTest

var TutorialScene = preload("res://src/tutorial/tutorial_scene.tscn")
var manager
var gm

func before_each():
	# Nunca tocar la partida guardada real del jugador
	SaveManager.SAVE_PATH = "user://test_savegame.json"
	GlobalConfig.reset_to_defaults()
	var escena = TutorialScene.instantiate()
	autofree(escena)
	get_tree().root.add_child(escena)
	for i in range(8):
		await get_tree().process_frame
	manager = escena.get_node("TutorialManager")
	gm = escena.get_node("GameManager")

func after_each():
	GlobalConfig.reset_to_defaults()

func _ir_al_nivel(objetivo: String) -> int:
	for i in range(manager.levels.size()):
		if manager.levels[i]["objective"] == objetivo:
			await manager._load_level(i)
			await get_tree().process_frame
			return i
	return -1

func _pieza_objetivo() -> Node:
	return manager._find_piece_by_id(manager._target_piece_ids[0])

func _ejecutar(pieza: Node, programa: Array) -> void:
	gm.save_piece_program(pieza, programa)
	await gm.execute_turn_and_switch()

# --- Limites del tablero ---

func test_limites_no_se_aprueba_con_un_solo_paso():
	assert_ne(await _ir_al_nivel("respect_board_limits"), -1)
	watch_signals(manager)
	await _ejecutar(_pieza_objetivo(), [{"type": "move_l"}])
	assert_signal_not_emitted(manager, "objective_completed", "Un paso no intenta salir del tablero")

func test_limites_no_se_aprueba_con_otro_bloque():
	await _ir_al_nivel("respect_board_limits")
	watch_signals(manager)
	await _ejecutar(_pieza_objetivo(), [{"type": "move_f"}, {"type": "move_f"}])
	assert_signal_not_emitted(manager, "objective_completed")

func test_limites_se_aprueba_al_intentar_salir():
	await _ir_al_nivel("respect_board_limits")
	watch_signals(manager)
	var peon = _pieza_objetivo()
	await _ejecutar(peon, [{"type": "move_l"}, {"type": "move_l"}])
	assert_eq(Vector2i(peon.board_position), Vector2i(0, 6), "Queda frenado en el borde")
	assert_signal_emitted(manager, "objective_completed")

# --- Reintentar durante una ejecucion ---

func test_reintentar_no_recarga_durante_una_ejecucion():
	await _ir_al_nivel("respect_board_limits")
	var antes = _pieza_objetivo()
	gm.execution_phase = true
	manager._on_retry_pressed()
	manager._on_next_pressed()
	await get_tree().process_frame
	assert_true(is_instance_valid(antes) and not antes.is_queued_for_deletion(), "La pieza no debe liberarse a mitad de la ejecucion")
	gm.execution_phase = false

	manager._on_retry_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(antes) and not antes.is_queued_for_deletion(), "Fuera de la ejecucion, reintentar recarga el nivel")

# --- Bloques entre niveles ---

func test_los_loops_no_pasan_al_nivel_siguiente():
	var idx = await _ir_al_nivel("create_loop")
	var loop_id = BlockSystem.create_loop_block([{"type": "move_f"}, {"type": "move_f"}], 5, "L", "white")
	await manager._load_level(idx + 1)
	assert_true(BlockSystem.get_block_info(loop_id).is_empty())

func test_los_niveles_no_guardan_estado_en_sus_datos():
	await _ir_al_nivel("create_loop")
	assert_false(manager._target_piece_ids.is_empty())
	for level in manager.levels:
		for key in level.keys():
			assert_false(str(key).begins_with("_"), "Estado de ejecucion en el nivel: " + str(key))
