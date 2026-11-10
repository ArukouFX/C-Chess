extends Window
class_name NamePopup

# Ventana para ponerle nombre a un bloque nuevo (loop o escape).
# Reemplaza a loop_name_popup y escape_name_popup, que solo cambiaban el texto.
#
# Uso:
#   var popup = NamePopupScene.instantiate()
#   popup.setup("Nombre del Loop:", "Loop")
#   add_child(popup)
#   popup.name_confirmed.connect(_on_nombre_elegido)
#   popup.popup_centered()

signal name_confirmed(chosen_name: String)

@onready var prompt_label: Label = $HBoxContainer2/VBoxContainer/Label
@onready var line_edit: LineEdit = $HBoxContainer2/VBoxContainer/LineEdit
@onready var confirm_button: Button = $HBoxContainer2/HBoxContainer/ConfirmButton
@onready var cancel_button: Button = $HBoxContainer2/HBoxContainer/CancelButton

var _prompt: String = "Nombre:"
var _default_name: String = ""

# Se puede llamar antes o despues de agregar la ventana al arbol
func setup(prompt: String, default_name: String) -> void:
	_prompt = prompt
	_default_name = default_name
	if is_node_ready():
		_apply_texts()

func _ready():
	_apply_texts()
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(queue_free)
	close_requested.connect(queue_free)
	# Enter confirma
	line_edit.text_submitted.connect(func(_text): _on_confirm_pressed())
	line_edit.grab_focus.call_deferred()

func _apply_texts() -> void:
	prompt_label.text = _prompt
	line_edit.placeholder_text = _default_name

func _on_confirm_pressed() -> void:
	var chosen := line_edit.text.strip_edges()
	if chosen.is_empty():
		chosen = _default_name
	name_confirmed.emit(chosen)
	queue_free()
