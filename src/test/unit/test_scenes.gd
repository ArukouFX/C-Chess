extends GutTest

# Estructura de las escenas de juego. Se instancian sin agregarlas al arbol,
# asi no arranca la partida ni la musica.

const BASE := "res://src/scenes/game_board.tscn"

# Nodos que los scripts buscan por ruta
const NODOS_COMUNES := [
	"BackGround/BackGround", "Turn/TurnDisplay", "Table/Board", "Pieces",
	"Camera/Camera2D", "GameManager", "SetProgramming", "CanvasLayer2",
	"Buttons/VBoxContainer/Back", "Buttons/VBoxContainer/SettingsButton",
	"Buttons/VBoxContainer/Exit", "TransitionLayer/TransitionRect",
]

func _revisar_nodos(ruta: String) -> void:
	var escena: Node = load(ruta).instantiate()
	assert_eq(escena.name, "Main", "Varios scripts buscan /root/Main")
	for nodo in NODOS_COMUNES:
		assert_not_null(escena.get_node_or_null(nodo), "%s no tiene %s" % [ruta, nodo])
	escena.free()

func test_la_base_tiene_todos_los_nodos():
	_revisar_nodos(BASE)

func test_main_hereda_de_la_base():
	var estado: SceneState = load("res://main.tscn").get_state()
	var base = estado.get_node_instance(0)
	assert_not_null(base, "La raiz de main.tscn debe ser una instancia de la base")
	assert_eq(base.resource_path, BASE)
	_revisar_nodos("res://main.tscn")

func _hereda_de_la_base(ruta: String) -> void:
	var estado: SceneState = load(ruta).get_state()
	var base = estado.get_node_instance(0)
	assert_not_null(base, "%s no es una escena heredada" % ruta)
	if base:
		assert_eq(base.resource_path, BASE, "%s hereda de otra escena" % ruta)

# Tutorial y desafio: ocultan el turno y los botones, y suben la capa de la
# interfaz para que quede sobre su panel de instrucciones
func _revisar_modo_practica(ruta: String, manager: String, panel: String) -> void:
	_hereda_de_la_base(ruta)
	_revisar_nodos(ruta)
	var escena: Node = load(ruta).instantiate()
	assert_not_null(escena.get_node_or_null(manager), "Falta " + manager)
	assert_not_null(escena.get_node_or_null(panel + "/InstructionPanel/VBox/ButtonsRow/NextButton"), "Falta el panel " + panel)
	assert_false(escena.get_node("Turn").visible, "Turn oculto")
	assert_false(escena.get_node("Buttons").visible, "Buttons oculto")
	assert_eq(escena.get_node("SetProgramming").layer, 2)
	escena.free()

# Paso 2
func test_tutorial_hereda_de_la_base():
	_revisar_modo_practica("res://src/tutorial/tutorial_scene.tscn", "TutorialManager", "TutorialUI")

func test_desafio_hereda_de_la_base():
	_revisar_modo_practica("res://src/challenge/challenge_scene.tscn", "ChallengeManager", "ChallengeUI")

# Paso 3
func test_escena_de_tests_hereda_de_la_base():
	_hereda_de_la_base("res://src/test/fixture/test_main.tscn")
	_revisar_nodos("res://src/test/fixture/test_main.tscn")

# Paso 4
func test_game_over_esta_junto_a_su_script():
	assert_true(ResourceLoader.exists("res://src/ui/menus/game_over_screen.tscn"))
	assert_false(ResourceLoader.exists("res://src/ui/game_over_screen.tscn"), "Quedo una copia en la ubicacion vieja")

# --- Musica ---

# La musica la reproduce el autoload MusicManager. Si una escena tuviera su
# propio reproductor, la pista volveria a empezar al cambiar de escena.
func test_ninguna_escena_tiene_reproductor_propio():
	for ruta in [BASE, "res://src/ui/menus/MainMenu.tscn"]:
		var escena: Node = load(ruta).instantiate()
		assert_null(escena.get_node_or_null("Music"), "%s todavia tiene su nodo Music" % ruta)
		for hijo in escena.get_children():
			assert_false(hijo is AudioStreamPlayer, "%s tiene un AudioStreamPlayer (%s)" % [ruta, hijo.name])
		escena.free()

func test_la_musica_la_reproduce_el_autoload():
	assert_not_null(get_node_or_null("/root/MusicManager"), "Falta el autoload MusicManager")
	assert_true(MusicManager.is_playing())
	assert_eq(MusicManager.player.stream, MusicManager.DEFAULT_TRACK)

func test_pedir_la_misma_pista_no_la_reinicia():
	var reproductor = MusicManager.player
	var pista = reproductor.stream
	MusicManager.play_music(pista)
	assert_eq(MusicManager.player, reproductor, "Sigue siendo el mismo reproductor")
	assert_true(MusicManager.is_playing())
