extends Node

# MusicManager (autoload)
# Unico reproductor de musica del juego. Antes cada escena (menu, partida,
# tutorial, desafio) tenia su propio AudioStreamPlayer con la misma pista y
# autoplay: al cambiar de escena se destruia uno y se creaba otro, y la musica
# volvia a empezar. Un autoload no se destruye al cambiar de escena, asi que
# la pista sigue sonando sin cortes.

const DEFAULT_TRACK: AudioStream = preload("res://assets/music/chess beat.mp3")
const DEFAULT_VOLUME_DB := -5.0
const DEFAULT_PITCH := 0.9

var player: AudioStreamPlayer

func _ready():
	# Sigue sonando aunque el juego se pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.name = "Player"
	player.volume_db = DEFAULT_VOLUME_DB
	player.pitch_scale = DEFAULT_PITCH
	player.bus = "Master"  # el volumen del menu de opciones controla este bus
	add_child(player)
	_apply_saved_volume()
	play_music(DEFAULT_TRACK)

# El volumen elegido en el menu de opciones rige desde el inicio, aunque el
# menu no se abra en esta sesion
func _apply_saved_volume() -> void:
	var config := ConfigFile.new()
	if config.load(ResolutionManager.SETTINGS_PATH) != OK:
		return
	SettingsMenu.set_master_volume(float(config.get_value("audio", "master_volume", SettingsMenu.DEFAULT_VOLUME)))

# Si ya suena esa pista no hace nada: por eso cambiar de escena no la reinicia
func play_music(stream: AudioStream) -> void:
	if stream == null:
		return
	if player.stream == stream and player.playing:
		return
	if "loop" in stream:
		stream.loop = true
	player.stream = stream
	player.play()

func stop_music() -> void:
	player.stop()

func is_playing() -> bool:
	return player.playing
