extends GutTest

# Juega cada desafio con la solucion documentada en challenge_database.gd y
# comprueba que se gana. Si un cambio en las reglas (RAM, escape, caballo...)
# deja un desafio sin solucion, este test lo detecta.

var ChallengeScene = preload("res://src/challenge/challenge_scene.tscn")
var manager
var gm
var resultado = null  # null: sin resolver; true/false: gano/perdio

func before_each():
	SaveManager.SAVE_PATH = "user://test_savegame.json"
	GlobalConfig.reset_to_defaults()
	resultado = null

func after_each():
	GlobalConfig.reset_to_defaults()

func _abrir(id: String) -> void:
	GlobalConfig.selected_challenge_id = id
	var escena = ChallengeScene.instantiate()
	autofree(escena)
	get_tree().root.add_child(escena)
	for i in range(10):
		await get_tree().process_frame
	manager = escena.get_node("ChallengeManager")
	gm = escena.get_node("GameManager")
	manager.challenge_resolved.connect(func(_i, won): resultado = won)

func _pieza(rol: String) -> Node:
	return manager._find_piece_by_id(manager._id_for_role(rol))

func _loop(pasos: Array) -> Dictionary:
	var bloques := pasos.map(func(t): return {"type": t})
	return {"type": BlockSystem.create_loop_block(bloques, BlockSystem.calculate_ram_usage(bloques), "L", "white")}

func _escape(paso: String) -> Dictionary:
	var bloques := [{"type": paso}]
	return {"type": BlockSystem.create_escape_protocol(bloques, BlockSystem.calculate_ram_usage(bloques) * 2, "E", "white")}

# Juega un turno como lo hace la interfaz: valida la RAM, guarda y ejecuta
func _jugar(rol: String, programa: Array) -> void:
	var pieza = _pieza(rol)
	assert_not_null(pieza, "No existe la pieza " + rol)
	var ram := BlockSystem.calculate_ram_usage(programa)
	assert_lte(ram, pieza.available_ram, "La solucion de %s no entra en la RAM (%d/%d)" % [rol, ram, pieza.available_ram])
	gm.save_piece_program(pieza, programa)
	await gm.execute_turn_and_switch()
	for i in range(5):
		await get_tree().process_frame

func test_compresion_de_memoria():
	await _abrir("ram_efficiency_2")
	await _jugar("target", [_loop(["move_f", "move_f", "move_f", "move_f"]), _loop(["move_f", "move_f", "move_f"])])
	assert_eq(resultado, true)

func test_el_escudo():
	await _abrir("escape_2")
	await _jugar("target", [_escape("move_fl")])
	assert_null(resultado, "Despues del turno 1 el desafio sigue")
	assert_eq(Vector2i(_pieza("threat").board_position), Vector2i(3, 6), "La torre se frena en la casilla que ataco")
	await _jugar("target", [{"type": "move_br"}])
	assert_eq(resultado, true)

func test_salto_exacto():
	await _abrir("horse_1")
	await _jugar("target", [{"type": "move_f"}, {"type": "move_fr"}, {"type": "move_fr"}, {"type": "move_f"}])
	assert_eq(resultado, true)

func test_emboscada():
	await _abrir("ambush_1")
	await _jugar("target", [{"type": "move_fr"}, {"type": "move_fr"}, _escape("move_l")])
	assert_null(resultado, "Despues del turno 1 el desafio sigue")
	await _jugar("target", [{"type": "move_r"}])
	assert_eq(resultado, true)

func test_mate_en_el_rincon():
	await _abrir("checkmate_2")
	await _jugar("support", [{"type": "move_fl"}, {"type": "move_fl"}, {"type": "move_f"}])
	assert_null(resultado)
	await _jugar("target", [_loop(["move_f", "move_f", "move_f", "move_f"]), _loop(["move_f", "move_f", "move_f"])])
	assert_eq(resultado, true)

# Sin bloquear el escape, el rey enemigo se salva (el desafio pide bloquearlo)
func test_mate_en_el_rincon_sin_bloquear_no_se_gana():
	await _abrir("checkmate_2")
	await _jugar("support", [{"type": "move_f"}])
	await _jugar("target", [_loop(["move_f", "move_f", "move_f", "move_f"]), _loop(["move_f", "move_f", "move_f"])])
	assert_ne(resultado, true, "El escape permanente debe salvar al rey")
