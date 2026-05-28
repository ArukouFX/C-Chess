extends Window

class_name LoopNamePopup

signal loop_confirmed(loop_name)

@onready var line_edit = $HBoxContainer2/VBoxContainer/LineEdit
@onready var confirm_button = $HBoxContainer2/HBoxContainer/ConfirmButton
@onready var cancel_button = $HBoxContainer2/HBoxContainer/CancelButton

func _ready():
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(queue_free)
	close_requested.connect(queue_free)

func _on_confirm_pressed():
	var loop_name = line_edit.text.strip_edges()
	if loop_name.is_empty():
		loop_name = "Loop"
	emit_signal("loop_confirmed", loop_name)
	queue_free()
