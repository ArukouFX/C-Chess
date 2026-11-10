extends GutTest

var ChallengeScene = preload("res://src/challenge/challenge_scene.tscn")
var manager

func before_each():
	# Nunca tocar la partida guardada real del jugador
	SaveManager.SAVE_PATH = "user://test_savegame.json"
	GlobalConfig.reset_to_defaults()

func after_each():
	GlobalConfig.reset_to_defaults()

# Abre la escena de desafios en el desafio indicado y espera a que cargue
func _abrir_desafio(id: String) -> Node:
	GlobalConfig.selected_challenge_id = id
	var escena = ChallengeScene.instantiate()
	autofree(escena)
	get_tree().root.add_child(escena)
	for i in range(10):
		await get_tree().process_frame
	return escena.get_node("ChallengeManager")

# Primer desafio cuya base asigna un escape a alguna pieza
func _desafio_con_escape() -> Dictionary:
	for ch in ChallengeDatabase.get_all():
		for pdata in ch["player_pieces"] + ch["enemy_pieces"]:
			if pdata.has("escape"):
				return {"id": ch["id"], "role": pdata["role"]}
	return {}

func test_la_base_de_desafios_es_de_solo_lectura():
	assert_true(ChallengeDatabase.CHALLENGES.is_read_only())
	for ch in ChallengeDatabase.CHALLENGES:
		assert_true(ch.is_read_only(), "Desafio modificable: " + ch["id"])

func test_cargar_un_desafio_no_escribe_en_la_base():
	var primero: String = ChallengeDatabase.get_all()[0]["id"]
	manager = await _abrir_desafio(primero)
	assert_false(manager._player_ids.is_empty(), "El estado vive en el manager")
	for ch in ChallengeDatabase.get_all():
		for key in ch.keys():
			assert_false(str(key).begins_with("_"), "Estado de ejecucion en la base: %s.%s" % [ch["id"], key])

func test_roles_y_piezas_se_resuelven_desde_el_manager():
	var primero: Dictionary = ChallengeDatabase.get_all()[0]
	manager = await _abrir_desafio(primero["id"])
	for pdata in primero["player_pieces"]:
		var pid: String = manager._id_for_role(pdata["role"])
		assert_ne(pid, "")
		var pieza = manager._find_piece_by_id(pid)
		assert_not_null(pieza)
		assert_eq(manager._role_of(pieza), pdata["role"])

func test_el_escape_de_la_base_se_reutiliza_al_reintentar():
	var datos = _desafio_con_escape()
	if datos.is_empty():
		pending("Ningun desafio define escapes")
		return
	manager = await _abrir_desafio(datos["id"])
	var clave: String = datos["id"] + ":" + datos["role"]
	var primer_id: String = manager._escape_protocol_ids.get(clave, "")
	assert_ne(primer_id, "", "El escape se registra en el manager")

	await manager._load_challenge(manager.current_challenge_index)
	for i in range(3):
		await get_tree().process_frame
	assert_eq(manager._escape_protocol_ids.get(clave, ""), primer_id, "Reintentar no crea otro protocolo")

	var pieza = manager._find_piece_by_id(manager._id_for_role(datos["role"]))
	assert_true(pieza.defense_protocol_active)
	assert_true(pieza.defense_protocol_permanent)
