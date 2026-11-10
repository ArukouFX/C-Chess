extends Control

@onready var label_title = $VBoxContainer/LabelTitle
@onready var label_winner = $VBoxContainer/LabelWinner
@onready var restart_button = $VBoxContainer/ButtonRestart

func setup(winner_color: String):

	label_title.text = "GAME OVER"

	label_winner.text = winner_color.to_upper() + " WINS"

	if winner_color == "white":
		label_winner.modulate = Color.WHITE
	else:
		label_winner.modulate = Color.RED

func _on_button_restart_pressed():
	get_tree().reload_current_scene()
