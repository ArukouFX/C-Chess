extends GutTest

# Partidas completas contra el bot con programas blancos al azar (semilla
# fija, asi un fallo se puede repetir). Despues de cada turno se revisan los
# invariantes del tablero.

var TestMainScene = preload("res://src/test/fixture/test_main.tscn")
const MOVIMIENTOS := ["move_f", "move_b", "move_l", "move_r", "move_fl", "move_fr", "move_bl", "move_br"]
const TURNOS := 25

var escena: Node
var gm

func before_each():
	SaveManager.SAVE_PATH = "user://test_savegame.json"
	GlobalConfig.reset_to_defaults()
	GlobalConfig.bot_disabled = false  # contra el bot
	Engine.time_scale = 20.0

func after_each():
	Engine.time_scale = 1.0
	if escena and is_instance_valid(escena):
		escena.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	GlobalConfig.reset_to_defaults()

func _vivas() -> Array:
	return gm.pieces_container.get_children().filter(func(p): return not p.get_meta("is_dead", false) and not p.is_queued_for_deletion())

func _revisar_invariantes(turno: int) -> void:
	var ocupadas := {}
	for p in _vivas():
		var c := Vector2i(p.board_position)
		assert_eq(c, Vector2i(p.virtual_board_position), "T%d: %s con posiciones desincronizadas" % [turno, p.piece_id])
		assert_true(c.x >= 0 and c.x < 8 and c.y >= 0 and c.y < 8, "T%d: %s fuera del tablero %s" % [turno, p.piece_id, str(c)])
		assert_false(ocupadas.has(c), "T%d: %s y %s en la misma casilla %s" % [turno, p.piece_id, ocupadas.get(c, ""), str(c)])
		ocupadas[c] = p.piece_id
		var esperado = gm._board_to_world_position(Vector2(c))
		assert_almost_eq(p.position, esperado, Vector2(1, 1), "T%d: %s se dibuja fuera de su casilla" % [turno, p.piece_id])
	if not gm.game_over:
		assert_eq(gm.current_turn, "white", "T%d: despues del bot vuelve a jugar el blanco" % turno)

# Programa blanco al azar que entra en la RAM de la pieza
func _programa_al_azar(rng: RandomNumberGenerator, pieza) -> Array:
	var programa := []
	for i in range(rng.randi_range(1, 4)):
		var candidato = programa + [{"type": MOVIMIENTOS[rng.randi_range(0, 7)]}]
		if BlockSystem.calculate_ram_usage(candidato) > pieza.available_ram:
			break
		programa = candidato
	return programa

func _jugar_partida(semilla: int) -> void:
	escena = TestMainScene.instantiate()
	get_tree().root.add_child(escena)
	for i in range(6):
		await get_tree().process_frame
	gm = escena.get_node("GameManager")

	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	for turno in range(TURNOS):
		if gm.game_over:
			break
		var blancas = _vivas().filter(func(p): return p.piece_color == "white")
		var pieza = blancas[rng.randi_range(0, blancas.size() - 1)]
		var programa = _programa_al_azar(rng, pieza)
		if programa.is_empty():
			continue
		gm.save_piece_program(pieza, programa)
		await gm.execute_turn_and_switch()
		for i in range(3):
			await get_tree().process_frame
		_revisar_invariantes(turno + 1)
	gut.p("Semilla %d: %d piezas vivas, game_over=%s, ganador=%s" % [semilla, _vivas().size(), gm.game_over, gm.winner])

func test_partida_semilla_1():
	await _jugar_partida(1)

func test_partida_semilla_2():
	await _jugar_partida(2)

func test_partida_semilla_3():
	await _jugar_partida(3)
