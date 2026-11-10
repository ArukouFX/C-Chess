extends Node

# Configuracion global del juego (autoload).
# Cada modo (partida, tutorial, desafio) activa sus flags al entrar.
# reset_to_defaults() los deja todos en su valor inicial; lo llama el menu
# principal, que es el punto de partida de todos los modos.

var bot_disabled: bool = false
var is_multiplayer: bool = false
var load_save: bool = false

# Dificultad del bot: "easy", "normal" o "hard". No es un flag de modo: es una
# preferencia del jugador, se guarda en settings.cfg y reset_to_defaults() no
# la toca.
const DIFFICULTIES: Array[String] = ["easy", "normal", "hard"]
const SETTINGS_PATH := "user://settings.cfg"
var bot_difficulty: String = "normal"

var tutorial_mode: bool = false
var challenge_mode: bool = false
var selected_challenge_id: String = ""

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		set_bot_difficulty(str(config.get_value("game", "bot_difficulty", "normal")))

func set_bot_difficulty(value: String) -> void:
	bot_difficulty = value if value in DIFFICULTIES else "normal"

func reset_to_defaults() -> void:
	bot_disabled = false
	is_multiplayer = false
	load_save = false
	tutorial_mode = false
	challenge_mode = false
	selected_challenge_id = ""
