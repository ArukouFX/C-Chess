extends Control

class_name DifficultySelect

# Ventana para elegir la dificultad del bot al empezar una partida nueva.
# Usa el mismo tema que el menu de opciones. La eleccion se guarda en
# settings.cfg, asi la proxima vez aparece marcada la ultima usada.

signal difficulty_chosen(level: String)
signal cancelled

# Archivo de configuracion; los tests usan otro para no tocar el real
var settings_path: String = GlobalConfig.SETTINGS_PATH

@onready var panel: PanelContainer = $Center/Panel
@onready var level_buttons := {
	"easy": $Center/Panel/VBox/Levels/EasyRow/EasyButton,
	"normal": $Center/Panel/VBox/Levels/NormalRow/NormalButton,
	"hard": $Center/Panel/VBox/Levels/HardRow/HardButton,
}
@onready var level_hints := {
	"easy": $Center/Panel/VBox/Levels/EasyRow/EasyHint,
	"normal": $Center/Panel/VBox/Levels/NormalRow/NormalHint,
	"hard": $Center/Panel/VBox/Levels/HardRow/HardHint,
}
@onready var cancel_button: Button = $Center/Panel/VBox/CancelButton

func _ready() -> void:
	visible = false
	for level in level_buttons:
		level_buttons[level].pressed.connect(_choose.bind(level))
		level_hints[level].text = SettingsMenu.DIFFICULTY_HINTS[level]
	cancel_button.pressed.connect(close)

func open() -> void:
	if not is_node_ready():
		await ready
	visible = true
	modulate.a = 0.0
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.96, 0.96)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# El foco arranca en la ultima dificultad usada
	level_buttons.get(GlobalConfig.bot_difficulty, level_buttons["normal"]).grab_focus()

func close() -> void:
	if not visible:
		return
	visible = false
	cancelled.emit()

func _choose(level: String) -> void:
	GlobalConfig.set_bot_difficulty(level)
	_save_difficulty()
	visible = false
	difficulty_chosen.emit(level)

func _save_difficulty() -> void:
	var config := ConfigFile.new()
	config.load(settings_path)  # conserva pantalla y volumen
	config.set_value("game", "bot_difficulty", GlobalConfig.bot_difficulty)
	var err := config.save(settings_path)
	if err != OK:
		push_error("No se pudo guardar la dificultad: %s" % error_string(err))

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
